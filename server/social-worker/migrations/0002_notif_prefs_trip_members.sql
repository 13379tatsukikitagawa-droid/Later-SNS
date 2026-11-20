-- v111:通知の スイッチ ・ Trip の メンバー登録 ・ チャット通知の 間引き。
-- 何回 流しても 安全(IF NOT EXISTS だけ)。既存の テーブルは 触らない。
--   npx wrangler d1 execute later-social --remote --file=migrations/0002_notif_prefs_trip_members.sql
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

-- 入った 人が 自分で 登録する(uid の 対応表は 作らない)。trip_id = LaterGroup.id(小文字の UUID)
CREATE TABLE IF NOT EXISTS trip_members (
  trip_id TEXT NOT NULL,
  uid TEXT NOT NULL,
  joined_at INTEGER NOT NULL,
  PRIMARY KEY (trip_id, uid)
);
CREATE INDEX IF NOT EXISTS trip_members_uid ON trip_members(uid);

-- 受け取る 人ごとに 1つの Trip で 2分に 1回
CREATE TABLE IF NOT EXISTS trip_chat_push (
  trip_id TEXT NOT NULL,
  uid TEXT NOT NULL,
  last_at INTEGER NOT NULL,
  PRIMARY KEY (trip_id, uid)
);
