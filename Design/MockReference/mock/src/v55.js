/* ================= v55 Home の まんなか = 横に スライドする 5枚(カメラ + 4つ) =================
   ・0 カメラ(Shoot / Yesterday)→ 1 Friends → 2 Trip → 3 Mondo → 4 Yesterday
   ・指で 横に はらう / 下の 目次を 押す / カメラの 四すみの ボタンを 押す → その ページへ
   ・たてに スクロールすると、今までどおり 下の 写真(Today ・ Yesterday ・ Albums)へ
   ・v53 の「まわす ダイヤル」と「ひらく カード」は やめる(横の スワイプと ぶつかるため) */
const HPK=['cam','friends','group','mondo','yday'];
const HPL={cam:'Camera',friends:'Friends',group:'Trip',mondo:'Mondo',yday:'Yesterday'};
const HPI={cam:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.6"/></svg>'};
var HPG={i:0,x:0,drag:null,moved:false};
DL.hint=false;

/* ---------- つくる:#orb を 1枚目に 入れて、うしろに 4枚 ---------- */
function hpBuild(){if($('hpg'))return;const O=$('orb');const G=document.createElement('div');G.className='hpg';G.id='hpg';
  G.innerHTML=`<div class="hpt" id="hpt">${HPK.map((k,i)=>`<div class="hsl" data-i="${i}" data-k="${k}"><div class="hsi">${i?`<div class="hpc" id="hpc${i}"></div>`:''}</div></div>`).join('')}</div>
    <nav class="hpi" id="hpi" aria-label="ページ">${HPK.map((k,i)=>`<button data-i="${i}" aria-label="${HPL[k]}"><i></i><span>${HPL[k]}</span></button>`).join('')}</nav>`;
  O.parentNode.insertBefore(G,O);G.querySelector('.hsl[data-i="0"] .hsi').appendChild(O);
  G.querySelectorAll('.hpi button').forEach(b=>b.onclick=e=>{e.stopPropagation();hpGo(+b.dataset.i)});
  hpBind();hpIcons();hpRender();hpLayout(0)}
function hpIcons(){document.querySelectorAll('#hpi button').forEach(b=>{const k=HPK[+b.dataset.i];b.querySelector('i').innerHTML=k==='cam'?HPI.cam:OI[k]})}

/* ---------- 位置 ・ ちょっと 立体に ---------- */
function hpLayout(px){HPG.x=px;const T=$('hpt');if(!T)return;T.style.transform=`translate3d(${px.toFixed(1)}px,0,0)`;
  const pos=-px/390;T.querySelectorAll('.hsl').forEach(s=>{const d=+s.dataset.i-pos,a=Math.min(1,Math.abs(d));
    const I=s.firstElementChild;I.style.transform=`perspective(900px) rotateY(${(-d*14).toFixed(2)}deg) scale(${(1-.08*a).toFixed(3)})`;I.style.opacity=(1-.45*a).toFixed(3)});
  const ci=Math.round(pos);document.querySelectorAll('#hpi button').forEach(b=>b.classList.toggle('on',+b.dataset.i===ci))}
function hpGo(i,v){i=Math.max(0,Math.min(HPK.length-1,i));const from=HPG.x,to=-i*390,ch=i!==HPG.i;HPG.i=i;cancelAnimationFrame(HPG.raf);
  if(ch){hap('sel','コツッ(ページ)',{norip:1});hpRender(i);hpEnter(i)}
  let x=from,vel=v||0,last=performance.now();const k=.0009,c=.05;
  const st=now=>{const dt=Math.min(32,now-last);last=now;for(let s=0;s<dt;s+=4){const a=-k*(x-to)-c*vel;vel+=a*4;x+=vel*4}
    if(Math.abs(x-to)<.3&&Math.abs(vel)<.01){hpLayout(to);return}hpLayout(x);HPG.raf=requestAnimationFrame(st)};HPG.raf=requestAnimationFrame(st)}
function hpEnter(i){if(!i||matchMedia('(prefers-reduced-motion:reduce)').matches)return;const C=$('hpc'+i);if(!C)return;
  C.querySelectorAll('.hpe').forEach((e,j)=>e.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:480,delay:120+j*60,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'}));
  setTimeout(()=>hap('tick',null,{norip:1}),260)}

/* ---------- 指で 横に はらう(たては 今までどおり スクロール) ---------- */
function hpBind(){const G=$('hpg');let s=null,eat=false;
  G.addEventListener('pointerdown',e=>{if(e.button)return;s={x:e.clientX,y:e.clientY,x0:HPG.x,on:false,id:e.pointerId,h:[[performance.now(),HPG.x]]}},true);
  G.addEventListener('pointermove',e=>{if(!s)return;const dx=(e.clientX-s.x)/SC,dy=(e.clientY-s.y)/SC;
    if(!s.on){if(Math.abs(dx)>8&&Math.abs(dx)>Math.abs(dy)*1.2){s.on=true;cancelAnimationFrame(HPG.raf);try{G.setPointerCapture(s.id)}catch(_){}G.classList.add('drg')}else if(Math.abs(dy)>10){s=null;return}else return}
    let x=s.x0+dx;const min=-(HPK.length-1)*390;if(x>0)x*=.35;if(x<min)x=min+(x-min)*.35;hpLayout(x);
    const now=performance.now();s.h.push([now,x]);while(s.h.length>2&&now-s.h[0][0]>90)s.h.shift()},true);
  const end=e=>{if(!s)return;const S=s;s=null;if(!S.on)return;G.classList.remove('drg');eat=true;setTimeout(()=>eat=false,60);
    const h=S.h,f=h[0],l=h[h.length-1],v=l[0]-f[0]>8?(l[1]-f[1])/(l[0]-f[0]):0;
    let i=Math.round(-(HPG.x+v*160)/390);i=Math.max(HPG.i-1,Math.min(HPG.i+1,i));
    if((HPG.x>0&&i===0&&HPG.i===0)||(i===HPK.length-1&&HPG.i===i&&HPG.x<-(HPK.length-1)*390))hap('soft','やわらかく1回(はし)',{norip:1});hpGo(i,v)};
  G.addEventListener('pointerup',end,true);G.addEventListener('pointercancel',end,true);
  G.addEventListener('click',e=>{if(eat){e.stopPropagation();e.preventDefault()}},true);
  G.addEventListener('wheel',e=>{if(Math.abs(e.deltaX)>Math.abs(e.deltaY)&&Math.abs(e.deltaX)>18){e.preventDefault();if(HPG.wl)return;HPG.wl=1;setTimeout(()=>HPG.wl=0,420);hpGo(HPG.i+(e.deltaX>0?1:-1))}},{passive:false})}

/* ---------- 4枚の 中身 ---------- */
function hpHead(i,k,sub){return `<div class="hph hpe"><span class="ic">${OI[k]}</span><span class="nb">0${i} / 04</span><span class="st">${sub||''}</span></div><b class="hpt2 hpe">${HPL[k]}</b>`}
function hpGoBtn(lab,lk){return `<button class="hpgo hpe${lk?' lk':''}" data-a="go"><span>${lab}</span><i>${lk?OI.shoot:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'}</i></button>`}
function hpRender(only){if(!$('hpg')||!ORB)return;const lk=!shots;
  /* 1 Friends */
  if(!only||only===1){const C=$('hpc1'),took=FR.filter(f=>f.k>0),V=FR.slice().sort((a,b)=>b.k-a.k).slice(0,FR.length>3?7:3);
    C.className='hpc pf';C.innerHTML=hpHead(1,'friends',took.length?`● ${took.length} shot today`:'')+
    (REQ.length?`<button class="hprq hpe" data-a="req"><span class="avs">${REQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>Requests</b><em>承認 ›</em></button>`:'')+
    `<div class="hpfr hpe"><button class="ad" data-a="add"><span>${ICO.plus}</span><small>Add</small></button>${V.map(f=>`<button data-a="f" data-n="${f.n}"><span class="r${f.k>0?' k':''}" style="--k:${f.k}"><i style="background:${avBg(f)}">${f.n[0]}</i></span><small>${f.n}</small></button>`).join('')}</div>
    <div class="hpyd hpe"><span class="lb">YESTERDAY</span><div class="hpth${lk?' lk':''}">${(FR.length?FR.slice(0,4):[0,1,2,3]).map((f,j)=>`<i style="background-image:url(${PH['dbfa'[j]]})">${f&&f.n?`<u style="background:${avBg(f)}">${f.n[0]}</u>`:''}</i>`).join('')}${lk?`<em>${ICO.lock}</em>`:''}</div></div>`+hpGoBtn('Open friends');
    C.querySelector('[data-a="go"]').onclick=()=>{hap('pop');openFriend()};C.querySelectorAll('[data-a="add"]').forEach(b=>b.onclick=()=>{hap('pop');openAdd()});
    const rq=C.querySelector('[data-a="req"]');if(rq)rq.onclick=()=>{hap('pop');openFriend()};
    C.querySelectorAll('[data-a="f"]').forEach(b=>b.onclick=()=>{hap('sel');const f=FR.find(x=>x.n===b.dataset.n);openFriend();setTimeout(()=>{FSEL=FR.indexOf(f);fSoft()},500)})}
  /* 2 Trip */
  if(!only||only===2){const C=$('hpc2'),t=GRP.find(g=>g.trip);C.className='hpc pt';
    if(t){const c=t.cnt||0;C.innerHTML=hpHead(2,'group',t.dates||'')+`<b class="hptn hpe">${rmEsc(t.n)}</b>
      <div class="hpgrid hpe">${Array.from({length:23},(_,j)=>{const w=t.by&&t.by[j];const f=w==='me'?null:t.m[w];return `<i class="${j<c?'on':''}" style="${j<c?`background:${w==='me'?'#C8F25A':avBg(f||t.m[0])}`:''}"></i>`}).join('')}<span class="ct"><b>${c}</b>/23</span></div>
      <div class="hptb hpe"><span class="avs">${[{me:1},...t.m].slice(0,5).map(f=>f.me?`<i class="me">ゆ</i>`:`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span><small>あした 9:00 に みんなで ひらく</small></div>
      <div class="hptw hpe"><button class="hpsh" data-a="shot">${OI.shoot}<span>Shoot</span></button><button class="ch" data-a="chat">${ICH}${t.un?`<u>${t.un}</u>`:''}</button></div>`;
      C.querySelector('[data-a="shot"]').onclick=e=>{tripShot(t,C);setTimeout(()=>hpRender(2),300)};C.querySelector('[data-a="chat"]').onclick=()=>openRoom(t)}
    else{C.innerHTML=hpHead(2,'group','')+`<div class="hpt0 hpe"><svg viewBox="0 0 120 96"><g fill="none" stroke="#fff" stroke-width="3" stroke-linejoin="round"><rect x="22" y="26" width="76" height="58" rx="10" fill="#24A03C"/><path d="M46 26v-8a6 6 0 016-6h16a6 6 0 016 6v8M40 40v30M80 40v30"/></g><g fill="#C8F25A" stroke="#111" stroke-width="2"><rect x="70" y="6" width="34" height="22" rx="4" transform="rotate(10 87 17)"/></g></svg>
      <b>旅行 ・ イベント ・ 合宿</b><small>1日 23枚を、みんなで 分けあって 撮る</small></div>`+hpGoBtn('New trip');
      C.querySelector('[data-a="go"]').onclick=()=>{hap('pop');tripSeed()}}}
  /* 3 Mondo */
  if(!only||only===3){const C=$('hpc3'),m=ORB.A.mondo;C.className='hpc pm';const now=new Date(),u=now.getUTCHours()+now.getUTCMinutes()/60;
    C.innerHTML=hpHead(3,'mondo',lk?'LOCKED':'TOP 5')+`<div class="hpgl hpe"><svg viewBox="0 0 120 120"><defs><clipPath id="hpcl"><circle cx="60" cy="60" r="52"/></clipPath></defs><circle cx="60" cy="60" r="52" class="o"/><g clip-path="url(#hpcl)"><g class="mer"><path d="M60 8c-20 14-20 90 0 104M60 8c20 14 20 90 0 104M24 16c-16 24-16 64 0 88M96 16c16 24 16 64 0 88M-12 8c-20 14-20 90 0 104M132 8c20 14 20 90 0 104"/></g><path d="M8 60h104M12 36h96M12 84h96" class="lat"/></g><circle cx="86" cy="34" r="6" class="pin"/></svg></div>
      <b class="hpwd hpe">The world,<br><em>yesterday.</em></b>
      <div class="hptg hpe${lk?' lk':''}">${['#夕焼け','#放課後','#帰り道'].map((t,j)=>`<span style="--j:${j}"><b>0${j+1}</b>${t}</span>`).join('')}${lk?`<em>${ICO.lock}</em>`:''}</div>
      <div class="hpclk hpe">${[['Tokyo',9],['Paris',1],['New York',-5]].map(([c,z])=>{const h=((u+z)%24+24)%24;return `<span class="${h>=9&&h<21?'on':''}"><i></i>${c} <b>${Math.floor(h)}:${p2(Math.floor((h%1)*60))}</b></span>`}).join('')}</div>`+hpGoBtn(lk?'Shoot first':'Explore',lk);
    C.querySelector('[data-a="go"]').onclick=()=>{if(lk){hap('pop');ORB.A.shoot&&ORB.A.shoot.run();return}hap('pop');m.run()}}
  /* 4 Yesterday */
  if(!only||only===4){const C=$('hpc4'),y=ORB.A.yday;C.className='hpc py';
    C.innerHTML=hpHead(4,'yday',lk?'LOCKED':Math.min(shots,3)+' OPENED')+`<div class="hpfan hpe${lk?' lk':''}">${YD.map((d,j)=>`<i style="--r:${(j-1)*10}deg;--x:${(j-1)*70}px;--y:${Math.abs(j-1)*14}px"><span style="background-image:url(${PH[d.p]})"></span><s>${d.tm}</s></i>`).join('')}${lk?`<em>${ICO.lock}</em>`:''}</div>
      <div class="hpys hpe">${YD.map(d=>`<span style="background:${tgc(d.t)[0]};color:${tgc(d.t)[1]}">${d.t}</span>`).join('')}</div>`+hpGoBtn(lk?'Shoot first':'Open',lk);
    C.querySelector('[data-a="go"]').onclick=()=>{if(lk){hap('pop');ORB.A.shoot&&ORB.A.shoot.run();return}hap('pop');y.run()}}}

/* ---------- カメラの 四すみの ボタン = その ページへ(ダイヤル ・ カードは やめる) ---------- */
function hpCorner(){document.querySelectorAll('#odbs .odb').forEach(b=>{if(b._hp)return;const n=b.cloneNode(true);n._hp=1;b.replaceWith(n);
  n.addEventListener('pointerdown',()=>{n.classList.add('dn');hap('click','カチッ(おした)',{norip:1})});['pointerup','pointerleave','pointercancel'].forEach(t=>n.addEventListener(t,()=>n.classList.remove('dn')));
  n.addEventListener('click',e=>{e.stopPropagation();const i=HPK.indexOf(n.dataset.k);n.querySelector('i').animate([{scale:'1'},{scale:'.84'},{scale:'1.1'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(i>0)setTimeout(()=>hpGo(i),120);else{const a=ORB.A[n.dataset.k];a&&setTimeout(()=>a.run(),120)}})})}
{const _b=dlBuild;dlBuild=function(){_b();hpCorner();DL.phi=0;dlLayout()}}
{const _r=renderOrb;renderOrb=function(){_r();try{hpBuild();hpRender()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
/* たてスクロールの 動き(視差)は ページ全体に かける */
$('hs').addEventListener('scroll',()=>{const o=$('orb'),g=$('hpg');if(!g)return;g.style.transform=o.style.transform;g.style.opacity=o.style.opacity;o.style.transform='';o.style.opacity=''},{passive:true});
{const _hf=homeFocus;homeFocus=function(){_hf();const g=$('hpg');if(g){g.style.transform='';g.style.opacity=''}}}
renderOrb();
window.hpGo=hpGo;window.HPG=HPG;
/* ボタンの 大きさは 4つとも 同じ(READY の 拡大は やめる) */
dlLayout=function(){document.querySelectorAll('#odbs .odb').forEach(b=>{const i=+b.dataset.i,th=DLB[i],[x,y]=dlPos(th);DL.pos[b.dataset.k]=[x,y,th];b.style.transform=`translate(${x.toFixed(2)}px,${y.toFixed(2)}px)`;b.classList.remove('rdy')})};
dlLayout();

/* ほかの ページを 見ている 間は カメラの 位置を 測りなおさない(ずれ 防止) */
{const _m=dlMeasure;dlMeasure=function(){if(HPG.i!==0||Math.abs(HPG.x)>1)return;_m()}}
