import { test } from "node:test";
import assert from "node:assert/strict";
import { dayKey, withinDailyLimit, decideRequest, isExpired, noticeText, normalizeHandle, pair, validHandle } from "../src/logic.ts";

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
test("1日 50件", () => {
  assert.equal(withinDailyLimit(49, 50), true);
  assert.equal(withinDailyLimit(50, 50), false);
  assert.equal(dayKey(Date.UTC(2026, 10, 20, 23, 59)), "2026-11-20");
});

import { DEFAULT_PREFS, prefKeyFor, sanitizePrefs, shouldPush, useWorkerFor } from "../src/logic.ts";
test("prefs: 初期は ラストコール だけ オフ", () => {
  assert.equal(shouldPush(null, "request"), true);
  assert.equal(shouldPush(null, "lastcall"), false);
  assert.equal(shouldPush({ ...DEFAULT_PREFS, friend_request: false }, "request"), false);
  assert.equal(prefKeyFor("mutual"), "friend_accepted");
  assert.equal(prefKeyFor("trip_joined"), "trip_invite");
});
test("prefs: 知らない キー ・ 真偽 でない 値は 捨てる", () => {
  const p = sanitizePrefs({ friend_request: false, lastcall: "yes", evil: true });
  assert.equal(p.friend_request, false);
  assert.equal(p.lastcall, false);
  assert.equal((p as any).evil, undefined);
});
test("config: useWorker は 全員 / 許可リスト", () => {
  assert.equal(useWorkerFor("a", "1", ""), true);
  assert.equal(useWorkerFor("a", "0", "x, a"), true);
  assert.equal(useWorkerFor("b", "0", "x, a"), false);
  assert.equal(useWorkerFor("b", undefined, undefined), false);
});

import { chatPreview, chatPushDue, validTripId } from "../src/logic.ts";
test("trip-chat: ID ・ 2分に 1回 ・ 文の 整え", () => {
  assert.equal(validTripId("3f2504e0-4f89-11d3-9a0c-0305e82c3301"), true);
  assert.equal(validTripId("../etc"), false);
  assert.equal(chatPushDue(null, 1000), true);
  assert.equal(chatPushDue(1000, 1000 + 119_000), false);
  assert.equal(chatPushDue(1000, 1000 + 120_000), true);
  assert.equal(chatPreview("のった〜!\n\n  ほんとに"), "のった〜! ほんとに");
  assert.equal(chatPreview("あ".repeat(100)).length, 60);
});
