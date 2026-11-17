# P13 ・ v69 Home を カメラの ファインダーに(ヘッダー ・ 四すみ ・ しぼり羽根)

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P13_v69_camera_header.md` を 読んで、その とおりに 進めて」と だけ 伝える。
> ルールは リポジトリの `CLAUDE.md`。**計画モードで 始めて、計画を 見せて から 作る**。キットの 場所:`Design/LattagKit/`(以下 `Kit/`)。
> P12(v68 フルブリード)の **あと** に やる。P12 が まだ なら、先に P12 の A(Home フルブリード)だけ 終わらせる。

## 読む もの

1. `Kit/prompts/reference/PROMPT_v69.md`(ぜんぶ)
2. `Kit/mock/src/v66.css` `Kit/mock/src/v66.js`(値は ここが 正解)
3. 見本:`Kit/screens/H01_home.jpg` `H04` `H06` `H07` `H09` `H11` `H13` `L01`、数値 `Kit/spec/screens/<ID>.json`(`#hhd` `.h66` `.odb` `.vf66` `#irs`)
4. 動き:`Kit/motion/M17_home_camera_boot.png` `M18_iris_shutter.png` `M19_header_compact.png`

## 作る 順番(1つ ごとに ビルド → シミュレータ → スクショ → 見本と 比べる → commit)

1. **ヘッダーの HUD**(1-1):ロゴ ・ モード ・ アバターの 輪 ・ HUD の ガラス(輪 ・ 点 ・ 秒の 時計 ・ こま)。
2. **まとまる 動き**(1-2):スクロール 60pt で 小さな ガラスへ。iOS 26 は Liquid Glass の 形が 変わる 動き。
3. **四すみ**(2章):78pt の 角丸 ・ 中の ラベル ・ 角の かぎ ・ 飛び出す 動き。
4. **ファインダー**(3章):3分割の 線 ・ AF の 枠。
5. **しぼり羽根**(4章):押す → しまる → はなす → シャッター。
6. 実機の 左上で ロゴに 重なって いる ボタンが 残って いたら 消す。

## 終わったら

- `Kit/PROGRESS.md` に「P13 v69」を 足して ✓、**git commit**。
- `PERF.md` に Home の CPU を 書く(何も しない とき 15% 以下)。
- 報告:できた もの / のこり / 気に なる 所。
