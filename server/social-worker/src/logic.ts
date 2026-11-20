// 友だちの きまり(純粋な 関数 ・ テストできる)。片方だけの フォローは 作らない。相互 = 承認 ・ おたがいの 申請。

export type Outcome =
  | { kind: "self" }
  | { kind: "already" }
  | { kind: "mutual" }    // おたがいに 申請 → その 場で 相互
  | { kind: "pending" };  // 申請を のこす

export function pair(x: string, y: string): [string, string] {
  return x < y ? [x, y] : [y, x];
}

/** 申請を 送った 時の 結果 */
export function decideRequest(from: string, to: string, opts: { alreadyFriends: boolean; reversePending: boolean }): Outcome {
  if (from === to) return { kind: "self" };
  if (opts.alreadyFriends) return { kind: "already" };
  if (opts.reversePending) return { kind: "mutual" };
  return { kind: "pending" };
}

export function isExpired(createdAtMs: number, nowMs: number, ttlDays: number): boolean {
  return nowMs - createdAtMs > ttlDays * 86_400_000;
}

export function normalizeHandle(raw: string): string {
  return raw.trim().replace(/^@/, "").toLowerCase();
}

export function validHandle(h: string): boolean {
  return /^[a-z0-9_.]{3,20}$/.test(h);
}

export type NoticeKind = "request" | "accepted" | "mutual" | "trip_invite" | "trip_joined";

/** 通知の 文(PROMPT v108 §4)。メール ・ 電話番号は 入れない */
export function noticeText(kind: NoticeKind, p: { name: string; handle?: string; group?: string; dates?: string; members?: number; host?: string }): { title: string; body: string } {
  const name = p.name || "ともだち";
  switch (kind) {
    case "request": return { title: `${name}${p.handle ? `(@${p.handle})` : ""}から 友だち申請`, body: "承認すると、あしたの 9:00 から 写真を 見せあえます" };
    case "accepted": return { title: `${name} が 承認しました`, body: "友だちに なりました ・ あしたの 9:00 に 見せあえます" };
    case "mutual": return { title: `${name} と 友だちに なりました`, body: "あしたの 9:00 に、おたがいの 1枚が ひらきます" };
    case "trip_invite": return { title: `${p.host ?? name} から『${p.group ?? ""}』の Trip に 招待`, body: `${p.dates ?? ""} ・ タップして 参加` };
    case "trip_joined": return { title: `${name} が『${p.group ?? ""}』に 入りました`, body: `いま ${p.members ?? 0}人` };
  }
}

/** 1日の 申請の 上限(1人 50件) */
export function withinDailyLimit(countToday: number, limit: number): boolean { return countToday < limit; }
export function dayKey(nowMs: number): string { return new Date(nowMs).toISOString().slice(0, 10); }

/** 通知の 種類ごとの 保存(PROMPT v111 §8-3)。初期は ラストコール だけ オフ */
export const PREF_KEYS = ["friend_request", "friend_accepted", "trip_invite", "trip_chat", "opened", "lastcall"] as const;
export type PrefKey = (typeof PREF_KEYS)[number];
export type Prefs = Record<PrefKey, boolean>;
export const DEFAULT_PREFS: Prefs = { friend_request: true, friend_accepted: true, trip_invite: true, trip_chat: true, opened: true, lastcall: false };

/** お知らせの 種類 → スイッチ */
export function prefKeyFor(kind: NoticeKind | "trip_chat" | "opened" | "lastcall"): PrefKey {
  switch (kind) {
    case "request": return "friend_request";
    case "accepted": case "mutual": return "friend_accepted";
    case "trip_invite": case "trip_joined": return "trip_invite";
    case "trip_chat": return "trip_chat";
    case "opened": return "opened";
    case "lastcall": return "lastcall";
  }
}

/** 送る 時に サーバーで 止める。行が 無い 人は 初期値 */
export function shouldPush(prefs: Partial<Prefs> | null, kind: Parameters<typeof prefKeyFor>[0]): boolean {
  const k = prefKeyFor(kind);
  return (prefs?.[k] ?? DEFAULT_PREFS[k]) === true;
}

/** 受けとった 値を 6つの スイッチ(真偽)に そろえる。知らない キーは 捨てる */
export function sanitizePrefs(raw: unknown, base: Prefs = DEFAULT_PREFS): Prefs {
  const out = { ...base };
  if (raw && typeof raw === "object") for (const k of PREF_KEYS) { const v = (raw as Record<string, unknown>)[k]; if (typeof v === "boolean") out[k] = v; }
  return out;
}

/** リモート設定:useWorker。USE_WORKER=1 なら みんな、そうで なければ 許可リスト(uid を カンマ 区切り)の 人 だけ */
export function useWorkerFor(uid: string, flag: string | undefined, allow: string | undefined): boolean {
  if ((flag ?? "").trim() === "1") return true;
  return (allow ?? "").split(",").map((x) => x.trim()).filter(Boolean).includes(uid);
}
