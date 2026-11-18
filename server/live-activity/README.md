# Lattag ライブ アクティビティ サーバー(P40 C ・ v97)

アプリが 前面で ない 時の 開始は **push-to-start**(iOS 17.2〜)。送る 側が この フォルダ。**まだ 配備して いない**(Firebase / APNs の 権限が いる ユーザーの 作業)。

## 必要な もの
- APNs の 認証キー(.p8)・ Key ID ・ Team ID ・ Bundle ID `com.tatsukikitagawa.laternew2`
- Firestore に `liveTokens/{uid}`:`{ startToken, pushToken?, tz: "Asia/Tokyo", night: true, morning: true, dayKey, shots, yesterdayShots, friends }`
  - アプリは `UserDefaults "live.pushToStartToken"` / `"live.pushToken"` に 控えて いる(`LattagLive.startObserving`)。**Firebase の Firestore を アプリに 入れて 送る 部分は 未実装**(今の アプリは Firebase Auth だけ)
- 時間:ユーザーの 時間帯で 23:00 start / 23:50 update / 24:00 end / 8:30 start / 9:00 update → end

## 送り方(APNs)
- topic `<bundle>.push-type.liveactivity` ・ `apns-push-type: liveactivity` ・ priority 10
- start: `{"aps":{"timestamp":T,"event":"start","content-state":{...},"attributes-type":"LattagLiveAttributes","attributes":{"dayKey":"2026-11-18"},"alert":{"title":"","body":""}}}`(トークン = startToken)
- update / end: `{"aps":{"timestamp":T,"event":"update|end","content-state":{...},"dismissal-date":T2}}`(トークン = pushToken)
- `content-state` は アプリの `LattagLiveAttributes.ContentState`(`phase` `shotsTaken` `endsAt`(秒 since 2001 ではなく ISO8601 ではなく **数値 秒**)`frameThumbs` `friendCount` `devPercent`)。
  - ActivityKit の 既定の Date は 2001-01-01 からの 秒(`timeIntervalSinceReferenceDate`)。
- 8時間 制限:夜(23:00〜24:00 = 1時間)と 朝(8:30〜9:00)に 分けて あるので 超えない。
- 友だちの 本物の 写真は 送らない(content-state に 画像を 入れない)。

## 実装 の ひな形
`index.js`(firebase-functions v2 の scheduler。5分ごとに 時間帯が 合う ユーザーを 選ぶ)。
