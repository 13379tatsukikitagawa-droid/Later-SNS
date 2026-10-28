// グループの合言葉(「くじら 47」)。合言葉 → 招待トークン を、サーバーだけが引けるようにする。
//
// - 招待トークン(128bit 以上のランダム値)は、グループのメンバーだけが知っている。合言葉の発行・再発行は、
//   トークンを持っている(= メンバーである)ことを確かめてから行う(CloudKit 公開 DB の invite_<token>)
// - 合言葉は短く推測されやすいので、引くとき(resolve)に試行回数を制限する(IP・端末ごと、5分に5回)
// - 有効期限は7日。期限がきたら、メンバーの端末が開いたときに新しく発行しなおす
// - 満員かどうかは、アプリが参加の直前と直後に確かめる(CKShare への参加はサーバーで止められないため)

export const PASSPHRASE_TTL_DAYS = 7;
/// 合言葉を引くのは、IP・端末ごとに5分で5回まで
export const RESOLVE_LIMIT = 5;
export const RESOLVE_WINDOW_MS = 5 * 60_000;

/// ひらがなの短いことば(読みやすく、まぎらわしくないもの)
export const WORDS = [
  "くじら", "いるか", "うさぎ", "きつね", "たぬき", "ひつじ", "らくだ", "りんご", "みかん", "いちご",
  "さくら", "もみじ", "ひまわり", "すみれ", "つばき", "ほたる", "とんぼ", "かえる", "めだか", "すずめ",
  "つばめ", "かもめ", "ふくろう", "からす", "こまどり", "ひかり", "そらまめ", "くもり", "あさひ", "ゆうひ",
  "ほしぞら", "なぎさ", "みずうみ", "こもれび", "かざぐるま", "しゃぼん", "ぶらんこ", "すなはま", "わたあめ", "おにぎり",
  "たまご", "ぱんけーき", "ぷりん", "どーなつ", "まどべ", "ろうそく", "てがみ", "ふうせん", "えんぴつ", "けしごむ",
  "らんぷ", "かさ", "ながぐつ", "まふらー", "てぶくろ", "ぼうし", "こたつ", "ふとん", "やかん", "きゅうす",
  "ことり", "こねこ", "こいぬ", "ぺんぎん", "あざらし", "らっこ", "しまうま", "きりん", "ぱんだ", "こあら",
];

export interface Store {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
  delete(key: string): Promise<void>;
}

export function isValidToken(token: unknown): token is string {
  return typeof token === "string" && /^[A-Za-z0-9_-]{22,64}$/.test(token);
}

/// 入力のゆれをそろえる:空白をとる・カタカナ → ひらがな・全角数字 → 半角
export function normalizePassphrase(input: string): string {
  return input
    .normalize("NFKC")
    .replace(/\s+/g, "")
    .replace(/[ァ-ヶ]/g, (c) => String.fromCharCode(c.charCodeAt(0) - 0x60))
    .toLowerCase();
}

export function makePassphrase(random: () => number): string {
  const word = WORDS[Math.floor(random() * WORDS.length) % WORDS.length];
  // ことば70 × 数字900 = 63,000 通り(試行制限とあわせて、当てずっぽうでは入れない)
  const number = 100 + Math.floor(random() * 900);
  return `${word}${number}`;
}

/// 画面に出す形「くじら 47」
export function displayPassphrase(passphrase: string): string {
  return passphrase.replace(/(\d+)$/, " $1");
}

interface Entry {
  token?: string;
  passphrase?: string;
  expiresAt: number;
}

/// 合言葉を発行する。同じトークンに有効な合言葉があれば、それを返す(メンバー全員が同じ合言葉を見る)。
export async function issue(
  store: Store,
  token: string,
  now: number,
  random: () => number,
  options: { forceNew?: boolean } = {},
): Promise<{ passphrase: string; expiresAt: number }> {
  const existingRaw = await store.get(`pptok:${token}`);
  if (existingRaw) {
    const existing = JSON.parse(existingRaw) as Entry;
    // 残り1日を切ったら、新しく出しなおす(使っている途中で切れないように)
    if (!options.forceNew && existing.passphrase && existing.expiresAt - now > 86_400_000) {
      return { passphrase: existing.passphrase, expiresAt: existing.expiresAt };
    }
    if (existing.passphrase) await store.delete(`pp:${existing.passphrase}`);
  }
  const ttl = PASSPHRASE_TTL_DAYS * 86_400;
  const expiresAt = now + ttl * 1000;
  for (let attempt = 0; attempt < 20; attempt++) {
    const passphrase = makePassphrase(random);
    if (await store.get(`pp:${passphrase}`)) continue;
    await store.put(`pp:${passphrase}`, JSON.stringify({ token, expiresAt }), { expirationTtl: ttl });
    await store.put(`pptok:${token}`, JSON.stringify({ passphrase, expiresAt }), { expirationTtl: ttl });
    return { passphrase, expiresAt };
  }
  throw new Error("passphrase space exhausted");
}

/// 合言葉をなくす(リンクの無効化と同時に呼ぶ)
export async function revoke(store: Store, token: string): Promise<void> {
  const existingRaw = await store.get(`pptok:${token}`);
  if (existingRaw) {
    const existing = JSON.parse(existingRaw) as Entry;
    if (existing.passphrase) await store.delete(`pp:${existing.passphrase}`);
  }
  await store.delete(`pptok:${token}`);
}

export type ResolveResult = { status: 200; token: string } | { status: 404 } | { status: 429 };

/// 合言葉からトークンを引く。IP・端末ごとに5分で5回まで(まちがえても、正しくても数える)。
export async function resolve(store: Store, input: string, ip: string, device: string, now: number): Promise<ResolveResult> {
  const bucket = Math.floor(now / RESOLVE_WINDOW_MS);
  const keys = [`rl:ip:${ip}:${bucket}`, `rl:dev:${device || "unknown"}:${bucket}`];
  const counts = await Promise.all(keys.map(async (k) => Number((await store.get(k)) ?? "0")));
  if (counts.some((c) => c >= RESOLVE_LIMIT)) return { status: 429 };
  // KV の TTL は60秒以上
  await Promise.all(keys.map((k, i) => store.put(k, String(counts[i] + 1), { expirationTtl: 600 })));

  const passphrase = normalizePassphrase(input);
  if (!passphrase) return { status: 404 };
  const raw = await store.get(`pp:${passphrase}`);
  if (!raw) return { status: 404 };
  const entry = JSON.parse(raw) as Entry;
  if (!entry.token || entry.expiresAt <= now) return { status: 404 };
  return { status: 200, token: entry.token };
}
