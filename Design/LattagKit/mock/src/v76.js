
/* ================= v76(PROMPT v81)・ アイコン(プロフィール写真)================= */
const AV76={p:'f',z:1,ini:'ゆ'};   /* p = 写真(なし = null → 名前の 1文字 + 色)*/
const avUrl=()=>AV76.p?`url(${PH[AV76.p]})`:'none';
function avApply(){
  const H=document.querySelector('#home #hhd .av');if(H){H.classList.toggle('ini',!AV76.p);let k=H.querySelector('.avi');if(!AV76.p){if(!k){H.insertAdjacentHTML('beforeend','<b class="avi"></b>');k=H.querySelector('.avi')}k.textContent=AV76.ini}else if(k)k.remove();H.style.backgroundImage=AV76.p?avUrl():''}
  const T=document.querySelector('#yst .y72 .ztd.zava>i');if(T){T.className=AV76.p?'':'ini';T.style.backgroundImage=avUrl();T.textContent=AV76.p?'':AV76.ini}
  const P=document.querySelector('#prf .pic');if(P){if(P.dataset.bg0==null)P.dataset.bg0=P.style.backgroundImage||'';P.classList.toggle('ph76',!!AV76.p);P.style.backgroundImage=AV76.p?avUrl():P.dataset.bg0;if(!P.querySelector('.av76b'))P.insertAdjacentHTML('beforeend','<span class="av76b" role="button" tabindex="0" aria-label="写真を 変える"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>写真</span>');}
  const L=document.querySelector('#psetl');if(L&&!L.querySelector('.av76r')){L.insertAdjacentHTML('afterbegin','<button class="av76r"><i></i><span>アイコンの 写真</span></button>');L.querySelector('.av76r').onclick=()=>avOpen()}
  const R=document.querySelector('#psetl .av76r i');R&&(R.style.backgroundImage=avUrl());
  const O=$('obph');if(O){try{OB.img=!!AV76.p}catch(e){}O.classList.toggle('im',!!AV76.p);O.style.backgroundImage=AV76.p?avUrl():''}
  const OB2=document.querySelector('.ob76 button');OB2&&(OB2.classList.toggle('on',!!AV76.p),OB2.style.backgroundImage=avUrl())}
function avOpen(){let S=$('av76s');const ph=$('phone');if(!S){ph.insertAdjacentHTML('beforeend','<div class="av76p" id="av76s" aria-hidden="true"><div class="k7sh"></div></div>');S=$('av76s');S.onclick=e=>{if(e.target===S)avClose()}}
  const D={p:AV76.p,z:AV76.z};const lib=[['e','きのう'],['b','きのう'],['d','きのう'],['f',''],['a',''],['c',''],['b',''],['d','']];
  const draw=()=>{S.querySelector('.k7sh').innerHTML=`<div class="k7gb"></div><div class="k7hd"><b>アイコン</b><button data-a="x" aria-label="とじる">×</button></div>
    <div class="k7pv">${D.p?`<i style="background-image:url(${PH[D.p]});transform:scale(${D.z})"></i>`:`<b>${AV76.ini}</b>`}</div>
    <div class="k7zm"><span>小</span><input type="range" min="1" max="2" step=".01" value="${D.z}" aria-label="大きさ"${D.p?'':' disabled'}><span>大</span></div>
    <div class="k7ac"><button data-a="cam"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>写真を 撮る</button><button data-a="lib"><svg viewBox="0 0 24 24"><rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.8"/><path d="M20.5 16l-5-5-8 8.5"/></svg>ライブラリ</button><button class="dl" data-a="del"><svg viewBox="0 0 24 24"><path d="M5 7h14M10 7V5h4v2M7 7l1 12h8l1-12"/></svg>写真を 消す</button></div>
    <div class="k7lb">最近の 写真</div><div class="k7gr">${lib.map(([p,t],i)=>`<button data-p="${p}" data-i="${i}" class="${D.p===p&&i===D.i?'on':''}" style="background-image:url(${PH[p]})" aria-label="写真 ${i+1}">${t?`<em>${t}</em>`:''}</button>`).join('')}</div>
    <button class="k7ok" data-a="ok">これに する</button>`;
    const q=s=>S.querySelector(s);q('[data-a="x"]').onclick=avClose;
    q('input').oninput=e=>{D.z=+e.target.value;const i=q('.k7pv i');i&&(i.style.transform=`scale(${D.z})`);hap('tick',null,{norip:1,gap:60})};
    S.querySelectorAll('.k7gr button').forEach(b=>b.onclick=()=>{D.p=b.dataset.p;D.i=+b.dataset.i;D.z=1;draw();hap('sel','コツッ(えらぶ)');const v=q('.k7pv');!matchMedia('(prefers-reduced-motion:reduce)').matches&&v.animate([{transform:'scale(.92)'},{transform:'scale(1.04)'},{transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.5,.5,1)'})});
    q('[data-a="cam"]').onclick=()=>{hap('shutter','カシャ(撮る ・ モック)');D.p='c';D.i=-1;D.z=1.15;draw()};
    q('[data-a="lib"]').onclick=()=>{hap('pop');q('.k7gr').scrollIntoView({behavior:'smooth',block:'center'})};
    q('[data-a="del"]').onclick=()=>{hap('warn','ブッ(消す)');D.p=null;D.z=1;draw()};
    q('[data-a="ok"]').onclick=()=>{AV76.p=D.p;AV76.z=D.z;avApply();try{renderYAll()}catch(e){}avClose();hap('success','トトン(アイコン)')}};
  draw();S.classList.add('on');S.setAttribute('aria-hidden','false');hap('pop','ぷにっ(アイコン)')}
function avClose(){const S=$('av76s');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}
/* yesterday の 右上 = アイコン(1回 = プロフィール ・ 2回 = 今日へ)*/
{const _h=y72Head;y72Head=function(){return _h().replace(/<button class="ztd" data-a="today"[^]*?<\/button><\/div>$/,`<button class="ztd zava" data-a="today" aria-label="アイコン ・ 2回 タップで 今日へ"><i class="${AV76.p?'':'ini'}" style="background-image:${avUrl()}">${AV76.p?'':AV76.ini}</i><span class="tip">2回 タップで 今日へ</span></button></div>`)}}
{const _b=y72Bind;y72Bind=function(W){_b(W);const ds=W.querySelector('[data-a="today"]');if(!ds)return;let lt=0,tm=0;
  ds.onclick=()=>{const n=performance.now();if(n-lt<380){clearTimeout(tm);lt=0;cancelAnimationFrame(Y72.raf);hap('pop','ぷにっ(今日へ)');try{closeY($('dsw'))}catch(e){closeY()}return}
    lt=n;hap('tick',null,{norip:1});tm=setTimeout(()=>{try{openPrf(ds)}catch(e){console.error(e)}setTimeout(avApply,80);setTimeout(avApply,600)},400)}}}
/* はじめての 設定:Name の 画面に アイコンの 丸 */
{const _ob=obBind;obBind=function(){_ob();try{
  if(OB.st==='name'){const X=$('obx');if(X&&!X.querySelector('.ob76')){const h=X.querySelector('.obh');h&&h.insertAdjacentHTML('afterend',`<div class="ob76"><button aria-label="アイコンの 写真を えらぶ"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg><u>+</u></button><p><b>アイコンの 写真</b>あとで プロフィールでも 変えられます</p></div>`);X.querySelector('.ob76 button').onclick=()=>avOpen()}}
  const c=document.querySelector('#obsw .cam');c&&(c.onclick=e=>{e.stopPropagation();avOpen()});avApply()}catch(e){console.error(e)}}}
{const _r=renderOrb;renderOrb=function(){_r();try{avApply()}catch(e){}};window.renderOrb=renderOrb}
document.addEventListener('click',e=>{if(e.target.closest('.av76b')){e.stopPropagation();e.preventDefault();avOpen();return}if(e.target.closest('#home #hhd .av')){setTimeout(avApply,60);setTimeout(avApply,600)}},true);
['pointerdown','pointerup'].forEach(t=>document.addEventListener(t,e=>{if(e.target.closest('.av76b'))e.stopPropagation()},true));
try{avApply()}catch(e){}
Object.assign(window.__kit||(window.__kit={}),{openPrf:()=>{try{openPrf()}catch(e){}setTimeout(avApply,80);setTimeout(avApply,600)},avOpen:()=>avOpen(),avSet:(p,z)=>{AV76.p=p;AV76.z=z||1;avApply();try{renderYAll()}catch(e){}}});
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-av]'))return;C.insertAdjacentHTML('beforeend','<button data-av="1">アイコンを 変える</button>');C.querySelector('[data-av]').onclick=()=>avOpen()})();
