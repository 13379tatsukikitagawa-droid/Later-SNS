// Mondo(世界の「昨日」)のサーバ。Cloudflare Workers(無料プラン)で30分ごとに動く。
//
// 1. 新しい公開写真(MondoPhoto)を画像審査する(Workers AI。はっきり SAFE のものだけ承認)
// 2. 同じ写真への報告(Report)がしきい値に達したら、自動で保留にする
// 3. 昨日・一昨日の MondoDay(承認した写真の一覧・光の数・国の数・ことばの上位6つ)を作りなおす
// 4. 公開から48時間を過ぎた MondoPhoto と、古い MondoDay を削除する
//
// アプリは MondoDay に載っている写真だけを出す(公開レコードの中の値は本人が書きかえられるため信用しない)。

import { CloudKit, type CKRecord } from "./cloudkit.ts";
import { afterUnclear, buildDay, hasBlockedWord, readVerdict, shiftDay, todayKey, type PhotoInfo, type Status } from "./logic.ts";
import { displayPassphrase, isValidToken, issue, resolve, revoke, type Store } from "./invite.ts";

export interface Env {
  AI: Ai;
  MONDO: KVNamespace;
  CLOUDKIT_CONTAINER: string;
  CLOUDKIT_ENVIRONMENT: string;
  /// 見る環境(カンマ区切り)。Xcode から入れたアプリは development、TestFlight・App Store は production に書く
  CLOUDKIT_ENVIRONMENTS?: string;
  CLOUDKIT_KEY_ID: string;
  /// Production 用のサーバ間キー(CloudKit のキーは環境ごと。Development のキーでは Production に入れない)
  CLOUDKIT_PROD_KEY_ID?: string;
  CLOUDKIT_PROD_PRIVATE_KEY?: string;
  CLOUDKIT_PRIVATE_KEY: string;
  REPORT_THRESHOLD: string;
  RETENTION_HOURS: string;
}

const MODEL = "@cf/meta/llama-3.2-11b-vision-instruct";
const PROMPT =
  "You are a strict content moderator for a public photo app used by teenagers. " +
  "Answer with exactly one word: SAFE or UNSAFE. " +
  "UNSAFE if the image contains nudity, sexual content, gore, violence, weapons aimed at people, self-harm, drugs, hate symbols, " +
  "a clearly identifiable face of a child, personal documents, license plates, screens showing private messages, or readable home addresses. " +
  "Otherwise SAFE.";

function photoInfo(r: CKRecord): PhotoInfo {
  return {
    recordName: r.recordName,
    mondoID: String(r.fields.mondoID?.value ?? ""),
    dayKey: String(r.fields.dayKey?.value ?? ""),
    countryCode: r.fields.countryCode?.value as string | undefined,
    tags: (r.fields.tags?.value as string[] | undefined) ?? [],
  };
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

/// 審査の記録の鍵。development は以前からの形のまま、production は頭に prod: を付ける(同じ名前でも混ざらない)
function statusKey(environment: string, recordName: string): string {
  return environment === "development" ? `status:${recordName}` : `status:prod:${recordName}`;
}

async function statusOf(env: Env, environment: string, recordName: string): Promise<Status | undefined> {
  return ((await env.MONDO.get(statusKey(environment, recordName))) ?? undefined) as Status | undefined;
}

async function setStatus(env: Env, environment: string, recordName: string, status: Status, ttlHours: number) {
  await env.MONDO.put(statusKey(environment, recordName), status, { expirationTtl: Math.max(3600, ttlHours * 3600 * 2) });
}

/// 審査しなおした回数(一時的な失敗・あいまいな答え)
async function bumpAttempts(env: Env, environment: string, recordName: string, ttlHours: number): Promise<number> {
  const key = `attempts:${statusKey(environment, recordName)}`;
  const attempts = Number((await env.MONDO.get(key)) ?? "0") + 1;
  await env.MONDO.put(key, String(attempts), { expirationTtl: Math.max(3600, ttlHours * 3600 * 2) });
  return attempts;
}

/// 画像審査(サムネイルで判定)。答えがあいまい・一時的な失敗は retry(次の回に、もう一度)。理由も返す(ログ用。写真・名前は出さない)
async function moderate(env: Env, record: CKRecord, blockedWords: string[]): Promise<{ status: Status; reason: string }> {
  const texts = [String(record.fields.name?.value ?? ""), ...((record.fields.tags?.value as string[]) ?? [])];
  if (hasBlockedWord(texts, blockedWords)) return { status: "rejected", reason: "blockedWord" };
  const url = CloudKit.assetURL(record, "thumb");
  if (!url) return { status: "retry", reason: "noThumbURL" };
  try {
    const response = await fetch(url);
    if (!response.ok) return { status: "retry", reason: `thumbHTTP${response.status}` };
    const image = new Uint8Array(await response.arrayBuffer());
    // 画像は、メッセージの中に data URL で入れる(messages と image を別々に渡す形は、いまのモデルでは
    // 「AiError 3030: no user-supplied messages」で失敗する。prompt + image の形は、ふつうの写真も UNSAFE と答えることがあった)
    const input = {
      messages: [{
        role: "user",
        content: [
          { type: "text", text: PROMPT },
          { type: "image_url", image_url: { url: `data:image/jpeg;base64,${base64(image)}` } },
        ],
      }],
      max_tokens: 4,
    };
    const run = () => env.AI.run(MODEL, input as never);
    let result: unknown;
    try {
      result = await run();
    } catch (error) {
      // このモデルは、はじめに一度だけライセンスへの同意("agree")が必要
      if (String(error).toLowerCase().includes("agree")) {
        await env.AI.run(MODEL, { prompt: "agree" } as never);
        result = await run();
      } else {
        throw error;
      }
    }
    const answer = (result as { response?: string }).response;
    const status = readVerdict(answer);
    return { status, reason: status === "retry" ? `unclearAnswer(${String(answer ?? "").slice(0, 40)})` : "answered" };
  } catch (error) {
    return { status: "retry", reason: `error(${String(error).slice(0, 160)})` };
  }
}

async function run(env: Env, now: Date) {
  const environments = (env.CLOUDKIT_ENVIRONMENTS ?? env.CLOUDKIT_ENVIRONMENT).split(",").map((e) => e.trim()).filter(Boolean);
  for (const environment of environments) {
    // ひとつの環境で失敗しても(スキーマ未反映など)、ほかの環境は続ける
    try {
      await runEnvironment(env, environment, now);
    } catch (error) {
      console.log(`[Mondo][run] env=${environment} error=${String(error).slice(0, 200)}`);
    }
  }
}

async function runEnvironment(env: Env, environment: string, now: Date) {
  const isProduction = environment === "production";
  const keyID = isProduction ? env.CLOUDKIT_PROD_KEY_ID : env.CLOUDKIT_KEY_ID;
  const privateKeyPEM = isProduction ? env.CLOUDKIT_PROD_PRIVATE_KEY : env.CLOUDKIT_PRIVATE_KEY;
  if (!keyID || !privateKeyPEM) {
    console.log(`[Mondo][run] env=${environment} skipped(reason=noServerKey)`);
    return;
  }
  const ck = new CloudKit({
    container: env.CLOUDKIT_CONTAINER,
    environment,
    keyID,
    privateKeyPEM,
  });
  const retentionHours = Number(env.RETENTION_HOURS || "48");
  const threshold = Number(env.REPORT_THRESHOLD || "2");
  const aliases = JSON.parse((await env.MONDO.get("aliases")) ?? "{}") as Record<string, string>;
  const blockedWords = JSON.parse((await env.MONDO.get("blockedWords")) ?? "[]") as string[];

  const today = todayKey(now);
  const days = [shiftDay(today, -2), shiftDay(today, -1), today];
  const textKeys = ["mondoID", "dayKey", "countryCode", "tags", "name"];

  // 報告の数(写真ごと)
  const reports = await ck.query("Report", [{ fieldName: "targetType", comparator: "EQUALS", value: "mondoPhoto" }], ["targetID", "reporterCloudKitUserRecordName"]);
  const reporters = new Map<string, Set<string>>();
  for (const r of reports) {
    const target = String(r.fields.targetID?.value ?? "");
    const reporter = String(r.fields.reporterCloudKitUserRecordName?.value ?? r.recordName);
    if (!reporters.has(target)) reporters.set(target, new Set());
    reporters.get(target)!.add(reporter);
  }

  for (const dayKey of days) {
    const records = await ck.query("MondoPhoto", [{ fieldName: "dayKey", comparator: "EQUALS", value: dayKey }], [...textKeys, "thumb"]);
    console.log(`[Mondo][scan] env=${environment} day=${dayKey} photos=${records.length}`);
    for (const record of records) {
      const current = await statusOf(env, environment, record.recordName);
      const reported = (reporters.get(record.recordName)?.size ?? 0) >= threshold;
      if (reported && current !== "held" && current !== "rejected") {
        await setStatus(env, environment, record.recordName, "held", retentionHours);
        console.log(`[Mondo][moderate] env=${environment} record=${record.recordName} status=held reason=reported`);
        continue;
      }
      if (current === undefined || current === "retry") {
        const verdict = await moderate(env, record, blockedWords);
        let status = verdict.status;
        if (status === "retry") status = afterUnclear(await bumpAttempts(env, environment, record.recordName, retentionHours));
        await setStatus(env, environment, record.recordName, status, retentionHours);
        console.log(`[Mondo][moderate] env=${environment} record=${record.recordName} status=${status} reason=${verdict.reason}`);
      }
    }
    // その日の MondoDay(昨日・一昨日だけ。今日のぶんは窓が閉まるまで出さない)
    if (dayKey !== today) {
      const statuses = new Map<string, Status | undefined>();
      for (const r of records) statuses.set(r.recordName, await statusOf(env, environment, r.recordName));
      const fields = buildDay(dayKey, records.map(photoInfo), (name) => statuses.get(name), aliases);
      await ck.save([{
        recordName: `mondoday_${dayKey}`,
        recordType: "MondoDay",
        fields: {
          dayKey: { value: fields.dayKey },
          photoNames: { value: fields.photoNames },
          lightCount: { value: fields.lightCount },
          countryCount: { value: fields.countryCount },
          topTags: { value: fields.topTags },
          topTagCounts: { value: fields.topTagCounts },
          generatedAt: { value: now.getTime(), type: "TIMESTAMP" },
        },
      }]);
      console.log(`[Mondo][day] env=${environment} day=${dayKey} approved=${fields.photoNames.length} of=${records.length}`);
    }
  }

  // 48時間を過ぎた分を削除(公開は短いほど安全)。dayKey の窓が閉まってから retention を数える
  const expiredDays = [shiftDay(today, -3), shiftDay(today, -4), shiftDay(today, -5)];
  for (const dayKey of expiredDays) {
    const closesAt = new Date(`${shiftDay(dayKey, 1)}T00:00:00Z`).getTime();
    if (now.getTime() - closesAt < retentionHours * 3600 * 1000) continue;
    const old = await ck.query("MondoPhoto", [{ fieldName: "dayKey", comparator: "EQUALS", value: dayKey }], ["dayKey"]);
    try {
      await ck.delete([...old.map((r) => r.recordName), `mondoday_${dayKey}`]);
    } catch (error) {
      // 公開レコードは作った本人のもの。サーバのキーに削除の権限がないときは、ここで失敗する(README の「セキュリティロール」を参照)
      console.log(`[Mondo][delete] env=${environment} day=${dayKey} error=${String(error).slice(0, 160)}`);
    }
  }
}

export default {
  async scheduled(_event: ScheduledEvent, env: Env, ctx: ExecutionContext) {
    ctx.waitUntil(run(env, new Date()));
  },

  // 動作確認用(GET /health)。審査・集計は scheduled だけで動く。
  // グループの合言葉:POST /invite/passphrase(発行)・/invite/resolve(引く)・/invite/revoke(なくす)
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    if (request.method === "POST" && url.pathname.startsWith("/invite/")) {
      return handleInvite(request, env, url.pathname);
    }
    return new Response("not found", { status: 404 });
  },
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function kvStore(kv: KVNamespace): Store {
  return {
    get: (key) => kv.get(key),
    put: (key, value, options) => kv.put(key, value, options),
    delete: (key) => kv.delete(key),
  };
}

/// トークンが本物の招待(CloudKit 公開 DB の invite_<token>)かを確かめる。メンバーだけがトークンを知っている。
async function tokenExists(env: Env, token: string): Promise<boolean> {
  const ck = new CloudKit({
    container: env.CLOUDKIT_CONTAINER,
    environment: env.CLOUDKIT_ENVIRONMENT,
    keyID: env.CLOUDKIT_KEY_ID,
    privateKeyPEM: env.CLOUDKIT_PRIVATE_KEY,
  });
  const records = await ck.lookup([`invite_${token}`], ["groupID"]);
  return records.length > 0;
}

async function handleInvite(request: Request, env: Env, path: string): Promise<Response> {
  let body: { token?: unknown; passphrase?: unknown; device?: unknown; renew?: unknown };
  try {
    body = await request.json();
  } catch {
    return json({ error: "bad request" }, 400);
  }
  const store = kvStore(env.MONDO);
  const now = Date.now();

  if (path === "/invite/resolve") {
    if (typeof body.passphrase !== "string" || body.passphrase.length > 40) return json({ error: "bad request" }, 400);
    const ip = request.headers.get("cf-connecting-ip") ?? "unknown";
    const device = typeof body.device === "string" ? body.device.slice(0, 64) : "unknown";
    const result = await resolve(store, body.passphrase, ip, device, now);
    if (result.status === 200) return json({ token: result.token });
    return json({ error: result.status === 429 ? "too many attempts" : "not found" }, result.status);
  }

  if (!isValidToken(body.token)) return json({ error: "bad request" }, 400);
  const token = body.token;
  if (!(await tokenExists(env, token))) return json({ error: "not found" }, 404);

  if (path === "/invite/passphrase") {
    const issued = await issue(store, token, now, Math.random, { forceNew: body.renew === true });
    return json({ passphrase: issued.passphrase, display: displayPassphrase(issued.passphrase), expiresAt: issued.expiresAt });
  }
  if (path === "/invite/revoke") {
    await revoke(store, token);
    return json({ ok: true });
  }
  return json({ error: "not found" }, 404);
}
