# Workflow Integration — Live-Run Verification

**Date:** 2026-06-01
**Branch:** `feat/workflow-integration`
**Scope:** Task 6 of `docs/plans/2026-06-01-workflow-integration.md`

## Summary

| Item | Result |
|---|---|
| Code Hardener reachable | ✅ healthy (`GET /health` → 200) |
| Corrected `/api/v1` contract discovered | ✅ from running backend + compiled source |
| Project create against v1 contract | ✅ verified (`201`, real project id) |
| Full scan-fix-rescan end-to-end run | ⛔ **BLOCKED** by Code Hardener scan-quota (CH config, not conductor-dev) |
| Route/field fixes applied to `conduct.md` + `hardening-loop.js` | ✅ consistent, canonical block byte-identical |
| Structural harness (both workflows) | ✅ `OK`, exit 0 |

The live scan-fix-rescan loop is **not** claimed as a passing run. It is deferred pending Code
Hardener scan-quota provisioning for the dev identity (see Blocker).

## Environment

Code Hardener stack running under Docker:

```
codehardener-backend-1    0.0.0.0:7002->4000/tcp
codehardener-scanner-1
codehardener-postgres-1    0.0.0.0:5432->5432/tcp
codehardener-redis-1       0.0.0.0:6381->6379/tcp
codehardener-dashboard-1   0.0.0.0:3005->3000/tcp
codehardener-n8n-1         0.0.0.0:5678->5678/tcp
```

`GET http://localhost:7002/health` → `{"success":true,"data":{"status":"healthy",...}}`

## API drift discovered (and fixed)

The Code Hardener API was redesigned to a versioned base path `/api/v1` since `conduct.md`'s
Code Hardener section was authored. The documented routes (`/api/projects`, `/api/scans`,
`/api/findings`, `/api/reports`) all returned `404 Route not found`. Corrected, verified contract:

| Operation | Old (stale) | Corrected (`/api/v1`) | Evidence |
|---|---|---|---|
| Create project | `POST /api/projects` `{name, repoUrl}` | `POST /api/v1/projects` `{name, repoPath}` | **201**, returned project id `fde1eae0-…` |
| Start scan | `POST /api/scans` `{projectId, profile}` | `POST /api/v1/scans` `{projectId, profile\|scanType:"comprehensive"}` | schema `scans.controller.js:170` (`createScanSchema`); profile enum includes `comprehensive` |
| Poll scan | `GET /api/scans/:id` | `GET /api/v1/scans/:id` | mounted `app.js:70` |
| Findings | `GET /api/findings?scanId=&status=open` | `GET /api/v1/scans/:id/findings?status=open` | nested route `scans.routes.js` `getScanFindings`; `status` filter is **best-effort** (could not be runtime-confirmed without a completed scan) |
| Reports | `POST /api/reports`, `GET /api/reports/:id/download` | `POST /api/v1/reports`, `GET /api/v1/reports/:id/download` | mounted `app.js:75`; routes `reports.routes.js:116,243` |

The `X-User-Id: dev@codehardener.local` dev-auth bypass is honored (`auth.js:14-16`).

Fixes applied consistently to both `commands/conduct.md` (Code Hardener QA Phase + report step)
and `workflows/hardening-loop.js` (scan prompt). Canonical block in `conduct.md` verified
byte-identical before/after (sha256 `21acea01…f07f5a`).

## Blocker — why the full run is deferred

`POST /api/v1/scans` is gated by the `enforceScanLimit` middleware
(`scans.routes.js:23`, `tierEnforcement.js:63-84`), which rejects when the authenticated user has
no remaining scan quota:

> "Your {plan} plan allows {N} scans/month. You've used {current}. Upgrade for unlimited scans."

The dev identity `dev@codehardener.local` has no scan quota, so the scan request returns an empty
`400` before the scan starts. This is a **Code Hardener account/plan configuration issue**, outside
the conductor-dev Workflow-integration scope. Resolving it requires provisioning the dev user's
plan/quota in Code Hardener.

### To complete the deferred run later

1. Provision scan quota for `dev@codehardener.local` in Code Hardener.
2. Create a throwaway target repo with planted findings:
   ```bash
   TGT=$(mktemp -d)/wf-live && mkdir -p "$TGT" && cd "$TGT" && git init -q
   printf 'const pw = "hardcoded-secret-123";\nfunction run(i){ eval(i); }\nmodule.exports = { run };\n' > app.js
   git add -A && git commit -qm "seed: planted findings"
   ```
3. From the conductor-dev repo, invoke the workflow:
   ```
   Workflow({ scriptPath: "<conductor-dev>/workflows/hardening-loop.js",
              args: { projectName: "wf-live", projectPath: "<TGT>" } })
   ```
4. Expected: returned JSON with `history` (≥1 entry), integer `finalScore`, boolean `converged`;
   first iteration `open > 0` (the two planted findings), score climbing across iterations.

## Probe artifacts created (harmless test data)

- Code Hardener projects: `wf-probe`, several `wf-l`, `wf-live` (created while discovering the
  contract). Removable via the dashboard or `DELETE /api/v1/projects/:id`.
- A `/tmp` throwaway git repo with the two planted findings.
