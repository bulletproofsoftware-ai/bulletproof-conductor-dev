#!/usr/bin/env bash
# Local plugin validation runner — mirrors the CI workflow.
# Run before committing to catch issues that would fail CI.
#
# Usage: ./tests/validate-plugin.sh [--fix]
#   --fix: attempt to auto-fix what can be auto-fixed (yamllint --fix style)
#
# Exit codes:
#   0 = all checks passed
#   1 = one or more checks failed
#   2 = required tooling missing

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PLUGIN_ROOT"

# ---------- color/output helpers ----------
if [ -t 1 ]; then
    GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; RESET='\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; BOLD=''; RESET=''
fi

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass() { echo -e "${GREEN}PASS${RESET}  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "${RED}FAIL${RESET}  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
skip() { echo -e "${YELLOW}SKIP${RESET}  $*"; SKIP_COUNT=$((SKIP_COUNT + 1)); }
section() { echo -e "\n${BOLD}=== $* ===${RESET}"; }

# ---------- tool checks ----------
check_tool() {
    local tool="$1"
    local install_hint="$2"
    if ! command -v "$tool" &>/dev/null; then
        fail "$tool not installed — $install_hint"
        return 1
    fi
    return 0
}

section "Tool availability"
check_tool jq "brew install jq" || true
check_tool python3 "install python 3.10+" || true
check_tool shellcheck "brew install shellcheck" || true

# ---------- 1. shellcheck on hooks ----------
section "Shell scripts (shellcheck)"
if command -v shellcheck &>/dev/null; then
    SHELL_FAIL=0
    while IFS= read -r script; do
        if shellcheck -x "$script" >/dev/null 2>&1; then
            pass "$(basename "$script")"
        else
            fail "$(basename "$script") — run: shellcheck -x $script"
            SHELL_FAIL=1
        fi
    done < <(find hooks/scripts -type f -name '*.sh')
else
    skip "shellcheck not installed"
fi

# ---------- 2. JSON schema valid + state validates ----------
section "JSON schema"
if command -v python3 &>/dev/null && python3 -c "import jsonschema" 2>/dev/null; then
    if python3 -c "
import json, jsonschema
schema = json.load(open('schemas/conductor-state.schema.json'))
jsonschema.Draft202012Validator.check_schema(schema)
" 2>/dev/null; then
        pass "schemas/conductor-state.schema.json is valid Draft 2020-12"
    else
        fail "schemas/conductor-state.schema.json is NOT valid Draft 2020-12"
    fi

    if [ -f conductor-state.json ]; then
        if python3 -c "
import json, jsonschema
schema = json.load(open('schemas/conductor-state.schema.json'))
state = json.load(open('conductor-state.json'))
jsonschema.validate(state, schema)
" 2>/dev/null; then
            pass "conductor-state.json validates against schema"
        else
            ERR="$(python3 -c "
import json, jsonschema
schema = json.load(open('schemas/conductor-state.schema.json'))
state = json.load(open('conductor-state.json'))
try:
    jsonschema.validate(state, schema)
except jsonschema.ValidationError as e:
    print(e.message[:200])
" 2>&1)"
            fail "conductor-state.json validation: $ERR"
        fi
    else
        skip "no conductor-state.json in repo"
    fi
else
    skip "python3 jsonschema not installed (pip install jsonschema)"
fi

# ---------- 3. Agent file frontmatter ----------
section "Agent frontmatter"
if command -v python3 &>/dev/null && python3 -c "import yaml" 2>/dev/null; then
    AGENT_FAIL=0
    AGENT_COUNT=0
    while IFS= read -r path; do
        AGENT_COUNT=$((AGENT_COUNT + 1))
        if ! python3 -c "
import yaml, sys
text = open('$path').read()
if not text.startswith('---\n'):
    sys.exit('missing YAML frontmatter')
end = text.index('\n---\n', 4)
meta = yaml.safe_load(text[4:end])
required = {'name', 'description', 'model'}
missing = required - set(meta.keys() if isinstance(meta, dict) else [])
if missing:
    sys.exit(f'missing keys: {missing}')
" 2>/dev/null; then
            fail "$(basename "$path") frontmatter incomplete"
            AGENT_FAIL=1
        fi
    done < <(find agents -type f -name '*.md' | sort)
    if [ "$AGENT_FAIL" -eq 0 ]; then
        pass "all $AGENT_COUNT agent files have valid frontmatter"
    fi
else
    skip "python3 + pyyaml required (pip install pyyaml)"
fi

# ---------- 4. Agent registry consistency ----------
section "Agent registry consistency"
REGISTRY="skills/agent-interop/references/agent-registry.yaml"
if [ -f "$REGISTRY" ] && command -v grep &>/dev/null; then
    MISSING_COUNT=0
    while IFS= read -r agent; do
        # skip PLANNED entries
        if grep -A2 "^  ${agent}:" "$REGISTRY" | grep -q "PLANNED — agent file not yet created"; then
            continue
        fi
        if [ ! -f "agents/${agent}.md" ]; then
            fail "registry references '${agent}' but agents/${agent}.md missing"
            MISSING_COUNT=$((MISSING_COUNT + 1))
        fi
    done < <(grep -E "^  conductor-" "$REGISTRY" | sed 's/^  //;s/:.*//')
    if [ "$MISSING_COUNT" -eq 0 ]; then
        pass "every implemented registry agent has a corresponding file"
    fi
else
    skip "agent-registry.yaml or grep unavailable"
fi

# ---------- 5. Skill reference files exist ----------
section "Skill reference files"
SKILL_FAIL=0
SKILL_COUNT=0
for skill_md in skills/*/SKILL.md; do
    skill_dir="$(dirname "$skill_md")"
    SKILL_COUNT=$((SKILL_COUNT + 1))
    while IFS= read -r ref; do
        full="${skill_dir}/${ref}"
        if [ ! -e "$full" ]; then
            fail "${skill_md}: missing reference '${ref}'"
            SKILL_FAIL=1
        fi
    done < <(grep -oE "references/[a-zA-Z0-9_./-]+\.(yaml|yml|md|json)" "$skill_md" 2>/dev/null | sort -u)
done
if [ "$SKILL_FAIL" -eq 0 ]; then
    pass "every reference mentioned in $SKILL_COUNT SKILL.md files exists"
fi

# ---------- 6. Hook runtime smoke test ----------
section "Hook runtime smoke test"
if [ -x hooks/scripts/post-state-write.sh ] && command -v jq &>/dev/null; then
    # non-conductor file: should exit 0 silently
    OUT="$(echo '{"tool_input":{"file_path":"/tmp/non-conductor.json"}}' | bash hooks/scripts/post-state-write.sh 2>&1)"
    EXIT=$?
    if [ "$EXIT" -eq 0 ] && [ -z "$OUT" ]; then
        pass "post-state-write.sh ignores non-conductor files cleanly"
    else
        fail "post-state-write.sh on non-conductor file: exit=$EXIT, output='$OUT'"
    fi

    # path traversal attempt: file_path should be treated as data, not executed
    OUT="$(echo '{"tool_input":{"file_path":"/etc/passwd; touch /tmp/conductor-test-INJECTED"}}' | bash hooks/scripts/post-state-write.sh 2>&1)"
    if [ ! -f /tmp/conductor-test-INJECTED ]; then
        pass "post-state-write.sh does not execute injection in file_path"
    else
        fail "post-state-write.sh DID execute injection — /tmp/conductor-test-INJECTED was created"
        rm -f /tmp/conductor-test-INJECTED
    fi
else
    skip "hooks/scripts/post-state-write.sh not executable or jq missing"
fi

# ---------- 7. Secrets scan ----------
section "Secrets scan"
if command -v gitleaks &>/dev/null; then
    if gitleaks detect --source . --no-git --report-format json --report-path /tmp/conductor-test-gitleaks.json --no-banner 2>/dev/null; then
        FOUND="$(jq 'length' /tmp/conductor-test-gitleaks.json 2>/dev/null || echo 0)"
        if [ "$FOUND" = "0" ]; then
            pass "no secrets detected in repository"
        else
            fail "$FOUND secret(s) detected — see /tmp/conductor-test-gitleaks.json"
        fi
    else
        fail "gitleaks scan failed"
    fi
else
    skip "gitleaks not installed (brew install gitleaks)"
fi

# ---------- 8. Hermes E1-E6 hook regression tests ----------
section "Hermes E1-E6 hook regression tests"
if [ -x "$PLUGIN_ROOT/tests/test-hermes-hooks.sh" ]; then
    if "$PLUGIN_ROOT/tests/test-hermes-hooks.sh" > /tmp/conductor-test-hermes-hooks.log 2>&1; then
        HERMES_PASS=$(grep -c "^PASS " /tmp/conductor-test-hermes-hooks.log || echo 0)
        pass "tests/test-hermes-hooks.sh — ${HERMES_PASS} assertions"
    else
        HERMES_FAIL=$(grep -c "^FAIL " /tmp/conductor-test-hermes-hooks.log || echo 0)
        fail "tests/test-hermes-hooks.sh — ${HERMES_FAIL} assertion(s) failed; see /tmp/conductor-test-hermes-hooks.log"
    fi
else
    skip "tests/test-hermes-hooks.sh not executable"
fi

# ---------- 9. Plugin manifest sanity ----------
section "Plugin manifest"
if [ -f .claude-plugin/plugin.json ] && command -v jq &>/dev/null; then
    if jq -e '.name and .version and .description' .claude-plugin/plugin.json >/dev/null; then
        pass ".claude-plugin/plugin.json has required fields (name, version, description)"
    else
        fail ".claude-plugin/plugin.json missing required fields"
    fi
else
    skip ".claude-plugin/plugin.json or jq missing"
fi

# ---------- summary ----------
section "Summary"
TOTAL=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
echo -e "Total: ${TOTAL}  ${GREEN}Pass: ${PASS_COUNT}${RESET}  ${RED}Fail: ${FAIL_COUNT}${RESET}  ${YELLOW}Skip: ${SKIP_COUNT}${RESET}"

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "\n${RED}${BOLD}One or more checks failed.${RESET}"
    exit 1
fi

if [ "$SKIP_COUNT" -gt 0 ]; then
    echo -e "\n${YELLOW}${BOLD}All checks passed (with skips).${RESET}"
    echo "Install missing tools to get full coverage: jq, python3, jsonschema, pyyaml, shellcheck, gitleaks"
    exit 0
fi

echo -e "\n${GREEN}${BOLD}All checks passed.${RESET}"
exit 0
