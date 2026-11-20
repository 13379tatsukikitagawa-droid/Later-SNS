-- later-social(D1)。`wrangler d1 execute later-social --remote --file=schema.sql`
CREATE TABLE IF NOT EXISTS users (
  uid TEXT PRIMARY KEY,          -- Firebase の uid
  handle TEXT UNIQUE,            -- @id(小文字)
  name TEXT NOT NULL DEFAULT '',
  record_name TEXT,              -- CloudKit の userRecordName(ひもづけ ・ 写真の 取りこみ用)
  updated_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS devices (
  token TEXT PRIMARY KEY,        -- APNs の 端末トークン
  uid TEXT NOT NULL,
  env TEXT NOT NULL DEFAULT 'production',
  updated_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS devices_uid ON devices(uid);
CREATE TABLE IF NOT EXISTS friend_requests (
  from_uid TEXT NOT NULL,
  to_uid TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (from_uid, to_uid)
);
CREATE INDEX IF NOT EXISTS fr_to ON friend_requests(to_uid);
-- 相互だけ。a < b の 順で 1行
CREATE TABLE IF NOT EXISTS friendships (
  a TEXT NOT NULL,
  b TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (a, b)
);
CREATE INDEX IF NOT EXISTS fs_b ON friendships(b);
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  uid TEXT NOT NULL,             -- 受け取る 人
  kind TEXT NOT NULL,            -- request | accepted | mutual | trip_invite | trip_joined
  other_uid TEXT,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  read_at INTEGER
);
CREATE INDEX IF NOT EXISTS n_uid ON notifications(uid, created_at);

-- 1日の 申請の 回数(1人 1日 50件)
CREATE TABLE IF NOT EXISTS request_counts (
  uid TEXT NOT NULL,
  day TEXT NOT NULL,             -- YYYY-MM-DD(UTC)
  n INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (uid, day)
);
-- CloudKit から 1回 だけ 移す 友だち(おたがいに 申し出た 組 だけ 友だちに する)
CREATE TABLE IF NOT EXISTS legacy_claims (
  reporter_rec TEXT NOT NULL,    -- 申し出た 人の CloudKit 記録名
  other_rec TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  PRIMARY KEY (reporter_rec, other_rec)
);

-- v109:Trip の 招待リンク(ランダムな トークン ・ 24時間 ・ 作った 人が のばせる)。KEY は ページに 出さない
CREATE TABLE IF NOT EXISTS trip_links (
  token TEXT PRIMARY KEY,
  uid TEXT NOT NULL,             -- 作った 人
  group_name TEXT NOT NULL DEFAULT '',
  from_name TEXT NOT NULL DEFAULT '',
  dates TEXT NOT NULL DEFAULT '',   -- 例 11/20〜11/22(なければ 空)
  members INTEGER NOT NULL DEFAULT 0,
  key TEXT NOT NULL,             -- 今の KEY(アプリが 参加の 時に 使う)
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS trip_links_exp ON trip_links(expires_at);
-- 1つの IP で 1分 10回 まで(トークンの 当て推量 よけ)
CREATE TABLE IF NOT EXISTS rate_hits (
  ip TEXT NOT NULL,
  minute INTEGER NOT NULL,
  n INTEGER NOT NULL,
  PRIMARY KEY (ip, minute)
);

-- v111:通知の 種類ごとの スイッチ(行が 無い 人は 初期値:ラストコール だけ オフ)
CREATE TABLE IF NOT EXISTS notif_prefs (
  uid TEXT PRIMARY KEY,
  friend_request  INTEGER NOT NULL DEFAULT 1,
  friend_accepted INTEGER NOT NULL DEFAULT 1,
  trip_invite     INTEGER NOT NULL DEFAULT 1,
  trip_chat       INTEGER NOT NULL DEFAULT 1,
  opened          INTEGER NOT NULL DEFAULT 1,
  lastcall        INTEGER NOT NULL DEFAULT 0,
  updated_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS trip_members (
  trip_id TEXT NOT NULL,
  uid TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (trip_id, uid)
);
CREATE INDEX IF NOT EXISTS trip_members_uid ON trip_members(uid);
CREATE TABLE IF NOT EXISTS trip_chat_push (
  trip_id TEXT NOT NULL,
  uid TEXT NOT NULL,
  last_at INTEGER NOT NULL,
  PRIMARY KEY (trip_id, uid)
);
