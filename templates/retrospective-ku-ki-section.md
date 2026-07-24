## Prompt Patterns Detected

Mined from `gemini_validations[]` for this workflow. Phrases correlated with PASS verdicts are flagged Key-Useful (KU); phrases correlated with FAIL or low-completion-pct verdicts are flagged Key-Irrelevant (KI).

This section is informational. Downstream consumption by other agents is out of scope for the current spec — operators decide what to do with these signals.

**Window analyzed:** {{validations_analyzed}} validations ({{pass_count}} PASS / {{fail_count}} FAIL / {{partial_count}} PARTIAL)
**Baseline P(PASS):** {{baseline_pass_rate}}
**Extraction file:** `{{extraction_file}}`

### Top 5 Key-Useful (KU) Phrases

Phrases where `P(PASS | phrase present)` is materially higher than the baseline (lift >= 1.25, occurrences >= 3, correlation >= 0.6).

| Phrase | Correlation | Lift | Occurrences | Confidence |
|---|---|---|---|---|
{{#each top_ku}}
| `{{phrase}}` | {{correlation}} | {{lift}} | {{occurrences}} | {{confidence}} |
{{/each}}

### Top 5 Key-Irrelevant (KI) Phrases

Phrases where `P(PASS | phrase present)` is materially lower than the baseline (lift <= 0.75, occurrences >= 3, correlation <= 0.4).

| Phrase | Correlation | Lift | Occurrences | Confidence | Notes |
|---|---|---|---|---|---|
{{#each top_ki}}
| `{{phrase}}` | {{correlation}} | {{lift}} | {{occurrences}} | {{confidence}} | {{notes}} |
{{/each}}

### Cold-Start Note

> _Rendered only when fewer than 10 validations were available:_
>
> Insufficient data for KU/KI extraction — fewer than 10 Gemini validations recorded in this workflow. An empty extraction file was written with this note. The section will be populated once the validation window meets the minimum threshold.
