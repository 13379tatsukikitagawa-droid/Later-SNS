import { test } from "node:test";
import assert from "node:assert/strict";
import { aasa, allowedHit, escapeHtml, friendCard, isLinkLive, newToken, renderPage, tripCard, validToken } from "../src/links.ts";

test("token: 12 chars, no confusing chars, unique-ish", () => {
  const set = new Set<string>();
  for (let i = 0; i < 500; i++) { const t = newToken(); assert.match(t, /^[A-HJ-NP-Za-km-z2-9]{12}$/); set.add(t); }
  assert.equal(set.size, 500);
});
test("token validation", () => { assert.ok(validToken("Kx7Qm2pLx9")); assert.ok(validToken("maple24")); assert.ok(!validToken("a b")); assert.ok(!validToken("<x>")); });
test("expiry + rate limit", () => {
  assert.ok(isLinkLive(2000, 1000)); assert.ok(!isLinkLive(1000, 1000));
  assert.ok(allowedHit(10)); assert.ok(!allowedHit(11));
});
test("aasa has u/t/g and no redirect-ish keys", () => {
  const j = JSON.parse(aasa()); const c = j.applinks.details[0].components.map((x: any) => x["/"]);
  assert.deepEqual(c, ["/u/*", "/t/*", "/g/*"]);
});
test("cards: text per v109 §5", () => {
  assert.equal(friendCard("たつき", "tatsuki_1120").title, "たつき から 友だち申請");
  const t = tripCard({ group_name: "大阪", from_name: "たつき", dates: "11/20〜11/22", members: 3 });
  assert.equal(t.title, "『大阪』の Trip に 招待されました");
  assert.equal(t.desc, "11/20〜11/22 ・ 3人 ・ 1日 23枚、みんなで 撮る");
  assert.equal(tripCard(null).valid, false);
});
test("html is escaped, KEY never in page", () => {
  const html = renderPage(tripCard({ group_name: `<script>alert(1)</script>`, from_name: `"x"`, dates: "", members: 0 }), { host: "h.example", path: "/t/abc", code: "abc", storeURL: "" });
  assert.ok(!html.includes("<script>alert(1)"));
  assert.ok(html.includes("&lt;script&gt;"));
  assert.equal(escapeHtml(`<a href="x">&'`), "&lt;a href=&quot;x&quot;&gt;&amp;&#39;");
  assert.ok(html.includes('property="og:url" content="https://h.example/t/abc"'));
});
