# P29 ・ v86:ME を Recap 中心に(画面 + つくる しくみ)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P29_v86_me_recap.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。**2回に 分ける**(A → B)。

## 読む もの
1. `prompts/reference/PROMPT_v86.md`(**ここが 正解**)
2. `mock/src/v79.css` `v79.js`(と 縦線の `v73.js`)
3. 見本 `screens/F09 F10 F13 F14 F15 F16 F17 F18` ・ 動き `motion/M24_recap_develop` `M25_recap_play`

## A. 画面(1回目)
1. 今の ME の View を さがして、**作りなおす ファイルの 一覧**を 出す(古い Recap の 再生 `meplay` 相当も)。
2. ME:ヒーロー → 作成中 → Recaps → 縦線 → アルバム → 数字。入る 時の 動き。
3. 1日の 全画面(横ページ)・ Recap の 再生(題 → 写真 → おわり ・ タップ / 長押し)。
4. この 段階は **見本の データ**で よい(DEBUG の 状態メニューに `Recap:見た` `Recap:できた(新)` `Recap:再生` を 足す)。
5. 見本と 比べる → `PROGRESS.md` の P29 A に ✓ → git commit。

## B. しくみ(2回目)
1. 自分の 写真を **端末(SwiftData + ファイル)と CloudKit に のこす** 処理が 今 あるか 調べて 報告。なければ 足す(Firebase の 7日で 消す しくみは 変えない)。
2. `Recap` モデル ・ 作る 処理(冪等)・ 3つの きっかけ(ひらいた 時 ・ `BGAppRefreshTask` ・ ローカル通知 月曜 9:00 / 1日 9:00)。
3. 状態 `.building / .ready / .seen` を 画面に つなぐ。
4. 保存 / シェア の 時だけ `AVAssetWriter` で 動画(1080 × 1920)。`Info.plist` に `NSPhotoLibraryAddUsageDescription` と `BGTaskSchedulerPermittedIdentifiers`(`app.lattag.recap`)。
5. `PROMPT_v86.md` E 章の 1〜5 を 確かめる。

## 終わったら
- `PROGRESS.md` の P29 に ✓、git commit。報告:足した ファイル ・ Info.plist の 変更 ・ 写真の のこし方(端末 / iCloud)が どう なって いたか。
