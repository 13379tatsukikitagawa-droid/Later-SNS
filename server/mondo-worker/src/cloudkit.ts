// CloudKit Web Services(サーバ間キー)で、Public DB を読み書きする最小のクライアント。
// 署名:ECDSA P-256 / SHA-256 で `日時:本文のSHA256(base64):サブパス` に署名し、DER の base64 を送る。
// https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/CloudKitWebServicesReference/SettingUpWebServices.html

export interface CloudKitConfig {
  container: string;
  environment: string; // "development" | "production"
  keyID: string;
  privateKeyPEM: string; // PKCS#8("-----BEGIN PRIVATE KEY-----")
}

export interface CKRecord {
  recordName: string;
  recordType: string;
  recordChangeTag?: string;
  created?: { timestamp: number };
  fields: Record<string, { value: unknown; type?: string }>;
}

const BASE = "https://api.apple-cloudkit.com";

function b64(bytes: ArrayBuffer | Uint8Array): string {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let s = "";
  for (const b of u8) s += String.fromCharCode(b);
  return btoa(s);
}

function pemToDer(pem: string): ArrayBuffer {
  const body = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const raw = atob(body);
  const out = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i);
  return out.buffer;
}

/// WebCrypto の ECDSA 署名(r||s の 64バイト)を、CloudKit が求める DER 形式にする
export function rawSignatureToDER(raw: Uint8Array): Uint8Array {
  const trim = (x: Uint8Array) => {
    let i = 0;
    while (i < x.length - 1 && x[i] === 0) i++;
    let v = x.slice(i);
    if (v[0] & 0x80) v = Uint8Array.from([0, ...v]);
    return v;
  };
  const r = trim(raw.slice(0, 32));
  const s = trim(raw.slice(32));
  const seq = [0x02, r.length, ...r, 0x02, s.length, ...s];
  return Uint8Array.from([0x30, seq.length, ...seq]);
}

export class CloudKit {
  private keyPromise: Promise<CryptoKey>;
  private config: CloudKitConfig;

  constructor(config: CloudKitConfig) {
    this.config = config;
    this.keyPromise = crypto.subtle.importKey(
      "pkcs8",
      pemToDer(config.privateKeyPEM),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  }

  private subpath(op: string): string {
    return `/database/1/${this.config.container}/${this.config.environment}/public/${op}`;
  }

  async request<T>(op: string, body: unknown, method: "POST" | "GET" = "POST"): Promise<T> {
    const subpath = this.subpath(op);
    const text = method === "GET" ? "" : JSON.stringify(body);
    const date = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
    const bodyHash = b64(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
    const message = new TextEncoder().encode(`${date}:${bodyHash}:${subpath}`);
    const raw = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, await this.keyPromise, message));
    const response = await fetch(BASE + subpath, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-Apple-CloudKit-Request-KeyID": this.config.keyID,
        "X-Apple-CloudKit-Request-ISO8601Date": date,
        "X-Apple-CloudKit-Request-SignatureV1": b64(rawSignatureToDER(raw)),
      },
      body: method === "GET" ? undefined : text,
    });
    if (!response.ok) {
      throw new Error(`CloudKit ${op} ${response.status}: ${await response.text()}`);
    }
    return (await response.json()) as T;
  }

  /// 条件に合うレコードを、続きの印(continuationMarker)をたどって全部読む(上限つき)
  async query(recordType: string, filters: Array<{ fieldName: string; comparator: string; value: unknown }>, desiredKeys?: string[], limit = 2000): Promise<CKRecord[]> {
    const out: CKRecord[] = [];
    let marker: string | undefined;
    do {
      const res = await this.request<{ records: CKRecord[]; continuationMarker?: string }>("records/query", {
        query: {
          recordType,
          filterBy: filters.map((f) => ({ fieldName: f.fieldName, comparator: f.comparator, fieldValue: { value: f.value } })),
        },
        desiredKeys,
        resultsLimit: 200,
        continuationMarker: marker,
      });
      out.push(...res.records.filter((r) => !(r as unknown as { serverErrorCode?: string }).serverErrorCode));
      marker = res.continuationMarker;
    } while (marker && out.length < limit);
    return out;
  }

  async lookup(recordNames: string[], desiredKeys?: string[]): Promise<CKRecord[]> {
    if (recordNames.length === 0) return [];
    const res = await this.request<{ records: CKRecord[] }>("records/lookup", {
      records: recordNames.map((recordName) => ({ recordName })),
      desiredKeys,
    });
    return res.records.filter((r) => !(r as unknown as { serverErrorCode?: string }).serverErrorCode);
  }

  async save(records: Array<{ recordName: string; recordType: string; fields: CKRecord["fields"] }>): Promise<void> {
    if (records.length === 0) return;
    await this.request("records/modify", {
      operations: records.map((record) => ({ operationType: "forceReplace", record })),
    });
  }

  async delete(recordNames: string[]): Promise<void> {
    for (let i = 0; i < recordNames.length; i += 200) {
      await this.request("records/modify", {
        operations: recordNames.slice(i, i + 200).map((recordName) => ({ operationType: "forceDelete", record: { recordName } })),
      });
    }
  }

  /// このキーが、CloudKit の中でどのユーザーとして動いているか(ロールを付ける相手を調べる)
  async caller(): Promise<{ userRecordName?: string }> {
    return this.request("users/caller", undefined, "GET");
  }

  /// アセットのダウンロード URL(`${f}` をファイル名に置きかえる)
  static assetURL(record: CKRecord, field: string): string | undefined {
    const value = record.fields[field]?.value as { downloadURL?: string } | undefined;
    return value?.downloadURL?.replace("${f}", "file.jpg");
  }
}
