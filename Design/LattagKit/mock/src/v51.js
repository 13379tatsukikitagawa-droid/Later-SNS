/* ================= v51 プロフィール(右上の まるを 1回 タップ) ================= */
var PF={on:false,st:[]};
const PFT=[['#C8F25A','#111'],['#EE5E9C','#fff'],['#9ED8FF','#111'],['#FFD60A','#111'],['#9B8CFF','#fff'],['#61D278','#111']];
const PFP=[[-128,-118,-9,1.08],[118,-100,8,1],[-136,40,6,1],[132,58,-7,1.05],[-96,168,-4,.92],[104,178,10,.9]];
function pfTags(){const m=fMe();const rec=['#夕焼け','#放課後','#帰り道'].filter(t=>!m.tags.includes(t));return [...m.tags.map(t=>({t,me:1})),...rec.slice(0,6-m.tags.length).map(t=>({t,me:0}))]}
function pfYear(){/* 1年の ★(52週 × 7日)*/let h='';const N=52*7;for(let i=0;i<N;i++){const age=N-1-i;const on=age<44&&((i*37)%11===0||(i*13)%9===0);const lv=on?(age<7?3:age<30?2:1):0;h+=`<i class="l${lv}"></i>`}return h}
function openPrf(from){if(PF.on)return;PF.on=true;const P=$('prf'),m=fMe(),tg=pfTags(),d=new Date();P.classList.toggle('dk',true);
  const stp2=`'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}`;const MEK2=['c','a','e','b','f','d','a'];
  P.innerHTML=`<div class="pbg"><i class="g" style="background:linear-gradient(160deg,${m.c[0]},${m.c[1]})"></i>${['b','e','c','f'].map((p,i)=>`<i class="ck" style="--i:${i};background-image:url(${PH[p]})"></i>`).join('')}<i class="vg"></i></div>
   <div class="phd"><button class="pbk" id="pfx" aria-label="とじる"><svg viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg></button><span class="pid">${m.id}</span><button class="pbk" id="pfset" aria-label="設定"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/></svg></button></div>
   <div class="pbd" id="pbd">
    <div class="phero" id="phero">
      ${tg.map((x,i)=>{const [X,Y,R,S]=PFP[i],c=PFT[i];return `<button class="pst${x.me?' me':''}" data-i="${i}" style="--x:${X}px;--y:${Y}px;--r:${R}deg;--s:${S};--bg:${c[0]};--fg:${c[1]};--d:${i}">${rmEsc(x.t)}</button>`}).join('')}
      <button class="pck" id="pck" aria-label="じぶんの チェキ ・ タップで QR"><span class="fa"><i class="tape"></i><span class="pic" style="${m.img?`background-image:url(${PH[m.img===true?'d':m.img]})`:`background:radial-gradient(circle at 30% 26%,#fff9,transparent 42%),linear-gradient(150deg,${m.c[0]},${m.c[1]})`}">${m.img?'':`<b>${rmEsc(m.n[0])}</b>`}<i class="lk"></i><span class="st">${stp2}</span></span><span class="nm">${rmEsc(m.n)}</span><i class="gl"></i></span>
        <span class="fb"><span class="qr3"></span><b>${m.id}</b><small>SCAN TO ADD</small></span></button>
    </div>
    <div class="pnm"><b>${rmEsc(m.n)}</b><span class="mood">since <em>Oct 2026</em></span></div>
    <div class="pstat"><button data-a="streak"><b>${shots?12:11}</b><span>day streak</span></button><button data-a="shots"><b>${48+shots}</b><span>shots</span></button><button data-a="kept"><b>9</b><span>kept</span></button></div>
    <div class="pact">
      <button data-a="qr" class="pr"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg><b>QR</b></button>
      <button data-a="edit"><svg viewBox="0 0 24 24"><path d="M4 20h4L19 9l-4-4L4 16z"/><path d="M13 7l4 4"/></svg><b>Edit</b></button>
      <button data-a="share"><svg viewBox="0 0 24 24"><path d="M12 15V4M7 9l5-5 5 5M5 14v6h14v-6"/></svg><b>Share</b></button>
      <button data-a="scan"><svg viewBox="0 0 24 24"><path d="M4 8V5a1 1 0 011-1h3M16 4h3a1 1 0 011 1v3M20 16v3a1 1 0 01-1 1h-3M8 20H5a1 1 0 01-1-1v-3M4 12h16"/></svg><b>Scan</b></button></div>
    <button class="pme" id="pme"><span class="pmk">ME · 7 DAYS</span><span class="pmf">${MEK2.map((p,i)=>`<i style="background-image:url(${PH[p]});--i:${i}"></i>`).join('')}</span><span class="go">Recap<svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z"/></svg></span></button>
    <div class="pyr"><div class="pyh"><span>1 YEAR · KEPT</span><em>9 KEPT</em></div><div class="pyg">${pfYear()}</div></div>
    <div class="pset" id="psetl">
      <button data-a="nt"><span>通知</span><em id="pnt">オン</em></button>
      <button data-a="lang"><span>言語 / Language</span><em>日本語</em></button>
      <button data-a="blk"><span>ブロックした 人</span><em>0</em></button>
      <button data-a="help"><span>ヘルプ ・ 利用規約</span><em>›</em></button>
      <button data-a="out" class="red"><span>ログアウト</span></button></div>
   </div>`;
  P.classList.add('on');P.setAttribute('aria-hidden','false');
  if(from){const o=yOrigin(from);P.animate([{clipPath:`circle(0px at ${o.x}px ${o.y}px)`},{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`}],{duration:680,easing:'cubic-bezier(.3,.85,.25,1)'});ringBurst(o)}
  hap('pop','ぷにっ(プロフィール)');
  const C=$('pck');C.animate([{transform:'translateY(-260px) rotate(-18deg)',opacity:0},{transform:'translateY(14px) rotate(1deg)',opacity:1,offset:.6},{transform:'none'}],{duration:820,delay:120,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'});
  setTimeout(()=>hap('land','トン(チェキが おちる)',{norip:1}),560);
  P.querySelectorAll('.pst').forEach((s,i)=>{s.animate([{scale:'0',opacity:0},{scale:'1.25',opacity:1,offset:.6},{scale:'1'}],{duration:520,delay:700+i*110,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'});setTimeout(()=>hap('tick','ペタッ(シール)',{norip:1}),700+i*110)});
  P.querySelectorAll('.pnm,.pstat,.pact button,.pme,.pyr,.pset').forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:560,delay:420+i*50,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
  pfBind()}
function closePrf(){if(!PF.on)return;PF.on=false;const P=$('prf');const o=yOrigin(HAV);
  P.animate([{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`},{clipPath:`circle(0px at ${o.x}px ${o.y}px)`}],{duration:460,easing:'cubic-bezier(.5,0,.7,.3)',fill:'forwards'}).onfinish=()=>{P.classList.remove('on');P.setAttribute('aria-hidden','true');P.getAnimations().forEach(a=>a.cancel());P.innerHTML=''};hap('soft','ふわっ(とじる)')}
function pfBind(){const P=$('prf'),C=$('pck'),H=$('phero');
  $('pfx').onclick=closePrf;
  /* チェキ:タップ = うらがえして QR / 長押し = シールが はじけて もどる / なぞると かたむく */
  let t0=0,lt=0;C.addEventListener('pointerdown',()=>{t0=performance.now();lt=setTimeout(()=>{lt=0;if(!PF.edit)pfBurst()},480)});
  C.addEventListener('pointerup',()=>{if(PF.edit){clearTimeout(lt);lt=0;return}if(lt){clearTimeout(lt);lt=0;C.classList.toggle('fl');hap(C.classList.contains('fl')?'pop':'sel',C.classList.contains('fl')?'ぷにっ(QR)':'コツッ')}});
  C.addEventListener('pointerleave',()=>{clearTimeout(lt);lt=0;C.style.setProperty('--rx','0deg');C.style.setProperty('--ry','0deg')});
  H.addEventListener('pointermove',e=>{const r=H.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;C.style.setProperty('--ry',(x*16).toFixed(1)+'deg');C.style.setProperty('--rx',(-y*12).toFixed(1)+'deg');C.style.setProperty('--gx',((x+.5)*100).toFixed(0)+'%');
    P.querySelectorAll('.pst').forEach((s,i)=>{s.style.translate=`${(x*(10+i*3)).toFixed(1)}px ${(y*(8+i*2)).toFixed(1)}px`})});
  /* シール:タップで ぷるん、ドラッグで 動かせる */
  P.querySelectorAll('.pst').forEach(s=>{let sx=0,sy=0,ox=0,oy=0,dr=false,mv=false;
    s.addEventListener('pointerdown',e=>{e.stopPropagation();dr=true;mv=false;sx=e.clientX;sy=e.clientY;ox=parseFloat(s.dataset.ox||0);oy=parseFloat(s.dataset.oy||0);try{s.setPointerCapture(e.pointerId)}catch(_){}s.classList.add('dg')});
    s.addEventListener('pointermove',e=>{if(!dr)return;const dx=(e.clientX-sx)/SC,dy=(e.clientY-sy)/SC;if(Math.abs(dx)+Math.abs(dy)>4){if(!mv)hap('soft','ペリッ(はがす)',{norip:1});mv=true}s.dataset.ox=ox+dx;s.dataset.oy=oy+dy;s.style.setProperty('--ox',(ox+dx)+'px');s.style.setProperty('--oy',(oy+dy)+'px')});
    s.addEventListener('pointerup',()=>{dr=false;s.classList.remove('dg');if(mv){hap('tick','ペタッ(はる)',{norip:1});return}hap('pop','ぷにっ('+s.textContent+')');s.animate([{scale:'1'},{scale:'1.3',rotate:'8deg'},{scale:'.92',rotate:'-4deg'},{scale:'1',rotate:'0deg'}],{duration:480,easing:'cubic-bezier(.3,1.6,.4,1)'})})});
  P.querySelectorAll('.pstat button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;hap('pop');b.animate([{scale:'1'},{scale:'.92'},{scale:'1'}],{duration:260});
    if(a==='fr'){closePrf();setTimeout(openFriend,420)}else if(a==='shots'||a==='kept'){closePrf();setTimeout(openMe,420)}else{const f=P.querySelector('.pyr');$('pbd').scrollTo({top:f.offsetTop-140,behavior:'smooth'});setTimeout(()=>f.animate([{boxShadow:'0 0 0 0 rgba(59,211,90,0)'},{boxShadow:'0 0 0 3px rgba(59,211,90,.9)'},{boxShadow:'0 0 0 0 rgba(59,211,90,0)'}],{duration:900}),500)}});
  P.querySelectorAll('.pact button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;b.animate([{scale:'1'},{scale:'.88'},{scale:'1.05'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(a==='qr'){hap('pop','ぷにっ(QR)');if(!C.classList.contains('fl'))C.classList.add('fl');$('pbd').scrollTo({top:0,behavior:'smooth'})}
    else if(a==='edit'){pfEdit(true)}
    else if(a==='share'){hap('pop');const m=fMe();openShare({t:`Lattag で つながろう ・ ${m.n}(${m.id})\nhttps://lattag.app/u/${m.id.slice(1)}`,h:m.n})}
    else{hap('pop');openScan('fr')}});
  $('pme').onclick=()=>{hap('pop','ぷにっ(ME)');closePrf();setTimeout(openMe,420)};
  P.querySelectorAll('.pyg i.l1,.pyg i.l2,.pyg i.l3').forEach(i=>i.onclick=()=>{hap('tick');i.animate([{scale:'1'},{scale:'2.4'},{scale:'1'}],{duration:360});_toast('★ この日の 1枚 ・ 端末に 1年 のこる')});
  $('pfset').onclick=()=>{hap('sel');$('pbd').scrollTo({top:$('psetl').offsetTop-140,behavior:'smooth'})};
  P.querySelectorAll('.pset button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;
    if(a==='nt'){const e=$('pnt');e.textContent=e.textContent==='オン'?'オフ':'オン';hap('click','カチッ')}
    else if(a==='lang')actSheet('言語 / Language',[{l:'日本語',r:'✓',fn:()=>ovClose('acs')},{l:'English',fn:()=>{ovClose('acs');_toast('iOS の 設定 > Lattag > 言語 を ひらく(モック)')}}]);
    else if(a==='blk')actSheet('ブロックした 人',[{l:'まだ いません',fn:()=>ovClose('acs')}]);
    else if(a==='help')actSheet('ヘルプ',[{l:'使いかた',fn:()=>ovClose('acs')},{l:'利用規約',fn:()=>ovClose('acs')},{l:'プライバシー',fn:()=>ovClose('acs')},{l:'問い合わせ',fn:()=>ovClose('acs')}]);
    else actSheet('ログアウトしますか?',[{l:'ログアウト',red:1,fn:()=>{ovClose('acs');_toast('(モック)ログアウトしました')}}])})}
function pfBurst(){const P=$('prf');hap('rumble','ブルブル(シールが はじける)',{norip:1});$('pck').animate([{transform:'rotate(-2deg)'},{transform:'rotate(3deg) scale(1.04)'},{transform:'rotate(-2deg)'}],{duration:300,iterations:2});
  P.querySelectorAll('.pst').forEach((s,i)=>{const a=Math.atan2(PFP[i][1],PFP[i][0]);s.animate([{transform:`translate(-50%,-50%) translate(var(--x),var(--y)) rotate(var(--r))`},{transform:`translate(-50%,-50%) translate(calc(var(--x) + ${(Math.cos(a)*160).toFixed(0)}px),calc(var(--y) + ${(Math.sin(a)*160).toFixed(0)}px)) rotate(${i%2?200:-200}deg)`,offset:.45},{transform:`translate(-50%,-50%) translate(var(--x),var(--y)) rotate(var(--r))`}],{duration:1100,delay:i*40,easing:'cubic-bezier(.3,1.25,.4,1)'});setTimeout(()=>hap('tick',null,{norip:1}),600+i*70)})}
/* 入口:右上の まるを 1回 タップ(2回 = きのうへ は そのまま) */
{const _t2=toast;toast=function(m){if(m==='ダブルタップで 昨日へ')return openPrf(HAV);return _t2(m)}}
{const _ca=closeAll;closeAll=function(){if(PF.on)closePrf();if(ME&&ME.on)closeMe();_ca()}}
