import test from "node:test";
import assert from "node:assert/strict";
import {
  protectOpaqueSpans,
  restoreOpaqueSpans,
  translateTopDown,
} from "../src/translate.mjs";

function response(body) {
  return Response.json({
    status: "completed",
    output: [{ type: "message", content: [{ type: "output_text", text: JSON.stringify(body) }] }],
  });
}

test("protects and restores Slack markup, URLs, quotes, code, and secret-like tokens", () => {
  const original = '<@U123|Prash> said "keep this" at https://example.com ```x = 1``` abcdef0123456789abcdef0123456789';
  const protectedMessage = protectOpaqueSpans(original);
  assert.doesNotMatch(protectedMessage.text, /example\.com|abcdef0123456789/);
  assert.equal(restoreOpaqueSpans(protectedMessage.text, protectedMessage.values), original);
});

test("accepts a faithful translation", async () => {
  let call = 0;
  const fetchImpl = async (_url, init) => {
    const request = JSON.parse(init.body);
    const input = JSON.parse(request.input);
    call += 1;
    if (call === 1) {
      return response({ translations: [{ id: "message", text: `Status first. ${input.slack_message}` }] });
    }
    return response({ faithfulness_score: 100, meaning_changed: false });
  };
  const result = await translateTopDown("Because context, we are blocked.", { apiKey: "test", fetchImpl });
  assert.equal(result.reverted, false);
  assert.match(result.text, /^Status first\./);
});

test("reverts a semantically risky translation", async () => {
  let call = 0;
  const fetchImpl = async () => {
    call += 1;
    if (call === 1) {
      return response({ translations: [{ id: "message", text: "We decided to ship Friday." }] });
    }
    return response({ faithfulness_score: 70, meaning_changed: true });
  };
  const original = "Maybe we could ship Friday?";
  const result = await translateTopDown(original, { apiKey: "test", fetchImpl });
  assert.equal(result.reverted, true);
  assert.equal(result.text, original);
});
