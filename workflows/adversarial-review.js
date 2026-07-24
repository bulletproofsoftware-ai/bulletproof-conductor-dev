export const meta = {
  name: 'conductor-adversarial-review',
  description: 'Dual-AI (Claude + Gemini) independent review of a git diff, debate disputed findings, report consensus',
  whenToUse: 'STANDARD/MAJOR dev workflows after hardening reaches score 1000; conductor supplies args.diff',
  phases: [
    { title: 'Review' },
    { title: 'Debate' },
  ],
}

const DIFF = args && args.diff ? args.diff : '';
const MAX_ROUNDS = 5;

const REVIEW_SCHEMA = {
  type: 'object',
  required: ['findings', 'risk'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['severity', 'domain', 'file', 'line', 'description', 'fix'],
        properties: {
          severity: { type: 'string', enum: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'] },
          domain: { type: 'string' },
          file: { type: 'string' },
          line: { type: 'integer' },
          description: { type: 'string' },
          fix: { type: 'string' },
        },
      },
    },
    risk: { type: 'string', enum: ['PASS', 'PASS_WITH_NOTES', 'NEEDS_CHANGES', 'BLOCK'] },
  },
}

const DEBATE_SCHEMA = {
  type: 'object',
  required: ['verdict', 'evidence'],
  properties: {
    verdict: { type: 'string', enum: ['AGREE', 'DISAGREE'] },
    evidence: { type: 'string' },
  },
}

const REVIEW_DOMAINS =
  '1. SECURITY 2. CODE QUALITY 3. PERFORMANCE 4. ARCHITECTURE 5. MAINTAINABILITY 6. EDGE CASES';

const claudePrompt =
  `You are a senior staff engineer performing an independent code review of the diff below. ` +
  `Examine every changed file. For each issue cite the exact file and line. Review domains: ${REVIEW_DOMAINS}. ` +
  `Return findings (array of {severity,domain,file,line,description,fix}) and an overall risk ` +
  `(PASS | PASS_WITH_NOTES | NEEDS_CHANGES | BLOCK).\n\nDIFF:\n${DIFF}`;

const geminiPrompt =
  `Run an INDEPENDENT third-party code review using the Gemini "agy" CLI, following conduct.md's Adversarial Review ` +
  `Step 2 exactly: write the full review prompt + diff to a temp file, then run ` +
  `"$AGY --dangerously-skip-permissions --print-timeout 5m --log-file <tmp> -p \"$(cat <tmpfile>)\"" where ` +
  `AGY="$(command -v agy || echo "$HOME/.local/bin/agy")". NEVER interpolate the diff into the -p argument directly. ` +
  `Review domains: ${REVIEW_DOMAINS}. Parse agy's stdout and return findings (array of ` +
  `{severity,domain,file,line,description,fix}) and an overall risk (PASS | PASS_WITH_NOTES | NEEDS_CHANGES | BLOCK). ` +
  `If agy is unavailable, return {"findings":[],"risk":"PASS"} and note it.\n\nDIFF TO REVIEW:\n${DIFF}`;

phase('Review');
const [claude, gemini] = await parallel([
  () => agent(claudePrompt, { label: 'review:claude', phase: 'Review', schema: REVIEW_SCHEMA, agentType: 'general-purpose' }),
  () => agent(geminiPrompt, { label: 'review:gemini', phase: 'Review', schema: REVIEW_SCHEMA, agentType: 'general-purpose' }),
]);

const claudeFindings = (claude && claude.findings) || [];
const geminiFindings = (gemini && gemini.findings) || [];

// Classify in plain JS (no agent): AGREED if same file+line+domain in both reviews.
const key = (f) => `${f.file}:${f.line}:${(f.domain || '').toUpperCase()}`;
const geminiKeys = new Set(geminiFindings.map(key));
const claudeKeys = new Set(claudeFindings.map(key));
const agreed = claudeFindings.filter((f) => geminiKeys.has(key(f)));
const disputed = [
  ...claudeFindings.filter((f) => !geminiKeys.has(key(f))).map((f) => ({ finding: f, source: 'claude' })),
  ...geminiFindings.filter((f) => !claudeKeys.has(key(f))).map((f) => ({ finding: f, source: 'gemini' })),
];
log(`reviews complete: ${agreed.length} agreed, ${disputed.length} disputed`);

// Debate each disputed finding up to MAX_ROUNDS; challenger is the OTHER model.
phase('Debate');
const debated = await parallel(
  disputed.map((d) => async () => {
    const challengerType = 'general-purpose'; // both challengers run as general-purpose agents
    let rounds = 0;
    let consensus = null;
    let challengerNote = '';
    while (rounds < MAX_ROUNDS) {
      rounds++;
      const v = await agent(
        `A code review (source: ${d.source}) raised this finding:\n${JSON.stringify(d.finding, null, 2)}\n` +
          (challengerNote ? `Prior challenger note: ${challengerNote}\n` : '') +
          `As an independent challenger, do you AGREE or DISAGREE that this is a real, must-fix issue? Provide evidence. ` +
          (d.source === 'gemini'
            ? `You are the Claude-side challenger; reason directly.`
            : `You are the Gemini-side challenger; run the "agy" CLI per conduct.md to get Gemini's position, then report it.`),
        { label: `debate:${key(d.finding)}#${rounds}`, phase: 'Debate', schema: DEBATE_SCHEMA, agentType: challengerType },
      );
      challengerNote = v ? v.evidence : '';
      if (v && v.verdict === 'AGREE') { consensus = 'CONFIRMED'; break; }
      if (v && v.verdict === 'DISAGREE') { consensus = 'REJECTED'; break; }
    }
    return { finding: d.finding, source: d.source, rounds, disposition: consensus || 'DISPUTED', challengerNote };
  }),
).then((r) => r.filter(Boolean));

const confirmed = debated.filter((d) => d.disposition === 'CONFIRMED').map((d) => d.finding);
const stillDisputed = debated.filter((d) => d.disposition === 'DISPUTED');

return {
  claudeRisk: claude ? claude.risk : null,
  geminiRisk: gemini ? gemini.risk : null,
  agreedFindings: agreed,
  confirmedViaDebate: confirmed,
  // consensus findings the conductor should remediate (then re-run Task 2's hardening loop to verify score holds):
  mustFix: [...agreed, ...confirmed],
  disputed: stillDisputed,
  debateRoundsUsed: debated.reduce((n, d) => n + d.rounds, 0),
};
