import { verifyFirebaseToken } from "./auth.ts";
import { sendPush, type ApnsEnv } from "./apns.ts";
import { decideRequest, isExpired, noticeText, normalizeHandle, pair, validHandle, type NoticeKind } from "./logic.ts";

interface Env extends ApnsEnv {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  REQUEST_TTL_DAYS: string;
  NOTICE_TTL_DAYS: string;
  APNS_ENVIRONMENT: string;
}

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });
const err = (status: number, code: string) => json({ error: code }, status);

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    const bearer = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
    const uid = bearer ? await verifyFirebaseToken(bearer, env.FIREBASE_PROJECT_ID) : null;
    if (!uid) return err(401, "unauthorized");
    try { return await route(request, url, uid, env, ctx); }
    catch (e) { console.log("error", String(e)); return err(500, "server"); }
  },

  async scheduled(_e: ScheduledController, env: Env): Promise<void> {
    const now = Date.now();
    await env.DB.prepare("DELETE FROM friend_requests WHERE created_at < ?").bind(now - Number(env.REQUEST_TTL_DAYS) * 86_400_000).run();
    await env.DB.prepare("DELETE FROM notifications WHERE created_at < ?").bind(now - Number(env.NOTICE_TTL_DAYS) * 86_400_000).run();
  },
};

async function route(req: Request, url: URL, me: string, env: Env, ctx: ExecutionContext): Promise<Response> {
  const p = url.pathname;
  const body = req.method === "POST" || req.method === "DELETE" ? ((await req.json().catch(() => ({}))) as Record<string, any>) : {};

  if (p === "/v1/me" && req.method === "POST") {
    const handle = normalizeHandle(String(body.handle ?? ""));
    if (handle && !validHandle(handle)) return err(400, "bad_handle");
    const name = String(body.name ?? "").slice(0, 24);
    try {
      await env.DB.prepare("INSERT INTO users (uid, handle, name, record_name, updated_at) VALUES (?1, ?2, ?3, ?4, ?5) ON CONFLICT(uid) DO UPDATE SET handle=excluded.handle, name=excluded.name, record_name=excluded.record_name, updated_at=excluded.updated_at")
        .bind(me, handle || null, name, body.recordName ? String(body.recordName) : null, Date.now()).run();
    } catch { return err(409, "handle_taken"); }
    return json({ ok: true });
  }

  if (p.startsWith("/v1/users/by-handle/") && req.method === "GET") {
    const h = normalizeHandle(decodeURIComponent(p.split("/").pop() ?? ""));
    const u = await env.DB.prepare("SELECT uid, handle, name FROM users WHERE handle = ?").bind(h).first<{ uid: string; handle: string; name: string }>();
    return u ? json(u) : err(404, "not_found");
  }

  if (p === "/v1/devices" && req.method === "POST") {
    const token = String(body.token ?? "");
    if (!/^[0-9a-f]{32,200}$/i.test(token)) return err(400, "bad_token");
    const e = body.env === "development" ? "development" : "production";
    await env.DB.prepare("INSERT INTO devices (token, uid, env, updated_at) VALUES (?1, ?2, ?3, ?4) ON CONFLICT(token) DO UPDATE SET uid=excluded.uid, env=excluded.env, updated_at=excluded.updated_at").bind(token, me, e, Date.now()).run();
    return json({ ok: true });
  }
  if (p === "/v1/devices" && req.method === "DELETE") {   // ログアウト
    await env.DB.prepare("DELETE FROM devices WHERE token = ? AND uid = ?").bind(String(body.token ?? ""), me).run();
    return json({ ok: true });
  }

  if (p === "/v1/requests" && req.method === "POST") {
    let to = String(body.toUid ?? "");
    if (!to && body.handle) to = (await env.DB.prepare("SELECT uid FROM users WHERE handle = ?").bind(normalizeHandle(String(body.handle))).first<{ uid: string }>())?.uid ?? "";
    if (!to) return err(404, "not_found");
    const [a, b] = pair(me, to);
    const already = !!(await env.DB.prepare("SELECT 1 x FROM friendships WHERE a=? AND b=?").bind(a, b).first());
    const reverse = !!(await env.DB.prepare("SELECT 1 x FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(to, me).first());
    const out = decideRequest(me, to, { alreadyFriends: already, reversePending: reverse });
    if (out.kind === "self") return err(400, "self");
    if (out.kind === "already") return json({ status: "already" });
    if (out.kind === "mutual") { await makeFriends(env, ctx, me, to, "mutual"); return json({ status: "mutual" }); }
    await env.DB.prepare("INSERT INTO friend_requests (from_uid, to_uid, created_at) VALUES (?1, ?2, ?3) ON CONFLICT(from_uid, to_uid) DO UPDATE SET created_at=excluded.created_at").bind(me, to, Date.now()).run();
    await notify(env, ctx, to, "request", me, {});
    return json({ status: "pending" });
  }

  if (p === "/v1/requests/accept" && req.method === "POST") {
    const from = String(body.fromUid ?? "");
    const row = await env.DB.prepare("SELECT created_at FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(from, me).first<{ created_at: number }>();
    if (!row || isExpired(row.created_at, Date.now(), Number(env.REQUEST_TTL_DAYS))) return err(404, "no_request");
    await makeFriends(env, ctx, from, me, "accepted");
    return json({ status: "friends" });
  }

  if (p === "/v1/requests/decline" && req.method === "POST") {   // 相手には 知らせない
    await env.DB.prepare("DELETE FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(String(body.fromUid ?? ""), me).run();
    return json({ ok: true });
  }

  if (p === "/v1/inbox" && req.method === "GET") {
    const cutoff = Date.now() - Number(env.REQUEST_TTL_DAYS) * 86_400_000;
    const reqs = await env.DB.prepare("SELECT r.from_uid uid, r.created_at createdAt, u.name, u.handle FROM friend_requests r LEFT JOIN users u ON u.uid = r.from_uid WHERE r.to_uid = ? AND r.created_at > ? ORDER BY r.created_at DESC LIMIT 100").bind(me, cutoff).all();
    const notices = await env.DB.prepare("SELECT id, kind, other_uid otherUid, title, body, created_at createdAt, read_at readAt FROM notifications WHERE uid = ? ORDER BY created_at DESC LIMIT 100").bind(me).all();
    return json({ requests: reqs.results, notices: notices.results });
  }

  if (p === "/v1/friends" && req.method === "GET") {
    const r = await env.DB.prepare("SELECT CASE WHEN f.a = ?1 THEN f.b ELSE f.a END uid, u.name, u.handle, u.record_name recordName FROM friendships f LEFT JOIN users u ON u.uid = CASE WHEN f.a = ?1 THEN f.b ELSE f.a END WHERE f.a = ?1 OR f.b = ?1").bind(me).all();
    return json({ friends: r.results });
  }

  return err(404, "not_found");
}

/** 相互に する(申請は 両方向 消す)。承認 = 申請した 人へ「承認しました」、おたがいに 申請 = 2人へ 「友だちに なりました」 */
async function makeFriends(env: Env, ctx: ExecutionContext, x: string, y: string, kind: "accepted" | "mutual") {
  const [a, b] = pair(x, y);
  await env.DB.batch([
    env.DB.prepare("INSERT OR IGNORE INTO friendships (a, b, created_at) VALUES (?, ?, ?)").bind(a, b, Date.now()),
    env.DB.prepare("DELETE FROM friend_requests WHERE (from_uid=?1 AND to_uid=?2) OR (from_uid=?2 AND to_uid=?1)").bind(x, y),
  ]);
  if (kind === "accepted") await notify(env, ctx, x, "accepted", y, {});   // x = 申請した 人、y = 承認した 人
  else { await notify(env, ctx, x, "mutual", y, {}); await notify(env, ctx, y, "mutual", x, {}); }
}

/** お知らせに のこし、端末へ push(ユーザーの 通知設定 オフ は 端末側で 表示しない)。`otherUid` の 名前を 文に 入れる */
async function notify(env: Env, ctx: ExecutionContext, toUid: string, kind: NoticeKind, otherUid: string, extra: { group?: string; dates?: string; members?: number }) {
  const o = await env.DB.prepare("SELECT name, handle FROM users WHERE uid = ?").bind(otherUid).first<{ name: string; handle: string | null }>();
  const t = noticeText(kind, { name: o?.name ?? "", handle: o?.handle ?? undefined, ...extra });
  await env.DB.prepare("INSERT INTO notifications (id, uid, kind, other_uid, title, body, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(crypto.randomUUID(), toUid, kind, otherUid, t.title, t.body, Date.now()).run();
  const devices = await env.DB.prepare("SELECT token, env FROM devices WHERE uid = ?").bind(toUid).all<{ token: string; env: string }>();
  ctx.waitUntil((async () => {
    for (const d of devices.results) {
      const r = await sendPush(env, d, { ...t, kind });
      if (r === "gone") await env.DB.prepare("DELETE FROM devices WHERE token = ?").bind(d.token).run();
    }
  })());
}
