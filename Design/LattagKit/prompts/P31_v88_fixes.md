# P31 ・ v88:yesterday の アイコン ・ 編集 ・ オープニングの 角 ・ Home の スクロール

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P31_v88_fixes.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。1回で よい。

## 読む もの
1. `prompts/reference/PROMPT_v88.md`(**ここが 正解**)
2. `mock/src/v81.css` `v81.js` ・ `v80.js`(`x8Home` の アイコン)
3. 見本 `screens/F23_profile_edit` `F24_profile_edit_fields` `O0y_opening_icon_corner.png` `O0x_opening_v72_0000ms.png`

## 最初に(計画の 中で 報告)
- D:Home の 上の かたまりに 付いて いる ジェスチャーの 一覧 と、どれが スクロールを 止めて いるか。
- B:古い 白い プロフィール / 編集の View の ファイル名(消す もの)。
- C:オープニングの アイコンを 何で 描いて いるか(AppIcon の 画像 か)。

## すすめ方(この 順で 1つずつ commit)
1. **D** Home の スクロール(UI テスト 3本 を 先に 書いて、赤 → 直す → 緑)。
2. **C** オープニングの 角丸(Slow Animations で 確かめる)。
3. **A** yesterday の アイコン(Home と 同じ 部品に まとめる)。
4. **B** 編集を その場で(古い View を 消す)。`F23` `F24` と 比べる。

## 終わったら
- `PROMPT_v88.md` E章の 1〜4。`PROGRESS.md` の P31 に ✓。
- 報告:スクロールを 止めて いた 原因 ・ 消した ファイル ・ UI テストの 結果。
