<!-- ========== v101 : サインイン(Google ・ メールの リンク)を 本当に 動かす ========== -->
# PROMPT v101 ・ Google と メールで サインイン(Firebase Authentication)

> **いちばん 新しい 指示**。見た目の 正解:モック `mock/lattag_v92.html` の はじめての 設定(`O04〜O06` ・ `O25〜O31`)。元コード `mock/src/v91.js` `v91.css`(関数は `a9…`)。
> Swift の 形:`prompts/reference/swift/AuthService_v101_example.swift`。
> たつきさんが 自分で やる 設定:`prompts/reference/FIREBASE_SETUP_v101.md`(**これが 終わって いないと 動かない**)。
> モックの デモボタン:`サインイン:送った / 送れない / もどってきた / おかえり / 別の端末 / リンク期限切れ / 登録済み / Google とじた`。

---

## 0. まず しらべて 報告(コードは まだ 変えない)
1. **Firebase の SDK**:版(`Package.resolved`)。メールの リンクは **FirebaseAuth 11.8 以上が 必要**(`linkDomain` を 使う ため)。できれば 最新に 上げる。
2. `FirebaseApp.configure()` を 呼んで いる 場所。`GoogleService-Info.plist` の `BUNDLE_ID` が アプリと 同じか。`CLIENT_ID` と `REVERSED_CLIENT_ID` が 入って いるか。
3. **Apple の サインインの 作り**:Firebase の `OAuthProvider.appleCredential` を 使って いるか(nonce あり)、Apple だけで 完結して いるか。**ログインした 人を 何で 見分けて いるか**(Firebase の `uid` / Apple の `user` / CloudKit の ID)。プロフィールは どこに あるか。
4. 前の メールの 作りの のこり:`dynamicLinkDomain` ・ `page.link` ・ `FirebaseDynamicLinks` が のこって いないか(**2025年8月で 止まった しくみ**。のこって いると 送れない / もどれない)。
5. URL の 受け取り:`.onOpenURL` ・ `.onContinueUserActivity` ・ `AppDelegate` の 場所。`Associated Domains` の 権限。`Info.plist` の `URL Types`。
6. 今の 画面(`O04〜O06`)の View と、ボタンが 何を 呼んで いるか。

**ここで 止まって 報告**。設定(`FIREBASE_SETUP_v101.md`)が 終わって いるかも たつきさんに 聞く。

## 1. 守る こと
- **Apple の サインインを 壊さない**(今 入れて いる 人が 入れなく なるのが いちばん こわい)。終わったら Apple で 入りなおして 同じ 人に なるかを 確かめる。
- **変えない**:Bundle ID ・ Firebase の プロジェクト ・ CloudKit の コンテナ ・ 型名。
- 見た目は モック どおり。字は モックの まま(分かち書き)。
- **リリース版の ログに メールアドレスや トークンを 出さない**(`#if DEBUG` だけ)。

## 2. Google で つづける(`O04`)
1. Swift Package:`https://github.com/google/GoogleSignIn-iOS`(SPM。CocoaPods は 使わない)。
2. `Info.plist` の `URL Types` に `REVERSED_CLIENT_ID` を 入れる。
3. 押す → ボタンの 字が 回る 点 + `Google`(`a9dot`)・ `click`。
4. `GIDSignIn.sharedInstance.signIn(withPresenting:)` で いちばん 上の 画面から ひらく。
5. `GoogleAuthProvider.credential(withIDToken:accessToken:)` → `Auth.auth().signIn(with:)`。
6. **えらぶ 画面を とじた(キャンセル)= 何も 出さない**。ボタンが 元に もどる だけ + `soft`。
7. URL は `GIDSignIn.sharedInstance.handle(url)` に わたす(`.onOpenURL`)。

## 3. メールで つづける(リンク ・ パスワード なし)
### 3-1. おくる(`O05` → `O25` → `O06`)
- 形を たしかめる(まちがい = 下に オレンジ `#FF7A2F` の 1行 + 下線が オレンジ + 左右に ゆれる)。
- 押す → `おくって います`(点が 回る ・ ボタンは 押せない)・ `click`。
- `ActionCodeSettings`:
  - `url` = `https://<PROJECT_ID>.firebaseapp.com/finishSignIn`
  - `handleCodeInApp = true`
  - `setIOSBundleID(Bundle.main.bundleIdentifier!)`
  - **`linkDomain = "<PROJECT_ID>.firebaseapp.com"`**
  - `dynamicLinkDomain` は **使わない**
- 成功 → メールアドレスを **端末に 保存**(`UserDefaults` ・ 送った 時刻も)→ `O06`。
- `O06`:`メールを ひらく`(メールの アプリを ひらく)・ **`もういちど おくる` は 60秒 まつ**(`0:59` と 数字が へる)・ `アドレスを まちがえた` で もどる。
### 3-2. おくれない(`O26`)
- 1行で やさしく。**DEBUG と TestFlight だけ** 下に 小さく `auth/… (番号)`。`warn`。
| 番号 | 意味 | 画面の 1行 |
|---|---|---|
| 17008 `invalidEmail` | 形が ちがう | メールアドレスの 形を たしかめて ください |
| 17006 `operationNotAllowed` | Console で メールリンクが オフ | 今は この 方法が 使えません(→ 設定 1-2)|
| `unauthorizedDomain` / `invalidContinueURI` / `unauthorizedContinueURI` | ドメインの 許可 | 今は この 方法が 使えません(→ 設定 1-4)|
| 17010 `tooManyRequests` / `quotaExceeded` | 送りすぎ | 少し まって、もう一度 |
| 17020 `networkError` | 通信 | 通信を たしかめて、もう一度 |
### 3-3. リンクから もどって きた(`O27`)
- `.onOpenURL` と `.onContinueUserActivity(NSUserActivityTypeBrowsingWeb)` の 両方で 受ける → `Auth.auth().isSignIn(withEmailLink:)`。
- 保存した メールが ある → `Auth.auth().signIn(withEmail:link:)`。
  - その 間は `はいって います`(ライムの 輪が 回る ・ `#`)・ `projector`。
  - 成功 → `success` → 保存した メールを 消す。
- 保存した メールが ない(**ちがう 端末で ひらいた** / アプリを 入れなおした)→ `O29`:メールを もう一度 入れて もらう。
- `expiredActionCode` / `invalidActionCode`(古い ・ もう 使った)→ `O30` `あたらしい リンクを おくる`。
- メールが ちがう(`invalidEmail` など)→ `O29` に もどり、下に 1行。

## 4. 入った あと:はじめて か、前から いる か
- 入れたら **プロフィールが あるか** を 見る(0 で しらべた 場所)。
  - ない → `Name`(今の はじめての 設定へ)。
  - ある → **`O28` おかえり、<名前>。**(`heart` ・ 1.7秒)→ Home。はじめての 設定は 出さない。
- **同じ 人か の きめ方を 1つに**:Firebase の `uid` を キーに する。Apple で 入って いた 人の 今の キーが ちがう 時は、どう つなぐか **報告して から** 決める(勝手に 作りなおさない)。

## 4-2. きまった こと(0 の 報告を うけて):**案1 = Apple も Firebase に のせる**
> 理由:案2 だと Apple の 人だけ Firebase の 人に ならず、Google / メールと **ずっと 別人の まま**(`link(with:)` も できない)。アカウント削除の Apple トークン失効も Firebase で できる ように なる。テスト中の 今が いちばん 安く 切りかえられる。
1. **Apple**:`ASAuthorizationAppleIDRequest` に nonce(SHA256)→ `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)` → `Auth.auth().signIn(with:)`。
2. **今の 人を 引きつぐ**:入れたら `credential.user`(= appleUserID)で SwiftData の `UserProfile` を さがす → あれば その プロフィールに `firebaseUID = uid` を 書く(**appleUserID は 消さない**)→ `O28` おかえり。なければ 新しい 人 → Name。
3. **すでに Apple で 入って いる 人(appleUserID だけ ・ firebaseUID なし)**:**ログアウト させない**。次に 起動した 時に 1回 だけ、下から 小さな シート「Apple で つなぎなおす」(Apple の ボタン 1つ ・ `あとで` も 押せる)。おわれば 2 と 同じ。
4. 「入って いる」の 判定(`LaterApp.swift:119`)は しばらく **appleUserID か firebaseUID の どちらか**の まま。全員が つなぎなおしたら firebaseUID だけに する(今は しない)。
5. アカウントを 消す 時:`Auth.auth().revokeToken(withAuthorizationCode:)` で Apple の トークンも 失効。
6. **Google は GoogleSignIn SDK に 切りかえる**(今の `OAuthProvider("google.com")` の ウェブ経由は 使わない)。
7. **報告して ほしい こと**:`UserProfile`(SwiftData)が **端末の 中 だけか、CloudKit で 同期して いるか**。端末 だけ だと、入れなおした 時に 「おかえり」に できない → その 時は どこで 見分けるか を 報告(勝手に 作らない)。
8. メールの 戻りは `.onOpenURL`(`:306`)と `.onContinueUserActivity`(`:376`)の **両方から 同じ `handleIncoming`** を 呼ぶ。今の `emailSignInLinkFailed`(別の 端末)は `O29` に 作りかえる。

## 5. ほかの 方法で 登録 済み(`O31`)
- `accountExistsWithDifferentCredential`(17012)の 時。
- 「メールの 列挙 保護」が オン(新しい プロジェクトの 初め の 設定)だと、**どの 方法か は 分からない** → 字は 「前に 使った 方法で つづけて ください」+ 3つの ボタン。分かる 時 だけ `Apple で はいって いました`。
- 前の 方法で 入れたら、**エラーに 入って いた 新しい 方法(`AuthErrorUserInfoUpdatedCredentialKey`)を `currentUser.link(with:)` で つなぐ** → 次から どちらでも 入れる。

## 6. そのほか
- サインアウト:`Auth.auth().signOut()` + `GIDSignIn.sharedInstance.signOut()`。
- アカウントを 消す:直近に 入りなおしが 必要(`requiresRecentLogin`)→ その 人の 方法で もう一度(Google = えらぶ 画面 ・ メール = リンク ・ Apple = 今 まで どおり + トークン 失効)。
- 起動時:`Auth.auth().currentUser` が いれば はじめての 設定を 出さない(今 まで どおり)。

## 7. 確かめる こと(実機で)
1. Google:入れる / キャンセルで 何も 出ない / 入りなおしで 同じ 人。
2. メール:届く → タップで アプリに もどる → 入れる。**メールの アプリが Gmail でも** もどれる。
3. 別の 端末(または アプリを 消して 入れなおし)で リンク → `O29`。古い リンク → `O30`。
4. Google と メールで 同じ アドレス → `O31` → つないだ あとは どちらでも 入れる。
5. **Apple で 前から いる 人が そのまま 入れる**(いちばん 大事)。
6. 前から いる 人は `おかえり` → Home。はじめての 人は `Name`。
