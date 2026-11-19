# P50 ・ v107:写真 = チェキ ・ 動画 = iPhone 8 の 質感(**必須**)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P50_v107_film_look.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。A〜D の 4回に 分けて commit。
> **ほかの タブと 同じ フォルダで 同時に 動かさない**。

## 読む もの
1. `prompts/reference/PROMPT_v107.md`(**ここが 正解**)
2. `tools/film/film_pipeline.py`(数字の 正解)・ `assets/film/`(LUT ・ 粒子 ・ 色見本 ・ 見本)
3. `prompts/reference/swift/FilmLook_v107_example.swift`(形の 見本)

## すすめ方
- **0 しらべて 報告**(PROMPT 0章の 5つ)。コードは 変えない。
- **A 写真の チェキ**:素材を Bundle に 入れる → `FilmLook.chekiJPEG` → 撮った あと 1回 焼く → 焼いた ファイル だけ を 保存。先に Unit テスト(色見本)を 書く。
- **B 送る ・ 見せる**:ME ・ Trip ・ 友だち(R2)・ ウィジェット が **焼いた ファイル** を 使う。表示時の フィルターと 古い `FilmEmulation` を 消す。外に 共有 → 白い 枠。
- **C 動画の iPhone 8 風**:撮る 設定(1080p30 ・ HDR オフ ・ sRGB ・ `.standard` ・ H.264)→ 撮った あと 書き出し → 書き出した ファイル だけ を 送る。
- **D はかる**:写真 1枚の ms ・ メモリ ・ 大きさ / 動画 10秒の 書き出し時間 ・ 大きさ / 撮った 直後の ヒッチ。
- 毎回:実機で 撮って `assets/film/samples/_overview.jpg` と 見くらべる。

## 終わったら
- `PROGRESS.md` の P50 に ✓(A〜D)。報告:0 の 結果 ・ 消した 処理 ・ D の 数字 ・ 実機の 写真 / 動画の 見本 3つずつ。
