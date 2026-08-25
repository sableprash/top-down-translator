# Top-down Slack translator

A meaning-preserving translator optimized against the communication judge in [`sable-inc/ops` PR #20](https://github.com/sable-inc/ops/pull/20).

The system is deliberately two-stage:

1. Rewrite the message with the winning top-down prompt.
2. Verify semantic faithfulness and return the original when the score is below 98 or meaning changed.

Slack links, mentions, quoted spans, code, URLs, and secret-like tokens are frozen before either model call and restored afterward. The project contains no historical Slack message text.

## Run

Requires Node 20+ and an OpenAI API key:

```sh
export OPENAI_API_KEY=...
npm run translate -- 'Because the migration moved the job, we need a loading state.'
```

Or pipe a message on stdin:

```sh
pbpaste | npm run translate
```

The output includes the translated text, whether it changed, whether it was reverted, and the verifier result.

## Test

```sh
npm test
```

See [RESULTS.md](./RESULTS.md) for the corpus, hill-climb method, aggregate measurements, and evaluation limitation.
