# later-mondo(Mondo のサーバ)

Cloudflare Workers の**無料プラン**で動く、Mondo(世界の「昨日」)の審査・集計・削除です。30分ごとに次を行います。

1. 新しい公開写真(`MondoPhoto`)を、Workers AI(`@cf/meta/llama-3.2-11b-vision-instruct`)で画像審査する。**はっきり SAFE と答えたものだけ承認**。あいまい・失敗は保留
2. 同じ写真への報告(`Report`、`targetType = mondoPhoto`)が `REPORT_THRESHOLD` 人に達したら、自動で保留
3. 昨日・一昨日の `MondoDay`(承認した写真の一覧・光の数・国の数・ことばの上位6つ)を作りなおす
4. 窓が閉まってから48時間を過ぎた `MondoPhoto` と、古い `MondoDay` を削除する

アプリは **`MondoDay` に載っている写真だけ**を出します。サーバを置くまで、アプリの Mondo は「準備中」です(審査していない写真は出しません)。

## 無料枠の目安

| もの | 無料枠 | Mondo での使い方 |
|---|---|---|
| Workers | 1日 10万リクエスト | 30分ごとに1回(1日48回) |
| Workers AI | 1日 10,000 neurons | 写真1枚につき1回(サムネイル 320px) |
| KV | 1日 10万回の読み・1,000回の書き | 審査結果・辞書 |
| CloudKit Public DB | 利用者数に応じて増える | 写真は 1080px と 320px の2枚 |

> 1日の公開が数百枚を超えたら、Workers AI の無料枠を超える可能性があります。そのときは有料(Workers Paid は月 $5〜)か、審査方法の見直しを検討してください。

## セットアップ(あなたがやること)

### 1. CloudKit Console(https://icloud.developer.apple.com)

> 画面の名前は 2026年10月時点の想定です。※ の付いた名前は、実際の表示と少し違うことがあります(近い名前のものを選んでください)。

#### 1-1. コンテナと環境をえらぶ

1. https://icloud.developer.apple.com を開き、Apple ID(開発者アカウント)でサインイン
2. **CloudKit Database** をクリック
3. 画面いちばん上の**コンテナの選択**で `iCloud.jp.shotoku.later` をえらぶ(`iCloud.com.tatsukikitagawa.Later` ではない)
4. そのとなりの**環境の選択**で **Development** をえらぶ

#### 1-2. スキーマを読みこむ(型・インデックス・セキュリティロールがまとめて入る)

1. 左のメニューの **Schema** の下にある **Record Types** を開く
2. 右上の **⋯** または **Import Schema**※ をクリック
3. `CloudKitSchema/Later.ckdb`(リポジトリの中)をえらぶ → 内容を確認して **Import**
   - これで `MondoPhoto` `MondoDay` `Report` `Block` の型、`dayKey` `recordName` `targetType` の QUERYABLE、`MondoServer` ロールと各型の権限が入ります
   - `CREATE ROLE` の行でエラーになったら:ファイルから `CREATE ROLE MondoServer;` と `"MondoServer"` への `GRANT` の行を消して読みこみ、1-3 の手順でロールを手で作る

#### 1-3. セキュリティロールを確かめる(1-2 で入っていれば、見るだけ)

1. 左のメニュー **Schema** → **Security Roles** を開く
2. 一覧に `World`(だれでも)・`Authenticated`(iCloud にサインインした人)・`Creator`(作った本人)と、`MondoServer` があることを確かめる
   - ない場合:一覧の上の **+**(New Role※)をクリック → 名前に `MondoServer` → **Save**
3. 一覧で各ロールをクリックすると、右に「型ごとの **Create / Read / Write** のチェック」が出る。次のとおりになっているか確かめ、ちがえばチェックを直して **Save**

| 型 | World | Authenticated | Creator | MondoServer |
|---|---|---|---|---|
| `MondoPhoto` | Read | Create | Write | **Write**(48時間で消すため) |
| `MondoDay` | Read | **なし**(偽の一覧を作れないように) | なし | **Create・Write** |
| `Report` | **なし**(通報した人を守る) | Create | Read・Write | **Read**(報告の数を数えるため) |

#### 1-4. サーバ間キーを作る

1. 左のメニューの **Tokens & Keys**※(または **API Access**)を開く
2. **Server-to-Server Keys** の **+** をクリック
3. **Name**:`later-mondo`(なんでもよい)
4. **Public Key**:`~/mondo-keys/eckey.pem` から作った公開鍵を貼る(`-----BEGIN PUBLIC KEY-----` から `-----END PUBLIC KEY-----` まで全部)
   ```sh
   openssl ec -in ~/mondo-keys/eckey.pem -pubout | pbcopy   # クリップボードに入る
   ```
   (まだ鍵がなければ:`openssl ecparam -name prime256v1 -genkey -noout -out eckey.pem` → `openssl pkcs8 -topk8 -nocrypt -in eckey.pem -out eckey-pkcs8.pem`)
5. **Save** → 表示される **Key ID** を控える。`eckey*.pem` は**リポジトリに入れない**

#### 1-5. サーバ間キーと MondoServer ロールを結びつける

CloudKit のロールは「キー」ではなく「ユーザー」に付けます。サーバ間キーで動くとき、CloudKit の中では**キーを作った開発者のアカウントに対応するユーザー**として動く想定ですが、確実ではないため、**実際にどのユーザーとして動いているかを、確認用のスクリプトで調べてから**付けます。

1. 手元の Mac で、確認用のスクリプトを動かす
   ```sh
   cd server/mondo-worker
   npm install
   node --experimental-strip-types scripts/check.ts <Key ID> ~/mondo-keys/eckey-pkcs8.pem
   ```
   いちばん上に `userRecordName = _xxxxxxxx…` と出たら、それが**サーバのユーザー**です(控える)
   - このとき「MondoDay を作れる」は ✘(権限がない)になるのが正しい状態です(まだロールを付けていないため)
2. CloudKit Console の左のメニュー **Data** → **Records** を開く
3. **Database**:**Public Database**、**Record Type**:**Users** をえらび、**Query Records** をクリック
   - 1件も出ないときは、インデックスの画面(**Schema** → **Indexes**)で `Users` の `recordName` を **QUERYABLE** にしてから、もう一度
4. 一覧から、手順1で控えた `userRecordName` のレコードをクリックして開く
5. **Roles**※(または `roles` の欄)で **MondoServer** を追加 → **Save**
   - Records 画面にロールの欄がないときは、**Schema** → **Security Roles** → `MondoServer` を開き、**Users / Assign**※ の欄から、同じ `userRecordName` を追加
6. もう一度スクリプトを動かし、**3つとも ✔** になることを確かめる
   ```sh
   node --experimental-strip-types scripts/check.ts <Key ID> ~/mondo-keys/eckey-pkcs8.pem
   ```
   - `✔ MondoDay を作れる` `✔ Report を読める` になれば完了(MondoPhoto は確認用の写真がないので「省略」でよい)

**どうしても結びつけられないとき**(ロールの欄が見つからない・付けても ✘ のまま)は、`MondoDay` の `Authenticated` に一時的に **Create** を戻すと、サーバは動きます。ただしその間は、悪意のある人が偽の一覧(`MondoDay`)を作れてしまうため、App Store に出す前に必ず解決してください(サーバの署名つきの一覧にするなど、別の方法を相談してください)。

#### 1-6. 本番(Production)へ

Development で 1-2〜1-5 がすべて ✔ になったら、Console の左下の **Deploy Schema Changes…**※ をクリックして Production に反映。Production でも 1-5 のロールの割り当て(Users のレコード)は**別に**必要です(`scripts/check.ts … production` で確認)。

### 2. Cloudflare(https://dash.cloudflare.com ・無料アカウント)

```sh
cd server/mondo-worker
npm install
npx wrangler login
npx wrangler kv namespace create MONDO        # 出てきた id を wrangler.toml に書く
npx wrangler kv key put --binding=MONDO --remote aliases "$(cat aliases.json)"
npx wrangler kv key put --binding=MONDO --remote blockedWords '[]'
npx wrangler secret put CLOUDKIT_KEY_ID        # Key ID を貼る
npx wrangler secret put CLOUDKIT_PRIVATE_KEY < eckey-pkcs8.pem
npx wrangler deploy
```

- ことばの辞書(別名 → 代表のことば)は KV の `aliases`。コードを変えずに増やせます
- 出してはいけない言葉は KV の `blockedWords`(名前・ことばに含まれていたら却下)

### 3. 動かして確かめる

```sh
npx wrangler dev --test-scheduled
curl "http://localhost:8787/__scheduled?cron=*/30+*+*+*+*"
npx wrangler tail      # 本番のログ
```

App Store に出すときは `CLOUDKIT_ENVIRONMENT = "production"` にして、Production のスキーマ(インデックス・ロール)も同じように設定してください。

### 4. Production(TestFlight・App Store)でも動かす

Xcode から入れたアプリは **Development**、TestFlight・App Store のアプリは **Production** に投稿します。
サーバは両方を見ます(`wrangler.toml` の `CLOUDKIT_ENVIRONMENTS = "development,production"`)。
ただし CloudKit のサーバ間キーは**環境ごと**なので、Production 用のキーを別に作ります(ないあいだ、Production は
ログに `skipped(reason=noServerKey)` と出して飛ばします)。

1. CloudKit Console で、環境を **Production** にする
2. **Schema** に `MondoPhoto` `MondoDay` `Report` があるか確かめる。なければ、Development の画面で
   **Deploy Schema Changes…** を押して Production に反映する(インデックス・セキュリティロールも一緒に入る)
3. Production の **Tokens & Keys** → **Server-to-Server Keys** の **+** で、1-4 と同じ手順でキーを作る
   (公開鍵は 1-4 で作ったものを、そのまま使ってよい)
4. ターミナルで:
   ```sh
   npx wrangler secret put CLOUDKIT_PROD_KEY_ID          # 3 で出た Key ID
   npx wrangler secret put CLOUDKIT_PROD_PRIVATE_KEY     # 秘密鍵(PEM)の中身をそのまま
   ```
5. 次の回(30分ごと)のログ(`npx wrangler tail`)に `[Mondo][scan] env=production` が出れば、動いています

## 運営の確認

- 保留・却下の写真は KV の `status:<レコード名>`(`approved` / `held` / `rejected`)。保留を承認するときは `npx wrangler kv key put --binding=MONDO --remote "status:<レコード名>" approved`
- 報告は CloudKit ダッシュボードの `Report`(Public DB)で見られます

## テスト

```sh
npm test    # 集計・並び・審査の答え・署名の形式
```
