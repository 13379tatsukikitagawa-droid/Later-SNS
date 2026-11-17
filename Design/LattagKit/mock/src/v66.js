
/* ================= v66(PROMPT v69)・ カメラの ファインダー ================= */
var V66={t:0,last:''};
const p66=n=>String(n).padStart(2,'0');

/* ---------- A. ヘッダーの HUD ---------- */
function h66Build(){const D=$('dsw'),HH=document.querySelector('#hhd .hh');if(D&&HH&&D.parentElement!==HH)HH.appendChild(D);const H=$('hst');if(!H||H.querySelector('.h66'))return;
  H.insertAdjacentHTML('afterbegin',`<span class="h66"><span class="rg"><svg viewBox="0 0 32 32"><circle class="t" cx="16" cy="16" r="13"/><circle class="p" cx="16" cy="16" r="13" pathLength="100" id="h66p"/></svg><i></i></span>
    <span class="lb" id="h66l">消灯まで</span><span class="tm" id="h66t"></span><i class="sp"></i>
    <span class="fm"><span class="fr" id="h66f"></span><b id="h66n">3</b><small>EXP</small></span>
    <span class="ch"><svg viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg></span></span>`);
  h66Tick();clearInterval(V66.t);V66.t=setInterval(()=>{if($('home').classList.contains('on'))h66Tick()},1000)}
function h66Tick(){const d=new Date(),h=d.getHours(),m=d.getMinutes(),s=d.getSeconds(),now=h*3600+m*60+s;
  const night=h<9,end=night?9*3600:24*3600,rem=Math.max(0,end-now);
  const tx=[Math.floor(rem/3600),p66(Math.floor(rem%3600/60)),p66(rem%60)];
  const T=$('h66t');if(T){const old=V66.last.split(':');T.innerHTML=`<span class="d${old[0]!=tx[0]?' tk':''}">${tx[0]}</span>:<span class="d${old[1]!=tx[1]?' tk':''}">${tx[1]}</span><span class="sec">:<span class="d tk">${tx[2]}</span></span>`;V66.last=tx.join(':')}
  const L=$('h66l');if(L)L.textContent=night?'ひらくまで':'消灯まで';
  const P=$('h66p');if(P){const f=night?1-rem/(9*3600):(now-9*3600)/(15*3600);P.style.strokeDashoffset=(100*(1-Math.min(1,Math.max(0,f)))).toFixed(1)}
  h66Film()}
function h66Film(){const n=Math.min(3,typeof shots==='number'?shots:0),left=3-n,F=$('h66f');
  if(F){if(F.children.length!==3)F.innerHTML='<i></i><i></i><i></i>';[...F.children].forEach((x,i)=>x.classList.toggle('u',i>=left))}
  const N=$('h66n');if(N&&N.textContent!==String(left)){N.textContent=left;N.animate([{transform:'translateY(40%)',opacity:0},{transform:'none',opacity:1}],{duration:320,easing:'cubic-bezier(.2,.9,.3,1)'})}
  const A=document.querySelector('#hhd .av');if(A)A.style.setProperty('--av66',(n/3).toFixed(3))}
/* 下へ スクロールすると ヘッダーが 1つに まとまる */
(()=>{const S=$('hs');if(!S)return;let c=false;S.addEventListener('scroll',()=>{const on=S.scrollTop>60;if(on!==c){c=on;$('hhd').classList.toggle('cpt',on);hap('tick',null,{norip:1,gap:300})}},{passive:true})})();

/* ---------- B. 四すみ ---------- */
dlLayout=function(){const P=[[-135,-141],[135,-141],[-135,133],[135,133]];
  document.querySelectorAll('#odbs .odb').forEach(b=>{const i=+b.dataset.i,[x,y]=P[i];DL.pos[b.dataset.k]=[x,y,DLB[i]];b.style.transform=`translate(${x}px,${y}px)`;b.classList.remove('rdy');
    if(!b.querySelector('.ck'))b.querySelector('.w').insertAdjacentHTML('beforeend','<span class="ck"></span>')})};
/* Home に 入ると:かぎが ピントを 合わせ、ボタンが レンズから 飛び出す */
function odb66In(d0){if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;const P=[[-135,-141],[135,-141],[-135,133],[135,133]];
  document.querySelectorAll('#odbs .odb').forEach(b=>{const i=+b.dataset.i,[x,y]=P[i],W=b.querySelector('.w'),C=b.querySelector('.ck');if(!W)return;
    W.animate([{transform:`translate(${-x}px,${-y}px) scale(.28)`,opacity:0},{transform:`translate(${(-x*.06).toFixed(1)}px,${(-y*.06).toFixed(1)}px) scale(1.08)`,opacity:1,offset:.68},{transform:'none',opacity:1}],{duration:720,delay:d0+i*70,easing:'cubic-bezier(.3,1.1,.4,1)',fill:'backwards'});
    if(C)C.animate([{transform:`translate(${Math.sign(x)*14}px,${Math.sign(y)*14}px) scale(1.5)`,opacity:0},{transform:'none',opacity:1}],{duration:460,delay:d0+380+i*70,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'backwards'});
    setTimeout(()=>hap('tick',null,{norip:1}),d0+520+i*70)})}
{const _hi=homeIn;homeIn=function(s){_hi(s);odb66In(420);const V=$('vf66');if(V&&!matchMedia('(prefers-reduced-motion:reduce)').matches){V.classList.add('ar');setTimeout(()=>V.classList.remove('ar'),1350)}
  const H=document.querySelector('#hhd .hst');if(H&&!matchMedia('(prefers-reduced-motion:reduce)').matches)H.animate([{clipPath:'inset(0 100% 0 0 round 23px)'},{clipPath:'inset(0 0 0 0 round 23px)'}],{duration:700,delay:260,easing:'cubic-bezier(.3,.9,.3,1)',fill:'backwards'})}}

/* ---------- C. ファインダー ・ しぼり羽根 ---------- */
function vf66Build(){const O=$('orb'),L=$('lens');if(!O||!L||$('vf66'))return;
  O.insertAdjacentHTML('beforeend',`<div class="vf66" id="vf66"><i class="gd"></i><i class="af"></i></div>`);
  const r0=-200,blades=Array.from({length:6},(_,k)=>`<g style="transform:rotate(${k*60}deg)"><g class="bl" style="transform:translateY(calc(var(--d) * -1)) rotate(-18deg)"><rect x="-150" y="-170" width="300" height="170" rx="6"/></g></g>`).join('');
  L.querySelector('.lnb').insertAdjacentHTML('afterend',`<svg class="irs" id="irs" viewBox="-156 -156 312 312"><defs><clipPath id="ir66c"><circle r="117"/></clipPath><linearGradient id="ir66g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2a2a2e" stop-opacity=".96"/><stop offset="1" stop-color="#0d0d0f" stop-opacity=".96"/></linearGradient></defs><g clip-path="url(#ir66c)">${blades}</g></svg>`);
  const I=$('irs'),V=$('vf66');let dn=false;
  L.addEventListener('pointerdown',()=>{dn=true;I.classList.remove('sn');I.classList.add('cl');V.classList.add('ar')});
  const up=sn=>{if(!dn)return;dn=false;V.classList.remove('ar');
    if(sn&&!matchMedia('(prefers-reduced-motion:reduce)').matches){I.classList.add('sn');setTimeout(()=>{I.classList.remove('sn','cl')},110)}else I.classList.remove('cl')};
  L.addEventListener('pointerup',()=>up(true));['pointerleave','pointercancel'].forEach(e=>L.addEventListener(e,()=>up(false)))}
{const _r=renderOrb;renderOrb=function(){_r();try{h66Build();h66Film();vf66Build();dlLayout()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{h66Build();vf66Build();dlLayout()}catch(e){console.error(e)}
Object.assign(window.__kit||(window.__kit={}),{h66Tick:()=>h66Tick(),odbIn:()=>odb66In(0),iris:c=>{const I=$('irs');I&&I.classList.toggle('cl',!!c);const V=$('vf66');V&&V.classList.toggle('ar',!!c)}});
