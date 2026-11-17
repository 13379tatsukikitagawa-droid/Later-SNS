# P01 ・ オープニング と はじめての 設定

> **使い方**:Claude Code に「`Design/LattagKit/prompts/P01_opening_onboarding.md` を 読んで、その とおりに 進めて」と だけ 伝える(この 文を 貼っても よい)。
> ルールは リポジトリの `CLAUDE.md`(= `Design/LattagKit/CLAUDE.md`)。**計画モードで 始めて、計画を 見せて から 作る**。
> キットの 場所:`Design/LattagKit/`(以下 `Kit/` と 書く)。

## 対象

- 画面:`O01_opening_print` `O02_opening_logo` `O03_onboarding_intro` `O04_onboarding_signin` `O05_onboarding_mail` `O06_onboarding_sent` `O07_onboarding_name` `O08_onboarding_tag` `O09_onboarding_fr` `O10_onboarding_nt` `O11_onboarding_go`
- 動き:`Kit/motion/M01_opening.png` `M02_onboarding_intro.png`

## 読む コード(`Kit/mock/src/`)

- `app.js`:`playOpen` `openAnims` `openEnd`(オープニング:スロットから チェキが 出る → 写真が 浮かぶ → 「Lattag」が 1文字ずつ → Home へ)、`#open` の 部品は `body.html`
- `app.js`:`openOb` `obIntro` `obIntroEnd` `obTpl` `obStep` `obBind` `obSync` `obChips` `obDone`(手順:`in` → `mail` → `sent` → `name` → `tag` → `fr` → `nt` → `go`)
- `v48.js` の ob まわりの 上書き、`style.css` の `.ob` `.oplogo` `.wclogo` `.owm`、`v58.css` の 末尾(名前が Lattag に なった ぶんの 文字サイズ:`.owm` 44px ・ `.oplogo` 104px ・ `.wclogo` 112px)

## 作り方の 注意

- 認証(Apple / Google / メールリンク)の **しくみは 今の まま**。見た目と 流れ だけ モックに 合わせる。
- オープニングの 時間配分は `M01` の コマ と `openAnims` の `delay` / `duration` を そのまま。バイブも `hap(` の 場所 どおり(`thud` など)。
- はじめての 設定が おわったら、**いつもの Home**(はじめての 日の 形)へ(`Kit/prompts/reference/PROMPT_v66.md` §4)。はじめて 専用の Home は 作らない。

## さいごに(毎回 同じ)

1. 対象の **すべての 画面 ID** を、DEBUG の 状態メニューで その 状態に して スクショ → `Kit/tools/compare.py` で 比べる → 比べた 画像を **自分で 見て** 直す。
2. `Kit/PROGRESS.md` の この フェーズの 行に ✓ と、画面ごとの score(0 に 近い ほど 同じ)を 書く。
3. `git commit -m "P01 opening and onboarding"`。
4. 報告:できた 画面 / 見本と まだ 違う 所 / 次の フェーズで 気を つける こと(3〜8行)。
