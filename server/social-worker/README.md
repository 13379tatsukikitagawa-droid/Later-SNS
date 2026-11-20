# later-social(友だち ・ 申請 ・ お知らせ ・ 通知)

Cloudflare Workers + D1。本人確認は Firebase の ID トークン(`Authorization: Bearer <トークン>`)。

| きまり | 中身 |
|---|---|
| 申請 → 承認 | 承認で 相互(`friendships`)。片方だけの フォローは 作らない |
| おたがいに 申請 | その 場で 相互(承認 いらない) |
| 期限 | 申請 7日 ・ お知らせ 30日(毎日 cron で 消す) |

## API(すべて 要トークン)
`POST /v1/me`(handle ・ name ・ recordName)/ `GET /v1/users/by-handle/:id` / `POST|DELETE /v1/devices`(APNs トークン)/ `POST /v1/requests`(toUid か handle)/ `POST /v1/requests/accept|decline`(fromUid)/ `GET /v1/inbox` / `GET /v1/friends`

## 手元で たしかめる
`npm test`(純粋な きまり)。型: 上の 隣の `mondo-worker/node_modules` の tsc でも 通る。

## 出す 手順(たつきさんの 作業 ・ 1つずつ)
1. `cd server/social-worker && npm install`
2. `npx wrangler login`
3. `npx wrangler d1 create later-social` → 出た `database_id` を `wrangler.toml` に 入れる
4. `npx wrangler d1 execute later-social --remote --file=schema.sql`
5. `npx wrangler deploy`
6. APNs(通知):Apple Developer で キー(.p8)を 作り、`npx wrangler secret put APNS_KEY_ID` / `APNS_TEAM_ID` / `APNS_PRIVATE_KEY`(.p8 の 中身 ・ チャットに 貼らない)。
