# P25 ・ v81:アイコン(プロフィール写真)を どこでも 設定

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P25_v81_profile_icon.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。P24 の 上に 足す。

## 読む もの
1. `prompts/reference/PROMPT_v81.md`(**ここが 正解**)
2. `mock/src/v76.css` `v76.js`
3. 見本 `screens/Y02_yesterday_open` `F08_profile` `F11_icon_picker` `F12_profile_no_photo` `O07_onboarding_name`

## すすめ方
1. 今の ユーザー データ(名前 ・ 色)の 保存先と、アバターを 出して いる View を 全部 調べて 報告。
2. `profile.photo`(Storage + ユーザー ドキュメント)を 足し、1つの `AvatarView(size:)` に まとめる(写真 / 1文字 + 色)。
3. 写真を えらぶ シート(撮る ・ ライブラリ ・ 消す ・ 最近の 写真 ・ 大きさ)。
4. 入口:プロフィールの チェキ ・ 設定の 行 ・ はじめての 設定の Name ・ タグの 📷。
5. yesterday の 右上を AvatarView に(1回 = プロフィール ・ 2回 = 今日)。
6. `F08` `F11` `F12` `O07` `Y02` と 比べる。

## 終わったら
- `PROGRESS.md` の P25 に ✓。報告は 短く(Storage の ルールを 変えた なら 書く)。
