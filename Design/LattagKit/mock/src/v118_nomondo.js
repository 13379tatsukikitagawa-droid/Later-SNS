/* ===== v119 モック:Mondo を モックから のこさず 消す(v110 の 決定 ・ やり のこし)  印 nm9 =====
   のこって いた 所:Home の 横スライドの 3枚目(Mondo)・ きのうの 画面(#yst)の 下の タブ Friends | Mondo ・ デモボタン ・ かくれた 字。
   正解(CLAUDE.md):横スライド = Camera ・ Friends ・ Trip ・ Yesterday ・ きのうの 画面の タブ = Friends | Trip(`TripHubView`)。 */

/* 1 横スライドの 3枚目 = Yesterday(Mondo の ページは 作らない) */
try{HPK[3]='yday';HPL.mondo='Yesterday'}catch(e){}
{const _hr=hpRender;hpRender=function(only){
  if(!only||only===1||only===2){try{_hr(only?only:1)}catch(e){console.warn(e)};if(!only)try{_hr(2)}catch(e){console.warn(e)}}
  if(!only||only===3||only===4){const c3=$('hpc3');if(c3){c3.id='hpc4';try{_hr(4)}catch(e){console.warn(e)}c3.id='hpc3'}}}}
function nm9Nav(){const b=document.querySelector('#hpi button[data-i="3"]');if(!b)return;b.setAttribute('aria-label','Yesterday');const s=b.querySelector('span');if(s)s.textContent='Yesterday';try{b.querySelector('i').innerHTML=OI.yday}catch(e){}}
try{nm9Nav();hpRender(3)}catch(e){console.warn(e)}

/* 2 きのうの 画面 = Friends | Trip の 画面(g9)。古い #yst(Friends | Mondo)は ひらかない */
{const nm9OpenY=function(){try{g9Open('friends')}catch(e){console.warn(e)}};
  openY=nm9OpenY;try{window.__api.openY=nm9OpenY}catch(e){}
  try{const Y=$('yst');if(Y)Y.classList.add('nm9off')}catch(e){}}

/* 3 のこった Mondo の 字 と ボタン を 消す */
function nm9Sweep(){
  document.querySelectorAll('#ctl button').forEach(b=>{if(/mondo/i.test(b.textContent))b.remove()});
  document.querySelectorAll('#phone button,#phone span,#phone b,#phone div.sk').forEach(e=>{if(e.children.length<=2&&/^\s*(mondo|MONDO)\s*$/i.test(e.textContent)){const t=e.closest('button')||e;t.classList.add('nm9off')}})}
try{nm9Sweep()}catch(e){}
{const _rh=renderHome;renderHome=function(){const r=_rh.apply(this,arguments);try{nm9Sweep();nm9Nav()}catch(e){}return r}}
window.__kit=Object.assign(window.__kit||{},{nm9:()=>{const out=[];const w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;
  while(n=w.nextNode()){if(/mondo|the world, ?yesterday/i.test(n.nodeValue)&&n.parentElement.tagName!=='SCRIPT'){const e=n.parentElement;if(e.offsetParent!==null&&!e.closest('.nm9off'))out.push(n.nodeValue.trim().slice(0,30)+' @ '+(e.id||e.className))}}return out}});

/* 4 はじめての 説明(v99)の Mondo:3枚目 = Mondo の 対応を 消す ・ Mondo の 説明は ひらかない */
try{delete Z9P[3]}catch(e){}
{const _zo=z9Open;z9Open=function(k){if(k==='mondo')return;return _zo.apply(this,arguments)}}
{const _zq=z9QBtns;z9QBtns=function(){const r=_zq.apply(this,arguments);try{const q=$('hpc3')&&$('hpc3').querySelector('.z9q');if(q)q.remove()}catch(e){}return r}}
try{const q=$('hpc3')&&$('hpc3').querySelector('.z9q');if(q)q.remove()}catch(e){}
/* 5 3枚目の 番号(04 → 03) */
{const _h=hpHead;hpHead=function(i,k,sub){return _h(i===4?3:i,k,sub)}}
try{hpRender(3)}catch(e){}
