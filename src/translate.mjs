import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

const ROOT = new URL("../", import.meta.url);
const MODEL = "gpt-5.6-luna";
const FAITHFULNESS_THRESHOLD = 98;

const TRANSLATION_SCHEMA = {
  type: "object",
  properties: {
    translations: {
      type: "array",
      items: {
        type: "object",
        properties: {
          id: { type: "string" },
          text: { type: "string" },
        },
        required: ["id", "text"],
        additionalProperties: false,
      },
    },
  },
  required: ["translations"],
  additionalProperties: false,
};

const VERIFICATION_SCHEMA = {
  type: "object",
  properties: {
    faithfulness_score: { type: "integer", minimum: 0, maximum: 100 },
    meaning_changed: { type: "boolean" },
  },
  required: ["faithfulness_score", "meaning_changed"],
  additionalProperties: false,
};

let promptCache;

async function prompts() {
  if (!promptCache) {
    promptCache = Promise.all([
      readFile(new URL("prompts/translator.txt", ROOT), "utf8"),
      readFile(new URL("prompts/verifier.txt", ROOT), "utf8"),
    ]).then(([translator, verifier]) => ({ translator, verifier }));
  }
  return promptCache;
}

function nonce() {
  return Math.random().toString(36).slice(2, 10).toUpperCase();
}

export function protectOpaqueSpans(input) {
  const prefix = `TD_${nonce()}`;
  const values = new Map();
  let index = 0;

  const protect = (value, kind) => {
    const token = `[[${prefix}_${kind}_${++index}]]`;
    values.set(token, value);
    return token;
  };

  let text = input;
  text = text.replace(/```[\s\S]*?```/g, (value) => protect(value, "CODE"));
  text = text.replace(/“[^”]+”|"[^"\n]{2,}"/g, (value) => protect(value, "QUOTE"));
  text = text.replace(/<[^>\n]+>/g, (value) => protect(value, "SLACK"));
  text = text.replace(/https?:\/\/\S+/g, (value) => protect(value, "URL"));
  text = text.replace(
    /\b(?:[A-Fa-f0-9]{32,}|[A-Za-z0-9_-]{48,})\b/g,
    (value) => protect(value, "SECRET"),
  );

  return { text, values };
}

export function restoreOpaqueSpans(input, values) {
  let text = input;
  for (const [token, value] of values) {
    const occurrences = text.split(token).length - 1;
    if (occurrences !== 1) {
      throw new Error(`Frozen span ${token} appeared ${occurrences} times`);
    }
    text = text.replace(token, value);
  }
  return text;
}

function outputText(payload) {
  return payload.output
    ?.flatMap((item) => item.content ?? [])
    .find((item) => item.type === "output_text")?.text;
}

async function structuredResponse({ apiKey, fetchImpl, instructions, input, name, schema }) {
  const response = await fetchImpl("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      instructions,
      input: JSON.stringify(input),
      reasoning: { effort: "low" },
      max_output_tokens: 16384,
      store: false,
      text: {
        format: {
          type: "json_schema",
          name,
          strict: true,
          schema,
        },
      },
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(payload.error?.message ?? `OpenAI returned ${response.status}`);
  }
  const text = outputText(payload);
  if (payload.status !== "completed" || !text) {
    throw new Error(`OpenAI response was ${payload.status ?? "invalid"}`);
  }
  return JSON.parse(text);
}

export async function translateTopDown(
  original,
  { apiKey = process.env.OPENAI_API_KEY, fetchImpl = fetch } = {},
) {
  if (!apiKey) throw new Error("OPENAI_API_KEY is required");
  const { translator, verifier } = await prompts();
  const protectedMessage = protectOpaqueSpans(original);

  const translated = await structuredResponse({
    apiKey,
    fetchImpl,
    instructions: translator,
    input: { id: "message", slack_message: protectedMessage.text },
    name: "top_down_translation",
    schema: TRANSLATION_SCHEMA,
  });

  const row = translated.translations?.find((item) => item.id === "message");
  if (!row || translated.translations.length !== 1) {
    return { text: original, changed: false, reverted: true, reason: "invalid_translation" };
  }

  try {
    restoreOpaqueSpans(row.text, protectedMessage.values);
  } catch {
    return { text: original, changed: false, reverted: true, reason: "frozen_span_mismatch" };
  }

  const verification = await structuredResponse({
    apiKey,
    fetchImpl,
    instructions: verifier,
    input: {
      original_message: protectedMessage.text,
      candidate_message: row.text,
    },
    name: "translation_verification",
    schema: VERIFICATION_SCHEMA,
  });

  if (
    verification.meaning_changed ||
    verification.faithfulness_score < FAITHFULNESS_THRESHOLD
  ) {
    return {
      text: original,
      changed: false,
      reverted: true,
      reason: "faithfulness_gate",
      verification,
    };
  }

  const text = restoreOpaqueSpans(row.text, protectedMessage.values);
  return {
    text,
    changed: text !== original,
    reverted: false,
    verification,
  };
}

async function main() {
  const argument = process.argv.slice(2).join(" ").trim();
  const input = argument || (await new Promise((resolve, reject) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => { data += chunk; });
    process.stdin.on("end", () => resolve(data.trim()));
    process.stdin.on("error", reject);
  }));
  if (!input) throw new Error("Pass a Slack message as an argument or on stdin");
  const result = await translateTopDown(input);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error.message}\n`);
    process.exitCode = 1;
  });
}
