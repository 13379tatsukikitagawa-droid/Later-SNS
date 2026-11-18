# P40 ・ v97:ライブ アクティビティ ・ Dynamic Island(フィルム → ラストコール → 朝の 部)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P40_v97_live.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。**P39(ウィジェット)の A 土台(App Group)が 終わって から**。A〜C の 3回に 分けて commit。

## 読む もの
1. `prompts/reference/PROMPT_v97.md`(**ここが 正解**。v96 の 4章は 古い)
2. `widgets/lattag_live_v97.html`(Safari)・ 見本 `widgets/live/A_film*` `D_lastcall*` `E_opening*`
3. 参考 `widgets/swift/LattagLiveAttributes.swift`(形の 見本 ・ そのまま コピー しない)

## すすめ方
0. **先に 報告**:今の ライブ アクティビティの 有無 ・ ActivityKit の 設定(`NSSupportsLiveActivities`)・ APNs の しくみ。
- **A 形**:`LattagLiveAttributes` ・ ロック画面の 3つの 形(フィルム ・ ラストコール ・ 朝の 部)・ Dynamic Island(小 ・ 最小 ・ ひらく)・ `OpenCameraIntent` の ボタン。Xcode の プレビュー で 5つの phase を 並べて 見本と 比べる。
- **B 始め方 ・ 終わり方**:アプリから start / 3枚で end ・ push-to-start トークン ・ 設定 › 通知 の 夜 / 朝 の オン オフ。
- **C サーバー**:Cloud Functions で 23:00 start / 23:50 update / 24:00 end / 8:30 start / 9:00 update → end(ユーザーの 時間帯)。
- 毎回:時計を 進めて 切りかわりを 確かめる ・ 秒は 自動で 動く ・ 友だちの 本物の 写真は 出さない。

## 終わったら
- `PROMPT_v97.md` 7章。`PROGRESS.md` の P40 に ✓(A〜C)。報告:push の 送り方 ・ 8時間 制限の あつかい ・ 設定の 場所。
