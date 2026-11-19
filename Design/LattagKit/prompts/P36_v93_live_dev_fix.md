# P36 ・ v93:ライブ パネル(ライム ・ 動く 数字)・ Yesterday ページ 削除 ・ 現像画面(フリーズ 対策)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P36_v93_live_dev_fix.md` を 読んで、その とおりに 進めて」と だけ 伝える。**計画モードで 始める**。1回で よい。

## 読む もの
1. `prompts/reference/PROMPT_v93.md`(**ここが 正解**)
2. `mock/src/v85.css` `v85.js`(`v85LiveIn` ・ `lpLive` ・ `v85NoYday` ・ `renderDvx` ・ `dxApply` ・ `dxPlay`)
3. 見本 `screens/H10_live_panel` `H10b_live_panel_open` `H11〜H15` `L11_develop_view` `L13_develop_pressing` `L14_develop_done`
4. 動き `motion/M33_live_panel_numbers` `motion/M34_develop_press`

## すすめ方
1. **先に 調べて 報告**:現像画面が 止まる 原因(PROMPT_v93 3-1 の 表の どれか)。Instruments(Hangs ・ Time Profiler)の 結果も。
2. 現像画面を 直す:ぼかしは 1回 だけ ・ 動きは 不透明度 だけ ・ 自動 再生 なし ・ VStack で 並べなおす ・ 緑 → ライム。
3. ボタンを 押すと:ライムが たまる + `CHHapticEngine` の パターン(だんだん 細かく)+ 色が 濃く なる → `heart` `success`。
4. ライブ パネル:色を ライムに ・ **数字の オドメーター**(0 から ころがる ・ 毎秒 ・ 1分の 光)・ バーが のびる。
5. Home の 横スライドから Yesterday ページ と 目次の YESTERDAY を 消す(4枚 ・ `/ 03`)。
6. 見本と 比べる(`tools/compare.py`)。**実機で 現像画面を 10回 ひらいて 止まらない ことを 確かめる**。commit。

## 終わったら
- `PROMPT_v93.md` 4章。`PROGRESS.md` の P36 に ✓。報告:フリーズの 原因 ・ Hangs の 数(前 / 後)・ 120fps か。
