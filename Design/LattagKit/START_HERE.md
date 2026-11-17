# はじめに読む(Lattag 実装キット)

モックの画像を貼るだけでは、Claude Code に伝わる情報が足りません。正確な数値、アニメーションの時間、状態ごとの違いが抜けてしまいます。
このキットでは、Claude Code が**モックのコードと実測した数値を自分で読みに行く**ので、貼り付けはほとんど要りません。

---

## 1. 中身

| フォルダ / ファイル | 中身 |
|---|---|
| `CLAUDE.md` | Claude Code が毎回読むルール。**リポジトリのいちばん上に置く** |
| `prompts/P00〜P09` | 10段階の作業指示。**1回に 1つずつ**使う |
| `prompts/reference/` | これまでの詳しい仕様（PROMPT v54〜v67 と、全部をまとめたもの） |
| `mock/lattag_v64.html` | 最新のモック（Safari で開いて触れる） |
| `mock/src/` | モックの元のコード（読む順番は `LOAD_ORDER.md`） |
| `screens/` | オープニングから Trip 作成までの見本画像 **76枚**（`INDEX.md` に一覧） |
| `spec/screens/` | 76画面それぞれの**実測データ**（位置・大きさ・書体・色・角丸・影・ぼかし） |
| `motion/` | 主な動き 14本のコマ割り画像（`INDEX.md` に一覧） |
| `spec/` | 色・書体・バイブ・アニメーションの一覧 |
| `tools/` | 見本と実機を比べる `compare.py`、モックから画像や数値を撮り直す `capture_mock.js` / `capture_motion.js` |

## 2. 準備（最初に 1回）

1. この zip を解凍して、Xcode のプロジェクトのフォルダに **`Design/LattagKit/`** という名前で置く。
2. `Design/LattagKit/CLAUDE.md` を**リポジトリのいちばん上にコピー**する（すでに CLAUDE.md があるなら、その下に中身を足す）。
3. Mac のターミナルで画像比較用の部品を入れる：`pip3 install pillow`
4. Xcode のシミュレータに **iPhone 16e**（なければ iPhone 14 / 13）を入れておく。モックと同じ幅 390pt なので、ぴったり比べられます。
5. キットを git に入れたくない場合は、`.gitignore` に `Design/LattagKit/screens/` と `Design/LattagKit/motion/` を足す（入れても問題はありません）。

## 3. モデルとモード（Fable 以外）

- **モデル**：Claude Code で `/model` と打ち、**Opus** を選ぶ。長く複雑な UI の移植は Opus がいちばん安定します。細かい直しだけのときは Sonnet でも大丈夫です。
- **モード**：各段階の**始めは計画モード**にします（`Shift + Tab` を押して、画面の下に「plan mode」と出る状態）。
  1. Claude Code が、キット・見本・コードを読んで計画を出す。
  2. 計画を見て OK なら承認し、**「自動で編集を受け入れる（auto-accept edits）」**を選ぶ。
  3. ビルドやシミュレータのコマンドで確認を聞かれたら許可する（毎回聞かれて面倒なら「常に許可」で大丈夫です）。
- **1段階 = 1回の会話**です。終わって commit したら `/clear` で会話を消して、次の段階へ進みます。
- 途中で会話が長くなって遅くなったら `/compact`。

## 4. 毎回やること（P00 → P09 の順）

ターミナルでリポジトリのフォルダを開いて `claude` を起動し、次の **1行だけ**を送ります。

```
Design/LattagKit/prompts/P00_setup.md を 読んで、その とおりに 進めて
```

段階ごとに、ファイル名だけを変えます。

| 段階 | 送る 1行の ファイル | 中身 | 目安 |
|---|---|---|---|
| P00 | `P00_setup.md` | 今のアプリを調べる・土台（色・書体・バイブ・ガラス・**DEBUG 状態メニュー**）・名前を Lattag に | 1回 |
| P01 | `P01_opening_onboarding.md` | オープニング・はじめての設定（11画面） | 1〜2回 |
| P02 | `P02_home_top_card.md` | Home の上とカメラカード（10画面） | 2回 |
| P03 | `P03_home_pager.md` | 横スライドの 4ページ・目次・Mondo の地球（8画面） | 1〜2回 |
| P04 | `P04_home_lower.md` | Home の下（11画面） | 1〜2回 |
| P05 | `P05_capture.md` | タグ → 撮影 → 預ける → 翌朝の現像（11画面） | 2回 |
| P06 | `P06_yesterday.md` | Lattag yesterday（6画面） | 1回 |
| P07 | `P07_friends.md` | Friends・Profile・ME（10画面） | 2回 |
| P08 | `P08_trip.md` | Trip をつくるまで（9画面） | 1〜2回 |
| P09 | `P09_finish.md` | 本物のデータとつなぐ・全76画面をもう一度比べる・仕上げ | 1〜2回 |

> 1つの段階が 1回で終わらなかったら、`/clear` のあとに「`Design/LattagKit/prompts/P02_home_top_card.md` の続き。`Design/LattagKit/PROGRESS.md` を見て、のこりをやって」と送る。

## 5. うまくいかないとき

- **見た目がずれる**：「`Design/LattagKit/screens/H01_home.jpg` と違う。`spec/screens/H01_home.json` の数値に合わせて、`tools/compare.py` で比べながら直して」
- **動きが違う**：「`motion/M04_shutter.png` のコマと、`mock/src/v61.js` の `hxBuild` の時間に合わせて」
- **作業が止まる・遅い**：`/compact`。それでもだめなら `/clear` してから、`PROGRESS.md` を読ませて続きを。
- **Mondo などが空っぽ**：今の実機は投稿が無いので空になります。P00 で作る **DEBUG 状態メニューの「見本データ」**で埋めて確かめる。
- **自分で画像を貼りたいとき**：実機のスクショを貼って「これと `screens/○○.jpg` の違いを全部直して」と送るのがいちばん早いです。

## 6. 進み具合

- Claude Code が `Design/LattagKit/PROGRESS.md` に、段階ごとの ✓ と画面ごとの「ずれの点数」（0 に近いほど同じ）を書きます。
- 全部 ✓ になったら完了です。
