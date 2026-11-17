/* ================= v62 ・ 仕上げ =================
   1) 四すみの 位置を そろえる(上 y154 / 下 y428 = 下の ピルと 同じ 高さ)
   2) 上の チップ:だれが 今日 撮ったか → 押すと Friends ページへ
   3) ガラスの ふちの 光が、端末の かたむき(または 指の 位置)に ついて くる
   4) 目次の 選んだ 印が、液体の ように 伸びて すべる */
dlLayout=function(){const P=[[-133,-141],[133,-141],[-133,133],[133,133]];
  document.querySelectorAll('#odbs .odb').forEach(b=>{const i=+b.dataset.i,[x,y]=P[i];DL.pos[b.dataset.k]=[x,y,DLB[i]];b.style.transform=`translate(${x}px,${y}px)`;b.classList.remove('rdy')})};

/* --- ガラスの ふちを 足す --- */
function g62Rim(el){if(!el||el.querySelector(':scope>.lgr'))return;el.insertAdjacentHTML('beforeend','<span class="lgr"></span><span class="lgh"></span>')}
function g62Rims(){['#hxp','#hxc','#hpi'].forEach(s=>g62Rim(document.querySelector(s)));document.querySelectorAll('#odbs .odb i').forEach(g62Rim);
  const L=document.querySelector('#lens .lnb');if(L&&!L.querySelector('.lgr')){L.style.overflow='visible';g62Rim(L);L.querySelector('.lgr').style.padding='3px'}}

/* --- 上の チップ --- */
function g62Chip(){const O=$('orb');if(!O)return;let C=$('hxc');
  if(!C){O.insertAdjacentHTML('beforeend','<button class="hxc" id="hxc" aria-label="今日 撮った 友だち"></button>');C=$('hxc');
    C.onclick=e=>{e.stopPropagation();hap('sel','コツッ(Friends へ)');hpGo(1)};C.addEventListener('pointerdown',e=>e.stopPropagation())}
  const T=FR.filter(f=>f.k>0).sort((a,b)=>b.k-a.k);
  if(!T.length){C.className='hxc e';C.innerHTML=FR.length?'<b>まだ だれも 撮って いない</b>':'<b>友だちを よぶ</b><small>ADD ›</small>';
    if(!FR.length)C.onclick=e=>{e.stopPropagation();hap('pop');openAdd()};else C.onclick=e=>{e.stopPropagation();hap('sel');hpGo(1)}}
  else{C.className='hxc';const S=T.slice(0,3);C.innerHTML=`<span class="av">${S.map(f=>`<i style="background-image:url(${fPic(f)})"></i>`).join('')}${T.length>3?`<i class="n">+${T.length-3}</i>`:''}</span><b>${T.length===1?T[0].n+' が 撮った':T.length+'人 が 撮った'}</b><i class="lv"></i>`;
    C.onclick=e=>{e.stopPropagation();hap('sel','コツッ(Friends へ)');hpGo(1)}}
  g62Rim(C)}

/* --- 光の 向き --- */
var G62={tx:0,ty:0,x:0,y:0,t:0,user:0};
function g62Tick(now){requestAnimationFrame(g62Tick);if(!$('home').classList.contains('on'))return;
  if(now-G62.user>2500){const s=now/1000;G62.tx=Math.sin(s*.35)*.5;G62.ty=Math.cos(s*.27)*.35}  /* だれも 触って いない とき は ゆっくり 揺れる */
  G62.x+=(G62.tx-G62.x)*.08;G62.y+=(G62.ty-G62.y)*.08;const O=$('orb');if(!O)return;
  O.style.setProperty('--lx',G62.x.toFixed(3));O.style.setProperty('--ly',G62.y.toFixed(3));O.style.setProperty('--la',(210+G62.x*70).toFixed(1)+'deg')}
if(!matchMedia('(prefers-reduced-motion:reduce)').matches)requestAnimationFrame(g62Tick);
$('hs').addEventListener('pointermove',e=>{const r=$('orb').getBoundingClientRect();G62.tx=Math.max(-1,Math.min(1,(e.clientX-r.left)/r.width*2-1));G62.ty=Math.max(-1,Math.min(1,(e.clientY-r.top)/r.height*2-1));G62.user=performance.now()},{passive:true});
window.addEventListener('deviceorientation',e=>{if(e.gamma==null)return;G62.tx=Math.max(-1,Math.min(1,e.gamma/30));G62.ty=Math.max(-1,Math.min(1,(e.beta-45)/30));G62.user=performance.now()},{passive:true});

/* --- 目次:すべって 伸びる 印 --- */
var G62K={x:0,w:0,raf:0};
function g62Dock(jump){const N=$('hpi');if(!N)return;let K=N.querySelector('.hpk');if(!K){N.insertAdjacentHTML('afterbegin','<i class="hpk"></i>');K=N.querySelector('.hpk')}
  const B=N.querySelector('button.on');if(!B)return;const nx=B.offsetLeft,nw=B.offsetWidth;
  if(jump||!G62K.w||matchMedia('(prefers-reduced-motion:reduce)').matches){G62K.x=nx;G62K.w=nw;K.style.width=nw+'px';K.style.transform=`translateX(${nx}px)`;return}
  const x0=G62K.x,w0=G62K.w;G62K.x=nx;G62K.w=nw;const L=Math.min(x0,nx),R=Math.max(x0+w0,nx+nw);
  K.animate([{transform:`translateX(${x0}px)`,width:w0+'px'},{transform:`translateX(${nx>x0?x0:L}px)`,width:(R-L)+'px',offset:.42},{transform:`translateX(${nx}px)`,width:nw+'px'}],{duration:440,easing:'cubic-bezier(.3,1.25,.4,1)'});
  K.style.width=nw+'px';K.style.transform=`translateX(${nx}px)`}
{const _l=hpLayout;hpLayout=function(px){_l(px);const N=$('hpi');if(!N)return;const ci=Math.round(-px/390);if(ci!==G62K.ci){G62K.ci=ci;requestAnimationFrame(()=>requestAnimationFrame(()=>g62Dock(false)))}};window.hpLayout=hpLayout}

/* --- まとめて 反映 --- */
{const _r=renderOrb;renderOrb=function(){_r();try{g62Chip();g62Rims();dlLayout()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
{const _hi=homeIn;homeIn=function(s){_hi(s);if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;const C=$('hxc');
  C&&C.animate([{transform:'translateY(-10px) scale(.9)',opacity:0},{transform:'none',opacity:1}],{duration:520,delay:560,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'});
  $('lens').animate([{transform:'scale(.48)',opacity:0},{transform:'scale(.67)',opacity:1,offset:.7},{transform:'scale(.645)'}],{duration:680,delay:180,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'})}}
try{renderOrb();g62Dock(true)}catch(e){console.error(e)}
setTimeout(()=>g62Dock(true),400);
