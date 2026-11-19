/* ===== v92(モック v92 ・ PROMPT v102):利用規約 ・ プライバシーポリシーを つなぐ =====
   ・ 2か所:サインイン画面の 下の 字 / 設定 > サポート(プロフィールの 古い「ヘルプ」行は v80 で なくなって いる)
   ・ ひらく = アプリ内ブラウザ(SFSafariViewController)。「完了」で とじる。アプリ内に 文章を 持たない */
const B9SITE='https://13379tatsukikitagawa-droid.github.io/APP-Later2/';
const B9L={terms:{u:B9SITE+'terms.html',t:'利用規約'},priv:{u:B9SITE+'privacy.html',t:'プライバシーポリシー'}};
const B9={on:0,k:'',log:[]};
function b9Build(){if($('b9sf'))return;const host=$('ob').parentNode;
  host.insertAdjacentHTML('beforeend',`<div class="b9sf" id="b9sf" aria-hidden="true"><i class="b9bk" data-b="x"></i><div class="b9pn" role="dialog" aria-modal="true" aria-label="ページ"><div class="b9tb"><button class="b9dn" data-b="x">完了</button><div class="b9ad"><svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg><span id="b9ho"></span></div><button class="b9ex" data-b="out" aria-label="Safari で ひらく"><svg viewBox="0 0 24 24"><path d="M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 01-1 1H5a1 1 0 01-1-1V7a1 1 0 011-1h5"/></svg></button></div><div class="b9bd"><p class="b9ld">読みこみ中…</p><iframe id="b9if" title="利用規約 ・ プライバシー" referrerpolicy="no-referrer"></iframe></div></div></div>`);
  $('b9sf').querySelectorAll('[data-b="x"]').forEach(b=>b.onclick=()=>b9Close());
  $('b9sf').querySelector('[data-b="out"]').onclick=()=>{hap('tick',null,{norip:1});try{window.open(B9L[B9.k].u,'_blank','noopener')}catch(e){}};
  document.addEventListener('keydown',e=>{if(e.key==='Escape'&&B9.on)b9Close()})}
function b9Open(k){const L=B9L[k];if(!L)return;b9Build();B9.k=k;B9.on=1;B9.log.push(k);
  const f=$('b9if');if(f.dataset.k!==k){f.dataset.k=k;f.src=L.u}
  $('b9ho').textContent=new URL(L.u).host;$('b9if').title=L.t;$('b9sf').setAttribute('aria-label',L.t);
  $('b9sf').classList.add('on');$('b9sf').setAttribute('aria-hidden','false');hap('soft','ふわっ(ページが ひらく)',{norip:1});
  setTimeout(()=>{try{$('b9sf').querySelector('.b9dn').focus({preventScroll:true})}catch(e){}},520)}
function b9Close(){if(!B9.on)return;B9.on=0;$('b9sf').classList.remove('on');$('b9sf').setAttribute('aria-hidden','true');hap('tick',null,{norip:1})}
/* 1) サインイン画面 O04 の 下の 字 */
{const _t=obTpl;obTpl=function(st){const r=_t(st);
  if(st==='in'){r[1]=r[1].replace('<u>利用規約</u>','<u class="b9l" role="link" tabindex="0" data-b9="terms">利用規約</u>').replace('<u>プライバシー</u>','<u class="b9l" role="link" tabindex="0" data-b9="priv">プライバシー</u>')}
  return r}}
{const _b=obBind;obBind=function(){_b();if(OB.st==='in'){document.querySelectorAll('#ob [data-b9]').forEach(u=>{const go=e=>{e.preventDefault();e.stopPropagation();hap('tick',null,{norip:1});b9Open(u.dataset.b9)};u.onclick=go;u.onkeydown=e=>{if(e.key==='Enter'||e.key===' ')go(e)}})}}}
/* 2) 設定 > サポート の 2行 */
{const _s=x8Set;x8Set=function(){const r=_s.apply(this,arguments);
  try{document.querySelectorAll('.x8rw[data-a="terms"],.x8rw[data-a="priv"]').forEach(b=>{b.onclick=ev=>{ev.stopPropagation();hap('tick',null,{norip:1});b9Open(b.dataset.a)}})}catch(e){}
  return r}}
/* デモ */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-b9d]'))return;C.insertAdjacentHTML('beforeend','<button data-b9d="terms">規約を ひらく</button><button data-b9d="priv">プライバシーを ひらく</button>');
  C.querySelectorAll('[data-b9d]').forEach(b=>b.onclick=()=>b9Open(b.dataset.b9d))})();
window.__kit=Object.assign(window.__kit||{},{b9:k=>b9Open(k),b9x:()=>b9Close(),B9:()=>({on:B9.on,k:B9.k,log:B9.log.slice(),src:($('b9if')||{}).src||''})});
