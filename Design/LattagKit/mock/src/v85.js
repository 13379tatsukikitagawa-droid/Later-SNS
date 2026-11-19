/* ===== v85(モック v88) =====
   1. ライブ パネル:ライム ・ 数字が ころがって 止まる ・ 秒の 脈 ・ 1分ごとの 光 ・ バーが のびる
   2. Yesterday ページ(横スライド 5枚目)と 目次の YESTERDAY を なくす
   3. 現像画面:チェキ ・ ライム ・ 不透明度だけで 動かす(重い ぼかしの 計算を やめる)・ 押すと バイブが 強まり 色が 濃くなる */

/* ---------- 1. ライブ パネル ---------- */
var V85={m:null,s:null};
{const _o=openLive;openLive=function(from){_o(from);try{v85LiveIn()}catch(e){}}}
function v85LiveIn(){const K=$('lpk');if(!K)return;K.classList.add('v85i');setTimeout(()=>K.classList.remove('v85i'),1900);V85.m=null;
  /* 数字は 0 から 本当の 値へ ころがる(roll の 1回目 + .v85i の 長い ばね)*/
  const ez='cubic-bezier(.2,.8,.2,1)',f=K.querySelector('.lptr .fill'),n=$('lpnow');
  if(f)f.animate([{transform:'scaleX(0)'},{transform:'scaleX(1)'}],{duration:1100,delay:280,easing:ez,fill:'backwards'});
  if(n){const L=n.style.left;n.animate([{left:'0%',opacity:0},{left:L,opacity:1}],{duration:1100,delay:280,easing:ez,fill:'backwards'})}
  const big=K.querySelector('.lpm .big');big&&big.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:520,delay:160,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'});
  /* 数字が 止まる 時に コツコツ */
  [520,640,760,880,1000].forEach((t,i)=>setTimeout(()=>{if(LP.on)hap(i<4?'tick':'sel',null,{norip:1})},t))}
{const _l=lpLive;lpLive=function(){_l();try{if(!LP.on)return;const S=$('lpS'),K=$('lpk');if(!K||K.classList.contains('v85i'))return;
    S&&S.animate([{transform:'scale(1.22)',color:'#fff'},{transform:'scale(1)',color:'#C8F25A'}],{duration:520,easing:'cubic-bezier(.3,1.6,.5,1)'});
    const n=$('lpnow');if(n){n.classList.remove('v85b');void n.offsetWidth;n.classList.add('v85b')}
    const M=$('lpM')&&$('lpM')._s;if(V85.m!==null&&M!==V85.m){const b=K.querySelector('.lpm .big');if(b){b.classList.remove('v85sw');void b.offsetWidth;b.classList.add('v85sw')}hap('sel','コツッ(1分 へった)',{norip:1})}V85.m=M}catch(e){}}}

/* ---------- 2. Yesterday ページを なくす(Camera → Friends → Trip → Mondo の 4枚)---------- */
function v85NoYday(){const T=$('hpt');if(!T)return;const S=T.querySelector('.hsl[data-i="4"]');
  if(S){let H=$('v85hold');if(!H){H=document.createElement('div');H.id='v85hold';H.className='v85hide';$('hpg').appendChild(H)}H.appendChild(S)}
  const B=document.querySelector('#hpi button[data-i="4"]');if(B)B.remove();
  if(HPK.length>4)HPK.length=4;if(HPG.i>3)hpGo(3);hpLayout(HPG.x);try{g62Dock(true)}catch(e){}
  document.querySelectorAll('#hpg .hph .nb').forEach(e=>e.textContent=e.textContent.replace('/ 04','/ 03'))}
{const _h=hpHead;hpHead=function(i,k,sub){return _h(i,k,sub).replace('/ 04','/ 03')}}
v85NoYday();setTimeout(v85NoYday,0);

/* ---------- 3. 現像画面 ---------- */
const V85LK='<svg viewBox="0 0 12 12"><rect x="2.5" y="5.5" width="7" height="5" rx="1"/><path d="M4 5.5V4a2 2 0 014 0v1.5"/></svg>';
renderDvx=function(){let h='';
  for(let i=0;i<3;i++){const r=[-2,1.6,-1.2][i];
    if(i<shots)h+=`<div class="dxp" data-i="${i}"><div class="dxc v85c" data-dv="1" style="--r:${r}deg"><div class="dxw"><img class="dxim" src="${PH[DXP[i]]}" alt="" decoding="async"><i class="v85tn"></i><i class="v85wm"></i><div class="fog"></div><div class="gr" style="background-image:${GRN}"></div><i class="v85wv"></i><i class="v85fl"></i><span class="dxpt"></span></div><span class="dxtm">${i===shots-1?HM():TM[i]}</span><span class="v85lk">${V85LK}9:00</span><span class="dxkd">${KIND[i]&&KIND[i].m?'MOVIE':'PHOTO'}</span></div></div>`;
    else if(i===shots)h+=`<div class="dxp" data-i="${i}"><div class="dxc nx v85c" style="--r:0deg"><div class="dxw"><svg viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg><b>shoot</b><small>${['1st','2nd','3rd'][i]} shot</small></div></div></div>`;
    else h+=`<div class="dxp" data-i="${i}"><div class="dxc no v85c" style="--r:0deg"><div class="dxw"><b>Lattag</b><small>one by one</small></div></div></div>`}
  $('dxs').innerHTML=h;$('dxdots').innerHTML=[0,1,2].map(i=>`<i class="${i===DXI?'on':''}"></i>`).join('')};
/* 不透明度 だけ(ぼかしの 半径は 変えない)*/
dxApply=function(i,d){const c=document.querySelector(`.dxp[data-i="${i}"] .dxc[data-dv]`);if(!c)return;const v=Math.pow(Math.max(0,d),.35);
  c.style.setProperty('--v',v.toFixed(3));c.style.setProperty('--tn',(Math.sin(Math.PI*Math.min(1,v*1.2))*.55).toFixed(3))};
{const _u=dxUI;dxUI=function(){_u();try{const i=DXI,B=$('dxplay');if(!B)return;if(!B.querySelector('.v85bf'))B.insertAdjacentHTML('afterbegin','<i class="v85bf"></i>');
    const k=dxK(i),pct=Math.round(k*100),lab=$('dxlab');
    if(i<shots&&!DXplay){const seen=DXseen[i];$('dxplt').innerHTML=seen?'もう一度 見る':`現像する <small>${pct}% まで</small>`;B.classList.toggle('v85ok',!!seen);
      lab.textContent=seen?(DXD[i]>=k-.004?'NOW':'REPLAY'):'TAP TO DEVELOP'}
    if(DXplay)lab.textContent='DEVELOPING';
    $('dxt1').textContent='9:00 OPENS'}catch(e){}}}
dxPlay=function(){const i=DXI;if(i>=shots)return;const k=Math.max(.05,dxK(i)),tok=++DXtok,B=$('dxplay');DXplay=1;DXseen[i]=1;
  const dur=1700+k*2300,t0=performance.now(),card=document.querySelector(`.dxp[data-i="${i}"] .dxc[data-dv]`);let nx=t0,tens=-1;
  DXD[i]=0;dxApply(i,0);B.classList.remove('v85ok');B.classList.add('v85run');B.style.setProperty('--p',0);card&&card.classList.add('v85run');dxUI();
  (function f(n){if(tok!==DXtok)return;const p=Math.min(1,(n-t0)/dur),e=p<.5?2*p*p:1-Math.pow(-2*p+2,2)/2,d=k*e;
    DXD[i]=d;dxApply(i,d);B.style.setProperty('--p',p.toFixed(3));$('dxpc').textContent=Math.round(d*100);
    $('dxtr')&&($('dxfill').style.width=(d*100)+'%',$('dxth').style.left=(d*100)+'%');
    $('dxplt').innerHTML=`現像中 <small>${Math.round(d*100)}%</small>`;
    /* バイブ:最初は ゆっくり → だんだん 細かく 強く */
    setCont(.06+.62*p,'じわ…(色が 濃く なっていく)');
    if(n>=nx){hap(p<.55?'tick':'sel',null,{norip:1});nx=n+Math.max(60,230-185*p)}
    const t=Math.floor(d*10);if(t!==tens){tens=t;card&&card.animate([{transform:`translateX(var(--tx,0)) rotate(var(--r)) scale(1.012)`},{transform:`translateX(var(--tx,0)) rotate(var(--r)) scale(1)`}],{duration:220,easing:'ease-out'})}
    if(p<1){requestAnimationFrame(f);return}
    DXplay=0;setCont(0);B.classList.remove('v85run');card&&card.classList.remove('v85run');hap('heart','ドクン(いまの 濃さ まで 現像)',{norip:1});setTimeout(()=>hap('success',null,{norip:1}),160);
    const fl=card&&card.querySelector('.v85fl');fl&&fl.animate([{opacity:.55},{opacity:0}],{duration:620,easing:'ease-out'});
    card&&card.animate([{transform:'translateX(var(--tx,0)) rotate(var(--r)) scale(1)'},{transform:'translateX(var(--tx,0)) rotate(var(--r)) scale(1.035)',offset:.3},{transform:'translateX(var(--tx,0)) rotate(var(--r)) scale(1)'}],{duration:480,easing:'cubic-bezier(.3,1.5,.5,1)'});
    dxUI()})(t0)};
dxStop=function(){DXtok++;DXplay=0;setCont(0);const B=$('dxplay');B&&B.classList.remove('v85run');document.querySelectorAll('#dvx .v85c.v85run').forEach(c=>c.classList.remove('v85run'))};
/* ひらいた 時は ミルク色(0%)。自動で 再生しない(押すまで 待つ)*/
openDvx=function(i){if(DXopen)return;DXopen=true;DXI=Math.max(0,Math.min(2,i));DXseen={};DXD=[0,0,0];renderDvx();
  for(let j=0;j<shots;j++)dxApply(j,0);dxUI();
  const V=$('dvx');V.classList.remove('off');V.classList.add('on');hap('land','トン(現像の 中へ)');
  requestAnimationFrame(()=>{const S=$('dxs');S.scrollLeft=DXI*S.clientWidth;dxScroll(true);
    S.querySelectorAll('.dxp').forEach((p,j)=>p.animate([{opacity:0,transform:'translateY(40px)'},{opacity:1,transform:'none'}],{duration:560,delay:120+j*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
    $('dxctl').animate([{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'none'}],{duration:480,delay:260,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'})})};
dxScroll=function(init){const S=$('dxs'),w=S.clientWidth||1,x=S.scrollLeft/w;
  S.querySelectorAll('.dxp').forEach((p,j)=>{const dist=Math.min(1.2,Math.abs(x-j)),c=p.firstElementChild;c.style.setProperty('--sc',(1-dist*.1).toFixed(3));c.style.opacity=(1-dist*.5).toFixed(2);c.style.setProperty('--tx',((j-x)*-14).toFixed(1)+'px')});
  const idx=Math.max(0,Math.min(2,Math.round(x)));
  if(!init&&idx!==DXI){DXI=idx;dxStop();hap('sel','コツッ(となりの こま)',{norip:1});dxUI()}};
{const B=$('dxplay');
  B.onclick=()=>{if(DXI>=shots){hap('click','カチッ(撮る)');closeDvx();setTimeout(goShoot,420);return}if(DXplay){hap('warn','やわらかく2回(いま 現像中)');return}hap('click','カチッ(現像 スタート)');dxPlay()};
  B.addEventListener('pointerdown',()=>B.classList.add('v85dn'));['pointerup','pointercancel','pointerleave'].forEach(t=>B.addEventListener(t,()=>B.classList.remove('v85dn')))}

window.__kit=Object.assign(window.__kit||{},{v85Dev:()=>{if(DXopen&&!DXplay)dxPlay()},v85Live:()=>openLive($('hst'))});
