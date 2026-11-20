import { verifyFirebaseToken } from "./auth.ts";
import { sendPush, sendPushDetailed, type ApnsEnv } from "./apns.ts";
import { LINK_TTL_MS, OG_ORIGIN, aasa, allowedHit, friendCard, newToken, renderPage, tripCard, validToken } from "./links.ts";
import { CHAT_PUSH_INTERVAL_MS, DEFAULT_PREFS, MAX_TRIP_MEMBERS, chatPreview, chatPushDue, validTripId, PREF_KEYS, dayKey, decideRequest, isExpired, noticeText, normalizeHandle, pair, sanitizePrefs, shouldPush, useWorkerFor, validHandle, withinDailyLimit, type NoticeKind, type Prefs } from "./logic.ts";

interface Env extends ApnsEnv {
  DB: D1Database;
  FIREBASE_PROJECT_ID: string;
  REQUEST_TTL_DAYS: string;
  NOTICE_TTL_DAYS: string;
  REQUEST_DAILY_LIMIT: string;
  APNS_ENVIRONMENT: string;
  STORE_URL: string;
  USE_WORKER?: string;        // "1" で みんな オン(リモート設定)
  USE_WORKER_UIDS?: string;   // オンに する 人の uid(カンマ 区切り ・ テスト用)
}

const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });
const err = (status: number, code: string) => json({ error: code }, status);

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/health") return new Response("ok");
    try { const pub = await publicRoute(request, url, env); if (pub) return pub; }
    catch (e) { console.log("public error", String(e)); return new Response("error", { status: 500 }); }
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
    await env.DB.prepare("DELETE FROM trip_links WHERE expires_at < ?").bind(now - 86_400_000).run();
    await env.DB.prepare("DELETE FROM trip_chat_push WHERE last_at < ?").bind(now - 86_400_000).run();
    await env.DB.prepare("DELETE FROM rate_hits WHERE minute < ?").bind(Math.floor(now / 60_000) - 5).run();
  },
};

const html = (body: string, status = 200) => new Response(body, { status, headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store", "referrer-policy": "no-referrer", "x-robots-tag": "noindex" } });

/** 1つの IP で 1分 10回 まで(トークンの 当て推量 よけ) */
async function limited(req: Request, env: Env): Promise<boolean> {
  const ip = req.headers.get("cf-connecting-ip") ?? "unknown";
  const minute = Math.floor(Date.now() / 60_000);
  const row = await env.DB.prepare("INSERT INTO rate_hits (ip, minute, n) VALUES (?1, ?2, 1) ON CONFLICT(ip, minute) DO UPDATE SET n = n + 1 RETURNING n").bind(ip, minute).first<{ n: number }>();
  return !allowedHit(row?.n ?? 1);
}

/** ログイン 不要の 経路:AASA(リダイレクト なし)・ /u /t の ページ ・ og 画像 ・ トークンの 解決 */
async function publicRoute(req: Request, url: URL, env: Env): Promise<Response | null> {
  const p = url.pathname;
  if (req.method !== "GET" && req.method !== "HEAD") return null;
  if (p === "/.well-known/apple-app-site-association") return new Response(aasa(), { headers: { "content-type": "application/json", "cache-control": "public, max-age=300" } });
  if (p === "/og/friend.png" || p === "/og/trip.png") {
    const r = await fetch(OG_ORIGIN + p, { cf: { cacheTtl: 86400, cacheEverything: true } } as RequestInit);
    return new Response(r.body, { status: r.status, headers: { "content-type": "image/png", "cache-control": "public, max-age=86400" } });
  }
  const m = /^\/(u|t)\/([^/]+)\/?$/.exec(p);
  if (m) {
    const code = decodeURIComponent(m[2]);
    const o = { host: url.host, path: `/${m[1]}/${encodeURIComponent(code)}`, code, storeURL: env.STORE_URL ?? "" };
    if (m[1] === "u") {
      const h = normalizeHandle(code);
      const u = validHandle(h) ? await env.DB.prepare("SELECT name FROM users WHERE handle = ?").bind(h).first<{ name: string }>() : null;
      return html(renderPage(friendCard(u?.name ?? null, h || code.slice(0, 30)), { ...o, code: h || code.slice(0, 30) }));
    }
    if (await limited(req, env)) return html("しばらく たってから もう一度 ひらいて ください", 429);
    const t = validToken(code) ? await env.DB.prepare("SELECT group_name, from_name, dates, members FROM trip_links WHERE token = ? AND expires_at > ?").bind(code, Date.now()).first<any>() : null;
    return html(renderPage(tripCard(t), o), 200);
  }
  // アプリが トークンから KEY を 引く(ページには KEY を 出さない)
  const r = /^\/v1\/trip-links\/([^/]+)$/.exec(p);
  if (r) {
    if (await limited(req, env)) return err(429, "rate_limited");
    const code = decodeURIComponent(r[1]);
    const t = validToken(code) ? await env.DB.prepare("SELECT key, group_name groupName, from_name fromName, dates, members FROM trip_links WHERE token = ? AND expires_at > ?").bind(code, Date.now()).first<any>() : null;
    return t ? json(t) : err(404, "expired");
  }
  return null;
}

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
    if (body.recordName) await resolveLegacy(env, String(body.recordName));
    return json({ ok: true });
  }

  if (p.startsWith("/v1/users/by-handle/") && req.method === "GET") {
    const h = normalizeHandle(decodeURIComponent(p.split("/").pop() ?? ""));
    const u = await env.DB.prepare("SELECT uid, handle, name FROM users WHERE handle = ?").bind(h).first<{ uid: string; handle: string; name: string }>();
    return u ? json(u) : err(404, "not_found");
  }

  // v109:Trip の 招待リンクを 作る(ランダム 12文字 ・ 24時間)/ のばす
  if (p === "/v1/trip-links" && req.method === "POST") {
    const key = String(body.key ?? "").replace(/^#/, "").slice(0, 40);
    if (!key) return err(400, "bad_key");
    const token = newToken();
    const now = Date.now();
    await env.DB.prepare("INSERT INTO trip_links (token, uid, group_name, from_name, dates, members, key, created_at, expires_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9)")
      .bind(token, me, String(body.groupName ?? "").slice(0, 40), String(body.fromName ?? "").slice(0, 24), String(body.dates ?? "").slice(0, 24), Math.max(0, Math.min(99, Number(body.members ?? 0) | 0)), key, now, now + LINK_TTL_MS).run();
    return json({ token, expiresAt: now + LINK_TTL_MS });
  }
  if (p === "/v1/trip-links/extend" && req.method === "POST") {
    const t = String(body.token ?? "");
    const exp = Date.now() + LINK_TTL_MS;
    const res = await env.DB.prepare("UPDATE trip_links SET expires_at = ?1 WHERE token = ?2 AND uid = ?3").bind(exp, t, me).run();
    return res.meta.changes ? json({ ok: true, expiresAt: exp }) : err(404, "not_found");
  }

  // v111:リモート設定(useWorker を アプリの 外から 切りかえる)
  if (p === "/v1/config" && req.method === "GET") return json({ useWorker: useWorkerFor(me, env.USE_WORKER, env.USE_WORKER_UIDS) });

  // v111:通知の 種類ごとの 保存
  if (p === "/v1/prefs" && req.method === "GET") return json(await loadPrefs(env, me));
  if (p === "/v1/prefs" && (req.method === "POST" || req.method === "PUT")) {
    const next = sanitizePrefs(body, await loadPrefs(env, me));
    await env.DB.prepare("INSERT INTO notif_prefs (uid, friend_request, friend_accepted, trip_invite, trip_chat, opened, lastcall, updated_at) VALUES (?1,?2,?3,?4,?5,?6,?7,?8) ON CONFLICT(uid) DO UPDATE SET friend_request=excluded.friend_request, friend_accepted=excluded.friend_accepted, trip_invite=excluded.trip_invite, trip_chat=excluded.trip_chat, opened=excluded.opened, lastcall=excluded.lastcall, updated_at=excluded.updated_at")
      .bind(me, ...PREF_KEYS.map((k) => (next[k] ? 1 : 0)), Date.now()).run();
    return json(next);
  }

  // v111:テスト通知(自分の 端末へ)。設定の スイッチに かかわらず 送る。1分 5回まで
  if (p === "/v1/push/test" && req.method === "POST") {
    const minute = Math.floor(Date.now() / 60_000);
    const hit = await env.DB.prepare("INSERT INTO rate_hits (ip, minute, n) VALUES (?1, ?2, 1) ON CONFLICT(ip, minute) DO UPDATE SET n = n + 1 RETURNING n").bind(`push-test:${me}`, minute).first<{ n: number }>();
    if ((hit?.n ?? 1) > 5) return err(429, "rate_limited");
    const devices = await env.DB.prepare("SELECT token, env FROM devices WHERE uid = ?").bind(me).all<{ token: string; env: string }>();
    if (!devices.results.length) return json({ sent: 0, reason: "no_device" });
    let sent = 0; const reasons: string[] = [];
    for (const d of devices.results) {
      const r = await sendPushDetailed(env, d, { title: "Lattag", body: "テスト通知です。届いて います", kind: "test" });
      if (r.result === "ok") { sent++; if (r.usedEnv !== d.env) await env.DB.prepare("UPDATE devices SET env = ? WHERE token = ?").bind(r.usedEnv, d.token).run(); }
      else { reasons.push(r.result === "skip" ? "no_key" : (r.reason ?? r.result)); if (r.result === "gone") await env.DB.prepare("DELETE FROM devices WHERE token = ?").bind(d.token).run(); }
    }
    return json({ sent, devices: devices.results.length, reason: reasons[0] ?? null });
  }

  // v111:Trip の メンバー登録(入った 人が 自分で)・ チャットの 通知
  const tm = /^\/v1\/trips\/([^/]+)\/members$/.exec(p);
  if (tm && (req.method === "POST" || req.method === "DELETE")) {
    const tripId = decodeURIComponent(tm[1]).toLowerCase();
    if (!validTripId(tripId)) return err(400, "bad_trip");
    if (req.method === "DELETE") {
      await env.DB.prepare("DELETE FROM trip_members WHERE trip_id = ? AND uid = ?").bind(tripId, me).run();
      await env.DB.prepare("DELETE FROM trip_chat_push WHERE trip_id = ? AND uid = ?").bind(tripId, me).run();
      return json({ ok: true });
    }
    const cnt = await env.DB.prepare("SELECT COUNT(*) n FROM trip_members WHERE trip_id = ?").bind(tripId).first<{ n: number }>();
    if ((cnt?.n ?? 0) >= MAX_TRIP_MEMBERS) return err(409, "full");
    await env.DB.prepare("INSERT OR IGNORE INTO trip_members (trip_id, uid, joined_at) VALUES (?1, ?2, ?3)").bind(tripId, me, Date.now()).run();
    return json({ ok: true });
  }
  if (p === "/v1/push/trip-chat" && req.method === "POST") {
    const tripId = String(body.tripId ?? "").toLowerCase();
    if (!validTripId(tripId)) return err(400, "bad_trip");
    const mine = await env.DB.prepare("SELECT 1 x FROM trip_members WHERE trip_id = ? AND uid = ?").bind(tripId, me).first();
    if (!mine) return err(403, "not_member");
    const sender = await env.DB.prepare("SELECT name FROM users WHERE uid = ?").bind(me).first<{ name: string }>();
    const preview = chatPreview(body.preview);
    const tripName = String(body.tripName ?? "").slice(0, 40);
    const others = await env.DB.prepare("SELECT uid FROM trip_members WHERE trip_id = ? AND uid != ?").bind(tripId, me).all<{ uid: string }>();
    const now = Date.now();
    let sent = 0;
    for (const o of others.results) {
      if (!shouldPush(await loadPrefs(env, o.uid), "trip_chat")) continue;
      const last = await env.DB.prepare("SELECT last_at FROM trip_chat_push WHERE trip_id = ? AND uid = ?").bind(tripId, o.uid).first<{ last_at: number }>();
      if (!chatPushDue(last?.last_at ?? null, now)) continue;
      await env.DB.prepare("INSERT INTO trip_chat_push (trip_id, uid, last_at) VALUES (?1, ?2, ?3) ON CONFLICT(trip_id, uid) DO UPDATE SET last_at = excluded.last_at").bind(tripId, o.uid, now).run();
      const devices = await env.DB.prepare("SELECT token, env FROM devices WHERE uid = ?").bind(o.uid).all<{ token: string; env: string }>();
      const n = { title: tripName || "Trip", body: `${sender?.name || "だれか"}:${preview}`, kind: "trip_chat", collapseId: tripId };
      ctx.waitUntil((async () => {
        for (const d of devices.results) {
          const r = await sendPush(env, d, n);
          if (r === "gone") await env.DB.prepare("DELETE FROM devices WHERE token = ?").bind(d.token).run();
        }
      })());
      sent++;
    }
    return json({ ok: true, recipients: sent, intervalMs: CHAT_PUSH_INTERVAL_MS });
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
    if (!to && body.toRecordName) to = (await env.DB.prepare("SELECT uid FROM users WHERE record_name = ?").bind(String(body.toRecordName)).first<{ uid: string }>())?.uid ?? "";
    if (!to && body.handle) to = (await env.DB.prepare("SELECT uid FROM users WHERE handle = ?").bind(normalizeHandle(String(body.handle))).first<{ uid: string }>())?.uid ?? "";
    if (!to) return err(404, "not_found");
    const day = dayKey(Date.now());
    const used = (await env.DB.prepare("SELECT n FROM request_counts WHERE uid=? AND day=?").bind(me, day).first<{ n: number }>())?.n ?? 0;
    if (!withinDailyLimit(used, Number(env.REQUEST_DAILY_LIMIT || 50))) return err(429, "too_many_requests");
    const [a, b] = pair(me, to);
    const already = !!(await env.DB.prepare("SELECT 1 x FROM friendships WHERE a=? AND b=?").bind(a, b).first());
    const reverse = !!(await env.DB.prepare("SELECT 1 x FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(to, me).first());
    const out = decideRequest(me, to, { alreadyFriends: already, reversePending: reverse });
    if (out.kind === "self") return err(400, "self");
    if (out.kind === "already") return json({ status: "already" });
    await env.DB.prepare("INSERT INTO request_counts (uid, day, n) VALUES (?1, ?2, 1) ON CONFLICT(uid, day) DO UPDATE SET n = n + 1").bind(me, day).run();
    if (out.kind === "mutual") { await makeFriends(env, ctx, me, to, "mutual"); return json({ status: "mutual" }); }
    await env.DB.prepare("INSERT INTO friend_requests (from_uid, to_uid, created_at) VALUES (?1, ?2, ?3) ON CONFLICT(from_uid, to_uid) DO UPDATE SET created_at=excluded.created_at").bind(me, to, Date.now()).run();
    await notify(env, ctx, to, "request", me, {});
    return json({ status: "pending" });
  }

  if (p === "/v1/requests/accept" && req.method === "POST") {
    let from = String(body.fromUid ?? "");
    if (!from && body.fromRecordName) from = (await env.DB.prepare("SELECT uid FROM users WHERE record_name = ?").bind(String(body.fromRecordName)).first<{ uid: string }>())?.uid ?? "";
    const row = await env.DB.prepare("SELECT created_at FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(from, me).first<{ created_at: number }>();
    if (!row || isExpired(row.created_at, Date.now(), Number(env.REQUEST_TTL_DAYS))) return err(404, "no_request");
    await makeFriends(env, ctx, from, me, "accepted");
    return json({ status: "friends" });
  }

  if (p === "/v1/requests/decline" && req.method === "POST") {   // 相手には 知らせない
    let from = String(body.fromUid ?? "");
    if (!from && body.fromRecordName) from = (await env.DB.prepare("SELECT uid FROM users WHERE record_name = ?").bind(String(body.fromRecordName)).first<{ uid: string }>())?.uid ?? "";
    await env.DB.prepare("DELETE FROM friend_requests WHERE from_uid=? AND to_uid=?").bind(from, me).run();
    return json({ ok: true });
  }

  // CloudKit の 友だち(両方向が ある 組 だけ)を 1回 だけ 移す。両方が 申し出た 時に 友だちに する
  if (p === "/v1/migrate/friends" && req.method === "POST") {
    const rec = String(body.recordName ?? "");
    const mine = await env.DB.prepare("SELECT record_name r FROM users WHERE uid = ?").bind(me).first<{ r: string | null }>();
    if (!rec || mine?.r !== rec) return err(400, "register_first");   // /v1/me で recordName を 先に 登録
    const list = (Array.isArray(body.friends) ? body.friends : []).map(String).filter((x) => x && x !== rec).slice(0, 500);
    if (list.length) await env.DB.batch(list.map((o) => env.DB.prepare("INSERT OR IGNORE INTO legacy_claims (reporter_rec, other_rec, created_at) VALUES (?, ?, ?)").bind(rec, o, Date.now())));
    const made = await resolveLegacy(env, rec);
    return json({ claimed: list.length, connected: made });
  }

  if (p === "/v1/inbox" && req.method === "GET") {
    const cutoff = Date.now() - Number(env.REQUEST_TTL_DAYS) * 86_400_000;
    const reqs = await env.DB.prepare("SELECT r.from_uid uid, r.created_at createdAt, u.name, u.handle, u.record_name recordName FROM friend_requests r LEFT JOIN users u ON u.uid = r.from_uid WHERE r.to_uid = ? AND r.created_at > ? ORDER BY r.created_at DESC LIMIT 100").bind(me, cutoff).all();
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

async function loadPrefs(env: Env, uid: string): Promise<Prefs> {
  const row = await env.DB.prepare("SELECT friend_request, friend_accepted, trip_invite, trip_chat, opened, lastcall FROM notif_prefs WHERE uid = ?").bind(uid).first<Record<string, number>>();
  if (!row) return { ...DEFAULT_PREFS };
  const out = { ...DEFAULT_PREFS };
  for (const k of PREF_KEYS) out[k] = row[k] === 1;
  return out;
}

/** お知らせに のこし、端末へ push(ユーザーの 通知設定 オフ は 端末側で 表示しない)。`otherUid` の 名前を 文に 入れる */
async function notify(env: Env, ctx: ExecutionContext, toUid: string, kind: NoticeKind, otherUid: string, extra: { group?: string; dates?: string; members?: number }) {
  const o = await env.DB.prepare("SELECT name, handle FROM users WHERE uid = ?").bind(otherUid).first<{ name: string; handle: string | null }>();
  const t = noticeText(kind, { name: o?.name ?? "", handle: o?.handle ?? undefined, ...extra });
  await env.DB.prepare("INSERT INTO notifications (id, uid, kind, other_uid, title, body, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)").bind(crypto.randomUUID(), toUid, kind, otherUid, t.title, t.body, Date.now()).run();
  // 送る 時に サーバーで 止める(お知らせの 一覧には のこる)
  if (!shouldPush(await loadPrefs(env, toUid), kind)) return;
  const devices = await env.DB.prepare("SELECT token, env FROM devices WHERE uid = ?").bind(toUid).all<{ token: string; env: string }>();
  ctx.waitUntil((async () => {
    for (const d of devices.results) {
      const r = await sendPush(env, d, { ...t, kind });
      if (r === "gone") await env.DB.prepare("DELETE FROM devices WHERE token = ?").bind(d.token).run();
    }
  })());
}

/** 両方が 申し出た 組(どちらの 記録名も 登録ずみ)を 友だちに する */
async function resolveLegacy(env: Env, rec: string): Promise<number> {
  const rows = await env.DB.prepare(
    "SELECT u1.uid a_uid, u2.uid b_uid FROM legacy_claims c1 JOIN legacy_claims c2 ON c2.reporter_rec = c1.other_rec AND c2.other_rec = c1.reporter_rec JOIN users u1 ON u1.record_name = c1.reporter_rec JOIN users u2 ON u2.record_name = c1.other_rec WHERE c1.reporter_rec = ?"
  ).bind(rec).all<{ a_uid: string; b_uid: string }>();
  let n = 0;
  for (const r of rows.results) {
    const [a, b] = pair(r.a_uid, r.b_uid);
    const res = await env.DB.prepare("INSERT OR IGNORE INTO friendships (a, b, created_at) VALUES (?, ?, ?)").bind(a, b, Date.now()).run();
    n += res.meta.changes ?? 0;
  }
  return n;
}
