# Claude Code に 送る もの(v133 まで)

## 0. さきに やる こと(たつきさん)
1. `LattagKit_v133_update.zip` を ひらいて、中の `Design` フォルダを **リポジトリの いちばん上に 上書き**(`Design/LattagKit/` に 入る)。
2. 中の `CLAUDE.md` は `Design/LattagKit/CLAUDE.md`。リポジトリの いちばん上の `CLAUDE.md` にも 同じ 中身を 入れる(前と 同じ やり方)。
3. 消す 物:`prompts/reference/ALL_PROMPTS_v47-v132.md`(v133 に 入れかえ)。`mock/lattag_v118.html` は のこして も 消して も OK(正解は v120)。

## 1. いま 動いて いる ターミナルへ(すぐ 送る)
**P55 を 進めて いる なら**(P55 に かかわる 変更は ない ので、CLAUDE.md だけ):
```
Design/LattagKit を 最新に 上書きしました(v133 まで)。
P55 に かかわる 変更は ありません。CLAUDE.md が 新しく なったので、もう一度 読んで から 続けて ください。
```
**P56 を 進めて いる なら**:
```
Design/LattagKit を 最新に 上書きしました(v133 まで)。
Design/LattagKit/prompts/P56_v112_font_shutter_frame.md の「読む もの」の 00番(PROMPT_v133)と B ・ D を もう一度 読んで ください。
- 上の バー:Home ・ Friends ・ Trip で 同じ 部品 TopBar を 作る(通知 52pt ・ 題は ロゴと 同じ SF Pro Black 30pt ・ プロフィール 56pt ・ 同じ 位置 / 写真 / 通知の 数)。B で 作る。
- Today:撮る は 白い チェキに ライムの 丸 48pt、のこりの 枠は 番号の 丸 だけ(v133 1章)。
- Friends の かたまり:マイカード 1枚に まとめる(v133 2章)。カードの 外の「QR を 読む / ID で さがす」と「LINE ・ AirDrop ・ インスタ」は 消す。
- もう 前の 形で 作って いたら、その 区切りの 終わりに v133 に 直して ください。
- アプリに Mondo の 字 ・ 画面が のこって いないか 検索して、あれば 報告して ください(v133 4章)。
- CLAUDE.md も 新しく なって います。もう一度 読んで から 続けて ください。
```

## 2. 順番(前と 同じ)
| 順 | 送る 文 | 中身 |
|---|---|---|
| P55 | (進めて いる まま) | 共有 ・ 搭乗ゲート ・ お知らせ ・ 相互フォロー |
| P56 | `Design/LattagKit/prompts/P56_v112_font_shutter_frame.md を 読んで、その とおりに 進めて。計画モードで 始めて、0 の しらべた 結果を 先に 報告して。` | Home(字の 形 ・ レンズ = 撮る ・ 写真の カード ・ **TopBar** ・ **Today = ひも(次の 1枚 だけ)** ・ **マイカード 1枚** ・ フレーム) |
| P57 | `Design/LattagKit/prompts/P57_v129_trip_room_chat.md を 読んで、その とおりに 進めて。計画モードで 始めて、0 の しらべた 結果を 先に 報告して。` | Trip の 部屋 ・ チャット |
| P58 | `Design/LattagKit/prompts/P58_v132_trip_profile_today.md を 読んで、その とおりに 進めて。計画モードで 始めて、0 の しらべた 結果を 先に 報告して。` | **Friends / Trip の 上の バーを TopBar に** ・ Trip の 一覧 ・ プロフィール ・ Today の たしかめ |

## 守る こと(毎回)
- **1つの フォルダで 2つの フェーズを 同時に 動かさない**(P55 → P56 → P57 → P58 の 順)。
- `.p8` や トークンは チャットに 貼らない(ターミナルで `wrangler secret put … < ファイル`)。
- CloudKit の **Production に Deploy は 差分を 見て から**。
- **★ v119 バズ**(9:00 解禁 ・ シェア カード ・ 招待)は まだ 決めて いない ので、どの フェーズでも 作らない。
