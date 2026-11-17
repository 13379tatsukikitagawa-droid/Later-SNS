/* ================= v48 friend 画面(暗室・12の 席) ================= */
$('fscr').classList.add('v48');
const FTM=['08:14','12:40','17:05'],fStreak=f=>(f.n.charCodeAt(0)%9)+2,fSince=f=>{const d=new Date(Date.now()-((f.n.charCodeAt(0)%40)+6)*864e5);return MON[d.getMonth()]+' '+d.getDate()};
var FSEL=-1;
function fSeats(ni){const nx=FR.length;return Array.from({length:12},(_,i)=>{const a=i*30,f=FR[i];
  if(!f)return `<button class="fs e${i===nx?' nx':''}" data-i="${i}" style="--a:${a}deg;--d:${i*.04}s" aria-label="あいている 席"><i></i></button>`;
  return `<button class="fs f${f.k>0?' k':''}${FSEL===i?' sel':''}${POKED.has(i)?' pkd':''}${i===ni?' new':''}" data-i="${i}" style="--a:${a}deg;--d:${i*.04}s" aria-label="${f.n}、今日 ${f.k}こま"><svg viewBox="0 0 60 60"><circle cx="30" cy="30" r="27.5" class="t"/><circle cx="30" cy="30" r="27.5" class="p" pathLength="3" style="stroke-dasharray:${f.k} 3"/></svg><span class="av" style="background:${avBg(f)}">${f.n[0]}</span>${f.k>0?`<em>${f.k}</em>`:''}<small>${f.n}</small></button>`}).join('')}
/* なかまの イラスト(まるい キャラが あつまる) */
const FCOL=['#61D278','#EE5E9C','#FFD60A','#9ED8FF','#9B8CFF','#FF9A3C'];
function fChar(c,x,y,s,r,o){o=o||{};const arm=o.up?`<path d="M14 6 Q24 -4 22 -14" class="ar"/>${o.ph?`<rect x="16" y="-27" width="11" height="17" rx="3" fill="#111"/><rect x="18" y="-25" width="7" height="11" rx="1.5" fill="#9ED8FF"/>`:''}`:`<path d="M14 10 Q22 14 22 22" class="ar"/>`;
  return `<g class="ch" transform="translate(${x} ${y}) rotate(${r}) scale(${s})" style="--d:${(o.d||0)}s">${o.wv?`<path d="M-14 6 Q-24 -4 -22 -14" class="ar"/>`:`<path d="M-14 10 Q-22 14 -22 22" class="ar"/>`}${arm}
    <path d="M-18 34V2a18 18 0 0136 0v32z" fill="${c}" stroke="#111" stroke-width="2.6" stroke-linejoin="round"/>
    <circle cx="-6.5" cy="0" r="2.4" fill="#111"/><circle cx="6.5" cy="0" r="2.4" fill="#111"/><path d="M-5 6.5q5 5 10 0" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round"/>
    <ellipse cx="-11.5" cy="6" rx="3" ry="2" fill="#FF7FAE" opacity=".75"/><ellipse cx="11.5" cy="6" rx="3" ry="2" fill="#FF7FAE" opacity=".75"/></g>`}
function fCrowd(n){/* じぶん + ともだち(最大5) → 円の 下から のぞく */
  const k=Math.min(5,n),cols=['#61D278',...FR.slice(0,4).map(f=>f.g[1])].slice(0,k+0)||['#61D278'];const m=Math.max(1,Math.min(5,n));
  const P={1:[[88,112,1.5,0]],2:[[64,116,1.3,-7],[112,114,1.3,7]],3:[[48,124,1.15,-10],[88,106,1.3,0],[128,124,1.15,10]],4:[[38,128,1.05,-12],[70,110,1.15,-4],[106,110,1.15,4],[138,128,1.05,12]],5:[[30,132,.98,-14],[58,114,1.06,-7],[88,102,1.16,0],[118,114,1.06,7],[146,132,.98,14]]}[m];
  const order=P.map((p,i)=>i).sort((a,b)=>P[a][1]-P[b][1]);
  return `<svg class="crowd" viewBox="0 0 176 176">${order.reverse().map(i=>{const [x,y,s,r]=P[i];const mid=i===Math.floor(m/2);return fChar(cols[i]||'#9ED8FF',x,y,s,r,{up:mid||i===m-1,ph:mid,wv:i===0&&m>1,d:i*.12})}).join('')}</svg>`}
function fCore(){const f=FSEL>=0?FR[FSEL]:null;
  if(f)return `<div class="fcf"><span class="av" style="background:${avBg(f)}">${f.n[0]}</span><b>${f.n}</b><span class="fm">${[0,1,2].map(j=>`<i class="${j<f.k?'on':''}"></i>`).join('')}</span></div>`;
  return `<button class="fhold" id="fhold" aria-label="ながおしで ふって つながる"><span class="cw">${fCrowd(FR.length+1)}</span><svg class="rg" viewBox="0 0 176 176"><circle cx="88" cy="88" r="84" class="t"/><circle cx="88" cy="88" r="84" class="p" id="fhp" pathLength="100"/></svg></button>`}
function fRender(ni){const B=$('frbody');if(!B)return;
  const rows=FR.map((f,i)=>`<button class="frw${f.k>0?' k':''}${POKED.has(i)?' pkd':''}" data-i="${i}"><span class="av" style="background:${avBg(f)}">${f.n[0]}${f.k>0?'<u></u>':''}</span>
      <span class="tx"><b>${f.n}</b></span>
      <span class="fm">${[0,1,2].map(j=>`<i class="${j<f.k?'on':''}"></i>`).join('')}</span>
      ${f.k>0?`<em class="op">${FTM[f.k-1]}</em>`:`<em class="pk2" data-a="poke" aria-label="つつく"><svg viewBox="0 0 24 24"><path d="M9 11V5.5a1.5 1.5 0 013 0V10m0-1.5a1.5 1.5 0 013 0V11m0-1a1.5 1.5 0 013 0v4.5A6.5 6.5 0 0111.5 21h-.6a6 6 0 01-4.6-2.2L3.6 15.4a1.6 1.6 0 012.4-2.1L9 15.5"/></svg></em>`}</button>`).join('');
  B.innerHTML=`<div class="fhero" id="fr0"><i class="rad"></i><svg class="tk" viewBox="0 0 340 340">${Array.from({length:60},(_,i)=>{const a=i*6*Math.PI/180,r1=i%5?163:157,r2=167;return `<line x1="${(170+Math.sin(a)*r1).toFixed(1)}" y1="${(170-Math.cos(a)*r1).toFixed(1)}" x2="${(170+Math.sin(a)*r2).toFixed(1)}" y2="${(170-Math.cos(a)*r2).toFixed(1)}" class="${i%5?'':'h'}"/>`}).join('')}</svg>
      <div class="dial">${fSeats(ni)}</div><div class="fcore" id="fcore">${fCore()}</div></div>
    ${fMeCard()}
    ${FR.length?`<div class="frl">${rows}</div>`:''}
    <div class="fwy"><button data-a="shake" aria-label="ふる"><svg viewBox="0 0 24 24"><rect x="7.5" y="3" width="9" height="18" rx="2.4"/><path d="M3.5 9v6M20.5 9v6"/></svg><b>Shake</b></button>
      <button data-a="qr" class="pr" aria-label="QR"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg><b>QR</b></button>
      <button data-a="link" aria-label="リンク"><svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg><b>Link</b></button></div>`;
  fBind();}
function fBind(){const B=$('frbody');
  B.querySelectorAll('.fs').forEach(s=>s.onclick=e=>{e.stopPropagation();const i=+s.dataset.i;
    if(s.classList.contains('e')){if(FR.length>=999)return;hap('pop','ぷにっ(席に よぶ)');s.animate([{scale:'1'},{scale:'.8'},{scale:'1.12'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(()=>openSheet('shf'),180);return}
    FSEL=FSEL===i?-1:i;hap('sel','コツッ('+FR[i].n+')');fSoft()});
  $('fr0').onclick=e=>{if(e.target.closest('.fs,.fhold'))return;if(FSEL>=0){FSEL=-1;hap('soft',null,{norip:1});fSoft()}};
  B.querySelectorAll('.frw').forEach(r=>r.onclick=e=>{const i=+r.dataset.i;if(e.target.closest('[data-a="poke"]'))return fPoke(i,r);fMenu(i)});
  B.querySelectorAll('.fwy button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;b.animate([{scale:'1'},{scale:'.9'},{scale:'1.04'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(a==='shake'){if(FR.length>=999){hap('warn');_toast('12の 席が うまりました');return}$('fbody').scrollTo({top:0,behavior:'smooth'});hap('buzz','ブルブル(ふる)',{norip:1});const H=$('fr0');setTimeout(()=>{H.classList.add('hold');H.style.setProperty('--hk','1');setTimeout(()=>{H.classList.remove('hold');H.style.setProperty('--hk','0');bumpBurst($('fcore'),()=>askBump())},700)},380)}
    else if(a==='qr'){hap('pop');openSheet('shf')}else{hap('pop');openShare()}});
  fMeBind();
  const h=$('fhold');if(h)fHoldBind(h)}
function fSoft(){const D=document.querySelector('#fr0 .dial'),C=$('fcore');if(!D)return;D.innerHTML=fSeats();C.innerHTML=fCore();C.animate([{opacity:0,transform:'scale(.86)'},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'});fBind()}
function fPoke(i,r){if(POKED.has(i)){hap('warn','やわらかく2回(きょうは もう つついた)');shake(r);return}POKED.add(i);hap('heart','ドクン(つついた)',{norip:1});
  const av=r.querySelector('.av');av.animate([{rotate:'0deg'},{rotate:'-16deg'},{rotate:'14deg'},{rotate:'-6deg'},{rotate:'0deg'}],{duration:520});setTimeout(()=>{fRender();try{arcFriends()}catch(e){}_toast(FR[i].n+' を つついた')},420)}
function fMenu(i){const f=FR[i];hap('sel','コツッ('+f.n+')');
  actSheet(`${f.n} ・ since ${fSince(f)}`,[
    ...(f.k>0?[]:[{l:POKED.has(i)?'つついた(きょうは おわり)':'つつく',fn:()=>{ovClose('acs');setTimeout(()=>{const r=document.querySelector(`.frw[data-i="${i}"]`);r&&fPoke(i,r)},260)}}]),
    {l:'ふたりの グループを つくる',fn:()=>{ovClose('acs');setTimeout(()=>openGnw(),300)}},
    {l:'席で 見る',fn:()=>{ovClose('acs');FSEL=i;fSoft();$('fbody').scrollTo({top:0,behavior:'smooth'})}},
    {l:'ブロックする',red:1,fn:b=>{if(!b.dataset.ok){b.dataset.ok=1;b.querySelector('span').textContent='もういちど おすと ブロック';return}ovClose('acs');setTimeout(()=>{FR.splice(i,1);FSEL=-1;renderFriends();_toast(f.n+' を ブロックしました')},260)}},
    {l:'通報する',red:1,fn:()=>{ovClose('acs');setTimeout(()=>_toast('通報しました。Later が 確認します'),260)}}])}
function fHoldBind(btn){const MS=1500;let t0=0,raf=0,tk=0;const P=$('fhp'),H=$('fr0');
  const set=k=>{P.style.strokeDasharray=(k*100).toFixed(1)+' 100';H.style.setProperty('--hk',k.toFixed(3))};
  const end=()=>{if(!t0)return;cancelAnimationFrame(raf);t0=0;setCont(0);H.classList.remove('hold');const s=performance.now(),from=parseFloat(H.style.getPropertyValue('--hk'))||0;(function b(){const t=Math.min(1,(performance.now()-s)/300);set(from*(1-t));if(t<1)requestAnimationFrame(b)})();hap('soft','やわらかく1回(とまった)')};
  btn.addEventListener('pointerdown',e=>{if(FR.length>=999){hap('warn');_toast('12の 席が うまりました');return}try{btn.setPointerCapture(e.pointerId)}catch(_){}t0=performance.now();tk=0;H.classList.add('hold');hap('pop','ぷにっ(ふりはじめ)',{norip:1});
    const st=now=>{if(!t0)return;const k=Math.min(1,(now-t0)/MS);set(k);setCont(.12+.7*k*k,'だんだん強く(ふる)');const want=Math.floor(Math.pow(k,1.6)*14);while(tk<want){tk++;hap(k>.7?'thud':'tick',null,{norip:1,noq:1})}
      if(k>=1){t0=0;setCont(0);H.classList.remove('hold');set(0);bumpBurst($('fcore'),()=>askBump());return}raf=requestAnimationFrame(st)};raf=requestAnimationFrame(st)});
  ['pointerup','pointercancel'].forEach(ev=>btn.addEventListener(ev,end))}
{const _rf=renderFriends;renderFriends=function(n){_rf(n);FSEL=-1;fRender(n)}}
{const _of=openFriend;openFriend=function(){FSEL=-1;fRender();_of();const F=$('fscr');
  F.querySelectorAll('.fs').forEach((s,i)=>s.animate([{opacity:0,scale:'.3'},{opacity:1,scale:'1'}],{duration:520,delay:200+i*45,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'backwards'}));
  F.querySelectorAll('.fme,.frw,.fwy button').forEach((x,i)=>x.animate([{opacity:0,transform:'translateY(20px)'},{opacity:1,transform:'none'}],{duration:520,delay:500+i*45,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}}
$('fent').onclick=openFriend;
$('fcall').textContent='Add';
fRender();

/* つながった 瞬間:文字なし。2人の キャラが よりそう */
bumpBurst=function(el,after){hap('success','トトトン(つながった)',{norip:1});phone.classList.remove('qk');void phone.offsetWidth;phone.classList.add('qk');
  for(let i=0;i<3;i++){const r=document.createElement('i');r.className='bburst';r.style.borderColor=['#3BD35A','#EE5E9C','#9B8CFF'][i];el.appendChild(r);r.animate([{transform:'scale(.4)',opacity:1},{transform:'scale(5.5)',opacity:0}],{duration:900,delay:i*120,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'}).onfinish=()=>r.remove()}
  const w=document.createElement('div');w.className='bword bw2';w.innerHTML=`<svg viewBox="-60 -50 120 100">${fChar('#61D278',-20,0,1,-8,{up:1})}${fChar('#EE5E9C',20,0,1,8,{wv:1})}<path d="M-6 -36c0-6 8-6 6 0 -2-6 6-6 6 0 0 6-6 9-6 11 0-2-6-5-6-11z" fill="#FF5A7A" stroke="#111" stroke-width="2" transform="translate(0 -4) scale(1.3)"/></svg>`;el.appendChild(w);
  w.animate([{transform:'scale(.3) rotate(-10deg)',opacity:0},{transform:'scale(1.15) rotate(3deg)',opacity:1,offset:.45},{transform:'scale(1) rotate(-2deg)',opacity:1,offset:.8},{transform:'scale(1.05)',opacity:0}],{duration:1100,easing:'cubic-bezier(.3,1.4,.5,1)'}).onfinish=()=>{w.remove();after&&after()};
  setTimeout(()=>hap('pop','ぷにっ',{norip:1}),260)};
fRender();
/* じぶんの チェキ(プロフィール) */
function fMe(){const done=!!OB.name;return{n:OB.name||'ゆい',id:'@'+(OB.name?'you':'yui_0612'),c:OBP[done?OB.col:0],tags:(OB.tags&&OB.tags.length?OB.tags:['#カフェ','#音楽','#夜型']).slice(0,3),img:OB.img}}
function fMeCard(){const m=fMe(),d=new Date(),st=`'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}`;const TC=[['#C8F25A','#111',-8],['#EE5E9C','#fff',6],['#9ED8FF','#111',-4]];
  return `<div class="fme" id="fme"><button class="fmc" id="fmc" aria-label="じぶんの プロフィール ・ タップで QR">
    <span class="fa"><i class="tape"></i><span class="pic" style="${m.img?`background-image:url(${PH[m.img===true?'d':m.img]})`:`background:radial-gradient(circle at 32% 28%,#fff8,transparent 40%),linear-gradient(150deg,${m.c[0]},${m.c[1]})`}">${m.img?'':`<b>${m.n[0]}</b>`}<i class="lk"></i><span class="st">${st}</span></span>
      ${m.tags.map((t,i)=>`<em class="tg" style="--bg:${TC[i][0]};--fg:${TC[i][1]};--r:${TC[i][2]}deg;--i:${i}">${rmEsc(t)}</em>`).join('')}
      <span class="nm">${rmEsc(m.n)}</span><span class="id">${m.id}</span></span>
    <span class="fb"><span class="qr3"></span><span class="id">${m.id}</span></span></button>
    <button class="fed" id="fed" aria-label="プロフィールを なおす"><svg viewBox="0 0 24 24"><path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/></svg></button></div>`}
function fMeBind(){const c=$('fmc');if(!c)return;c.onclick=()=>{c.classList.toggle('fl');hap(c.classList.contains('fl')?'pop':'sel',c.classList.contains('fl')?'ぷにっ(QR)':'コツッ')};
  $('fed').onclick=()=>{hap('pop','ぷにっ(なおす)');openOb();setTimeout(()=>{try{obStep('name')}catch(e){}},500)};
  /* かたむけると 光が うごく */
  c.addEventListener('pointermove',e=>{const r=c.getBoundingClientRect();c.style.setProperty('--mx',((e.clientX-r.left)/r.width*100).toFixed(0)+'%');c.style.setProperty('--ry',(((e.clientX-r.left)/r.width-.5)*10).toFixed(1)+'deg')});
  c.addEventListener('pointerleave',()=>c.style.setProperty('--ry','0deg'))}
/* うしろ:ぼけた チェキが ただよう */
(function(){const F=$('fscr');if(F.querySelector('.fbg'))return;const g=document.createElement('div');g.className='fbg';
  g.innerHTML=`<i class="ph" style="background-image:url(${PH.a})"></i>`+[['b',-30,120,-14,1.1],['e',250,40,12,.9],['c',280,430,-8,1],['f',-40,560,10,.85],['d',120,760,-5,.95]].map(([p,x,y,r,s],i)=>`<i class="ck" style="left:${x}px;top:${y}px;--r:${r}deg;--s:${s};--i:${i}"><u style="background-image:url(${PH[p]})"></u></i>`).join('')+`<i class="vg"></i>`;
  F.insertBefore(g,F.firstChild);$('fbody').addEventListener('scroll',()=>g.style.setProperty('--y',($('fbody').scrollTop*-.25).toFixed(1)+'px'),{passive:true})})();
fRender();