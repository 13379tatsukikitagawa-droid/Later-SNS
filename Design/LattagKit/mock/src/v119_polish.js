/* ===== v120 モック(PROMPT v134 案):Today ・ Friends の かたまりを 磨く + 上の バーを そろえる =====
   Today(暗室の ひも)3案:__kit.t9('1'|'2'|'3')  ・ Friends 3案:__kit.w9('1'|'2'|'3'|'now') */
const T9={v:'2'},W9={v:'1'};
/* 見本の ID を 1つに そろえる(プロフィール ・ マイカード ・ QR で ばらばら だった) */
try{K9.id='tatsuki'}catch(e){}
{const _q=q9Open;q9Open=function(){const r=_q.apply(this,arguments);try{const Q=$('q9');if(Q){const w=document.createTreeWalker(Q,NodeFilter.SHOW_TEXT);let n;while(n=w.nextNode()){if(n.nodeValue.includes('@yui_0612'))n.nodeValue=n.nodeValue.replace('@yui_0612','@'+K9.id);else if(n.nodeValue.trim()==='ゆい')n.nodeValue=n.nodeValue.replace('ゆい',(typeof OB!=='undefined'&&OB&&OB.name)||'たつき')}}}catch(e){}return r}}

/* ---------- Today:ひもの 3案 ---------- */
{const _s=x9tShoot,_e=x9tEmpty,_c=x9tC;
  x9tShoot=function(sub){if(X9T.v!=='c'||T9.v==='0')return _s(sub);
    if(T9.v==='1')return `<button class="x9s t9sh" data-a="shoot" aria-label="撮る"><span class="t9in">${ICO.plus}</span><b class="x9sl">撮る</b></button>`;
    if(T9.v==='2')return `<button class="x9s t9sh" data-a="shoot" aria-label="撮る"><span class="t9in"><u>${ICO.plus}</u></span><b class="x9sl">撮る</b></button>`;
    return `<div class="x9s t9nx"><span class="t9in"></span><b class="x9sl">つぎ</b></div>`};
  x9tEmpty=function(n){if(X9T.v!=='c'||T9.v==='0')return _e(n);return `<div class="x9e t9em"><span class="t9in"></span><b class="x9en">${n}</b></div>`};
  x9tC=function(){let h=_c();if(T9.v==='0')return h;h=h.replace('<div class="x9t c">',`<div class="x9t c t9-${T9.v}">`);
    if(T9.v==='3'&&shots<3)h=h.replace(/<\/div>$/,`<button class="t9pill" data-a="shoot">${ICO.plus}<span>撮る</span><small>のこり ${3-shots} ・ 24:00 まで</small></button></div>`);
    return h}}

/* ---------- Friends の かたまり 3案 ---------- */
const W9I={scan:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8V5.5A1.5 1.5 0 015.5 4H8M16 4h2.5A1.5 1.5 0 0120 5.5V8M20 16v2.5a1.5 1.5 0 01-1.5 1.5H16M8 20H5.5A1.5 1.5 0 014 18.5V16M4 12h16"/></svg>',
  mag:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
  share:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V4M7.5 8.5L12 4l4.5 4.5"/><path d="M5 13v5.5A1.5 1.5 0 006.5 20h11a1.5 1.5 0 001.5-1.5V13"/></svg>',
  qr:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/></svg>'};
{const _af=arcFriends;arcFriends=function(){const r=_af.apply(this,arguments);const B=$('afc');if(!B)return r;
  B.classList.remove('w9','w9-1','w9-2','w9-3');if(W9.v==='now')return r;
  const head=B.querySelector('.u9wh'),rq=B.querySelector('.u9wrq'),fr=B.querySelector('.j9fpr');
  const nm=(typeof OB!=='undefined'&&OB&&OB.name)||'たつき';let av=`url(${PH.c})`;try{const u=avUrl();if(u&&u!=='none')av=u}catch(e){}
  const qr=`<button class="w9qr" data-j9="qr" aria-label="QR を 見せる"><i class="tp"></i><span class="qr">${tQR('@'+K9.id,120)}</span>${W9.v==='2'?`<span class="w9nm"><i style="background-image:${av}"></i><b>${nm}</b><small>@${K9.id}</small></span>`:'<small>タップで 大きく</small>'}</button>`;
  const me=`<div class="w9me"><span class="av" style="background-image:${av}"></span><div style="min-width:0"><b>${nm}</b><small>@${K9.id}</small></div></div>`;
  const link=`<button class="w9link" data-j9="link">${W9I.share}<span>リンクを 送る</span></button>`;
  const two=`<div class="w9two"><button class="w9pl" data-j9="scan">${W9I.scan}<span>${W9.v==='1'?'読む':'QR を 読む'}</span></button><button class="w9pl" data-j9="id">${W9I.mag}<span>${W9.v==='1'?'さがす':'ID で さがす'}</span></button></div>`;
  let card='';
  if(W9.v==='1')card=`<div class="w9card">${qr}<div class="w9side">${me}${two}</div>${link}</div>`;
  else if(W9.v==='2')card=`<div class="w9card">${qr}${link}${two}</div>`;
  else card=`<div class="w9card">${me}<div class="w9three"><button class="w9lm" data-j9="link">${W9I.share}<span>リンク</span></button><button data-j9="qr">${W9I.qr}<span>QR</span></button><button data-j9="scan">${W9I.scan}<span>読む</span></button></div><button class="w9find" data-j9="id">${W9I.mag}<span>@ID で さがす</span></button></div>`;
  B.innerHTML='';[head,fr,rq].forEach(x=>{if(x)B.appendChild(x)});B.insertAdjacentHTML('beforeend',card);
  B.classList.add('w9','w9-'+W9.v);try{j9Acts(B)}catch(e){}
  B.querySelectorAll('[data-j9="open"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Friends)');openFriend()});
  if(!J9RM()){const c=B.querySelector('.w9card');if(c&&!B._w9a){B._w9a=1;c.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:460,delay:120,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'})}}
  return r}}

/* ---------- デモ ---------- */
function t9Set(k){T9.v=k;X9T.v='c';X9T.force=true;try{arcToday()}catch(e){console.warn(e)}}
function w9Set(k){W9.v=k;const B=$('afc');if(B)B._w9a=0;try{arcFriends()}catch(e){console.warn(e)}}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-t9]'))return;
  C.insertAdjacentHTML('beforeend',[['t9','0','★ v120 Today:いま'],['t9','1','★ v120 Today:1 同じ 大きさの 3枚'],['t9','2','★ v120 Today:2 次の 1枚 だけ(決定)'],['t9','3','★ v120 Today:3 ひも + 撮る ボタン'],
    ['w9','1','★ v120 Friends:1 マイカード 1枚(決定)'],['w9','2','★ v120 Friends:2 QR が 主役'],['w9','3','★ v120 Friends:3 3つの 道'],['w9','now','★ v120 Friends:いま']].map(([g,k,t])=>`<button data-${g}="${k}">${t}</button>`).join(''));
  C.querySelectorAll('[data-t9]').forEach(b=>b.onclick=()=>t9Set(b.dataset.t9));C.querySelectorAll('[data-w9]').forEach(b=>b.onclick=()=>w9Set(b.dataset.w9))})();
window.__kit=Object.assign(window.__kit||{},{t9:k=>t9Set(k),w9:k=>w9Set(k)});
try{X9T.force=true;arcToday();arcFriends()}catch(e){console.warn(e)}
/* 上の バー:プロフィールの 写真 と 通知の 数も Home と 同じ ものを 出す */
function hd9Sync(){const G=$('g9');if(!G)return;const hav=document.querySelector('#hhd .av'),me=G.querySelector('.g9hd .g9me');if(hav&&me)me.style.backgroundImage=getComputedStyle(hav).backgroundImage;
  const hn=$('f9bn'),bd=G.querySelector('.g9hd .g9bd');if(hn&&bd){bd.textContent=hn.textContent;bd.style.display=hn.textContent&&hn.textContent!=='0'?'':'none'}}
{const _g=g9Open;g9Open=function(){const r=_g.apply(this,arguments);try{hd9Sync()}catch(e){}return r}}
