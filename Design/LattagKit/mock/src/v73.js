
/* ================= v73(PROMPT v75)・ ME = 縦線を 重ねた デザイン ================= */
const M73={n:60,sel:59};
function m73Days(){/* 60日:きのうまでの 記録(モックは 決まった 乱数 ・ 本番は 実データ)*/
  const P=['a','b','c','d','e','f'],out=[],t=new Date();let s=7;const R=()=>(s=(s*9301+49297)%233280)/233280;
  for(let i=M73.n-1;i>=0;i--){const d=new Date(t.getTime()-(i+1)*864e5);const r=R();const k=i<7?3-(i%2):(r<.18?0:r<.4?1:r<.68?2:3);
    out.push({d,k,sh:Array.from({length:k},(_,j)=>({h:7+((i*7+j*5)%16),p:P[(i+j*2)%6],st:R()<.12}))})}
  try{ME.days.forEach(x=>{const o=out.find(o=>o.d.toDateString()===x.d.toDateString());if(o){o.k=x.fr.length;o.sh=x.fr.map((f,j)=>({h:9+j*4,p:f.p,st:!!f.star}))}})}catch(e){}
  return out}
function m73Bars(D){const W=326,H=150,w=W/D.length;let s='';
  D.forEach((x,i)=>{const cx=i*w+w/2;
    if(!x.k){s+=`<rect x="${(cx-.5).toFixed(2)}" y="${H-26}" width="1" height="26" fill="rgba(255,255,255,.16)"/>`;return}
    /* 1枚 ごとに 1本。少し ずらして 重ねる(撮った 時間 = 線の 高さ)*/
    const C=['#24A03C','#3BD35A','#C8F25A'];
    x.sh.forEach((sh,j)=>{const hgt=40+((sh.h-7)/16)*(H-46);const xx=cx-1.6+j*1.3;
      s+=`<rect x="${xx.toFixed(2)}" y="${(H-hgt).toFixed(1)}" width="2.2" height="${hgt.toFixed(1)}" rx="1.1" fill="${C[Math.min(2,x.k-1+ (j===x.k-1?0:-1)<0?0:Math.min(2,j))]}" fill-opacity="${.62+j*.14}"/>`;
      if(sh.st)s+=`<circle cx="${(xx+1.1).toFixed(2)}" cy="${(H-hgt-6).toFixed(1)}" r="2.4" fill="#fff"/>`})});
  /* 写ルンです の 3色の 線(左の 目じるし)*/
  return `<svg viewBox="0 0 ${W} ${H}" preserveAspectRatio="none">${s}</svg>`}
function m73Day(D){const x=D[M73.sel],wd=['SUN','MON','TUE','WED','THU','FRI','SAT'][x.d.getDay()],mo=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][x.d.getMonth()];
  return `<div class="zdh"><b>${['日','月','火','水','木','金','土'][x.d.getDay()]} ${x.d.getMonth()+1}/${x.d.getDate()}</b><small>${wd} ・ ${mo} ${x.d.getDate()} ・ ${x.k} SHOTS</small></div>
   <div class="zdp">${[0,1,2].map(j=>x.sh[j]?`<i style="background-image:url(${PH[x.sh[j].p]})"></i>`:'<i class="e"></i>').join('')}</div>`}
meRender=function(){const W=$('mew');if(!W)return;const D=m73Days();M73.D=D;const tot=D.reduce((a,x)=>a+x.k,0),days=D.filter(x=>x.k).length,kept=D.reduce((a,x)=>a+x.sh.filter(s=>s.st).length,0);
  const wk=D.slice(-7).reverse();
  W.innerHTML=`<div class="m73"><div class="zs">
   <div class="zh"><button class="zbk" data-a="bk" aria-label="もどる"><svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg></button><div class="zt">ME</div><div class="zy">YOUR ${M73.n} DAYS<b>${new Date().getFullYear()}</b></div></div>
   <div class="zbc"><div class="lb"><b>●</b> 1日 = 1本 ・ 1枚 = 1本の 線</div><div class="rd"></div>${m73Bars(D)}<i class="cur"></i>
    <div class="ax"><span>${M73.n} DAYS AGO</span><span>30</span><span>YESTERDAY</span></div></div>
   <div class="zst"><div><b>${tot}</b><small>SHOTS</small></div><div><b>${days}</b><small>DAYS</small></div><div><b>${kept}</b><small>KEPT ★</small></div></div>
   <div class="zdy"></div>
   <div class="zwk"><div class="zwh"><b>この 1週間</b><span>7日で きえる ・ ★ で のこす</span></div>
    <div class="zfs">${wk.map(x=>`<div class="zfc"><small>${['SUN','MON','TUE','WED','THU','FRI','SAT'][x.d.getDay()]}<b>${x.d.getDate()}</b></small>${[0,1,2].map(j=>x.sh[j]?`<i style="background-image:url(${PH[x.sh[j].p]})">${x.sh[j].st?'<em>★</em>':''}</i>`:'<i style="background:#101113"></i>').join('')}</div>`).join('')}</div></div>
   <p class="znt">線の 高さ = 撮った 時間(高い ほど 夜)。白い 点 = ★ で のこした 1枚。</p>
  </div></div>`;
  W.querySelector('[data-a="bk"]').onclick=()=>closeMe();m73Sel(M73.sel,true);
  const B=W.querySelector('.zbc'),pick=e=>{const r=B.getBoundingClientRect(),x=Math.max(0,Math.min(1,(e.clientX-r.left-16)/(r.width-32)));const i=Math.min(D.length-1,Math.floor(x*D.length));if(i!==M73.sel){m73Sel(i);hap('tick',null,{norip:1,gap:40})}};
  B.onpointerdown=e=>{B.setPointerCapture(e.pointerId);pick(e);B.onpointermove=pick};B.onpointerup=B.onpointercancel=()=>{B.onpointermove=null}}
function m73Sel(i,q){M73.sel=i;const W=$('mew'),D=M73.D;if(!W||!D)return;const B=W.querySelector('.zbc'),c=B.querySelector('.cur');c.style.left=`calc(16px + (100% - 32px) * ${((i+.5)/D.length).toFixed(4)})`;
  const x=D[i];B.querySelector('.rd').innerHTML=`${x.d.getMonth()+1}/${x.d.getDate()}<small>${x.k} SHOTS</small>`;W.querySelector('.zdy').innerHTML=m73Day(D)}
Object.assign(window.__kit||(window.__kit={}),{meSel:i=>m73Sel(i)});
