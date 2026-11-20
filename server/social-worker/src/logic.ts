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
