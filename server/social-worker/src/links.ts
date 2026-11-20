// v109:リンクの ページ ・ AASA ・ OGP ・ トークン(純粋な 部分。テスト できる)
export const TEAM_APP_ID = "G79GN2S2U5.com.tatsukikitagawa.laternew2";
export const LINK_TTL_MS = 24 * 3600 * 1000;
export const RATE_LIMIT_PER_MIN = 10;
export const OG_ORIGIN = "https://later-app-f2606.firebaseapp.com";

export function escapeHtml(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";   // 紛らわしい 文字(0 O 1 l I)を 除く
/** 暗号用の 乱数から 12文字(57^12 ≒ 2^70)。かたよりが 出ない よう 範囲外は 捨てる */
export function newToken(len = 12, rnd: (n: number) => Uint8Array = (n) => crypto.getRandomValues(new Uint8Array(n))): string {
  const limit = 256 - (256 % ALPHABET.length);
  let out = "";
  while (out.length < len) {
    for (const b of rnd(len * 2)) { if (b < limit && out.length < len) out += ALPHABET[b % ALPHABET.length]; }
  }
  return out;
}
export function validToken(t: string): boolean { return /^[A-Za-z0-9_.\-]{3,40}$/.test(t); }

export function isLinkLive(expiresAt: number, now: number): boolean { return expiresAt > now; }
export function allowedHit(n: number, limit = RATE_LIMIT_PER_MIN): boolean { return n <= limit; }

export function aasa(): string {
  return JSON.stringify({
    applinks: { details: [{ appIDs: [TEAM_APP_ID], components: [
      { "/": "/u/*" }, { "/": "/t/*" }, { "/": "/g/*" },
    ] }] },
  });
}

export interface Card { kind: "friend" | "trip"; title: string; desc: string; head: string; sub: string; valid: boolean }

export function friendCard(name: string | null, handle: string): Card {
  const who = name && name.trim() ? name.trim() : "";
  return {
    kind: "friend", valid: true,
    title: who ? `${who} から 友だち申請` : "Lattag で 友だちに なろう",
    desc: "1日 3枚 撮って、あした 9:00 に ひらく",
    head: who ? `${who} から<br>友だち申請` : "友だち申請が<br>とどいて います",
    sub: `@${handle}`,
  };
}
export function tripCard(t: { group_name: string; from_name: string; dates: string; members: number } | null): Card {
  if (!t) return { kind: "trip", valid: false, title: "リンクの 期限が 切れました", desc: "もう一度 送って もらって ください", head: "リンクの 期限が<br>切れました", sub: "もう一度 送って もらって ください" };
  const bits = [t.dates, t.members > 0 ? `${t.members}人` : "", "1日 23枚、みんなで 撮る"].filter(Boolean);
  return {
    kind: "trip", valid: true,
    title: t.group_name ? `『${t.group_name}』の Trip に 招待されました` : "Trip に 招待されました",
    desc: bits.join(" ・ "),
    head: t.group_name ? `『${t.group_name}』の<br>Trip に 招待されました` : "Trip に 招待されました",
    sub: t.from_name ? `${t.from_name} から ・ 24時間 有効` : "24時間 有効",
  };
}

/** 名前 ・ Trip 名は すべて エスケープ(head は <br> だけ 許す ため 中身を 個別に 通す) */
export function renderPage(c: Card, o: { host: string; path: string; code: string; storeURL: string }): string {
  const e = escapeHtml;
  const headHtml = c.head.split("<br>").map(e).join("<br>");
  const url = `https://${o.host}${o.path}`;
  const img = `https://${o.host}/og/${c.kind === "friend" ? "friend" : "trip"}.png`;
  const store = o.storeURL
    ? `<a class="btn s" id="store" href="${e(o.storeURL)}">アプリを 入れる</a>`
    : `<button class="btn s" id="store">アプリを 入れる</button><div class="note" id="note"></div>`;
  return `<!doctype html><html lang="ja"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>${e(c.title)} ・ Lattag</title>
<meta name="description" content="${e(c.desc)}">
<meta property="og:type" content="website"><meta property="og:site_name" content="Lattag">
<meta property="og:title" content="${e(c.title)}"><meta property="og:description" content="${e(c.desc)}">
<meta property="og:url" content="${e(url)}">
<meta property="og:image" content="${e(img)}"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image"><meta name="robots" content="noindex"><meta name="referrer" content="no-referrer">
<meta name="theme-color" content="#000000">
<style>
:root{--lime:#C8F25A;--bg:#000;--card:#141416;--ink:#fff;--sub:#8C8C93}
*{box-sizing:border-box}html,body{margin:0;background:var(--bg);color:var(--ink);font-family:-apple-system,"Hiragino Sans","Noto Sans JP",sans-serif}
main{max-width:440px;margin:0 auto;padding:calc(28px + env(safe-area-inset-top)) 20px calc(28px + env(safe-area-inset-bottom));display:flex;flex-direction:column;gap:18px;min-height:100vh}
.lg{display:flex;align-items:center;gap:10px;font:900 26px/1 Inter,-apple-system,sans-serif;letter-spacing:-.05em}
.lg i{width:38px;height:38px;border-radius:9px;background:var(--lime);color:#111;display:grid;place-items:center;font-style:normal;font-size:22px}
.k{font:700 11px ui-monospace,Menlo,monospace;letter-spacing:.2em;color:var(--lime)}
h1{margin:0;font-size:30px;line-height:1.3;font-weight:900;text-wrap:balance}
.who{padding:14px;border-radius:22px;background:var(--card);color:var(--sub);font:700 13px ui-monospace,Menlo,monospace}
p{margin:0;color:var(--sub);font-size:14px;line-height:1.6}
.btn{display:flex;align-items:center;justify-content:center;height:56px;border-radius:28px;font-weight:800;font-size:16px;text-decoration:none;border:0;width:100%;cursor:pointer}
.p{background:var(--lime);color:#111}.s{background:#1C1C1F;color:#fff}
.tip{display:none;padding:12px 14px;border-radius:16px;background:#2A2A10;color:#F4F1EA;font-size:13px;line-height:1.5}
.line .tip{display:block}
.note,.ok{color:var(--lime);font-size:13px;min-height:18px;text-align:center}
footer{margin-top:auto;color:#5D5D63;font-size:11px;text-align:center}
</style></head><body><main>
<div class="lg"><i>#</i>Lattag</div>
<div class="tip">LINE の 中で ひらいて います。右上(または 下)の メニューから「ブラウザで 開く」を えらぶと、アプリが ひらきます。</div>
<span class="k">${c.kind === "friend" ? "FRIEND" : "TRIP PASS"}</span>
<h1>${headHtml}</h1>
<div class="who">${e(c.sub)}</div>
<p>${c.kind === "friend" ? "アプリで ひらくと、ボタン 1つで 友だち申請 できます。" : "アプリで ひらくと、Trip を たしかめて 参加 できます。アプリの「KEY で 入る」でも 入れます。"}</p>
${c.valid ? `<button class="btn p" id="open">アプリで ひらく</button>` : ""}
${store}
<button class="btn s" id="copy">リンクを コピー</button><div class="ok" id="ok" role="status"></div>
<p>Lattag は、1日 3枚 撮って、あした 9:00 に ひらく 写真アプリです。</p>
<footer>Lattag</footer>
</main><script>
(function(){
  var clean=${JSON.stringify(url)},code=${JSON.stringify(o.code)},kind=${JSON.stringify(c.kind === "friend" ? "u" : "t")};
  if(/\\bLine\\//i.test(navigator.userAgent||''))document.body.classList.add('line');
  function copy(cb){var ok=document.getElementById('ok');
    if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(clean).then(function(){cb&&cb(true)},function(){ok.textContent=clean;cb&&cb(false)})}else{ok.textContent=clean;cb&&cb(false)}}
  var op=document.getElementById('open');if(op)op.onclick=function(){location.href='later://'+kind+'/'+encodeURIComponent(code)};
  document.getElementById('copy').onclick=function(){copy(function(){document.getElementById('ok').textContent='コピー しました'})};
  var st=document.getElementById('store');
  st.addEventListener('click',function(){copy(function(){document.getElementById('ok').textContent='リンクを コピー しました。アプリを 入れたら「招待リンクを 貼りつける」を 押して ください'});
    var n=document.getElementById('note');if(n&&!st.getAttribute('href'))n.textContent='いまは テスト中です。招待した 人に TestFlight の 招待を もらって ください'});
})();
</script></body></html>`;
}
