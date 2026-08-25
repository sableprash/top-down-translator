# TopDown

A 520 KB native macOS menu-bar app for rewriting Slack messages into meaning-preserving, top-down communication. It is optimized against the communication judge in [`sable-inc/ops` PR #20](https://github.com/sable-inc/ops/pull/20).

## Mac app

TopDown stays in the menu bar and supports a short keyboard-driven loop:

1. Paste the message you are about to send.
2. Press **Command–Return** to translate and verify it.
3. Make any final edits in the result.
4. Press **Command–Shift–C** to copy it for Slack.

The OpenAI API key is stored in macOS Keychain. Message text and API responses stay in memory; the app does not save history or use a URL cache.

Build the signed app with the macOS command-line tools—full Xcode is not required:

```sh
npm run build:mac
```

The result is `dist/TopDown.app`. Install it for the current user with:

```sh
mkdir -p ~/Applications
ditto dist/TopDown.app ~/Applications/TopDown.app
```

Open `TopDown.app`, click its menu-bar icon, and use the gear button to save an OpenAI API key.

The system is deliberately two-stage:

1. Rewrite the message with the winning top-down prompt.
2. Verify semantic faithfulness and return the original when the score is below 98 or meaning changed.

Slack links, mentions, quoted spans, code, URLs, and secret-like tokens are frozen before either model call and restored afterward. The project contains no historical Slack message text.

## Command-line translator

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

## Tests

```sh
npm test
```

This runs both the Node API-flow tests and dependency-free Swift privacy tests.

See [RESULTS.md](./RESULTS.md) for the corpus, hill-climb method, aggregate measurements, and evaluation limitation.
