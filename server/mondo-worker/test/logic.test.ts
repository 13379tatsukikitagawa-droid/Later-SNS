import { test } from "node:test";
import assert from "node:assert/strict";
import { afterUnclear, buildDay, canonical, readVerdict, seededShuffle, shiftDay, hasBlockedWord } from "../src/logic.ts";
import { rawSignatureToDER } from "../src/cloudkit.ts";

const photos = [
  { recordName: "a", mondoID: "u1", dayKey: "2026-10-02", countryCode: "JP", tags: ["coffee", "空"] },
  { recordName: "b", mondoID: "u2", dayKey: "2026-10-02", countryCode: "IT", tags: ["コーヒー"] },
  { recordName: "c", mondoID: "u3", dayKey: "2026-10-02", countryCode: "JP", tags: ["珈琲"] },
  { recordName: "d", mondoID: "u4", dayKey: "2026-10-03", countryCode: "FR", tags: ["コーヒー"] }, // 今日:混ぜない
  { recordName: "e", mondoID: "u5", dayKey: "2026-10-02", countryCode: "US", tags: ["コーヒー"] }, // 保留
  { recordName: "f", mondoID: "u1", dayKey: "2026-10-02", countryCode: "JP", tags: ["夜"] },     // 同じ人の2枚目
];
const aliases = { coffee: "コーヒー", "珈琲": "コーヒー" };

test("昨日の窓・承認ずみ・1人1枚だけで集計する", () => {
  const day = buildDay("2026-10-02", photos, (n) => (n === "e" ? "held" : "approved"), aliases);
  assert.equal(day.lightCount, 3);
  assert.equal(day.countryCount, 2);
  assert.deepEqual(day.topTags, ["コーヒー", "空"]);
  assert.deepEqual(day.topTagCounts, [3, 1]);
  assert.deepEqual([...day.photoNames].sort(), ["a", "b", "c"]);
});

test("並びは日付で決まる(同じ日は同じ・ちがう日はちがう)", () => {
  const items = Array.from({ length: 20 }, (_, i) => i);
  assert.deepEqual(seededShuffle(items, "2026-10-02"), seededShuffle(items, "2026-10-02"));
  assert.notDeepEqual(seededShuffle(items, "2026-10-02"), seededShuffle(items, "2026-10-03"));
});

test("審査の答え:はっきり SAFE だけ承認", () => {
  assert.equal(readVerdict("SAFE"), "approved");
  assert.equal(readVerdict("Safe."), "approved");
  assert.equal(readVerdict("**SAFE**"), "approved");
  assert.equal(readVerdict("Answer: SAFE"), "approved");
  assert.equal(readVerdict(" unsafe."), "rejected");
  assert.equal(readVerdict("Not safe"), "rejected");
  assert.equal(readVerdict("I cannot tell"), "retry");
  assert.equal(readVerdict(undefined), "retry");
  assert.equal(afterUnclear(1), "retry");
  assert.equal(afterUnclear(4), "held");
});

test("日付・ことば・禁止語", () => {
  assert.equal(shiftDay("2026-10-01", -1), "2026-09-30");
  assert.equal(canonical("#Coffee", aliases), "コーヒー");
  assert.equal(hasBlockedWord(["hello", "#ok"], ["bad"]), false);
  assert.equal(hasBlockedWord(["so BAD"], ["bad"]), true);
});

test("署名を DER にする(先頭が 0x30、r・s の上位ビットを守る)", () => {
  const raw = new Uint8Array(64).fill(0xff);
  const der = rawSignatureToDER(raw);
  assert.equal(der[0], 0x30);
  assert.equal(der[2], 0x02);
  assert.equal(der[3], 33); // 0x00 を足して正の数にする
});
