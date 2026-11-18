# Lattag ウィジェット 一式(v96 ウィジェット + v97 ライブ アクティビティ)

## 中身
| ファイル | なに |
|---|---|
| `lattag_widgets_v96.html` | **ウィジェット の 見本**(Safari で ひらく)。ホーム ・ ロック ・ 一覧 ・ 状態の 表 |
| `lattag_live_v97.html` | **ライブ アクティビティ の 見本**(A〜E の 5案 + おすすめの 流れ)|
| `v96/*.jpg` | ウィジェット 1つずつ の 見本(S1〜S4 ・ M1〜M3 ・ L1 ・ LOCK ・ W01〜W04 = 画面の 中)・ `_overview.jpg` = 全部 |
| `live/*.png` | ライブ アクティビティ 1つずつ(`A_film` `D_lastcall` `E_opening` が 採用 ・ `_island` = Dynamic Island ・ B / C は 予備)|
| `swift/*.swift` | **形の 見本**(そのまま コピー しない)|
| `../prompts/P39_v96_widgets.md` | ウィジェットを 作る 手順(Claude Code に 送る)|
| `../prompts/P40_v97_live.md` | ライブ アクティビティを 作る 手順(Claude Code に 送る)|
| `../prompts/reference/PROMPT_v96.md` | ウィジェットの 詳しい 仕様(4章は 古い → v97)|
| `../prompts/reference/PROMPT_v97.md` | ライブ アクティビティの 詳しい 仕様 |

## 入れ方
- この zip の `LattagKit` を リポジトリの `Design/LattagKit` に **上書きで 合体**(ほかの ファイルは 消さない)。

## 送る 順番(Claude Code)
1. `Design/LattagKit/prompts/P39_v96_widgets.md を読んで、その通りに進めて(計画モードで開始・A→Dの順に1つずつcommit)`
2. P39 の A(App Group)が 終わったら:`Design/LattagKit/prompts/P40_v97_live.md を読んで、その通りに進めて(計画モードで開始・A→Cの順に1つずつcommit)`
