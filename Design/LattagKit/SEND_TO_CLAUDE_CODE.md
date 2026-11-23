# Claude Code に 送る もの(v132 まで)

## 0. さきに やる こと(たつきさん)
1. `LattagKit_v132_update.zip` を ひらいて、中の `Design` フォルダを **リポジトリの いちばん上に 上書き**(`Design/LattagKit/` に 入る)。
2. 中の `CLAUDE.md` は `Design/LattagKit/CLAUDE.md`。リポジトリの いちばん上の `CLAUDE.md` にも 同じ 中身を 入れる(前と 同じ やり方)。
3. 消す 物:`prompts/reference/ALL_PROMPTS_v47-v131.md`(v132 に 入れかえ)・ もし のこって いれば `prompts/P58_v130_compact.md`(不採用。新しい P58 は `P58_v132_trip_profile_today.md`)。`mock/lattag_v117.html` は のこして も 消して も OK(正解は v118)。

## 1. いま 動いて いる ターミナルへ(すぐ 送る)
**P55 を 進めて いる なら**:
```
Design/LattagKit を 最新に 上書きしました(v132 まで)。
P55 の B 1章(プロフィール)が 変わりました。
Design/LattagKit/prompts/P55_patch_after_v111.md を もう一度 読んで ください。
- B の 1章(プロフィール)は P55 では 作らない で ください。P58(v132)で アーカイブの 形に 作ります。もう 作って いたら そのまま で OK(作った ファイル名 だけ 報告)。
- C の 5章 ・ 6章 は 前と 同じく P57 で 作ります。
- それ 以外(B 2〜3章 ・ C 4章 ・ D ・ E ・ F)は 今の まま 進めて ください。
- CLAUDE.md も 新しく なって います。もう一度 読んで から 続けて ください。
```
**P56 を 進めて いる なら**:
```
Design/LattagKit を 最新に 上書きしました(v132 まで)。
Home の Today の カードが v132 3章(暗室の ひも)に 変わりました。
Design/LattagKit/prompts/P56_v112_font_shutter_frame.md の「読む もの」の 0番 と D を もう一度 読んで ください。
- D の Today は v121 の 3枠 では なく、v132 3章 で 作って ください(見本 screens/v132_today.png ・ モック mock/lattag_v118.html)。
- もう v121 の 形で 作って いたら、D の 終わりに v132 に 作りなおして ください。
- CLAUDE.md も 新しく なって います。もう一度 読んで から 続けて ください。
```

## 2. 順番(前と 同じ + P58)
| 順 | 送る 文 | 中身 |
|---|---|---|
| P55 | (進めて いる まま) | 共有 ・ 搭乗ゲート ・ お知らせ ・ 相互フォロー |
| P56 | `Design/LattagKit/prompts/P56_v112_font_shutter_frame.md を 読んで、その とおりに 進めて。計画モードで 始めて、0 の しらべた 結果を 先に 報告して。` | 字の 形 ・ # の レンズ = 撮る ・ 写真の カード 3枚 ・ Friends ページ ・ **Today = 暗室の ひも** ・ フレーム |
| P57 | `Design/LattagKit/prompts/P57_v129_trip_room_chat.md を 読んで、その とおりに 進めて。計画モードで 始めて、0 の しらべた 結果を 先に 報告して。` | Trip の 部屋 ・ 本当に 送れる チャット(iPhone 2台で ためす) |
| **P58** | 下の 文 | **Trip の 一覧(搭乗パスの 束)・ プロフィール(アーカイブ)・ Today の たしかめ** |

## 3. P57 が 終わったら(P58)
```
Design/LattagKit/prompts/P58_v132_trip_profile_today.md を 読んで、その とおりに 進めて。
計画モードで 始めて、0 の しらべた 結果を 先に 報告して。
```

## 守る こと(毎回)
- **1つの フォルダで 2つの フェーズを 同時に 動かさない**(P55 → P56 → P57 → P58 の 順)。
- `.p8` や トークンは チャットに 貼らない(ターミナルで `wrangler secret put … < ファイル`)。
- CloudKit の **Production に Deploy は 差分を 見て から**。
- **9:00 まえに 友だちの 写真 ・ きょうの 写真を はっきり 出さない**(Trip の 写真の 行 ・ プロフィールの マスも)。
