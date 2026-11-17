# P16 ・ v72:アプリアイコン と オープニング B(アイコンが 横へ → Lattag + 9:00 → レンズから Home)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P16_v72_opening.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。

## 読む もの

1. `prompts/reference/PROMPT_v72.md`(**ここが 正解**)
2. 動く 見本 `mock/opening_v72.html`(Safari で 開く ・ はじめから B が 動く ・「ゆっくり ×4」で 確かめる)。**作るのは B だけ**(A は 作らない)
3. `motion/M20_opening_icon_slide.png`(本番 B)、止め絵 `screens/O0x_opening_v72_*.png`
4. 部品 `assets/appicon/` ・ `assets/opening/`

## すすめ方

1. 今の オープニング(チェキ)の 場所と、起動 → Home までの 流れを 調べて 報告。
2. **アイコン**を 差しかえ(AppIcon)。
3. **起動画面**(Info.plist の UILaunchScreen ・ 色 `LaunchInk` = #0B0C0D ・ 画像 `LaunchIcon`)。
4. **OpeningView** を 時間割り どおりに。→ シミュレータで スロー(Debug → Slow Animations)にして `M20` と 比べる。
5. Home へ ひらく つなぎ(丸い mask ・ Home の 入る 動きを 2480ms から)。
6. 出す / 出さない(冷えた 起動だけ ・ とばす ・ 通知から 短い 版 ・ Reduce Motion)。
7. 古い チェキの オープニングを 消す。

## 終わったら

- `PROGRESS.md` の P16 に ✓。git commit(アイコン+起動画面 / オープニング の 2つ)。
- 報告:実機で チラつきが ないか は ユーザーの 確認(スロー撮影)。
