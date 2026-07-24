# conductor-dev Workflow Scripts

Deterministic `Workflow`-tool scripts invoked by `/conduct` for phase-scoped fan-out and loops.
The conductor (main loop) stays the spine — these scripts are muscle. See
`docs/plans/2026-06-01-workflow-integration.md` for the design rationale.

## Rules

Rules 1–4 are **mechanically enforced** by `tests/test-workflow-scripts.sh`; rules 5–7 are
conventions the harness does not check — follow them anyway.

1. Begin with `export const meta = { name, description, phases }`. The closing `}` MUST be at
   column 0 (the validator extracts the literal by matching the first `\n}`).
2. `meta` is a pure literal — no variables, calls, or interpolation. Every `meta.phases[].title`
   must have a matching `phase('title')` call in the body.
3. No filesystem, no Bash, no `require`/`import`-from inside the script. Anything needing a shell
   (curl, git, the `agy` Gemini CLI) is done by a dispatched agent via `agentType`.
4. No `Date.now()`, `Math.random()`, or argless `new Date()` — they throw in the sandbox. Pass
   timestamps via `args`; vary per-item work by index.
5. (Convention) Define JSON Schemas inline as local `const`s (scripts cannot import shared modules).
6. (Convention) Dispatch real agents with `agentType: 'conductor-dev:<name>'` or `'conductor-kernel:<name>'`.
7. (Convention) `return` a plain JSON-serializable object — the conductor reads it, writes state, commits.

## Invocation

`/conduct workflow <hardening|adversarial>` (see `commands/conduct.md`). The conductor resolves
`${CLAUDE_PLUGIN_ROOT}/workflows/<name>.js`, builds `args`, calls `Workflow({scriptPath, args})`,
and on the completion notification persists the result via `state_advance`.

## Validate

    bash tests/test-workflow-scripts.sh
