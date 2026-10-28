import { test } from "node:test";
import assert from "node:assert/strict";
import { displayPassphrase, isValidToken, issue, normalizePassphrase, resolve, revoke, RESOLVE_LIMIT, RESOLVE_WINDOW_MS, type Store } from "../src/invite.ts";

function memoryStore(): Store & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return {
    data,
    get: async (k) => data.get(k) ?? null,
    put: async (k, v) => { data.set(k, v); },
    delete: async (k) => { data.delete(k); },
  };
}

const token = "AbCdEfGhIjKlMnOpQrStUv";
const now = Date.UTC(2026, 9, 4);
let seed = 0.13;
const random = () => { seed = (seed * 9301 + 0.49297) % 1; return seed; };

test("トークンの形(推測できない長さ)", () => {
  assert.equal(isValidToken(token), true);
  assert.equal(isValidToken("short"), false);
  assert.equal(isValidToken("invite_hikari-1234"), false);
});

test("入力のゆれをそろえる", () => {
  assert.equal(normalizePassphrase(" クジラ ４７２ "), "くじら472");
  assert.equal(displayPassphrase("くじら472"), "くじら 472");
});

test("同じトークンには同じ合言葉。引ける", async () => {
  const store = memoryStore();
  const a = await issue(store, token, now, random);
  const b = await issue(store, token, now + 1000, random);
  assert.equal(a.passphrase, b.passphrase);
  const r = await resolve(store, displayPassphrase(a.passphrase), "1.1.1.1", "dev", now);
  assert.deepEqual(r, { status: 200, token });
});

test("有効期限(7日)をすぎたら引けない", async () => {
  const store = memoryStore();
  const a = await issue(store, token, now, random);
  const r = await resolve(store, a.passphrase, "1.1.1.1", "dev", now + 8 * 86_400_000);
  assert.equal(r.status, 404);
});

test("再発行・無効化したら、古い合言葉では入れない", async () => {
  const store = memoryStore();
  const a = await issue(store, token, now, random);
  const b = await issue(store, token, now, random, { forceNew: true });
  assert.notEqual(a.passphrase, b.passphrase);
  assert.equal((await resolve(store, a.passphrase, "1.1.1.1", "d1", now)).status, 404);
  await revoke(store, token);
  assert.equal((await resolve(store, b.passphrase, "1.1.1.1", "d2", now)).status, 404);
});

test("試行は5分に5回まで(端末・IPごと)", async () => {
  const store = memoryStore();
  for (let i = 0; i < RESOLVE_LIMIT; i++) {
    assert.equal((await resolve(store, "いるか100", "2.2.2.2", "dev", now)).status, 404);
  }
  assert.equal((await resolve(store, "いるか100", "2.2.2.2", "dev", now)).status, 429);
  // 別の端末でも、同じ IP なら止まる
  assert.equal((await resolve(store, "いるか100", "2.2.2.2", "other", now)).status, 429);
  // 5分たてば、また試せる
  assert.equal((await resolve(store, "いるか100", "2.2.2.2", "dev", now + RESOLVE_WINDOW_MS)).status, 404);
});
