# Audit Sink — Operator Configuration

Conductor emits audit events to external SIEM (Wazuh, Splunk, syslog, file, HTTP webhook) when `audit_sink.enabled = true` in `conductor-state.json`. This document explains how to configure it.

## Quick start

1. Pick a transport (see §Transports below)
2. Edit your project's `conductor-state.json` and add the `audit_sink` block:

```json
{
  "audit_sink": {
    "enabled": true,
    "transport": "file",
    "syslog_target": "/var/log/conductor/audit.jsonl",
    "events_to_emit": [
      "phase_transition",
      "gate_pass",
      "gate_block",
      "kill_switch",
      "escalation",
      "gemini_validation_fail",
      "prohibited_behavior",
      "cost_threshold",
      "workflow_complete",
      "nhi_spawn",
      "nhi_terminate"
    ],
    "emit_count": 0
  }
}
```

**This is the recommended default** — `file` transport paired with a Wazuh agent that tails the JSONL is the production-tested pattern. It's authenticated (TCP 1514 mTLS to manager), reliable (TCP not UDP), encrypted, and integrates with Wazuh's existing dashboards. See "Wazuh agent setup (recommended)" below.

3. Save the file. The PostToolUse hook fires immediately. New events emit on the next state change.
4. Verify in your SIEM. Verify `audit_sink.emit_count` increments. If `audit_sink.last_error` appears, fix the transport config.

## How it works

- Hook: `hooks/scripts/post-state-write.sh` calls `hooks/scripts/lib/audit_emitter.py` on every conductor-state.json write
- Emitter compares current state to a cached prior snapshot (`.conductor-cache/prior_state.json` per project, `chmod 600`)
- New events are detected, filtered by `events_to_emit[]`, formatted as JSON, and sent via the configured transport
- `audit_sink.emit_count` updates after each successful emit; `audit_sink.last_error` records the most recent failure
- **Fail-open**: emitter errors NEVER block the state write or the workflow

## Transports

### `syslog-udp` (default; lowest setup cost)
```json
"transport": "syslog-udp",
"syslog_target": "wazuh.example.com:514"
```
- Wire format: RFC 5424-ish — `<priority>app_name PID {JSON}`
- Wazuh ingests JSON natively after a small decoder (see Wazuh setup below)
- Pro: zero TLS/auth setup. Con: UDP loss possible on busy networks; not encrypted

### `syslog-tcp`
```json
"transport": "syslog-tcp",
"syslog_target": "wazuh.example.com:601"
```
- Same wire format as UDP, reliable delivery
- Pro: no loss. Con: still unencrypted

### `syslog-tls`
```json
"transport": "syslog-tls",
"syslog_target": "wazuh.example.com:6514"
```
- TLS-wrapped TCP syslog
- Pro: encrypted in transit. Con: requires CA-trusted cert on Wazuh receiver

### `http`
```json
"transport": "http",
"syslog_target": "https://siem.example.com/conductor/ingest",
"auth": { "hmac_secret_env": "CONDUCTOR_AUDIT_HMAC_SECRET" }
```
- POSTs JSON event to webhook
- Optional HMAC-SHA256 signature in `X-Conductor-Signature` header (set the env var)
- Use for: Splunk HEC, custom webhook receivers, Wazuh API endpoints
- 5-second timeout

### `file`
```json
"transport": "file",
"syslog_target": "/var/log/conductor/audit.jsonl"
```
- Appends one JSON line per event
- Use for: local Wazuh agent that monitors files; air-gapped environments; testing
- Directory created if missing

## Event types you can subscribe to

| Event | Severity | When |
|-------|----------|------|
| `phase_transition` | info | `current_phase.number` changes |
| `gate_pass` | info | a `verification_status.<gate>` becomes `pass` |
| `gate_block` | error | a `verification_status.<gate>` becomes `fail` |
| `gate_decision` | info | any `verification_status.<gate>` changes (catches advisory + skipped too) |
| `nhi_spawn` | info | new entry appended to `agent_instances[]` |
| `nhi_terminate` | info | existing NHI status → completed/failed/killed |
| `kill_switch` | critical | NHI status → killed |
| `handoff` | info | new entry appended to `handoff_history[]` |
| `gemini_validation` | info | new Gemini validation completed (verdict PASS) |
| `gemini_validation_fail` | warning | new Gemini validation FAIL or PARTIAL |
| `escalation` | error | new entry appended to `failed_tasks[]` |
| `prohibited_behavior` | critical | reserved — emitted by future kill-switch logic |
| `cost_threshold` | warning | `cost_tracking.budget_exceeded` flips false→true |
| `recovery_attempt` | notice | new `recovery.recovery_history[]` entry |
| `recovery_success` | notice | recovery event with `outcome: success` |
| `recovery_exhausted` | error | recovery event with `outcome: escalated` |
| `compliance_overview_generated` | notice | reserved — emitted by future compliance agent integration |
| `workflow_complete` | notice | `current_phase.number == 7 && current_step.status == "completed"` |

## Recommended event sets

### Minimum (security-only, low volume)
```json
["gate_block", "kill_switch", "escalation", "prohibited_behavior", "cost_threshold", "gemini_validation_fail"]
```
~5-15 events per workflow; only failure paths.

### Standard (production)
```json
["phase_transition", "gate_pass", "gate_block", "gate_decision", "kill_switch", "escalation", "gemini_validation_fail", "prohibited_behavior", "cost_threshold", "workflow_complete"]
```
~20-40 events per workflow.

### Full (compliance-grade, every action)
All event types above. ~50-200 events per workflow. Required for SOC 2 evidence trail or regulatory audit reconstruction.

## Wazuh setup

### 1. Receive syslog at Wazuh manager
Edit `/var/ossec/etc/ossec.conf`:
```xml
<remote>
  <connection>syslog</connection>
  <port>514</port>
  <protocol>udp</protocol>
  <allowed-ips>10.0.0.0/8</allowed-ips> <!-- example: your internal CIDR -->
  <local_ip>0.0.0.0</local_ip>
</remote>
```
Reload: `systemctl restart wazuh-manager`.

### 2. Add a JSON decoder
Edit `/var/ossec/etc/decoders/local_decoder.xml`:
```xml
<decoder name="conductor">
  <prematch>^conductor</prematch>
</decoder>

<decoder name="conductor-json">
  <parent>conductor</parent>
  <plugin_decoder offset="after_parent">JSON_Decoder</plugin_decoder>
</decoder>
```

### 3. Add rules to alert on critical events
Edit `/var/ossec/etc/rules/local_rules.xml`:
```xml
<group name="conductor,">
  <rule id="100100" level="3">
    <decoded_as>conductor</decoded_as>
    <description>Conductor audit event</description>
  </rule>

  <rule id="100101" level="10">
    <if_sid>100100</if_sid>
    <field name="event_type">prohibited_behavior</field>
    <description>Conductor: prohibited behavior detected (kill-switch triggered)</description>
    <group>authentication_failure,attack,</group>
  </rule>

  <rule id="100102" level="9">
    <if_sid>100100</if_sid>
    <field name="event_type">kill_switch</field>
    <description>Conductor: agent killed</description>
  </rule>

  <rule id="100103" level="7">
    <if_sid>100100</if_sid>
    <field name="event_type">gate_block</field>
    <description>Conductor: phase gate blocked workflow</description>
  </rule>

  <rule id="100104" level="6">
    <if_sid>100100</if_sid>
    <field name="event_type">escalation</field>
    <description>Conductor: task escalated to operator (dead-letter)</description>
  </rule>

  <rule id="100105" level="5">
    <if_sid>100100</if_sid>
    <field name="event_type">cost_threshold</field>
    <description>Conductor: cost budget exceeded</description>
  </rule>

  <rule id="100106" level="5">
    <if_sid>100100</if_sid>
    <field name="event_type">gemini_validation_fail</field>
    <description>Conductor: Gemini validation failed</description>
  </rule>
</group>
```
Reload: `systemctl restart wazuh-manager`.

### 4. Verify
```bash
# From the conductor host, send a test event:
echo '<134>conductor-test 1234 {"event_type":"test","payload":{}}' | nc -u -w1 wazuh.example.com 514

# On Wazuh:
tail -f /var/ossec/logs/archives/archives.log | grep conductor
```



## Wazuh agent setup (recommended pattern)

Verified 2026-04-18 against Wazuh 4.14.3. Pattern: `file` transport on the conductor host + Wazuh agent that tails the JSONL.

### On the conductor host (where conductor runs)

1. Install Wazuh agent (per https://documentation.wazuh.com/current/installation-guide/wazuh-agent/index.html). Linux:

```bash
WAZUH_MANAGER="manager.example.com" apt-get install wazuh-agent
# or yum/rpm equivalent
```

2. Add the conductor JSONL as a localfile in `/var/ossec/etc/ossec.conf`:

```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/conductor/audit.jsonl</location>
</localfile>
```

3. Create the JSONL directory and start the agent:

```bash
mkdir -p /var/log/conductor
touch /var/log/conductor/audit.jsonl
chmod 644 /var/log/conductor/audit.jsonl
systemctl restart wazuh-agent
```

### On the Wazuh manager

1. Enable filebeat to ship `/var/ossec/logs/archives/archives.json` to the indexer. In `/etc/filebeat/filebeat.yml` (host-mounted in dockerized Wazuh):

```yaml
filebeat.modules:
  - module: wazuh
    alerts:
      enabled: true
    archives:
      enabled: true   # CHANGE FROM false
```

Restart filebeat (or the manager container if filebeat.yml is bind-mounted).

2. Drop conductor alert rules into a file that loads BEFORE the Suricata generic JSON rule. Filename `0050_conductor_rules.xml` works (Wazuh loads rules in alphabetical order):

```xml
<group name="conductor,">

  <rule id="100200" level="3">
    <decoded_as>json</decoded_as>
    <field name="source">conductor-plugin</field>
    <description>Conductor audit event</description>
    <options>no_full_log</options>
  </rule>

  <rule id="100201" level="12">
    <if_sid>100200</if_sid>
    <field name="event_type">prohibited_behavior</field>
    <description>Conductor: PROHIBITED BEHAVIOR — kill-switch triggered</description>
    <group>attack,</group>
  </rule>

  <rule id="100202" level="10">
    <if_sid>100200</if_sid>
    <field name="event_type">kill_switch</field>
    <description>Conductor: agent killed</description>
  </rule>

  <rule id="100203" level="7">
    <if_sid>100200</if_sid>
    <field name="event_type">gate_block</field>
    <description>Conductor: phase gate blocked workflow</description>
  </rule>

  <rule id="100204" level="6">
    <if_sid>100200</if_sid>
    <field name="event_type">escalation</field>
    <description>Conductor: task escalated</description>
  </rule>

  <rule id="100205" level="5">
    <if_sid>100200</if_sid>
    <field name="event_type">cost_threshold</field>
    <description>Conductor: cost budget exceeded</description>
  </rule>

  <rule id="100206" level="5">
    <if_sid>100200</if_sid>
    <field name="event_type">gemini_validation_fail</field>
    <description>Conductor: Gemini validation failed</description>
  </rule>

  <rule id="100207" level="4">
    <if_sid>100200</if_sid>
    <field name="event_type">workflow_complete</field>
    <description>Conductor: workflow completed</description>
  </rule>

  <rule id="100208" level="3">
    <if_sid>100200</if_sid>
    <field name="event_type">gate_pass</field>
    <description>Conductor: gate passed</description>
  </rule>

</group>
```

**Important**: rule IDs 100100-100199 are used by `github_webhook_rules.xml` in default Wazuh installs. Use 100200+ to avoid conflict. Reload manager: `/var/ossec/bin/wazuh-control restart`.

3. Build the dashboard against `wazuh-archives-*` index. Ready-made dashboard at `https://localhost:9000/app/dashboards#/view/conductor-audit-dashboard` (after SSH tunnel to manager) with these 5 panels:

- Per-project event count (donut)
- Events over time (line, grouped by project)
- Event type breakdown (horizontal bar, stacked by project)
- Severity by project (heatmap)
- Recent events (auto-refresh table)

All panels filtered to `data.source : "conductor-plugin"`.

### Why this beats syslog-udp

| Property | syslog-udp | file + Wazuh agent |
|---|---|---|
| Authentication | None (or HMAC if added) | mTLS via Wazuh agent enrollment |
| Encryption in transit | None (TLS only with syslog-tls) | AES-256 (Wazuh agent built-in) |
| Reliability | UDP — packets can drop | TCP, queued retry on disconnect |
| Identity | Source IP only | Per-agent identity with auth key |
| SIEM dashboards | Manual | Built into Wazuh dashboard |
| Setup complexity | None on producer; firewall + decoder on receiver | Agent install once; everything else automatic |

## Splunk setup (HEC transport)

```json
"transport": "http",
"syslog_target": "https://splunk.example.com:8088/services/collector/event",
"auth": { "hmac_secret_env": "SPLUNK_HEC_TOKEN" }
```
**Note:** the current `http` transport sends `X-Conductor-Signature` (HMAC). Splunk HEC expects `Authorization: Splunk <token>`. Use a generic webhook receiver (e.g., n8n, Cribl) that translates HMAC → Splunk auth, OR run a small inbound proxy. (A future enhancement could add a `splunk-hec` transport variant — open an issue if you need it.)

## File transport with Wazuh agent

Run the Wazuh agent on the conductor host and have it tail the JSON-lines file:
```json
"transport": "file",
"syslog_target": "/var/log/conductor/audit.jsonl"
```
Then in `/var/ossec/etc/ossec.conf` on the conductor host:
```xml
<localfile>
  <log_format>json</log_format>
  <location>/var/log/conductor/audit.jsonl</location>
</localfile>
```
This is the simplest production setup if you already have Wazuh agents deployed.

## Operational notes

- The `.conductor-cache/prior_state.json` file is the diff baseline. Deleting it forces a full re-emit of all events that exist in the current state.
- `events_to_emit` is an allowlist. Empty array (`[]`) disables emission even when `enabled: true`.
- `last_error` clears when the next emit succeeds.
- Per-project audit_sink config lives in each project's `conductor-state.json` — no global config.
- The schema validates `transport`, `syslog_facility`, and `events_to_emit` enum values; bad config is rejected by the PostToolUse schema validator.

## Verification

Run the included smoke test:
```bash
bash ~/Code/conductor-plugin/tests/test-audit-emitter.sh
```
Expected: file transport produces JSON-lines; syslog-udp captures via netcat in RFC 5424 format; emit_count increments.

## Limitations & roadmap

- Currently tested: `file`, `syslog-udp`. `syslog-tcp` / `syslog-tls` / `http` use the same code path as syslog-udp / urllib but have not been live-tested against real Wazuh/Splunk. Operator should validate before relying for compliance evidence.
- No batching: each event is one packet/POST. For very high event rates (>100/s sustained), add a batched-HTTP transport or use the file transport with a Wazuh agent.
- No back-pressure: emitter does not retry on transient SIEM unavailability. The next state-write will pick up where it left off via the prior_state diff. Persistent SIEM outages will accumulate events in the next-emit batch.
- `compliance_overview_generated` and `prohibited_behavior` events are reserved in the schema but not yet emitted by any code path — they need the corresponding agent code to write the trigger to conductor-state.json first.
