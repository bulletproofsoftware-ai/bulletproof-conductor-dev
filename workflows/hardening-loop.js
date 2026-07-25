export const meta = {
  name: 'conductor-hardening-loop',
  description: 'Code Hardener scan-fix-rescan loop until score 1000 / zero open findings, max 5 iterations',
  whenToUse: 'STANDARD/MINOR/MAJOR dev workflows after implementation, when a Code Hardener backend is reachable (args.codehardenerUrl, default http://localhost:7002)',
  phases: [
    { title: 'Scan' },
    { title: 'Fix' },
  ],
}

const PROJECT = args && args.projectName ? args.projectName : 'unnamed-project';
const PROJECT_PATH = args && args.projectPath ? args.projectPath : '.';
// Code Hardener base URL. The conductor passes args.codehardenerUrl, resolved
// from $CODEHARDENER_URL; the default matches the service's own default port.
const CH_URL = (args && args.codehardenerUrl) || 'http://localhost:7002';
// Identity sent as X-User-Id. Override for a non-default Code Hardener install.
const CH_USER = (args && args.codehardenerUser) || 'dev@codehardener.local';
const MAX_ITER = 5;

const SCAN_SCHEMA = {
  type: 'object',
  required: ['scanId', 'score', 'findings'],
  properties: {
    scanId: { type: 'string' },
    score: { type: 'integer' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'title', 'severity'],
        properties: {
          file: { type: 'string' },
          line: { type: 'integer' },
          title: { type: 'string' },
          description: { type: 'string' },
          severity: { type: 'string' },
        },
      },
    },
  },
}

const FIX_SCHEMA = {
  type: 'object',
  required: ['file', 'fixes'],
  properties: {
    file: { type: 'string' },
    fixes: {
      type: 'array',
      items: {
        type: 'object',
        required: ['finding', 'change'],
        properties: {
          finding: { type: 'string' },
          change: { type: 'string' },
          evidence: { type: 'string' },
        },
      },
    },
  },
}

const scanPrompt = (iter) =>
  `Run a Code Hardener COMPREHENSIVE scan for project "${PROJECT}" at repo path "${PROJECT_PATH}". ` +
  `Use the Code Hardener API at ${CH_URL} with header "X-User-Id: ${CH_USER}":\n` +
  `1. POST /api/v1/projects {"name":"${PROJECT}","repoPath":"${PROJECT_PATH}"} to get or reuse the project id.\n` +
  `2. POST /api/v1/scans {"projectId":"<id>","profile":"comprehensive"} to start a scan.\n` +
  `3. Poll GET /api/v1/scans/<scanId> until status is terminal (max 600s).\n` +
  `4. GET /api/v1/scans/<scanId>/findings?status=open to list open findings.\n` +
  `Return ONLY: scanId (string), score (integer 0-1000), and findings (array of {file,line,title,description,severity}). ` +
  `This is hardening iteration ${iter}.`

const history = [];
let lastScanId = null;

for (let iter = 1; iter <= MAX_ITER; iter++) {
  phase('Scan');
  const scan = await agent(scanPrompt(iter), {
    label: `scan:iter${iter}`,
    phase: 'Scan',
    schema: SCAN_SCHEMA,
    agentType: 'conductor-dev:qa',
  });
  lastScanId = scan.scanId;
  history.push({ scanId: scan.scanId, score: scan.score, openFindings: scan.findings.length });
  log(`iteration ${iter}: score=${scan.score} open=${scan.findings.length}`);

  if (scan.score >= 1000 && scan.findings.length === 0) break;
  if (iter === MAX_ITER) {
    log(`max iterations (${MAX_ITER}) reached with ${scan.findings.length} open findings — escalating to conductor`);
    break;
  }

  // Group findings by file, fan out one fix agent per file.
  phase('Fix');
  const byFile = {};
  for (const f of scan.findings) (byFile[f.file] ??= []).push(f);
  const fixThunks = Object.entries(byFile).map(([file, findings]) => () =>
    agent(
      `Read ${file} and fix each of these Code Hardener findings without introducing new issues. ` +
        `For each finding report the finding title, the change you made (file:line), and why it resolves the finding.\n` +
        JSON.stringify(findings, null, 2),
      { label: `fix:${file}`, phase: 'Fix', schema: FIX_SCHEMA, agentType: 'conductor-dev:builder' },
    ),
  );
  const fixResults = (await parallel(fixThunks)).filter(Boolean);
  const dropped = fixThunks.length - fixResults.length;
  if (dropped > 0) log(`WARNING: ${dropped}/${fixThunks.length} fix agents failed this iteration (will be re-detected next scan)`);

  // Intra-phase git ratchet (conduct.md Hardening Loop step 6) — done by an agent (script has no shell).
  // Stage ONLY the files repaired this iteration — never `git add -A`/`git add .` (CLAUDE.md §code-standards).
  const repaired = Object.keys(byFile);
  await agent(
    `Stage ONLY these repaired files and commit — do NOT use "git add -A" or "git add .":\n` +
      repaired.map((f) => `git add ${JSON.stringify(f)}`).join(' && ') +
      ` && git commit -m "chore: hardening iteration ${iter} — fix ${scan.findings.length} findings". ` +
      `If a path is unknown to git or there is nothing to commit, report that and do nothing else.`,
    { label: `ratchet:iter${iter}`, phase: 'Fix', agentType: 'conductor-dev:builder' },
  );
}

const last = history[history.length - 1];
return {
  history,
  lastScanId,
  finalScore: last ? last.score : null,
  converged: !!last && last.score >= 1000 && last.openFindings === 0,
  iterations: history.length,
};
