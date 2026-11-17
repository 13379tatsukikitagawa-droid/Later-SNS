# Lattag(レイタグ)v62 ・ アプリの 名前を「Later」から「Lattag」に 変える プロンプト

> 新しい 名前は **Lattag(読み:レイタグ)**。**`#` は つけません**(はじめは「#Lattag」と して いましたが、やめました)。
> 画面の 文字・刻印・共有の 文章・通知・設定・ストアの 情報まで、**ユーザーの 目に 入る 所は すべて** 変えます。
> 中身の 名前(Bundle ID・型名・Firebase・CloudKit)は **変えません**(壊れる ため)。
> 見本(正解)は `mock/lattag_v60.html`。

---

## 0. ルール

- 見た目は モックが 正解。`lattag_v60.html` を ひらいて 見くらべる。
- 名前の 文字は **1か所に まとめる**(§2 の `Brand`)。画面に 直接 書かない。
- 「あとで」の 意味の `later`(英語の 動作の 名前:`reqLater` など)・フォント名 `Later Mincho` は **名前の 変更では ない** ので 変えない。
- わからない 所は 推測せず、`MockReference/mock/src/` を 見る。

---

## 1. 名前の かたち

| 使う 場面 | 書き方 | 例 |
|---|---|---|
| ふつうの 名前 | `Lattag` | ヘッダーの ロゴ、「Lattag で つながろう」 |
| 大文字(ラベル) | `LATTAG` | TRIP PASS の 上、Friend カードの 肩書 |
| 小文字(URL・URL スキーム) | `lattag`(`#` は つけない) | `lattag://join`、`https://lattag.app/u/<id>` |
| 読み(Siri・VoiceOver) | レイタグ | `CFBundleSpokenName` |
| 機能の 名前 | **Lattag yesterday**(昨日の ホーム) | 画面の 見出しには 出さず「Yesterday」と 書く |

> 名前に `#` は つけない。アプリの 中の タグ(`#夕焼け` など)と まぎれない ように、ロゴは タグと 同じ 見た目に しない。

---

## 2. 実装(いちばん 先に する)

```swift
enum Brand {
    static let name  = "Lattag"        // 画面・共有の 文章
    static let caps  = "LATTAG"        // 大文字の ラベル
    static let spoken = "レイタグ"
    static let scheme = "lattag"       // lattag://join?shareUrl=...
    static let legacyScheme = "later"  // 古い 招待リンクも 開く(互換)
    static let domain = "lattag.app"   // https://lattag.app/u/<id> など
}
```

- 画面・文章の「Later」を **すべて** `Brand` に 置きかえる。
- `Localizable.strings`(ja / en)の 中の「Later」も 置きかえる。`"%@ に 招待されました。\(Brand.name) で、昨日を ひらきあいましょう。"` のように。

---

## 3. 変える 場所 ・ チェックリスト

### A. アプリの 表示名

- [ ] `Info.plist`:`CFBundleDisplayName` = `Lattag`(ホーム画面に 出る 名前)。
- [ ] `InfoPlist.strings`(ja / en):`CFBundleDisplayName` = `Lattag`、`CFBundleSpokenName` = `レイタグ`。
- [ ] 権限の 説明文:カメラ・写真・位置情報・通知・マイク・連絡先(`NSCameraUsageDescription` など)に ある「Later」を `Lattag` に。
- [ ] 起動画面(LaunchScreen)に 名前の 文字が あれば 差しかえる。

### B. 画面の 文字(モックで 変えた 所)

| 場所 | 変更前 | 変更後 | 大きさ ・ 数値 |
|---|---|---|---|
| Home の ヘッダー ロゴ | Later | **Lattag** | Inter 900、**32pt**、字間 −0.065em。幅 **約 90pt**。右の「today / yesterday」は ロゴの **3pt 右**(旧:x 98 → 新:x 115、画面の 左端 から) |
| Later yesterday の ヘッダー | Later | **Lattag** | Inter 900、**44pt**、字間 −0.07em |
| Home カードの 上の 題字 | Later | **Lattag** | Inter **900 italic 20pt**、白、字間 −0.4pt、中央(その 下は 今日の 日付。`lattag_v63` の とおり) |
| レンズの 刻印 ・ 回る 文字の 輪 | LATER · 28mm … / LATER — TODAY — … | **なくなった**(`lattag_v63` で Home の カードを 作りなおした ため) | — |
| オープニングの ポラロイド | L・a・t・e・r(1文字ずつ 出る) | **L・a・t・t・a・g**(6文字、1文字ずつ) | **44pt**(旧 46pt)。出る 間隔は 70ms の まま |
| オープニング の 大きな 題字(`oplogo`) | Later | **Lattag** | **104pt**(旧 112pt)。幅 約 285pt で 画面に 収まる |
| ウェルカムの 題字(`wclogo`) | Later | **Lattag** | **112pt**(旧 132pt)。幅 約 307pt |
| はじめての 設定の ロゴ(`obl`) | Later | **Lattag** | 34pt(そのまま) |
| タグ画面の 透かし(`wm`) | Later | **Lattag** | 22pt(そのまま) |
| 通知の プレビュー | Later 9:00 | **Lattag 9:00** | — |
| 「Later の 1日」 | Later の 1日 | **Lattag の 1日** | — |
| Friend カード の 肩書 | LATER ・ FRIEND CARD | **LATTAG ・ FRIEND CARD** | — |
| Trip パス の 上 | LATER / TRIP PASS | **LATTAG / TRIP PASS** | — |
| 昨日の 現像の ラベル | later / one by one | **Lattag / one by one** | — |
| 今日の 1曲 | ♪ 今日の 1曲 ・ Later | **♪ 今日の 1曲 ・ Lattag** | — |

> 「Lattag」は 6文字で、5文字の「Later」より **約 1.2倍 長い**。大きな 題字は そのままの 大きさだと 画面の 端に 近づく ので、上の 数値(104 / 112 / 44pt)を 使う。

### C. 共有 ・ 招待の 文章 と リンク

- [ ] グループ・Trip の 招待:`「{name}」に 招待されました。Lattag で、昨日を ひらきあいましょう。\nlattag://join?shareUrl={url}`
- [ ] 友だち 招待:`Lattag で つながろう ・ {name}({id})\nhttps://lattag.app/u/{id}`
- [ ] Trip:`Lattag の Trip「{名前}」に 参加しよう\nKEY {key}\nhttps://lattag.app/t/{key}`
- [ ] 1週間の まとめ:`Your week on Lattag\nhttps://lattag.app/recap`
- [ ] **URL スキーム**:`lattag://` を 追加。古い `later://` も **残して** 受けつける(すでに 送った 招待が 開けなくなる ため)。
- [ ] **ユニバーサルリンク**:`lattag.app` の ドメインを 取得して から `applinks:lattag.app` を Associated Domains に 追加。**取得 前は 今の ドメインの まま**(リンクを 作る 部分だけ `Brand.domain` に 切りかえ 可能に しておく)。

### D. 通知 ・ トースト ・ 設定

- [ ] 通知の タイトル・本文(FCM の 既定、ローカル通知):「Later」を `Lattag` に。
- [ ] 通報の トースト:「通報しました。Lattag が 確認します」「報告しました。Lattag が 確認します」
- [ ] 設定の 言語 の 案内:「iOS の 設定 > Lattag > 言語」
- [ ] 名前の 入力:「Lattag で よばれる なまえ」
- [ ] 友だち ID の 初期の 頭(IDが ない とき の 既定):`later_` → `lattag_`(すでに ある ID は 変えない)。

### E. ウィジェット ・ Siri ・ ショートカット

- [ ] ウィジェットの 表示名・説明(`displayName` / `description`)。
- [ ] App Intents / ショートカットの 文言(「Later を 開く」→「Lattag を 開く」)。読みは「レイタグ」。
- [ ] Live Activity が あれば その 文字。

### F. アプリアイコン

- [ ] アイコンに 文字(L など)が ある 場合は 新しい 名前に 合わせた デザインに 差しかえる(別の 作業。**まだ 作らない**。決まる まで 今の アイコンの まま)。
- [ ] 小さな 「L」の ミニ アイコン(共有バナー・グループ上部)は 今は そのまま。アイコンが 決まったら 同時に 変える。

### G. App Store Connect(提出の とき)

- [ ] **名前**:`Lattag`。同じ 名前が 取られて いる 場合は サブタイトルを 足した 形(例:`Lattag - あした ひらく 写真`)を 使う。
- [ ] サブタイトル・プロモーション・説明文・キーワード・サポート URL・プライバシー ポリシー・利用規約 の「Later」。
- [ ] スクリーンショット(新しい ロゴで 撮りなおす)。
- [ ] **ほかの アプリ・商標と ぶつからないか** 先に 調べる(App Store で「Lattag」を 検索、J-PlatPat と USPTO)。

### H. コードの 中(変えない もの)

- Bundle ID、CloudKit の コンテナ、Firebase の プロジェクト・コレクション名・Storage の パス
- Swift の 型名・ファイル名(`LaterFont.swift`、`LaterColor.swift` など)、Xcode の ターゲット名
- フォント名 `Later Mincho`
- ボタンの 意味の「あとで」(`reqLater` など)
- 内部名の 変更は 別の 作業。**今回は しない**(壊れる 危険が 大きい)。

---

## 4. 完了の 条件

- 画面に 出る 文字の 中に 「Later」と「#Lattag」が **1つも 残って いない**(上の 変えない もの を のぞく)。次の 画面を すべて 見る:オープニング / 初回設定 / ログイン / Home(昼・夜)/ 撮影 / タグ画面 / Yesterday / Friends / Trip(パス・共有)/ Profile / 設定 / 通知 / ウィジェット。
- Home の ヘッダーの ロゴは 幅 約 90pt で、「today / yesterday」と 重ならない。
- 大きな 題字(オープニング・ウェルカム)が **画面から はみ出さない**(iPhone SE と 16 Pro Max の 両方)。
- レンズの 刻印・回る 文字の 輪が **切れずに** 読める。
- `lattag://join?...` と 古い `later://join?...` の 両方で 招待が 開く。
- ホーム画面の アプリ名が `Lattag`(`#` なし)、Siri で「レイタグ」と 言って 開く。
- 全 画面の スクショを `mock/lattag_v60.html` と 比べて、名前の 部分に 差が ない。

---

## 5. 決めて ほしい こと(提出 前に)

- 新しい ドメイン `lattag.app` を 取るか(今の ドメインの まま でも 動く)。
- アプリアイコンの 文字(L の まま か、キャラの 顔に するか)。
- 商標の 確認。
