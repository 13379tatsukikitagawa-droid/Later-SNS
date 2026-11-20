import { test } from "node:test";
import assert from "node:assert/strict";
import { decideRequest, isExpired, noticeText, normalizeHandle, pair, validHandle } from "../src/logic.ts";

test("申請: 自分 ・ すでに 友だち ・ おたがい ・ ふつう", () => {
  assert.equal(decideRequest("a", "a", { alreadyFriends: false, reversePending: false }).kind, "self");
  assert.equal(decideRequest("a", "b", { alreadyFriends: true, reversePending: false }).kind, "already");
  assert.equal(decideRequest("a", "b", { alreadyFriends: false, reversePending: true }).kind, "mutual");
  assert.equal(decideRequest("a", "b", { alreadyFriends: false, reversePending: false }).kind, "pending");
});
test("pair は 順番に よらない", () => { assert.deepEqual(pair("b", "a"), pair("a", "b")); });
test("7日で 期限", () => {
  const day = 86_400_000;
  assert.equal(isExpired(0, 6 * day, 7), false);
  assert.equal(isExpired(0, 8 * day, 7), true);
});
test("ID", () => {
  assert.equal(normalizeHandle(" @Riko_6982 "), "riko_6982");
  assert.equal(validHandle("riko_6982"), true);
  assert.equal(validHandle("ab"), false);
});
test("通知の 文(v108 §4)", () => {
  assert.deepEqual(noticeText("request", { name: "りこ", handle: "riko_6982" }), { title: "りこ(@riko_6982)から 友だち申請", body: "承認すると、あしたの 9:00 から 写真を 見せあえます" });
  assert.equal(noticeText("accepted", { name: "りこ" }).title, "りこ が 承認しました");
  assert.equal(noticeText("mutual", { name: "りこ" }).title, "りこ と 友だちに なりました");
  assert.equal(noticeText("trip_invite", { name: "たつき", group: "大阪", dates: "11/21〜11/23" }).title, "たつき から『大阪』の Trip に 招待");
  assert.equal(noticeText("trip_joined", { name: "れな", group: "大阪", members: 4 }).body, "いま 4人");
});
