# P05 ・ 撮る(タグ → 撮影 → 預ける → 翌朝の 現像)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P05_capture.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`C01_tag` `C02_camera_photo` `C03_camera_video` `C04_volume_button` `C05_after_shot_1` `C06_after_shot_2` `C07_after_shot_3` `C08_morning_develop_1` `C09_morning_develop_2` `C10_rare_film` `C11_cheki_develop`
- 動き:`M04_shutter`(Home の ボタン → タグ画面)`M06_after_shot` `M08_morning_develop`

## 仕様

撮影まわりは 前に まとめた 仕様が `Kit/prompts/reference/ALL_PROMPTS_v47-v67.md` に ある(「タグ」「撮影」「撮った あと」「現像」「レアフィルム」で 検索)。**見た目は 見本画像と JSON が 正解**。

## 読む コード

- `app.js`:`toTag` `renderTags` `commit`(タグは 3つ まで ・ 流れる 候補 2列 ・ キーボードが 最初から 出る)、`toCam` `renderCam` `setMode`(写真 / 動画)`shoot`、撮った あと `goShoot` `playIn` `playOut`、翌朝 `goDev` `devClear`、`openRvl`(ひらく ・ レア)
- 物理ボタン(音量)の 長押しで 撮る:`vol` の デモ と 撮影画面の 合図

## 作り方の 注意

- カメラは 外カメラ だけ。撮った 写真は **翌朝 9:00 まで 見えない**(しくみは 今の まま)。
- 1日 3枚。翌朝は 今日 撮った 枚数 ぶんだけ 前日が ひらく(今の しくみ)。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P05 capture flow"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
