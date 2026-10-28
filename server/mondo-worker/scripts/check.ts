// サーバ間キーの確認(手元の Mac で実行する)。鍵の情報は環境変数で渡す(コマンド引数でもよい)。
//   CLOUDKIT_KEY_ID=<Key ID> CLOUDKIT_KEY_PATH=~/mondo-keys/eckey-pkcs8.pem \
//     node --experimental-strip-types scripts/check.ts
//   CLOUDKIT_ENVIRONMENT=production を足すと本番で確認する(省略時は development)
//
// 1. このキーが、どのユーザーとして動いているか(MondoServer ロールを付ける相手)
// 2. MondoDay を作れるか(テスト用のレコードを作って、すぐ消す)
// 3. Report を読めるか
// 4. MondoPhoto を消せるか(本人以外が作ったテスト用レコードがあれば。なければ省略)
import { readFileSync } from "node:fs";
import { CloudKit } from "../src/cloudkit.ts";

const [argKeyID, argKeyPath, argEnvironment] = process.argv.slice(2);
const keyID = process.env.CLOUDKIT_KEY_ID ?? argKeyID;
const keyPath = process.env.CLOUDKIT_KEY_PATH ?? argKeyPath;
const environment = process.env.CLOUDKIT_ENVIRONMENT ?? argEnvironment ?? "development";
if (!keyID || !keyPath) {
  console.log("使い方: CLOUDKIT_KEY_ID=<Key ID> CLOUDKIT_KEY_PATH=<eckey-pkcs8.pem のパス> node --experimental-strip-types scripts/check.ts");
  process.exit(1);
}
const pem = readFileSync(keyPath.replace(/^~/, process.env.HOME ?? "~"), "utf8");
if (pem.includes("BEGIN EC PRIVATE KEY")) {
  console.log("この鍵は PKCS#8 ではありません。eckey.pem ではなく eckey-pkcs8.pem を指定してください。");
  console.log("(ない場合: openssl pkcs8 -topk8 -nocrypt -in ~/mondo-keys/eckey.pem -out ~/mondo-keys/eckey-pkcs8.pem)");
  process.exit(1);
}
console.log(`コンテナ iCloud.jp.shotoku.later / 環境 ${environment} で確認します`);
const ck = new CloudKit({
  container: "iCloud.jp.shotoku.later",
  environment,
  keyID,
  privateKeyPEM: pem,
});

async function step(label: string, run: () => Promise<string>) {
  try {
    console.log(`✔ ${label}: ${await run()}`);
  } catch (error) {
    console.log(`✘ ${label}: ${String(error).slice(0, 300)}`);
  }
}

await step("キーの接続とユーザー", async () => {
  const me = await ck.caller();
  return me.userRecordName ? `userRecordName = ${me.userRecordName}(この人に MondoServer ロールを付ける)` : JSON.stringify(me);
});

await step("MondoDay を作れる", async () => {
  const name = `mondoday_permission-check-${Date.now()}`;
  await ck.save([{ recordName: name, recordType: "MondoDay", fields: { dayKey: { value: "permission-check" }, lightCount: { value: 0 } } }]);
  const [created] = await ck.lookup([name], ["dayKey"]);
  await ck.delete([name]);
  const by = (created as unknown as { created?: { userRecordName?: string } })?.created?.userRecordName;
  return `作成・削除できた${by ? `(作成者 = ${by})` : ""}`;
});

await step("Report を読める", async () => {
  const reports = await ck.query("Report", [{ fieldName: "targetType", comparator: "EQUALS", value: "mondoPhoto" }], ["targetID"], 5);
  return `${reports.length} 件読めた`;
});

await step("MondoPhoto を消せる", async () => {
  const photos = await ck.query("MondoPhoto", [{ fieldName: "dayKey", comparator: "EQUALS", value: "permission-check" }], ["dayKey"], 1);
  if (photos.length === 0) return "確認用の写真がないので省略(アプリで dayKey=permission-check の写真は作らないため、通常は省略でよい)";
  await ck.delete([photos[0].recordName]);
  return `${photos[0].recordName} を削除できた`;
});
