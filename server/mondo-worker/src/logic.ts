// Mondo の集計(副作用なし。test/ で確かめる)

/// approved = 承認 / rejected = 不適切 / held = 保留(報告が多い・審査を何度しても決まらない)/
/// retry = 一時的に決まらなかった(次の回に、もう一度審査する)
export type Status = "approved" | "held" | "rejected" | "retry";

/// 一時的な失敗・あいまいな答えを、何回まで審査しなおすか(それでも決まらなければ保留)
export const MAX_MODERATION_ATTEMPTS = 4;

export interface PhotoInfo {
  recordName: string;
  mondoID: string;
  dayKey: string;
  countryCode?: string;
  tags: string[];
}

export interface MondoDayFields {
  dayKey: string;
  photoNames: string[];
  lightCount: number;
  countryCount: number;
  topTags: string[];
  topTagCounts: number[];
}

/// "2026-10-03" を n 日ずらす(UTC の暦で計算する)
export function shiftDay(dayKey: string, days: number): string {
  const d = new Date(`${dayKey}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

export function todayKey(now: Date): string {
  return now.toISOString().slice(0, 10);
}

/// 表記ゆれを、代表のことばにそろえる(辞書は KV。コードに埋め込まない)
export function canonical(tag: string, aliases: Record<string, string>): string {
  const t = tag.trim().replace(/^#/, "");
  return aliases[t.toLowerCase()] ?? aliases[t] ?? t;
}

/// 文字列から決まる乱数(同じ日は同じ並び・毎日ちがう並び)
export function seededShuffle<T>(items: T[], seed: string): T[] {
  let h = 2166136261;
  for (let i = 0; i < seed.length; i++) h = Math.imul(h ^ seed.charCodeAt(i), 16777619);
  let state = h >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const out = items.slice();
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(next() * (i + 1));
    [out[i], out[j]] = [out[j], out[i]];
  }
  return out;
}

/// 承認した「その日」の写真だけで、MondoDay を作る(今日の投稿は混ぜない・1人1枚)
export function buildDay(
  dayKey: string,
  photos: PhotoInfo[],
  status: (recordName: string) => Status | undefined,
  aliases: Record<string, string>,
  maxNames = 300,
): MondoDayFields {
  const seenPeople = new Set<string>();
  const approved = photos.filter((p) => {
    if (p.dayKey !== dayKey || status(p.recordName) !== "approved") return false;
    if (seenPeople.has(p.mondoID)) return false;
    seenPeople.add(p.mondoID);
    return true;
  });
  const counts = new Map<string, number>();
  for (const p of approved) {
    const tags = new Set(p.tags.map((t) => canonical(t, aliases)));
    for (const t of tags) counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  const top = [...counts.entries()].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, 6);
  return {
    dayKey,
    photoNames: seededShuffle(approved.map((p) => p.recordName), dayKey).slice(0, maxNames),
    lightCount: approved.length,
    countryCount: new Set(approved.map((p) => p.countryCode).filter(Boolean)).size,
    topTags: top.map((t) => t[0]),
    topTagCounts: top.map((t) => t[1]),
  };
}

/// 画像審査の答えを読む。SAFE と言ったものだけ承認。「Safe.」「**SAFE**」「Answer: SAFE」のような形も読む。
/// UNSAFE を先に見る(UNSAFE は SAFE を含むため)。どちらもなければ、あいまい(もう一度審査する)
export function readVerdict(response: string | undefined): Status {
  const words: string[] = (response ?? "").toUpperCase().match(/[A-Z]+/g) ?? [];
  if (words.includes("UNSAFE")) return "rejected";
  if (words.includes("SAFE")) return words.includes("NOT") ? "rejected" : "approved";
  return "retry";
}

/// 審査しなおしの回数から、次の状態を決める(上限に達したら保留)
export function afterUnclear(attempts: number): Status {
  return attempts >= MAX_MODERATION_ATTEMPTS ? "held" : "retry";
}

/// 名前・ことばに、出してはいけない言葉が入っていないか
export function hasBlockedWord(texts: string[], blocked: string[]): boolean {
  const joined = texts.join(" ").toLowerCase();
  return blocked.some((w) => w && joined.includes(w.toLowerCase()));
}
