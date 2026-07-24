#!/usr/bin/env node
// Structural validator for conductor-dev Workflow scripts.
// Usage: node check-workflow.mjs <path-to-workflow.js>
// Exit 0 = all checks pass; exit 1 = failure (reasons printed to stderr).
// Does NOT execute the script — only inspects its source and meta literal.
import fs from 'node:fs';
import vm from 'node:vm';

const file = process.argv[2];
if (!file) { console.error('usage: check-workflow.mjs <file>'); process.exit(1); }
let src;
try {
  src = fs.readFileSync(file, 'utf8');
} catch (e) {
  console.error(`cannot read file: ${e.message}`);
  process.exit(1);
}
const errors = [];

// 1. meta literal must exist and carry name + description. Parse STATICALLY — NEVER execute
//    file content (no new Function / no vm.run*). A validator that runs the code it validates is a
//    code-injection vector: a malicious workflow could execute arbitrary code just by being checked.
//    Convention: meta's closing brace sits at column 0 (first `\n}` after the declaration).
const metaMatch = src.match(/export\s+const\s+meta\s*=\s*(\{[\s\S]*?\n\})/);
if (!metaMatch) {
  errors.push('no `export const meta = { ... }` block with a column-0 closing brace');
} else {
  const metaBlock = metaMatch[1];
  if (!/\bname\s*:\s*['"][^'"]+['"]/.test(metaBlock)) errors.push('meta.name missing or empty');
  if (!/\bdescription\s*:\s*['"][^'"]+['"]/.test(metaBlock)) errors.push('meta.description missing or empty');
  // 2. every phases title must have a matching phase('title') call in the body.
  const phaseCalls = new Set([...src.matchAll(/phase\(\s*['"]([^'"]+)['"]\s*\)/g)].map((m) => m[1]));
  const declaredTitles = [...metaBlock.matchAll(/\btitle\s*:\s*['"]([^'"]+)['"]/g)].map((m) => m[1]);
  for (const t of declaredTitles) {
    if (!phaseCalls.has(t)) errors.push(`meta.phases title "${t}" has no matching phase('${t}') call`);
  }
}

// 3. forbidden primitives — unavailable in the Workflow sandbox.
const forbidden = [
  [/\bDate\.now\s*\(/, 'Date.now() (throws in Workflow sandbox)'],
  [/\bMath\.random\s*\(/, 'Math.random() (throws in Workflow sandbox)'],
  [/\bnew\s+Date\s*\(\s*\)/, 'argless new Date() (throws in Workflow sandbox)'],
  [/\brequire\s*\(/, 'require() (no module system in sandbox)'],
  [/^\s*import\s.+from\s/m, 'import-from (no module system in sandbox)'],
  [/\bfs\s*\./, 'fs.* (no filesystem in sandbox)'],
];
for (const [re, msg] of forbidden) {
  if (re.test(src)) errors.push('forbidden: ' + msg);
}

// 4. syntax-check the body by wrapping it in an async function.
//    (Workflow wraps the post-meta body in an async fn, so top-level return/await are legal.)
//    SAFETY: new vm.Script only COMPILES (parses) — it does NOT run the code. Never add a
//    .runInContext()/.runInThisContext() call here; that would execute unvalidated file content.
try {
  const body = src.replace(/^export\s+const\s+meta/m, 'const meta');
  new vm.Script('(async function __wf(args, budget){\n' + body + '\n})');
} catch (e) {
  errors.push('syntax error: ' + e.message);
}

if (errors.length) {
  console.error(`FAIL ${file}`);
  for (const e of errors) console.error('  - ' + e);
  process.exit(1);
}
console.log(`OK   ${file}`);
