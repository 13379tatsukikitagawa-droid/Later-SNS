# たつきさんが やる 設定(Google ・ メールの サインイン)

> Claude Code では できない 所です。**上から 順に**。終わったら ☑ を つけて、Claude Code に 「設定 おわった」と 伝えて ください。
> `<PROJECT_ID>` は Firebase の プロジェクトID(Console の ⚙ → プロジェクトの 設定 → 「プロジェクト ID」)。

## 1. Firebase Console(https://console.firebase.google.com)
- [ ] **1-1 Google を オン**:Authentication → Sign-in method → 「新しい プロバイダを 追加」→ **Google** → 有効に する → サポート メール を えらぶ → 保存。
- [ ] **1-2 メールの リンクを オン**:同じ 画面の **メール / パスワード** → 「有効に する」を オン → **「メールリンク(パスワードなしで ログイン)」も オン** → 保存。
  - 前に 出た エラー 17006 は、ここが オフ だった ため。
- [ ] **1-2b Apple を オン**:同じ 画面で **Apple** → 有効に する → 保存(iPhone アプリ だけ なら、ほかの 欄は 空で よい)。Apple も Firebase に のせる ため(案1)。
- [ ] **1-3 アプリの 名前**:⚙ → プロジェクトの 設定 → 全般 → 「一般公開 名」を **Lattag** に。サポートの メールも 入れる(Google の 画面と メールに 出る)。
- [ ] **1-4 ドメインの 許可**:Authentication → 設定 → **承認済み ドメイン** に `<PROJECT_ID>.firebaseapp.com` が あるか 見る(ふつうは 最初から ある)。
- [ ] **1-5 チーム ID**:⚙ → プロジェクトの 設定 → 全般 → **iOS アプリ(Lattag)** → **チーム ID** を 入れる(Apple Developer の Membership に ある 10文字)。App Store ID が あれば それも。
  - これが ないと、メールの リンクを 押しても **アプリに もどらない**(Safari が ひらく だけ)。
- [ ] **1-6 Hosting**:左の メニュー → Hosting。まだ なら 「はじめる」で 有効に する(何も 公開 しなくて よい)。メールの リンクは `<PROJECT_ID>.firebaseapp.com` で 作られる。
- [ ] **1-7 メールの 言語**:Authentication → テンプレート → 右上の 言語を **日本語** に。
- [ ] **1-8 新しい `GoogleService-Info.plist` を ダウンロード**:⚙ → プロジェクトの 設定 → iOS アプリ → `GoogleService-Info.plist`。
  - **Google を オンに した あとの もの**(中に `CLIENT_ID` と `REVERSED_CLIENT_ID` が 入る)。
  - Xcode の 今の ファイルと 入れかえる(名前は 同じ まま)。

## 2. 確かめ(ブラウザで)
- [ ] `https://<PROJECT_ID>.firebaseapp.com/.well-known/apple-app-site-association` を ひらく → 中に **`チームID.バンドルID`** が 出れば OK。
  - 出ない → 1-5 と 1-6 を もう一度。反映まで 少し 時間が かかる ことが ある。

## 3. Xcode(Claude Code が やるが、画面で 確かめる)
- [ ] Signing & Capabilities → **Associated Domains** に `applinks:<PROJECT_ID>.firebaseapp.com`。
  - 開発中に すぐ ためす 時は `applinks:<PROJECT_ID>.firebaseapp.com?mode=developer` も(iPhone の 設定 → デベロッパ → 「Associated Domains Development」を オン)。
- [ ] Info → URL Types に `REVERSED_CLIENT_ID`(`com.googleusercontent.apps.…`)。

## 4. ためす 時の ちゅうい
- **シミュレータでは メールの リンクが うまく もどらない ことが ある → 実機で**。
- 1つの アドレスに 何回も 送ると 送れなく なる(少し 待つ)。
- **迷惑メール** の フォルダも 見る(差出人は `noreply@<PROJECT_ID>.firebaseapp.com`)。

## 5. 規約ページの 登録(v102 ・ あとで で よい)
> ページ:利用規約 `https://13379tatsukikitagawa-droid.github.io/APP-Later2/terms.html` ・ プライバシー `https://13379tatsukikitagawa-droid.github.io/APP-Later2/privacy.html`
- [ ] **5-1 App Store Connect**:アプリ > アプリ情報 > **プライバシーポリシー URL** に `privacy.html` を 入れる(App Store に 出す 時は 必須)。TestFlight の「テスト情報」に 同じ 欄が あれば 同じ URL。
- [ ] **5-2 プライバシーの ページを 直す**:いまの `privacy.html` は ログインを「Apple の 識別子 または メール」と 書いて いる。**Google で 入る 場合 ・ メールの リンクで 入る 場合**を 足す(GitHub の `privacy.html`)。
- [ ] **5-3(あとで)Google の 同意画面**:Google の 確認画面に プライバシー / 利用規約の リンクを 出したい 時は、Google Cloud Console > Google Auth Platform > ブランディング に 2つの URL を 入れる。**もし「ドメインの 確認」を 求められたら 手を 止めて 相談**(`github.io` は 自分で 確認できない ため、独自ドメインが 要る かも。**未確認**)。

