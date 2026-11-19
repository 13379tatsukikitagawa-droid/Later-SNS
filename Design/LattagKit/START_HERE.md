# はじめに読む(Lattag 実装キット)

モックの画像を貼るだけでは、Claude Code に伝わる情報が足りません。正確な数値、アニメーションの時間、状態ごとの違いが抜けてしまいます。
このキットでは、Claude Code が**モックのコードと実測した数値を自分で読みに行く**ので、貼り付けはほとんど要りません。

---

## 1. 中身

| フォルダ / ファイル | 中身 |
|---|---|
| `CLAUDE.md` | Claude Code が毎回読むルール。**リポジトリのいちばん上に置く** |
| `prompts/P00〜P09` | 10段階の作業指示。**1回に 1つずつ**使う |
| `prompts/reference/` | これまでの詳しい仕様（PROMPT v54〜v70 と、全部をまとめたもの） |
| `mock/lattag_v83.html` | 最新のモック（Safari で開いて触れる） |
| `mock/lattag_v83.html` の デモボタン | `きのう を ひらく` ・ `Mondo:投稿 あり / なし` ・ `Mondo:地球に もどす` ・ `Friends へ` で yesterday を 動かせる |
| `mock/opening_v72.html` | 新しいオープニングの動く見本（本番 B ・ ゆっくり） |
| `assets/` | アプリアイコン・起動画面の印 |
| `mock/src/` | モックの元のコード（読む順番は `LOAD_ORDER.md`） |
| `screens/` | オープニングから Trip 作成までの見本画像 **83枚**（`INDEX.md` に一覧） |
| `spec/screens/` | 83画面それぞれの**実測データ**（位置・大きさ・書体・色・角丸・影・ぼかし） |
| `motion/` | 主な動き 19本のコマ割り画像（`INDEX.md` に一覧） |
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
| P12 | `P12_v68_home_friends_shake.md` | **v68 最終ブラッシュアップ**:Home フルブリード ・ Friends(BeReal 型)。**Shake の 部分は やらない(v85)** | 2〜3回 |
| P13 | `P13_v69_camera_header.md` | **v69**:Home を カメラの ファインダーに(ヘッダーの HUD ・ 四すみ 78pt ・ しぼり羽根)| 1〜2回 |
| P14 | `P14_v70_friends_card.md` | **v70**:Home 下の Friends カード(Instagram / BeReal 型 ・ キャラクター なし)| 1回 |
| P15 | `P15_v71_lens.md` | **v71**:まんなかを 本物の カメラの レンズに ・「Friends」の 表記 ・ 四すみの かぎを ボタンに 沿わせる | 1回 |
| P16 | `P16_v72_opening.md` | **v72**:新しい アプリアイコン(# + レンズ)・ オープニング B(黒い 画面で アイコンが 横へ → Lattag + 9:00 → レンズから Home)| 1回 |
| P17 | `P17_v73_shutter.md` | **v73**:レンズの まんなかを 黄緑の シャッター(# 入り)に ・ レンズを 黄緑 / 緑に | 1回 |
| P18 | `P18_v74_home_background.md` | **v74**:Home の 地を 単色(黒)に ・ ガラスは ボタン だけ | 1回 |
| P19 | `P19_v75_home_yesterday_me.md` | **v75**:**C(ME の 縦線)だけ** やる(A は P21、B は P20 で 置きかえ)| 1回 |
| P20 | `P20_v76_yesterday.md` | **v76**:Lattag yesterday:Friends = BeReal の 形(未公開は キャプション + ぼかし)・ Mondo = 壮大(投稿 あり / なし)・ タブ = Apple 標準 | 1〜2回 |
| P21 | `P21_v77_home_min_mondo.md` | **v77**:**B(Friends の タグ)・ C(Mondo の 地球儀)だけ** やる(A の Home は P22 で 置きかえ)| 1回 |
| P22 | `P22_v78_hash_home_yesterday.md` | **v78**:Home を 大きな # に(撮る ボタンを 戻す ・ TODAY は ロゴの 右上)・ yesterday の 上の 帯(通知 ・ Friends ・ TODAY)・ あなたの きのう ・ Mondo の タグ ランキング | 2回 |
| P23 | `P23_v79_switch_mondo_home.md` | **v79**:ダブルタップで 切りかえ ・ あなたの きのう(BeReal の 大きさ)・ Mondo の 大きな 地球(指で 回す)・ ない 日 ・ 時間の カプセル ・ ピルから CAMERA を 外す | 1〜2回 |
| P24 | `P24_v80_scroll_compact.md` | **v80**:スクロールで 上の 帯を 小さく(Home ・ yesterday)・ Mondo の 大きな 字を 消す | 1回 |
| P25 | `P25_v81_profile_icon.md` | **v81**:アイコン(プロフィール写真)を プロフィール ・ はじめての 設定で 設定 ・ yesterday 右上 = 自分の アイコン | 1回 |
| P26 | `P26_v82_mondo_globe_notext.md` | **v82**:Mondo の 地球の 画面を 字なしに(写真の ピン ・ 弧 ・ 丸い ボタン)| 1回 |
| P27 | `P27_v83_trip.md` | **v83**:Trip を わかりやすく(1問ずつの 入力 ・ できた 後は Trip の ホーム ・ チャットは サブ)| 2回 |
| P28 | `P28_v85_remove_shake.md` | **v85**:Shake(ふって つながる)を なくす ・ かわりに QR で 会って つながる | 1回 |
| P29 | `P29_v86_me_recap.md` | **v86**:ME を Recap 中心に(毎週 月曜 9:00 に できる ・ 作成中の リング ・ これまでの Recap ・ アルバム ・ 1日の 全画面 ・ Recap の 再生)| 2回(A 画面 → B しくみ)|
| P30 | `P30_v87_fixes.md` | **v87**:実機を 見て 直す(撮影画面の 色 + インカメ ・ Home の 帯 / アイコンで 切りかえ / 地球儀の ボタン / スクロール ・ Friends はじめて ・ Mondo ・ プロフィール + 設定)| 3回(A → B → C)|

> 1つの段階が 1回で終わらなかったら、`/clear` のあとに「`Design/LattagKit/prompts/P02_home_top_card.md` の続き。`Design/LattagKit/PROGRESS.md` を見て、のこりをやって」と送る。

> **順番の おすすめ**:P02〜P04(Home)と P07(Friends)が まだ なら、そのまま 進めて 大丈夫です(見本は v68 に 更新済み)。もう 作って ある 画面は、**P12 を 1回 流す** と v68 に そろいます。

## 5. うまくいかないとき

- **見た目がずれる**：「`Design/LattagKit/screens/H01_home.jpg` と違う。`spec/screens/H01_home.json` の数値に合わせて、`tools/compare.py` で比べながら直して」
- **動きが違う**：「`motion/M04_shutter.png` のコマと、`mock/src/v61.js` の `hxBuild` の時間に合わせて」
- **作業が止まる・遅い**：`/compact`。それでもだめなら `/clear` してから、`PROGRESS.md` を読ませて続きを。
- **Mondo などが空っぽ**：今の実機は投稿が無いので空になります。P00 で作る **DEBUG 状態メニューの「見本データ」**で埋めて確かめる。
- **自分で画像を貼りたいとき**：実機のスクショを貼って「これと `screens/○○.jpg` の違いを全部直して」と送るのがいちばん早いです。

## 6. 進み具合

- Claude Code が `Design/LattagKit/PROGRESS.md` に、段階ごとの ✓ と画面ごとの「ずれの点数」（0 に近いほど同じ）を書きます。
- 全部 ✓ になったら完了です。

| P44 | `P44_v101_auth_google_email.md` | **v101**:Google ・ メールの リンクで サインイン / Apple も Firebase に | 0 + A〜D |
| P45 | `P45_v102_legal_links.md` | **v102**:利用規約 ・ プライバシーを アプリに つなぐ(サインイン画面 ・ 設定 > サポート ・ アプリ内ブラウザ)。小さな 作業 | 0 + A〜B |
| P46 | `P46_v103_friends_backend.md` | **v103**:友だち ・ 申請 ・ 1対1チャット ・ 友だちの 写真を Cloudflare + Firebase 認証に まとめる。**P44 が 先** | 0 + A〜E |
