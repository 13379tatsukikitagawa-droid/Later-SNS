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
