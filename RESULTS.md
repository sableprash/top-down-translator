# Hill-climb results

## Corpus

- Slack workspace: Sable
- Author: Prash Subbiah (`U0B7EQ0LK1B`)
- Coverage: June 1 through August 25, 2026
- Messages scanned: 3,799
- Messages longer than 150 Unicode characters: 454
- Raw Slack text committed to this project: none

## Search

The search used `gpt-5.6-luna` with low reasoning. Five initial prompts were evaluated on 40 length-stratified development messages. Four mutations of the most faithful parent were evaluated on 40 unseen validation messages. Communication used Brian Zhao's judge rubric; a separate judge checked meaning preservation.

The winning prompt scored 94.25 mean communication, 95 median, and zero meaning changes on the 40-message validation set.

## Full-corpus batch audit

| Metric | Original | Rewrite | Verified + revert |
| --- | ---: | ---: | ---: |
| Mean | 82.19 | 90.67 | 90.66 |
| Median | 86 | 92 | 92 |
| 10th percentile | 70 | 82 | 82 |
| Messages below 70 | 44 | 13 | 12 |
| Meaning changes accepted | 0 | 9 | 0 |

The verifier threshold is 98. It reverted 13 of 454 messages, including all nine rewrites flagged as meaning-changing.

## Important limitation

The full-corpus optimization used a batched adaptation of the rubric because no OpenAI API key was available to the local process. A 20-message, single-message spot-check through the authenticated Codex CLI was substantially harsher: 59.10 mean original versus 60.65 mean after translation. Codex CLI includes an agent wrapper and is not identical to the production `POST /v1/responses` call in `sable-inc/ops` PR #20.

Treat the batch numbers as search diagnostics, not production certification. Run the exact Responses API path with the production key before shipping or claiming the larger gain.
