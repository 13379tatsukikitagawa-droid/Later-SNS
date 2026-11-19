/* ===== v89(モック v91 ・ PROMPT v99) =====
   はじめて ひらいた 時の 説明(Friends ・ Trip ・ Mondo)
   ・ 1つの 説明 = 4つの 場面(1つ 3.6秒 ・ 自動で 進む ・ 最後は 止まる)
   ・ 文字は 場面ごとに 1行 だけ。あとは 動きで 見せる
   ・ 右タップ = つぎ ・ 左タップ = もどる ・ 長押し = 一時停止 ・ 下へ スワイプ / スキップ = とじる
   ・ ページの 番号の 横の 「?」で もう一度 見られる */
const Z9={on:null,i:0,seen:{friends:0,trip:0,mondo:0},T:[],t0:0,left:0,then:null,tipd:0};const Z9D=3600;
const Z9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const Z9I={friends:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2"/><path d="M3.5 19c.6-3.2 2.8-5 5.5-5s4.9 1.8 5.5 5"/><circle cx="16.5" cy="9" r="2.6"/><path d="M15.5 14.2c2.6-.3 4.6 1.3 5 4.3"/></svg>',
  trip:'<svg viewBox="0 0 24 24"><rect x="4" y="7.5" width="16" height="12" rx="2.5"/><path d="M9 7.5V5.5a1.5 1.5 0 011.5-1.5h3A1.5 1.5 0 0115 5.5v2M4 12.5h16"/></svg>',
  mondo:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.4 3.8 5.2 3.8 8.5s-1.2 6.1-3.8 8.5c-2.6-2.4-3.8-5.2-3.8-8.5S9.4 5.9 12 3.5z"/></svg>',
  skip:'<svg viewBox="0 0 24 24"><path d="M6 6l7 6-7 6M14 6v12"/></svg>',redo:'<svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1 0 2.4-5.7"/><path d="M4 4v4.5h4.5"/></svg>',
  go:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',q:'<svg viewBox="0 0 24 24"><path d="M9.2 9.3a2.9 2.9 0 115 2c-.9.8-2.2 1.4-2.2 2.9"/><circle cx="12" cy="17.6" r=".6" fill="currentColor"/></svg>',
  srch:'<svg viewBox="0 0 24 24"><circle cx="10.5" cy="10.5" r="6"/><path d="M15 15l5 5"/></svg>',plus:'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  heart:'<svg viewBox="0 0 24 24"><path d="M12 20s-7.5-4.6-7.5-10.2A4.3 4.3 0 0112 7.3a4.3 4.3 0 017.5 2.5C19.5 15.4 12 20 12 20z"/></svg>',
  lock:'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9.5" rx="2.5"/><path class="sk" d="M8 11V8a4 4 0 018 0v3"/></svg>'};
/* 見本の 人(本番は 実データ)*/
const Z9F=[{n:'ゆい',g:['#fff7c2','#FFD60A','#2A8E3E']},{n:'れな',g:['#d9f2ff','#7fb0ff','#9C86FF']},{n:'そら',g:['#e6fff4','#6FCB8C','#0BB52D']},{n:'みお',g:['#ffe0ef','#F7A7CB','#D8619C']},{n:'かい',g:['#e8e6ff','#A792E2','#6B57A6']}];
const z9Av=(f,x,y,s,cls,st)=>`<i class="av ${cls||''}" style="left:${x-s/2}px;top:${y-s/2}px;width:${s}px;height:${s}px;font-size:${Math.round(s*.36)}px;${f.me?`background-image:url(${PH.f})`:`background:${avBg(f)}`};${st||''}">${f.me?'':f.n[0]}</i>`;
const z9Ck=(k,x,y,w,st,cls)=>`<span class="ck ${cls||''}" style="left:${x}px;top:${y}px;width:${w}px;${st||''}"><i style="background-image:url(${PH[k]})"></i></span>`;
const z9Icon=()=>`<svg viewBox="0 0 100 100"><rect x="19" y="31" width="62" height="10" rx="5"/><rect x="19" y="59" width="62" height="10" rx="5"/><rect x="31" y="19" width="10" height="62" rx="5"/><rect x="59" y="19" width="10" height="62" rx="5"/></svg>`;

/* ---------- 場面(html と、時間ごとの バイブ ・ 動き)---------- */
const Z9S={
friends:{t:'Friends',cta:'友だちを さがす',go:()=>{try{openAdd()}catch(e){}},sc:[
 {k:'SHOOT',c:'友だちも、1日 3枚',h:()=>{const P=[[70,112,0,'b'],[322,126,1,'d'],[96,352,2,'e'],[300,350,3,'a']];
   return `<i class="zorb"></i><i class="zorb o2"></i>${z9Av({me:1},195,226,88,'me z9pop')}<div class="fx" style="left:151px;top:182px;width:88px;height:88px;--d:2.3s"><i class="fl"></i>${z9Ck('f',22,-4,44,'','out')}</div>
   ${P.map(([x,y,j,k],n)=>`<div class="fx" style="left:${x-29}px;top:${y-29}px;--d:${(.55+n*.5).toFixed(2)}s">${z9Av(Z9F[j],29,29,58,'z9pop',`animation-delay:${.1+n*.08}s`)}<i class="fl"></i>${z9Ck(k,7,0,44,'','out')}</div>`).join('')}`},
  fx:[[550,'tick'],[1050,'tick'],[1550,'tick'],[2050,'tick'],[2300,'shutter']]},
 {k:'SLEEP',c:'夜は、ひみつ',nt:1,h:()=>`<i class="sky"></i><i class="moon"></i>
   <div class="clk"><span><b>23:59</b><b>0:00</b></span></div>
   <div class="zstk">${['b','d','e'].map((k,j)=>`<div class="c3" style="--j:${j};--r:${(j-1)*7}deg;--x0:${[-120,125,-95][j]}px;--y0:${[-110,-95,120][j]}px"><div class="in"><span class="zfr">${z9Ck(k,0,0,112,'position:relative')}</span><span class="bk"><b>#</b></span></div></div>`).join('')}</div>`,
  fx:[[300,'soft'],[1350,'click'],[1500,'click'],[1650,'click'],[2400,'soft']]},
 {k:'OPEN',c:'9:00 に、みんなで ひらく',h:()=>`<div class="hz"><i class="sun"></i></div><i class="nine">9:00</i>
   <div class="zfan">${['b','d','e'].map((k,j)=>`<div class="c3" style="--j:${j};--r:${(j-1)*13}deg;--x:${(j-1)*104}px;--y:${j===1?-14:6}px"><div class="in"><span class="zfr">${z9Ck(k,0,0,104,'position:relative','dv')}</span><span class="bk"><b>#</b></span></div></div>`).join('')}</div>
   <i class="ht" style="left:94px;--d:2.35s">${Z9I.heart}</i><i class="ht" style="left:250px;--d:2.65s">${Z9I.heart}</i><i class="ht sm" style="left:196px;--d:2.9s">${Z9I.heart}</i>`,
  fx:[[700,'success'],[1350,'pop'],[1500,'pop'],[1650,'pop'],[2400,'heart']]},
 {k:'CONNECT',c:'@ID で つながる',h:()=>`<div class="srch">${Z9I.srch}<span class="ty">@yui_k</span><i class="cr"></i></div>
   <div class="res">${z9Av(Z9F[0],48,42,52)}<span><b>ゆい</b><small>@yui_k</small></span><i class="zadd"><em class="p">${Z9I.plus}</em><em class="o">${Z9I.ok}</em></i></div>
   <svg class="ln" viewBox="0 0 390 440"><path d="M74 210 C 70 290, 190 270, 195 352"/></svg>${z9Av({me:1},195,382,72,'me z9pop')}<i class="pl" style="left:159px;top:346px"></i>`,
  fx:[[250,'tick'],[370,'tick'],[490,'tick'],[610,'tick'],[730,'tick'],[850,'tick'],[1150,'pop'],[2000,'click'],[2700,'success']]}]},
trip:{t:'Trip',cta:'Trip を つくる',go:()=>{try{openTrip()}catch(e){}},sc:[
 {k:'PRINT',c:'旅の パスを つくる',h:()=>`<div class="slot"><i class="lt"></i></div><div class="zwin"><div class="pass">
   <div class="top" style="background-image:url(${PH.c})"><i class="zsh"></i><small>LATTAG ・ TRIP PASS</small><b>Kyoto</b><span class="avs">${[{me:1},Z9F[0],Z9F[1],Z9F[2]].map(f=>`<i style="${f.me?`background-image:url(${PH.f})`:`background:${avBg(f)}`}"></i>`).join('')}</span></div>
   <div class="perf"></div><div class="bt"><div class="qw">${p9Qr('meadow95','c')}</div><span class="ky">KEY<b>#meadow<em>95</em></b></span><i class="stub"></i></div></div><i class="zstamp">ISSUED</i></div>`,
  fx:[[0,'projector'],[220,'tick'],[440,'tick'],[660,'tick'],[880,'tick'],[1100,'tick'],[2150,'thud'],[2500,'success']]},
 {k:'BOARD',c:'リンクで、なかまを のせる',h:()=>{const seat=(c,r)=>[87+c*50+(c>1?20:0)+23,150+r*58+23];
   return `<div class="bub"><i style="background-image:url(${PH.c})"></i><span><em>TRIP PASS</em><b>lattag.app/t/…</b></span></div>
   <div class="seats"><span class="nose">FRONT</span>${[0,1].map(r=>[0,1,2,3].map(c=>{const [x,y]=seat(c,r),j=r*4+c,on=j<6;return `<i class="se${on?' fill':''}" style="left:${x-23}px;top:${y-23}px;--d:${j===0?0:(.5+j*.34).toFixed(2)}s"><b>${String.fromCharCode(65+c)}${r+1}</b></i>`}).join('')).join('')}</div>
   ${z9Av({me:1},seat(0,0)[0],seat(0,0)[1],40,'z9pop')}
   ${[1,2,3,4,5].map(j=>{const [x,y]=seat(j%4,j>3?1:0),f=Z9F[j-1];return `<div class="zfly" style="--dx:${x-112}px;--dy:${y-62}px;--d:${(.5+j*.34-.42).toFixed(2)}s"><div class="fy">${z9Av(f,112,62,40)}</div></div>`}).join('')}
   <span class="zcnt"><b id="z9cnt">1</b> / 8</span>`},
  fx:[[150,'pop'],[920,'pop',()=>z9Cnt(2)],[1260,'pop',()=>z9Cnt(3)],[1600,'pop',()=>z9Cnt(4)],[1940,'pop',()=>z9Cnt(5)],[2280,'pop',()=>z9Cnt(6)],[2600,'success']]},
 {k:'SHARE',c:'1日 23枚を、みんなで',h:()=>{const fr=k=>12+k*64;
   return `<div class="row">${[{me:1},...Z9F.slice(0,4)].map((f,j)=>z9Av(f,75+j*60,30,42,'z9pop',`animation-delay:${j*.06}s`)).join('')}</div>
   <b class="big" id="z9big">23</b><small class="bigs">LEFT TODAY</small>
   <div class="film">${[0,1,2,3,4,5].map(k=>`<i class="zfs" style="left:${fr(k)}px"></i>`).join('')}
    ${[0,1,2,3,4,5].map(k=>{const sx=75+(k%5)*60,fx=fr(k)+(-14)+28;return `<div class="drop" style="left:${fr(k)}px;--dx:${sx-fx}px;--d:${(.45+k*.4).toFixed(2)}s"><span class="ck" style="left:0;top:0;width:56px"><i style="background-image:url(${PH['bdeacf'[k]]})"></i></span></div>`}).join('')}</div>`},
  fx:[[900,'tick',()=>z9Big(22)],[1300,'tick',()=>z9Big(21)],[1700,'tick',()=>z9Big(20)],[2100,'tick',()=>z9Big(19)],[2500,'tick',()=>z9Big(18)],[2900,'tick',()=>z9Big(17)]]},
 {k:'DEVELOP',c:'あした 9:00 に、まとめて 現像',h:()=>`<div class="hz t4"><i class="sun"></i></div><i class="nine">AM 9:00</i>
   <div class="grid">${[0,1,2,3,4,5,6,7,8].map(k=>{const r=Math.floor(k/3),c=k%3,dd=Math.hypot(r-1,c-1);return `<i class="tl" style="--d:${(1+dd*.32).toFixed(2)}s"><b>#</b><em style="background-image:url(${PH['abcdefabc'[k]]})"></em></i>`}).join('')}<i class="day">DAY 1</i></div>`,
  fx:[[200,'soft'],[1000,'land'],[1350,'tick'],[1500,'tick'],[2450,'thud'],[2600,'success']]}]},
mondo:{t:'Mondo',cta:()=>shots?'Mondo を ひらく':'まず 1枚 撮る',go:()=>{if(shots){try{ORB.A.mondo.run()}catch(e){}}else{try{hpGo(0)}catch(e){}}},sc:[
 {k:'LOOK',c:'世界の きのうを のぞく',h:()=>{const P=[[150,150,'TOKYO','b'],[248,128,'OSLO','d'],[272,236,'CAIRO','e'],[132,262,'LIMA','a'],[206,312,'SYDNEY','c']];
   return `<i class="zring"></i><div class="gl"><i class="dots"></i><i class="shd"></i></div><i class="zring r2"></i>
   ${P.map(([x,y,c,k],j)=>`<div class="zpin" style="left:${x}px;top:${y}px;--d:${(.6+j*.42).toFixed(2)}s"><i class="pd"></i>${z9Ck(k,-20,-66,40,'','up')}<small>${c}</small></div>`).join('')}`},
  fx:[[0,'rumble'],[600,'tick'],[1020,'tick'],[1440,'tick'],[1860,'tick'],[2280,'tick']]},
 {k:'MATCH',c:'同じ # で、世界と つながる',h:()=>{const N=6,cx=195,cy=214,R=148;
   return `<svg class="sp" viewBox="0 0 390 440">${[...Array(N)].map((_,j)=>{const a=-Math.PI/2+j*2*Math.PI/N;return `<path style="--d:${(.55+j*.22).toFixed(2)}s" d="M${cx} ${cy}L${(cx+Math.cos(a)*R).toFixed(1)} ${(cy+Math.sin(a)*R*.86).toFixed(1)}"/>`}).join('')}</svg>
   ${[...Array(N)].map((_,j)=>{const a=-Math.PI/2+j*2*Math.PI/N,x=cx+Math.cos(a)*R,y=cy+Math.sin(a)*R*.86;return `<div class="ph" style="left:${(x-30).toFixed(1)}px;top:${(y-36).toFixed(1)}px;--fx:${(Math.cos(a)*170).toFixed(0)}px;--fy:${(Math.sin(a)*170).toFixed(0)}px;--d:${(.45+j*.22).toFixed(2)}s;--r:${[-6,5,-4,7,-5,4][j]}deg">${z9Ck('abcdef'[j],0,0,60,'position:relative')}<small>${['TOKYO','PARIS','LIMA','SEOUL','CAIRO','OSLO'][j]}</small></div>`}).join('')}
   <i class="tag">#夕焼け</i>`},
  fx:[[150,'pop'],[450,'tick'],[670,'tick'],[890,'tick'],[1110,'tick'],[1330,'tick'],[1550,'tick'],[2100,'success']]},
 {k:'RANK',c:'きのうの 人気 TOP 5',h:()=>`<div class="rk">${[['#夕焼け',.86,'a'],['#放課後',.7,'b'],['#帰り道',.52,'d'],['#朝ごはん',.38,'e'],['#海',.26,'c']].map(([t,w,k],j)=>`<div class="r r${j}" style="top:${j*74}px;--w:${w};--d:${(.15+j*.08).toFixed(2)}s"><b class="n">0${j+1}</b><i class="cv" style="background-image:url(${PH[k]})"></i><span class="t">${t}</span><i class="bar"></i><em class="v" id="z9v${j}">0</em></div>`).join('')}</div>`,
  fx:[[200,'tick',()=>z9Count()],[1900,'pop',()=>z9Swap()],[2300,'success']]},
 {k:'UNLOCK',c:'1枚 撮ると、ひらく',h:()=>`<div class="g4">${['a','b','d','e'].map((k,j)=>`<i style="--d:${(2.05+j*.1).toFixed(2)}s"><b style="background-image:url(${PH[k]})"></b></i>`).join('')}<span class="lk">${Z9I.lock}</span></div>
   <div class="zsh"><span class="ic0">${z9Icon()}</span><span class="ic1">${z9Icon()}</span></div><i class="flash"></i>`,
  fx:[[400,'rumble'],[1700,'shutter'],[2000,'success']]}]}};
function z9Cnt(n){const e=$('z9cnt');if(!e)return;e.textContent=n;!Z9RM()&&e.animate([{transform:'translateY(-8px)',opacity:0},{transform:'none',opacity:1}],{duration:260,easing:'cubic-bezier(.3,1.5,.5,1)'})}
function z9Big(n){const e=$('z9big');if(!e)return;e.textContent=n;!Z9RM()&&e.animate([{transform:'translateY(-14px) scale(1.08)',opacity:.3},{transform:'none',opacity:1}],{duration:300,easing:'cubic-bezier(.3,1.5,.5,1)'})}
function z9Count(){const V=[2481,2210,1530,1104,760],t0=performance.now(),D=1500;const f=now=>{if(!Z9.on)return;const p=Math.min(1,(now-t0)/D),e=1-Math.pow(1-p,3);V.forEach((v,j)=>{const x=$('z9v'+j);x&&(x.textContent=Math.round(v*e*(j===1?1.18:1)).toLocaleString())});if(p<1)Z9.raf=requestAnimationFrame(f)};Z9.raf=requestAnimationFrame(f)}
function z9Swap(){const a=document.querySelector('.z9 .rk .r0'),b=document.querySelector('.z9 .rk .r1');if(!a||!b)return;a.classList.add('dn');b.classList.add('up');a.querySelector('.n').textContent='02';b.querySelector('.n').textContent='01'}

/* ---------- 開く ・ 進む ・ 閉じる ---------- */
function z9Open(k,o){o=o||{};const D=Z9S[k];if(!D)return;Z9.seen[k]=1;Z9.on=k;Z9.started=0;Z9.i=o.i||0;Z9.then=o.then||null;let S=$('z9');
  if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="z9" id="z9" aria-modal="true" role="dialog"></section>');S=$('z9')}
  S.className='z9 z9-'+k;S.setAttribute('aria-label',D.t+' の 説明');
  S.innerHTML=`<div class="z9bar">${D.sc.map(()=>'<i><b></b></i>').join('')}</div>
   <div class="z9top"><span class="z9tg"><i class="ic">${Z9I[k]}</i><b>${D.t}</b></span><button class="z9skip" data-a="skip" aria-label="スキップ"><span>スキップ${Z9I.skip}</span></button></div>
   <div class="z9st"></div><div class="z9cap" aria-live="polite"></div>
   <div class="z9ft"><i class="z9tp" aria-hidden="true"><b></b></i><button class="z9go" data-a="go"><span></span>${Z9I.go}</button><button class="z9re" data-a="redo">${Z9I.redo}<span>もう一度</span></button></div>
   <i class="z9tap l" data-a="prev"></i><i class="z9tap r" data-a="next"></i>${o.i||Z9RM()?'':`<b class="z9ttl">${D.t}</b>`}`;
  S.classList.add('on');hap('soft','ふわっ(説明)',{norip:1});z9Bind(S);
  if(o.i||Z9RM())z9Go(Z9.i);else{Z9.T.push(setTimeout(()=>z9Go(0),720))}}
function z9Clear(){Z9.T.forEach(clearTimeout);Z9.T=[];cancelAnimationFrame(Z9.raf)}
function z9Go(i){const k=Z9.on,D=Z9S[k];if(!D)return;z9Clear();i=Math.max(0,Math.min(D.sc.length-1,i));Z9.i=i;Z9.started=1;const S=$('z9'),sc=D.sc[i],last=i===D.sc.length-1;
  S.classList.toggle('last',last);S.classList.toggle('nt',!!sc.nt);S.classList.remove('pz');
  S.querySelectorAll('.z9bar i').forEach((b,j)=>{b.className=j<i?'dn':j===i?'on':''});
  const st=S.querySelector('.z9st');st.innerHTML=`<div class="z9sc ${k[0]}${i+1}">${sc.h()}</div>`;
  S.querySelector('.z9cap').innerHTML=`<small>${sc.k}</small><b>${sc.c}</b>`;
  S.querySelector('.z9go span').textContent=typeof D.cta==='function'?D.cta():D.cta;S.querySelector('.z9skip span').firstChild.textContent=last?'とじる':'スキップ';
  Z9.t0=performance.now();Z9.left=Z9D;(sc.fx||[]).forEach(([ms,h,f])=>Z9.T.push(setTimeout(()=>{if(Z9.on!==k||Z9.i!==i)return;h&&hap(h,null,{norip:1});f&&f()},Z9RM()?0:ms)));
  if(!last)Z9.T.push(setTimeout(()=>z9Go(i+1),Z9D));else Z9.T.push(setTimeout(()=>hap('success',null,{norip:1}),Z9RM()?0:400))}
function z9Pause(p){const S=$('z9');if(!S||!Z9.on||!Z9.started)return;if(p){if(S.classList.contains('pz'))return;S.classList.add('pz');Z9.left=Math.max(0,Z9D-(performance.now()-Z9.t0));Z9.T.forEach(clearTimeout);Z9.T=[]}
  else{if(!S.classList.contains('pz'))return;S.classList.remove('pz');const i=Z9.i,D=Z9S[Z9.on];Z9.t0=performance.now()-(Z9D-Z9.left);if(i<D.sc.length-1)Z9.T.push(setTimeout(()=>z9Go(i+1),Z9.left))}}
function z9Close(go){const S=$('z9'),k=Z9.on;if(!S||!k)return;z9Clear();Z9.on=null;S.classList.remove('on');hap('soft',null,{norip:1});const then=Z9.then;Z9.then=null;
  setTimeout(()=>{if(go)Z9S[k].go();else if(then)then();else z9Tip(k)},280)}
function z9Tip(k){const b=document.querySelector(`.z9q[data-k="${k}"]`);if(!b)return;!Z9RM()&&b.animate([{transform:'scale(1)'},{transform:'scale(1.35)'},{transform:'scale(1)'},{transform:'scale(1.2)'},{transform:'scale(1)'}],{duration:900,easing:'ease-in-out'});
  if(!Z9.tipd){Z9.tipd=1;try{_toast('? を おすと、もう一度 見られます')}catch(e){}}}
function z9Bind(S){let pd=null;
  S.querySelector('[data-a="skip"]').onclick=e=>{e.stopPropagation();z9Close(false)};
  S.querySelector('[data-a="go"]').onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(はじめる)');z9Close(true)};
  S.querySelector('[data-a="redo"]').onclick=e=>{e.stopPropagation();hap('sel');z9Go(0)};
  S.querySelectorAll('.z9tap').forEach(t=>{
    t.onpointerdown=e=>{pd={x:e.clientX,y:e.clientY,t:performance.now(),hold:0};pd.tm=setTimeout(()=>{pd&&(pd.hold=1);z9Pause(true)},240)};
    t.onpointerup=e=>{if(!pd)return;clearTimeout(pd.tm);const dy=e.clientY-pd.y,h=pd.hold;pd=null;
      if(dy>80){z9Close(false);return}if(h){z9Pause(false);return}hap('sel',null,{norip:1});t.dataset.a==='next'?(Z9.i<Z9S[Z9.on].sc.length-1&&z9Go(Z9.i+1)):z9Go(Z9.i-1)};
    t.onpointercancel=t.onpointerleave=()=>{if(pd){clearTimeout(pd.tm);if(pd.hold)z9Pause(false);pd=null}}})}

/* ---------- はじめて ページに 来た 時 ---------- */
const Z9P={1:'friends',2:'trip',3:'mondo'};
function z9Busy(){return !!(Z9.on||$('j9tl')||cur!=='home')}
{const _g=hpGo;hpGo=function(i,v){_g(i,v);const k=Z9P[HPG.i];if(!k||Z9.seen[k])return;const at=HPG.i;setTimeout(()=>{if(HPG.i===at&&!Z9.seen[k]&&!z9Busy())z9Open(k)},620)}}
{const _f=openFriend;openFriend=function(){if(!Z9.seen.friends&&!z9Busy()&&cur==='home'){z9Open('friends',{then:()=>_f.apply(this,arguments)});return}return _f.apply(this,arguments)};window.openFriend=openFriend}
{const _t=openTrip;openTrip=function(edit){if(!edit&&!Z9.seen.trip&&!z9Busy()){z9Open('trip',{then:()=>_t(edit)});return}return _t.apply(this,arguments)};if(window.openTrip)window.openTrip=openTrip}
/* ページの 番号の 横に 「?」(もう一度 見る)*/
function z9QBtns(){[[1,'friends','.nb'],[2,'trip','.mono'],[3,'mondo','.nb']].forEach(([i,k,s])=>{const C=$('hpc'+i);if(!C||C.querySelector('.z9q'))return;const L=C.querySelector(s);if(!L)return;
  L.insertAdjacentHTML('beforeend',`<button class="z9q" data-k="${k}" aria-label="${Z9S[k].t} の 説明を 見る">${Z9I.q}</button>`);
  C.querySelector('.z9q').onclick=e=>{e.stopPropagation();hap('sel');z9Open(k)};C.querySelector('.z9q').addEventListener('pointerdown',e=>e.stopPropagation())})}
{const _hr=hpRender;hpRender=function(only){_hr(only);try{z9QBtns()}catch(e){console.error(e)}};window.hpRender=hpRender}
setTimeout(()=>{try{z9QBtns()}catch(e){}},400);
/* デモボタン */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-z9]'))return;C.insertAdjacentHTML('beforeend','<button data-z9="friends">説明 Friends</button><button data-z9="trip">説明 Trip</button><button data-z9="mondo">説明 Mondo</button><button data-z9="reset">説明 リセット</button>');
  C.querySelectorAll('[data-z9]').forEach(b=>b.onclick=()=>{const k=b.dataset.z9;if(k==='reset'){Z9.seen={friends:0,trip:0,mondo:0};Z9.tipd=0;toast('(モック)説明を 未読に もどしました');return}z9Open(k)})})();
window.__kit=Object.assign(window.__kit||{},{z9Open:(k,i)=>z9Open(k,{i:i||0}),z9Go:i=>z9Go(i),z9Pause:p=>z9Pause(p),z9Close:g=>z9Close(g),z9Reset:()=>{Z9.seen={friends:0,trip:0,mondo:0};Z9.tipd=0},Z9:()=>Z9});
