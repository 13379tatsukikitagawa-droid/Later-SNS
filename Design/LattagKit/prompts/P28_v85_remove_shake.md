# P28 ・ v85:Shake(ふって つながる)を なくす

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P28_v85_remove_shake.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。

## 読む もの
1. `prompts/reference/PROMPT_v85.md`(**ここが 正解**)
2. `mock/src/v78.css` `v78.js`
3. 見本 `screens/F01_friend_empty` `F02_friend_list` `F06_add_friends` `O09_onboarding_fr`

## すすめ方
1. **Shake に かかわる もの を 全部 さがして 一覧に して 報告**(View ・ しくみ ・ Info.plist ・ DEBUG ・ 文字 ・ テスト)。消して よいか 確かめて から 消す。
2. 消す → ビルドが 通る ことを 確かめる。
3. Friends に「QR を 見せる / QR を 読む」の カード。下の ボタンは Link ・ ID。Add friends は 3つ。はじめての 設定は リンク だけ。
4. `F01` `F02` `F06` `O09` と 比べる。

## 終わったら
- `PROGRESS.md` の P12 の Shake の 行を「なし(v85 で 消した)」に、P28 に ✓。git commit。報告:消した ファイル ・ Info.plist の 変更。
