# バイブ(触覚) 一覧(モックの コードから 自動抽出)

`hap(名前, "説明")` の 名前 → iOS の 対応:

| 名前 | モックの 振動(ms) | 強さ | 追い打ち | 意味 | 実機(Core Haptics) |
|---|---|---|---|---|---|
| `tick` | 7ms | 0.35 | — | ごく軽く1回 | `UISelectionFeedbackGenerator` か Core Haptics transient 強さ0.35 鋭さ0.6 |
| `sel` | 11ms | 0.50 | — | コツッ | transient 0.50 / 鋭さ0.7(`UIImpactFeedbackGenerator(.light)`) |
| `pop` | 20ms | 0.70 | — | ぷにっ | transient 0.70 / 鋭さ0.35(`.soft`) |
| `click` | 16ms | 0.65 | — | カチッ | transient 0.65 / 鋭さ0.9(`.rigid`) |
| `soft` | 10ms | 0.30 | — | やわらかく1回 | transient 0.30 / 鋭さ0.2 |
| `thud` | 42ms | 1.00 | — | ドン | transient 1.0 / 鋭さ0.3(`.heavy`) |
| `warn` | 26-60-26 | 0.80 | 0, 90ms | やわらかく2回 | transient 0.8 を 0ms と 90ms |
| `success` | 18-60-18-60-46 | 0.90 | 0, 80, 160ms | トトトン | transient 0.9 を 0 / 80 / 160ms(最後だけ 少し長く) |
| `shutter` | 52-28-24 | 1.00 | 0, 70ms | カシャッ 強く2回 | transient 1.0/0.9 → 70ms後 0.8/0.5 |
| `land` | 30ms | 0.85 | — | トン | transient 0.85 / 鋭さ0.4(`.medium`) |
| `heart` | 30-70-18 | 0.90 | 0, 100ms | ドクン | transient 0.9 → 100ms後 0.55 |
| `projector` | 8-38-8-38… | 0.45 | 0, 46, 92, 138ms | カタカタ(映写機) | transient 0.45/鋭さ0.8 を 46ms 間隔で 4回 |
| `buzz` | 120ms | 0.75 | 0, 40, 80ms | ブルブル | continuous 0.75 を 0.12秒 |
| `rumble` | 200ms | 1.00 | 0〜175ms 35ms毎 | ブルブルブル 強く | continuous 1.0 を 0.2秒 + transient を 35ms 毎に 6回 |
| `vui` | 40-20-320 | 1.00 | 0〜300ms 60ms毎 | ブイッ | transient 1.0 → continuous 1.0 を 0.32秒(上がる カーブ) |

- 波紋(ripple)と 画面の ゆれ(`.qk`)は、パソコンで バイブを 見せるための **モックだけの 表現**。実機では 入れない。
- 同じ 名前が 短い間に 連続する 場合は `gap`(ms) 以内は 鳴らさない。

## 呼ばれる 場所

| ファイル | 関数 | 名前 | 説明(モックの 注記) |
|---|---|---|---|
| app.js:69 | onclick | `soft` | やわらかく1回(はずす) |
| app.js:70 | onclick | `tick` | ごく軽く1回(書く) |
| app.js:78 | commit | `warn` | やわらかく2回(もう入ってる) |
| app.js:79 | commit | `warn` | やわらかく2回(3つめは えらべない) |
| app.js:81 | commit | `success` |  |
| app.js:81 | commit | `pop` | ぷにっ(タグが入った) |
| app.js:87 | shake | `tick` | ごく軽く1回(書く) |
| app.js:102 | fillMq | `tick` | ごく軽く1回(とめる) |
| app.js:107 | onclick | `tick` |  |
| app.js:108 | onclick | `tick` |  |
| app.js:109 | onclick | `tick` |  |
| app.js:110 | onclick | `tick` |  |
| app.js:121 | onclick | `sel` | コツッ(えらぶ) |
| app.js:124 | onclick | `pop` | ぷにっ(音楽) |
| app.js:125 | onclick | `sel` | コツッ(きりかえ) |
| app.js:126 | onclick | `tick` |  |
| app.js:126 | onclick | `success` | やさしく2回(つながった) |
| app.js:128 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:128 | onclick | `success` | やさしく2回(きまった) |
| app.js:129 | onclick | `soft` | ふわっ(はずす) |
| app.js:132 | flyIn | `warn` | やわらかく2回(もう入ってる) |
| app.js:132 | flyIn | `warn` | やわらかく2回(3つめは えらべない) |
| app.js:133 | flyIn | `sel` | コツッ(つまむ) |
| app.js:137 | onclick | `warn` | やわらかく2回(今日は、ここまで) |
| app.js:138 | onclick | `click` | カチッ(撮影へ) |
| app.js:139 | onclick | `tick` | ごく軽く1回(もどる) |
| app.js:164 | rp | `click` | キュッ(はじが しまった) |
| app.js:165 | rp | `tick` | ごく軽く1回(もどる) |
| app.js:172 | toTag | `soft` | やわらかく1回(もどる) |
| app.js:197 | onclick | `tick` | ごく軽く1回(タグを なおす) |
| app.js:202 | onclick | `click` |  |
| app.js:203 | onclick | `soft` |  |
| app.js:204 | onclick | `tick` | ごく軽く1回(もどる) |
| app.js:211 | holdStart | `warn` | やわらかく2回(今日は、ここまで) |
| app.js:214 | holdStart | `pop` | ぷにっ(押しこむ) |
| app.js:218 | holdStart | `click` |  |
| app.js:218 | holdStart | `tick` |  |
| app.js:224 | rewind | `tick` |  |
| app.js:227 | hUp | `soft` | やわらかく1回(はなした) |
| app.js:241 | setMode | `sel` | コツッ( |
| app.js:241 | setMode | `tick` | ごく軽く1回(おさまる) |
| app.js:250 | mvStart | `pop` | ぷにっ(押しこむ) |
| app.js:254 | mvStart | `tick` |  |
| app.js:257 | mvStart | `tick` |  |
| app.js:262 | mvGo | `thud` | ドン(まわりはじめた) |
| app.js:262 | mvGo | `click` | カチッ(フィルムが かかった) |
| app.js:271 | mvEnd | `soft` | やわらかく1回(はなした) |
| app.js:272 | mvEnd | `warn` | やわらかく2回(1秒より みじかい) |
| app.js:273 | mvEnd | `soft` | やわらかく1回(テープが とまる) |
| app.js:279 | shoot | `shutter` |  |
| app.js:290 | onfinish | `pop` |  |
| app.js:292 | onfinish | `soft` | ふわっ(ホームへ) |
| app.js:298 | onfinish | `land` | トン(今日のカードに とまった) |
| app.js:302 | volDown | `click` | カチッ(音量ボタンを おした) |
| app.js:317 | onclick | `pop` | ゆらっ(チェキ) |
| app.js:317 | onclick | `click` | カチッ(撮る) |
| app.js:317 | onclick | `warn` | やわらかく2回(順番) |
| app.js:361 | openMondo | `pop` | ぷにっ(Mondo へ) |
| app.js:361 | openMondo | `warn` | やわらかく2回(まだ ひらけない) |
| app.js:363 | onclick | `click` | カチッ(参加する) |
| app.js:364 | toFilm | `sel` | コツッ(今日の film へ) |
| app.js:365 | onclick | `pop` | ぷにっ(現像を のぞく) |
| app.js:367 | onclick | `soft` | やわらかく1回(とじる) |
| app.js:380 | rp | `tick` |  |
| app.js:384 | rp | `land` |  |
| app.js:387 | rp | `pop` | ぷにっ(日の出) |
| app.js:402 | onclick | `warn` | やわらかく2回(12人まで) |
| app.js:402 | onclick | `tick` | ごく軽く1回 |
| app.js:406 | end | `soft` | やわらかく1回(とまった) |
| app.js:407 | end | `warn` |  |
| app.js:407 | end | `pop` | ぷにっ(ふりはじめ) |
| app.js:412 | bumpBurst | `success` | トトトン(BUMP!) |
| app.js:415 | onfinish | `pop` | ぷにっ |
| app.js:419 | onclick | `success` | トトトン(つながった) |
| app.js:420 | onclick | `soft` |  |
| app.js:422 | onclick | `tick` |  |
| app.js:423 | onclick | `click` | カチッ(コピー) |
| app.js:424 | onclick | `tick` |  |
| app.js:427 | bindKnock | `soft` | やわらかく1回(押した) |
| app.js:428 | bindKnock | `tick` |  |
| app.js:430 | bindKnock | `thud` | ドン(つよく) |
| app.js:441 | openSheet | `soft` | ふわっ(シート) |
| app.js:443 | onclick | `tick` |  |
| app.js:448 | onclick | `tick` | ごく軽く1回(はずす) |
| app.js:448 | onclick | `warn` | やわらかく2回(8人まで) |
| app.js:448 | onclick | `pop` | ぷにっ(えらぶ) |
| app.js:450 | onclick | `warn` |  |
| app.js:451 | onclick | `success` | トトトン(おくった) |
| app.js:455 | onclick | `click` | カチッ(リンクを つくる) |
| app.js:456 | onclick | `tick` |  |
| app.js:460 | onclick | `success` | トトトン(リンクが できた) |
| app.js:461 | onclick | `click` | カチッ(コピー) |
| app.js:463 | onclick | `pop` | ぷにっ(共有シート) |
| app.js:473 | onclick | `pop` | ぷにっ(はる) |
| app.js:474 | onclick | `tick` | ごく軽く1回 |
| app.js:475 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:476 | onclick | `success` | トトトン(入った) |
| app.js:477 | onclick | `tick` | ごく軽く1回 |
| app.js:481 | onclick | `success` | トトトン(入った) |
| app.js:482 | onclick | `soft` |  |
| app.js:485 | onclick | `pop` |  |
| app.js:494 | revealCheck | `tick` |  |
| app.js:509 | onclick | `click` | カチッ(撮る) |
| app.js:510 | onclick | `warn` | やわらかく2回(順番) |
| app.js:513 | beatF | `heart` |  |
| app.js:514 | beatF | `soft` | そっと(のぞく) |
| app.js:516 | up | `soft` | やわらかく1回(もどる) |
| app.js:532 | onclick | `click` | カチッ(撮る) |
| app.js:533 | onclick | `warn` | やわらかく2回(順番) |
| app.js:547 | f | `sel` |  |
| app.js:548 | f | `heart` | ドクン(いまの 濃さ) |
| app.js:553 | openDvx | `land` | トン(現像の 中へ) |
| app.js:557 | closeDvx | `soft` | やわらかく1回(もどる) |
| app.js:561 | dxScroll | `sel` | コツッ(となりの こま) |
| app.js:565 | onclick | `click` | カチッ(撮る) |
| app.js:565 | onclick | `warn` | やわらかく2回(いま 見ている) |
| app.js:565 | onclick | `click` | カチッ(もう一度) |
| app.js:568 | onclick | `warn` | やわらかく2回(さきは ひみつ) |
| app.js:569 | onclick | `tick` |  |
| app.js:570 | onclick | `soft` | そっと(つまむ) |
| app.js:580 | onclick | `pop` | ぷにっ(呼ぶ) |
| app.js:581 | onclick | `tick` | ごく軽く1回 |
| app.js:588 | onclick | `pop` |  |
| app.js:591 | onclick | `warn` | やわらかく2回(まだ ひらけない) |
| app.js:591 | onclick | `pop` | ぷにっ(ことばへ) |
| app.js:595 | onclick | `pop` | ぷにっ(その日の 1枚) |
| app.js:598 | ytab | `sel` | コツッ(タブ) |
| app.js:599 | onclick | `tick` |  |
| app.js:607 | onfinish | `pop` | ぷにっ(ダブルタップ) |
| app.js:607 | onfinish | `sel` | コツッ(昨日へ) |
| app.js:607 | onfinish | `soft` |  |
| app.js:608 | onfinish | `sel` | コツッ(昨日へ) |
| app.js:608 | onfinish | `tick` |  |
| app.js:610 | closeY | `pop` | ぷにっ(ダブルタップ) |
| app.js:610 | closeY | `sel` | コツッ(今日へ) |
| app.js:612 | onfinish | `sel` | コツッ(今日へ) |
| app.js:616 | dbl | `tick` |  |
| app.js:620 | hintDbl | `tick` |  |
| app.js:625 | onclick | `pop` | ぷにっ(ME) |
| app.js:626 | onclick | `soft` |  |
| app.js:628 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:642 | onclick | `pop` | ぷにっ(席) |
| app.js:643 | onclick | `sel` | コツッ(シール) |
| app.js:645 | yHeroIn | `pop` | ぷにっ(あなた) |
| app.js:647 | yHeroIn | `tick` |  |
| app.js:649 | yHeroIn | `soft` |  |
| app.js:654 | onclick | `heart` | ドクン(あなた) |
| app.js:655 | onclick | `soft` | やわらかく1回 |
| app.js:656 | onclick | `tick` |  |
| app.js:660 | onclick | `warn` | やわらかく2回(まだ ひらけない) |
| app.js:660 | onclick | `pop` | ぷにっ(ことばへ) |
| app.js:661 | onclick | `soft` |  |
| app.js:671 | bindYd | `success` | トトトン(1年 のこす) |
| app.js:671 | bindYd | `land` |  |
| app.js:675 | up | `sel` | コツッ(めくる) |
| app.js:675 | up | `tick` |  |
| app.js:689 | wkPick | `warn` | やわらかく2回(もうすぐ きえる) |
| app.js:689 | wkPick | `pop` | ぷにっ(日を えらぶ) |
| app.js:691 | wkKeep | `soft` | やわらかく1回(もう ★ です) |
| app.js:694 | wkKeep | `heart` | ドクン(★ 1年 のこす) |
| app.js:699 | f | `pop` | ぷにっ(こまが そろう) |
| app.js:713 | onclick | `tick` |  |
| app.js:719 | cancel | `sel` | コツッ(フィルムが 1こま すすむ) |
| app.js:732 | renderW9 | `soft` | そっと(つかむ) |
| app.js:733 | renderW9 | `tick` |  |
| app.js:733 | renderW9 | `sel` | コツッ(朝が 次の街へ) |
| app.js:734 | up | `soft` | やわらかく1回(いまに もどる) |
| app.js:741 | openFriend | `sel` | コツッ(friend へ) |
| app.js:741 | openFriend | `tick` |  |
| app.js:743 | closeFriend | `soft` | やわらかく1回(もどる) |
| app.js:744 | onclick | `warn` |  |
| app.js:779 | T | `pop` | ぷっ(光が ひとつ) |
| app.js:780 | T | `click` | キュッ(ファインダーが しまる) |
| app.js:781 | T | `shutter` | パシャ(まっ白) |
| app.js:782 | T | `soft` | すーっ(チェキが でてくる) |
| app.js:783 | T | `land` | トン(とまる) |
| app.js:785 | rp | `tick` |  |
| app.js:786 | rp | `heart` | ドクン(日の出に なる) |
| app.js:788 | rp | `land` | トン(おちつく) |
| app.js:790 | skipOpen | `tick` |  |
| app.js:795 | goShoot | `warn` | やわらかく2回(今日は、ここまで) |
| app.js:796 | goShoot | `pop` | ぷにっ(月) |
| app.js:799 | dayDone | `success` | トトトン(今日は、ここまで) |
| app.js:799 | dayDone | `tick` |  |
| app.js:800 | dayDone | `thud` | ドン(9:00 に ひらく) |
| app.js:813 | devSeq | `click` | カチッ(9:00) |
| app.js:817 | rp | `heart` | ドクン(ひらいた) |
| app.js:817 | rp | `tick` |  |
| app.js:818 | rp | `pop` | ぷにっ(上映する) |
| app.js:819 | playIn | `pop` | ぷにっ(ひろがる) |
| app.js:821 | playIn | `projector` | カタカタ(映写機が まわる) |
| app.js:821 | playIn | `tick` |  |
| app.js:822 | playOut | `soft` | やわらかく1回(とじる) |
| app.js:824 | playOut | `tick` | ごく軽く1回(もういちど) |
| app.js:826 | onclick | `tick` | ごく軽く1回(とじる) |
| app.js:838 | go | `pop` | ぷにっ(招待が とどいた) |
| app.js:858 | openRvl | `soft` | ふわっ(暗室) |
| app.js:864 | onfinish | `land` | トン(手の ひらに) |
| app.js:876 | rvLoop | `tick` | ごく軽く(濃くなる) |
| app.js:879 | rvDone | `heart` | ドクン(ひらいた) |
| app.js:879 | rvDone | `success` | トトトン |
| app.js:881 | rvDone | `click` | カチッ(日付) |
| app.js:885 | rvDone | `pop` | ぷにっ(タグを はる) |
| app.js:886 | rvDone | `thud` | ドン(RARE) |
| app.js:891 | rvDone | `tick` |  |
| app.js:893 | rvDone | `sel` | シャッ(ふる) |
| app.js:896 | closeRvl | `soft` | ふわっ(ホームへ) |
| app.js:897 | onclick | `click` | カチッ(投稿する) |
| app.js:898 | onclick | `soft` | ふわっ(投稿しない) |
| app.js:920 | onclick | `tick` | ごく軽く1回(はずす) |
| app.js:920 | onclick | `warn` | やわらかく2回(8人まで) |
| app.js:920 | onclick | `pop` | ぷにっ(えらぶ) |
| app.js:926 | openGnw | `soft` | ふわっ(はじまる) |
| app.js:928 | onfinish | `tick` |  |
| app.js:931 | onclick | `sel` | コツッ(なまえ) |
| app.js:934 | closeGnw | `tick` | ごく軽く1回(書く) |
| app.js:938 | onclick | `tick` | ごく軽く1回(とじる) |
| app.js:941 | onclick | `click` | カチッ(つくる) |
| app.js:944 | onclick | `tick` |  |
| app.js:952 | onclick | `warn` | やわらかく2回(しっぱい) |
| app.js:962 | onclick | `success` | トトトン(できた) |
| app.js:971 | gnShowCode | `tick` |  |
| app.js:972 | onclick | `pop` | ぷにっ(合言葉を コピー) |
| app.js:977 | onclick | `pop` | ぷにっ(共有シート) |
| app.js:979 | onclick | `pop` | ぷにっ(ともだちを 追加) |
| app.js:981 | onclick | `click` | カチッ(コピー) |
| app.js:982 | onclick | `pop` | ぷにっ(もういちど) |
| app.js:982 | onclick | `pop` | ぷにっ(共有シート) |
| app.js:983 | onclick | `soft` | ふわっ(あとで) |
| app.js:984 | onclick | `tick` | ごく軽く1回 |
| app.js:1013 | cmShow | `soft` | ふわっ(はじめての 合図) |
| app.js:1043 | onclick | `sel` | コツッ |
| app.js:1043 | onclick | `pop` | ぷにっ(撮りに いく) |
| app.js:1044 | onclick | `sel` | コツッ(もう 撮った) |
| app.js:1045 | onclick | `warn` | やわらかく2回(きょうは もう つついた) |
| app.js:1047 | onclick | `heart` | ドクン(つつく) |
| app.js:1063 | onclick | `pop` | ぷにっ(共有シート) |
| app.js:1073 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:1073 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:1085 | rmReply | `soft` | ふわっ(とどいた) |
| app.js:1087 | rmSendText | `click` | カチッ(おくる) |
| app.js:1088 | rmSendStk | `pop` | ぷにっ(タグ スタンプ) |
| app.js:1091 | rmView | `pop` | ぷにっ(写真を ひらく) |
| app.js:1093 | rmMenu | `thud` | ドン(もちあげる) |
| app.js:1099 | onclick | `click` | カチッ(コピー) |
| app.js:1100 | onclick | `soft` | ふわっ(とりけす) |
| app.js:1101 | onclick | `sel` | コツッ |
| app.js:1102 | onclick | `success` | やさしく2回(通報した) |
| app.js:1103 | onclick | `warn` | やわらかく2回(たしかめる) |
| app.js:1104 | onclick | `thud` | ドン(ブロック) |
| app.js:1117 | rmAll | `success` | トトトン(ぜんいん そろった) |
| app.js:1121 | onclick | `pop` | ぷにっ(部屋に 入る) |
| app.js:1126 | onclick | `tick` | ごく軽く1回(もどる) |
| app.js:1127 | onclick | `sel` | コツッ |
| app.js:1128 | onclick | `sel` | コツッ(タグ スタンプ) |
| app.js:1132 | onclick | `tick` |  |
| app.js:1134 | onclick | `sel` | コツッ(返信) |
| app.js:1164 | onclick | `sel` | コツッ |
| app.js:1166 | obTag | `tick` | ごく軽く(はずす) |
| app.js:1166 | obTag | `warn` | やわらかく2回(3つまで) |
| app.js:1166 | obTag | `pop` | ぷにっ(タグを はる) |
| app.js:1170 | onclick | `tick` | ごく軽く(とりけす) |
| app.js:1170 | onclick | `pop` | ぷにっ(申請) |
| app.js:1173 | onclick | `click` | カチッ(連絡先) |
| app.js:1177 | onclick | `click` | カチッ(つぎへ) |
| app.js:1178 | onclick | `tick` | ごく軽く(書く) |
| app.js:1181 | go | `click` | カチッ(おくる) |
| app.js:1182 | onclick | `pop` | ぷにっ(写真) |
| app.js:1182 | onclick | `sel` | コツッ(色) |
| app.js:1187 | obAct | `click` | カチッ(サインイン) |
| app.js:1187 | obAct | `success` | トトトン(サインイン できた) |
| app.js:1188 | obAct | `sel` | コツッ |
| app.js:1189 | obAct | `tick` |  |
| app.js:1190 | obAct | `success` | トトトン(もどってきた) |
| app.js:1191 | obAct | `sel` | コツッ |
| app.js:1192 | obAct | `heart` | ドクン |
| app.js:1193 | obAct | `pop` | ぷにっ(共有シート) |
| app.js:1194 | obAct | `success` | トトトン(通知 オン) |
| app.js:1195 | obAct | `soft` | ふわっ(あとで) |
| app.js:1198 | sw | `soft` | ふわっ(通知の 見本) |
| app.js:1198 | sw | `success` | トトトン(できた) |
| app.js:1203 | stop | `soft` | ふわっ(はなした) |
| app.js:1210 | onfinish | `tick` | コツ(たまる) |
| app.js:1211 | onfinish | `buzz` | ブルブル(もうすこし) |
| app.js:1212 | onfinish | `rumble` | ブルブルブル(いっぱい) |
| app.js:1214 | onfinish | `click` | カチッ(おさえた) |
| app.js:1216 | obFinish | `shutter` | カシャッ(はじまる) |
| app.js:1222 | T | `vui` | ブイッ(ようこそ) |
| app.js:1223 | T | `soft` | ふわっ(ひらく) |
| app.js:1236 | T | `tick` | ごく軽く(スロット) |
| app.js:1240 | T | `click` | カチッ(日付が ともる) |
| app.js:1246 | T | `thud` | ドン(Lattag) |
| app.js:1249 | onfinish | `land` | トン(チェキが おちる) |
| app.js:1255 | openOb | `soft` | ふわっ(はじまる) |
| app.js:1256 | onclick | `tick` |  |
| app.js:1258 | onclick | `tick` | ごく軽く1回(もどる) |
| app.js:1259 | onclick | `pop` | ぷにっ(写真) |
| app.js:1283 | onclick | `pop` | ぷにっ(撮りに いく) |
| app.js:1283 | onclick | `pop` | ぷにっ(現像中を みる) |
| app.js:1284 | onclick | `success` | トトトン(入った) |
| app.js:1286 | onclick | `tick` | ごく軽く1回 |
| app.js:1296 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:1296 | onclick | `pop` | ぷにっ(Mondo) |
| app.js:1297 | onclick | `tick` |  |
| app.js:1306 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:1309 | onclick | `heart` | ドクン(1年 のこす) |
| app.js:1309 | onclick | `success` | トトトン |
| app.js:1312 | arcBindTile | `tick` |  |
| app.js:1319 | onclick | `warn` | やわらかく2回(まだ) |
| app.js:1319 | onclick | `pop` | ぷにっ(ことばへ) |
| app.js:1326 | arcAlbums | `heart` | ドクン(★ 1年 のこす) |
| app.js:1327 | onclick | `pop` | ぷにっ |
| app.js:1337 | arcToday | `pop` | ぷにっ(撮りに いく) |
| app.js:1337 | arcToday | `pop` | ぷにっ(撮りに いく) |
| app.js:1337 | arcToday | `pop` | ぷにっ(現像を のぞく) |
| app.js:1343 | openAv | `pop` | ぷにっ(ひらく) |
| app.js:1347 | avDoKeep | `soft` | やわらかく1回(もう のこす) |
| app.js:1347 | avDoKeep | `heart` | ドクン(1年 のこす) |
| app.js:1347 | avDoKeep | `success` | トトトン |
| app.js:1350 | onclick | `tick` | ごく軽く1回(もどる) |
| app.js:1355 | onclick | `tick` | コツ(暗室へ) |
| app.js:1369 | orbActs | `success` | トトトン(入った) |
| app.js:1371 | orbActs | `warn` | やわらかく2回(まだ) |
| app.js:1374 | orbActs | `warn` | やわらかく2回(まだ) |
| app.js:1390 | renderOrb | `pop` | ぷにっ( |
| app.js:1393 | renderOrb | `click` | カチッ(おさえた) |
| app.js:1396 | up | `shutter` | カシャッ(撮影へ) |
| app.js:1397 | up | `pop` | ぷにっ( |
| app.js:1409 | onclick | `pop` | ぷにっ(つくる) |
| app.js:1409 | onclick | `pop` | ぷにっ(参加) |
| app.js:1415 | onclick | `pop` | ぷにっ |
| app.js:1439 | onclick | `sel` | コツッ(ことば) |
| app.js:1440 | onclick | `tick` |  |
| app.js:1442 | onclick | `pop` | ぷにっ(まち) |
| app.js:1443 | onclick | `tick` |  |
| app.js:1445 | onfinish | `soft` | ふわっ(ひかり) |
| app.js:1447 | onfinish | `heart` | ドクン(あなたの 1枚) |
| app.js:1447 | onfinish | `success` | トトトン |
| app.js:1456 | onclick | `sel` | コツッ( |
| app.js:1458 | onclick | `click` | カチッ(絞りが しまる) |
| app.js:1461 | up | `shutter` | カシャッ |
| app.js:1462 | up | `pop` | ぷにっ |
| v46.js:43 | onclick | `pop` | ぷにっ(現像を のぞく) |
| v46.js:43 | onclick | `shutter` | カシャッ(撮影へ) |
| v46.js:47 | lpLive | `tick` |  |
| v46.js:56 | openLive | `pop` | ぷにっ(ライブが ひらく) |
| v46.js:56 | openLive | `tick` |  |
| v46.js:60 | closeLive | `soft` | ふわっ(しまう) |
| v46.js:72 | lockGo | `pop` | ぷにっ(撮りに いく) |
| v46.js:91 | goMe | `pop` | ぷにっ(ME) |
| v46.js:92 | goMe | `tick` |  |
| v46.js:93 | goActive | `pop` | ぷにっ(グループ) |
| v46.js:97 | ovOpen | `soft` | ふわっ(シート) |
| v46.js:99 | onclick | `soft` |  |
| v46.js:109 | onclick | `success` | トトトン(おくった) |
| v46.js:110 | onclick | `click` | カチッ(コピー) |
| v46.js:111 | onclick | `pop` |  |
| v46.js:116 | onclick | `soft` |  |
| v46.js:118 | roomMenu | `sel` | コツッ(メニュー) |
| v46.js:121 | roomMenu | `click` | カチッ |
| v46.js:126 | openPickFr | `pop` | ぷにっ(ともだちを 追加) |
| v46.js:132 | onclick | `warn` |  |
| v46.js:132 | onclick | `success` | トトトン(おくった) |
| v46.js:137 | openScan | `sel` | コツッ(カメラ) |
| v46.js:141 | end | `soft` |  |
| v46.js:142 | end | `success` | トトトン(よめた) |
| v46.js:147 | rmHead | `pop` | ぷにっ(現像を のぞく) |
| v46.js:148 | rmHead | `sel` | コツッ |
| v46.js:152 | arcMondo | `warn` | やわらかく2回(まだ) |
| v46.js:152 | arcMondo | `pop` | ぷにっ(ことばへ) |
| v46.js:153 | arcYesterday | `warn` | やわらかく2回(まだ) |
| v46.js:153 | arcYesterday | `pop` | ぷにっ(Mondo) |
| v46.js:154 | onclick | `pop` | ぷにっ(ひと) |
| v46.js:155 | yOnce | `pop` |  |
| v46.js:156 | yMondo | `pop` |  |
| v46.js:157 | yMondo | `sel` | コツッ |
| v46.js:166 | arcOTD | `heart` | ドクン(ひらく) |
| v46.js:167 | arcOTD | `sel` | コツッ(うらがえす) |
| v46.js:168 | onclick | `tick` |  |
| v46.js:183 | arcFriends | `pop` | ぷにっ(席に よぶ) |
| v46.js:184 | arcFriends | `sel` | コツッ( |
| v46.js:185 | arcFriends | `soft` |  |
| v46.js:186 | arcFriends | `buzz` | ブルブル(ふる) |
| v46.js:188 | arcFriends | `warn` | やわらかく2回(きょうは もう つついた) |
| v46.js:188 | arcFriends | `heart` | ドクン(つついた) |
| v46.js:190 | arcFriends | `pop` |  |
| v46.js:198 | renderArc | `soft` | そっと(ひもを つまむ) |
| v46.js:199 | renderArc | `click` | カチッ(スイッチ) |
| v46.js:202 | sp2 | `click` | カチッ(スイッチ) |
| v48.js:38 | fBind | `pop` | ぷにっ(席に よぶ) |
| v48.js:39 | fBind | `sel` | コツッ( |
| v48.js:40 | fBind | `soft` |  |
| v48.js:43 | onclick | `warn` |  |
| v48.js:43 | onclick | `buzz` | ブルブル(ふる) |
| v48.js:44 | onclick | `pop` |  |
| v48.js:44 | onclick | `pop` |  |
| v48.js:48 | fPoke | `warn` | やわらかく2回(きょうは もう つついた) |
| v48.js:48 | fPoke | `heart` | ドクン(つついた) |
| v48.js:50 | fMenu | `sel` | コツッ( |
| v48.js:59 | end | `soft` | やわらかく1回(とまった) |
| v48.js:60 | end | `warn` |  |
| v48.js:60 | end | `pop` | ぷにっ(ふりはじめ) |
| v48.js:73 | bumpBurst | `success` | トトトン(つながった) |
| v48.js:77 | onfinish | `pop` | ぷにっ |
| v48.js:89 | onclick | `pop` | ぷにっ(なおす) |
| v49.js:10 | arcFriends | `pop` | ぷにっ(ともだちを 呼ぶ) |
| v49.js:11 | arcFriends | `pop` | ぷにっ(Friend へ) |
| v49.js:12 | arcFriends | `pop` |  |
| v49.js:23 | onclick | `pop` | ぷにっ(ともだちを 呼ぶ) |
| v49.js:24 | onclick | `pop` |  |
| v49.js:25 | onclick | `pop` |  |
| v49.js:39 | sp | `pop` | ぷにっ(ちきゅう) |
| v50.js:9 | openMe | `sel` | コツッ(ME) |
| v50.js:9 | openMe | `projector` | カタカタ(フィルム) |
| v50.js:12 | closeMe | `soft` | やわらかく1回(もどる) |
| v50.js:25 | onclick | `pop` | ぷにっ(Recap) |
| v50.js:26 | onclick | `sel` | コツッ( |
| v50.js:27 | onclick | `pop` |  |
| v50.js:38 | onpointerdown | `projector` | カタカタ(上映) |
| v50.js:44 | meGo | `thud` | ドン(つぎの 日) |
| v50.js:49 | meGo | `success` | トトトン(おわり) |
| v50.js:51 | meGo | `tick` |  |
| v50.js:51 | meGo | `success` | トトトン(保存) |
| v50.js:54 | meStop | `soft` |  |
| v50.js:57 | onclick | `pop` | ぷにっ(ME) |
| v50.js:58 | goMe | `pop` | ぷにっ(ME) |
| v50.js:59 | onclick | `pop` |  |
| v51.js:35 | openPrf | `pop` | ぷにっ(プロフィール) |
| v51.js:37 | openPrf | `land` | トン(チェキが おちる) |
| v51.js:38 | openPrf | `tick` | ペタッ(シール) |
| v51.js:42 | onfinish | `soft` | ふわっ(とじる) |
| v51.js:54 | pfBind | `soft` | ペリッ(はがす) |
| v51.js:55 | pfBind | `tick` | ペタッ(はる) |
| v51.js:55 | pfBind | `pop` | ぷにっ( |
| v51.js:56 | onclick | `pop` |  |
| v51.js:59 | onclick | `pop` | ぷにっ(QR) |
| v51.js:61 | onclick | `pop` |  |
| v51.js:62 | onclick | `pop` |  |
| v51.js:63 | onclick | `pop` | ぷにっ(ME) |
| v51.js:64 | onclick | `tick` |  |
| v51.js:65 | onclick | `sel` |  |
| v51.js:67 | onclick | `click` | カチッ |
| v51.js:72 | pfBurst | `rumble` | ブルブル(シールが はじける) |
| v51.js:73 | pfBurst | `tick` |  |
| v52.js:6 | pfEdit | `pop` | ぷにっ(なおす) |
| v52.js:20 | peGo | `sel` | コツッ |
| v52.js:31 | peTag | `warn` | やわらかく2回(3つまで) |
| v52.js:31 | peTag | `pop` | ペタッ(タグ) |
| v52.js:32 | peTag | `tick` | ペリッ(はずす) |
| v52.js:35 | onclick | `shutter` | カシャッ(カメラ) |
| v52.js:35 | onclick | `pop` | ぷにっ(写真) |
| v52.js:35 | onclick | `sel` | コツッ(色) |
| v52.js:44 | peBindStatic | `tick` |  |
| v52.js:45 | peBindStatic | `tick` |  |
| v52.js:46 | onclick | `warn` | やわらかく2回(名前が ない) |
| v52.js:46 | onclick | `soft` |  |
| v52.js:47 | onclick | `success` | トトトン(保存) |
| v52.js:50 | onclick | `soft` |  |
| v52.js:55 | openPrf | `thud` | ドン(なおす) |