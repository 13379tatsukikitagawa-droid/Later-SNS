
/* ================= v72(PROMPT v76)・ Lattag yesterday:Friends = BeReal ・ Mondo = 壮大 ・ タブ = Apple 標準 ================= */
const Y72={tab:'f',ms:'posted',mo:'closed',sw:{},anim:1,spd:.35};
const Y72I={people:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2"/><path d="M3.5 19c.6-3.2 2.8-5 5.5-5s4.9 1.8 5.5 5"/><circle cx="16.5" cy="9.5" r="2.6"/><path d="M15.5 14.2c2.5.1 4.3 1.7 5 4.8"/></svg>',
  globe:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.4 2.5 3.6 5.3 3.6 8.5s-1.2 6-3.6 8.5c-2.4-2.5-3.6-5.3-3.6-8.5s1.2-6 3.6-8.5z"/></svg>',
  smile:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M8.5 14c.8 1.3 2 2 3.5 2s2.7-.7 3.5-2"/><path d="M9 9.5h.01M15 9.5h.01"/><path d="M19 3v4M17 5h4"/></svg>'};
function y72Lock(){try{return !(shots>0)}catch(e){return true}}
function y72Data(){const P=['a','b','c','d','e','f'],L=(typeof FR!=='undefined'&&FR.length?FR.map(f=>f.n):['れな','あや','そら']);
  const cap=['帰り道の 空、ずっと 見てた','部活 おわった〜','この 自販機 すき','雨の あとの におい','ケーキ 半分こ','席替え した'];
  const pl=['鎌倉市','藤沢市','横浜市','江ノ島','茅ヶ崎市'];
  const TG=['#夕焼け','#帰り道','#自販機','#放課後','#おやつ','#教室'];
  const pub=L.map((n,i)=>({n,av:P[(i+3)%6],pub:true,tg:[0,1,2].map(j=>TG[(i*2+j)%6]),t:`${[17,12,20][i%3]}:${String((i*17)%60).padStart(2,'0')}`,pl:pl[i%5],cap:cap[i%6],ph:[0,1,2].map(j=>P[(i*2+j)%6]),rj:[(i+1)%6,(i+4)%6,(i+2)%6].map(k=>P[k])}));
  const np=[['ひなた','b','席替え した'],['さき','d','ケーキ 半分こ']].map(([n,p,c],i)=>({n,av:P[(i+1)%6],pub:false,t:'',pl:'',cap:c,ph:[p,p,p],tg:[],rj:[]}));
  return pub.concat(np)}
function y72Mount(){const Y=$('yst');if(!Y)return null;Y.classList.add('y72on');let W=Y.querySelector('.y72');if(!W){Y.insertAdjacentHTML('beforeend','<div class="y72"><div class="zsc"></div><nav class="ztb" aria-label="タブ"></nav></div>');W=Y.querySelector('.y72')}return W}
function y72Head(){const D=y72Data(),pub=D.filter(f=>f.pub).length,np=D.length-pub;
  return `<div class="zhd2"><button class="zbl" data-a="nt" aria-label="通知"><svg viewBox="0 0 24 24"><path d="M6 16.5V11a6 6 0 0112 0v5.5l1.5 2H4.5z"/><path d="M10 20.5a2.2 2.2 0 004 0"/></svg><i></i></button>
   <div class="zti"><h1>${Y72.tab==='f'?'Friends':'Mondo'}</h1><small>${Y72.tab==='f'?`きのう ・ ${pub}人が 公開 ・ ${np}人 まだ`:'THE WORLD, YESTERDAY'}</small></div>
   <button class="ztd" data-a="today" aria-label="ダブルタップで 今日へ"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.2"/><circle cx="12" cy="12" r="3.6" class="f"/></svg><span class="tip">2回 タップで 今日へ</span></button></div>`}
function y72Friends(lk){const D=y72Data();
  let h=`<section class="zmy"><div class="zmyr"><button class="zmyp" data-a="mine" aria-label="あなたの きのうを 見る" style="background-image:url(${PH.e})"><span>18:05</span><em>#夕焼け</em></button>
   <button class="zmym" data-a="mine2" aria-label="ほかの 2枚"><i style="background-image:url(${PH.b})"></i><i style="background-image:url(${PH.d})"></i><b>+2</b><small>more</small></button></div>
   <p class="zmyc">キャプションを 追加…</p><div class="zmyb"><button aria-label="送る"><svg viewBox="0 0 24 24"><path d="M21 3L10 14"/><path d="M21 3l-7 18-4-7-7-4z"/></svg></button><button aria-label="タグ"><b>#</b></button><button aria-label="ME に のこす"><svg viewBox="0 0 24 24"><path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/></svg></button></div></section>`;
  if(lk)h+=`<div class="zbn"><div class="tx"><b>今日 1枚 撮ると、きのうが ひらく</b><small>友だちの 写真は ぼかしと ひとこと だけ</small></div><button data-a="shoot">撮る</button></div>`;
  h+=D.map((f,i)=>{const s=Y72.sw[i]||0,m=f.ph[s],sm=f.ph.filter((_,j)=>j!==s);const np=!f.pub;
    return `<article class="zpo${np?' np':''}" data-i="${i}"><div class="zph"><i style="background-image:url(${PH[f.av]})"></i><div class="nm"><b>${f.n}</b><small>${np?'まだ 公開して いません':`${f.pl} ・ きのう ${f.t}`}</small></div><button class="mr" aria-label="メニュー">···</button></div>
     <div class="zpc${lk&&!np?' bl':''}"><i class="mn" style="background-image:url(${PH[m]})"></i>
      <div class="sm">${sm.map((p,j)=>`<button data-sw="${i}" data-p="${f.ph.indexOf(p,j===0?0:f.ph.indexOf(sm[0])+1)}" style="background-image:url(${PH[p]})" aria-label="ほかの 1枚"></button>`).join('')}</div>
      <span class="tm">${f.t}</span><div class="rj">${f.rj.map(p=>`<i style="background-image:url(${PH[p]})"></i>`).join('')}</div><button class="ra" data-a="rj" aria-label="リアクション">${Y72I.smile}</button></div>
     ${np?'':`<div class="ztg">${f.tg.map((t,j)=>`<button class="${j===s?'on':''}" data-sw="${i}" data-p="${j}"><i>#</i>${t.slice(1)}</button>`).join('')}</div>`}<p class="zcp">${f.cap}</p>${np||lk?'':'<p class="zcm">コメントを 追加…</p>'}</article>`}).join('');
  return h}
/* ---- Mondo:地球儀(正射図 ・ 傾き 23°)---- */
const Y72C=[['TOKYO',35.7,139.7],['SEOUL',37.6,127],['BANGKOK',13.8,100.5],['SYDNEY',-33.9,151.2],['PARIS',48.9,2.3],['LONDON',51.5,-.1],['NEW YORK',40.7,-74],['SAO PAULO',-23.5,-46.6],['CAIRO',30,31.2],['MUMBAI',19.1,72.9],['L.A.',34,-118.2],['NAIROBI',-1.3,36.8],['KAMAKURA',35.3,139.5],['MEXICO',19.4,-99.1],['BERLIN',52.5,13.4]];
const Y72T=[['夕焼け',1203,'a','c',2],['帰り道',864,'b','e',0],['放課後',712,'d','f',-1],['おやつ',540,'e','a',3],['雨の日',388,'c','b',-2],['教室',301,'f','d',1],['電車',257,'b','a',0],['自販機',198,'d','c',4]];
function y72Sphere(rot,on,R,cx,cy,nolab){const t=23*Math.PI/180,P=(la,lo)=>{la*=Math.PI/180;const l=(lo-rot)*Math.PI/180;const x=Math.cos(la)*Math.sin(l),y=Math.sin(la)*Math.cos(t)-Math.cos(la)*Math.cos(l)*Math.sin(t),z=Math.sin(la)*Math.sin(t)+Math.cos(la)*Math.cos(l)*Math.cos(t);return[cx+x*R,cy-y*R,z]};
  const line=pts=>{let d='',pen=false;pts.forEach(([x,y,z])=>{if(z>0){d+=(pen?'L':'M')+x.toFixed(1)+' '+y.toFixed(1);pen=true}else pen=false});return d};
  let g='';for(let la=-60;la<=60;la+=30){const pts=[];for(let lo=-180;lo<=180;lo+=6)pts.push(P(la,lo));g+=line(pts)}
  let m='';for(let lo=-180;lo<180;lo+=20){const pts=[];for(let la=-90;la<=90;la+=6)pts.push(P(la,lo));m+=line(pts)}
  let dots='';if(on)Y72C.forEach(([n,la,lo],k)=>{const[x,y,z]=P(la,lo);if(z>.05){const o=Math.min(1,z*1.6);dots+=`<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(9+(k%3)*3)}" fill="#C8F25A" opacity="${(.16*o).toFixed(2)}"/><circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="3.4" fill="#C8F25A" opacity="${o.toFixed(2)}"/>`+(!nolab&&z>.55&&[0,2,4,6,9,7].includes(k)&&R>120?`<text x="${(x+8).toFixed(1)}" y="${(y+3.5).toFixed(1)}" fill="rgba(255,255,255,${(.8*o).toFixed(2)})" style="font:700 9px var(--mono);letter-spacing:.12em">${n}</text>`:'')}});
  return `<circle cx="${cx}" cy="${cy}" r="${R}" fill="url(#y72gl)"/><circle cx="${cx}" cy="${cy}" r="${R}" fill="none" stroke="rgba(200,242,90,.45)" stroke-width="1.2"/><path d="${g}" fill="none" stroke="rgba(59,211,90,.28)" stroke-width=".9"/><path d="${m}" fill="none" stroke="rgba(59,211,90,.22)" stroke-width=".9"/>${dots}`}
const Y72D='<defs><radialGradient id="y72sh" cx=".78" cy=".3" r=".9"><stop offset=".35" stop-color="#000" stop-opacity="0"/><stop offset=".75" stop-color="#000" stop-opacity=".75"/><stop offset="1" stop-color="#000" stop-opacity=".95"/></radialGradient><radialGradient id="y72gl" cx=".38" cy=".32" r=".75"><stop offset="0" stop-color="#173320"/><stop offset=".6" stop-color="#07130b"/><stop offset="1" stop-color="#020403"/></radialGradient><linearGradient id="y72mt" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#2a2b2e"/><stop offset=".45" stop-color="#8d8f94"/><stop offset=".55" stop-color="#cfd1d5"/><stop offset="1" stop-color="#1c1d20"/></linearGradient></defs>';
function y72Spin(){cancelAnimationFrame(Y72.raf);const G=document.querySelector('#yst .y72 [data-sp]');if(!G)return;const k=G.dataset.sp;let last=0;const on=Y72.ms==='posted'&&(Y72.mo==='open'||k==='stage');
  const draw=()=>{const r=Y72.rot||120;if(k==='stage'){y72StageDraw(G,r);return}G.innerHTML=k==='big'?y72Sphere(r,on,160,180,180):k==='night'?y72Sphere(r,false,270,290,290):y72Sphere(r,false,118,180,170)};
  const f=ts=>{if(!document.contains(G)||!$('yst').classList.contains('on'))return;if(ts-last>33){if(!Y72.drag){Y72.rot=((Y72.rot||120)+Y72.spd)%360;if(!Y72.busy)Y72.spd+=(.35-Y72.spd)*.06}draw();last=ts}Y72.raf=requestAnimationFrame(f)};
  draw();if(!matchMedia('(prefers-reduced-motion:reduce)').matches)Y72.raf=requestAnimationFrame(f)}
/* 地球儀を タップ → 速く 回る → 近づいて 光る → Mondo */
function y72Tap(){if(Y72.busy)return;Y72.busy=1;const W=document.querySelector('#yst .y72');const st=W.querySelector('.zst'),gb=W.querySelector('.zdg');const rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
  hap('click','カチッ(地球儀)');if(rm){Y72.mo='open';Y72.anim=0;Y72.busy=0;y72Render();hap('success');return}
  const t0=performance.now();const acc=()=>{const k=Math.min(1,(performance.now()-t0)/900);Y72.spd=.35+k*k*22;if(k<1)requestAnimationFrame(acc)};acc();
  setTimeout(()=>hap('rumble','ゴゴゴ(回る)',{norip:1}),180);
  gb.animate([{transform:'none'},{transform:'scale(1.03)',offset:.3},{transform:'scale(1)'}],{duration:900,easing:'cubic-bezier(.3,1.4,.5,1)'});
  W.querySelector('.zring').animate([{opacity:1,transform:'scale(1)'},{opacity:0,transform:'scale(1.6)'}],{duration:700,fill:'forwards'});
  setTimeout(()=>{gb.animate([{transform:'scale(1)',opacity:1,filter:'blur(0)'},{transform:'scale(2.6)',opacity:0,filter:'blur(6px)'}],{duration:620,easing:'cubic-bezier(.6,0,.3,1)',fill:'forwards'});
    W.querySelector('.zfl').animate([{opacity:0,transform:'scale(.4)'},{opacity:1,transform:'scale(1.2)',offset:.55},{opacity:0,transform:'scale(1.6)'}],{duration:760,easing:'cubic-bezier(.2,.7,.3,1)',fill:'forwards'});
    st.querySelectorAll('.zhint,.zsq').forEach(e=>e.animate([{opacity:1},{opacity:0}],{duration:300,fill:'forwards'}))},900);
  setTimeout(()=>{Y72.mo='open';Y72.spd=.35;Y72.anim=1;Y72.busy=0;y72Render();hap('success','ポン(Mondo)')},1420)}
function y72Stage(){const P=['a','b','c','d','e','f'];
  return `<section class="zst"><i class="stars"></i><div class="zdg" data-a="globe" role="button" aria-label="Mondo を ひらく ・ 指で 地球を まわせます"><svg viewBox="0 0 390 520">${Y72D}<g data-sp="stage"></g></svg>
   ${[0,4,6,2,9,3,7,11,13,8].map((c,i)=>`<i class="pin" data-c="${c}" style="background-image:url(${PH[P[i%6]]})"></i>`).join('')}<i class="zring"></i><i class="zring b"></i></div>
   <button class="zhint" data-a="open" aria-label="Mondo を ひらく"><svg viewBox="0 0 24 24"><path d="M14 4h6v6M20 4l-7 7M10 20H4v-6M4 20l7-7"/></svg></button><i class="zfl"></i></section>`}
/* 舞台の 1コマ:球 + 都市を むすぶ 弧 + 写真の ピン */
function y72StageDraw(G,r){const R=178,cx=195,cy=262,t=23*Math.PI/180;
  const P=(la,lo)=>{la*=Math.PI/180;const l=(lo-r)*Math.PI/180;const x=Math.cos(la)*Math.sin(l),y=Math.sin(la)*Math.cos(t)-Math.cos(la)*Math.cos(l)*Math.sin(t),z=Math.sin(la)*Math.sin(t)+Math.cos(la)*Math.cos(l)*Math.cos(t);return[x,y,z]};
  const S=([x,y],k=1)=>[cx+x*R*k,cy-y*R*k];
  let arcs='';[[0,4],[4,6],[6,7],[0,2],[2,9],[9,8],[8,4],[3,0],[10,6],[11,8]].forEach(([a,b],i)=>{const A=P(Y72C[a][1],Y72C[a][2]),B=P(Y72C[b][1],Y72C[b][2]);if(A[2]<.05||B[2]<.05)return;
    const M=[(A[0]+B[0])/2,(A[1]+B[1])/2],d=Math.hypot(A[0]-B[0],A[1]-B[1]),k=1+d*.35,[x1,y1]=S(A),[x2,y2]=S(B),[mx,my]=S(M,k),o=Math.min(A[2],B[2]);
    arcs+=`<path d="M${x1.toFixed(1)} ${y1.toFixed(1)}Q${mx.toFixed(1)} ${my.toFixed(1)} ${x2.toFixed(1)} ${y2.toFixed(1)}" fill="none" stroke="#C8F25A" stroke-opacity="${(.55*o).toFixed(2)}" stroke-width="1.4" stroke-dasharray="3 5" class="arc"/>`});
  G.innerHTML=y72Sphere(r,true,R,cx,cy,true)+arcs;
  const W=G.closest('.zdg');W&&W.querySelectorAll('.pin').forEach(p=>{const c=Y72C[+p.dataset.c],[x,y,z]=P(c[1],c[2]);const [sx,sy]=S([x,y],1.12);
    p.style.transform=`translate(${(sx-18).toFixed(1)}px,${(sy-42).toFixed(1)}px) scale(${(.55+z*.45).toFixed(2)})`;p.style.opacity=z>.12?Math.min(1,z*1.6).toFixed(2):0;p.style.zIndex=Math.round(z*10)})}
function y72StageBind(W){const O=W.querySelector('.zst [data-a="open"]');O&&(O.onclick=()=>y72Tap());const D=W.querySelector('.zdg');if(!D)return;let x0=0,y0=0,lx=0,lt=0,mv=false,acc=0,v=0;
  D.onpointerdown=e=>{D.setPointerCapture(e.pointerId);x0=lx=e.clientX;y0=e.clientY;lt=performance.now();mv=false;Y72.drag=1;v=0};
  D.onpointermove=e=>{if(!Y72.drag)return;const dx=e.clientX-lx,now=performance.now();if(Math.abs(e.clientX-x0)+Math.abs(e.clientY-y0)>6)mv=true;
    Y72.rot=((Y72.rot||120)-dx*.35+360)%360;acc+=Math.abs(dx*.35);if(acc>18){acc=0;hap('tick',null,{norip:1,gap:40})}v=-dx*.35/Math.max(1,(now-lt)/33);lx=e.clientX;lt=now};
  D.onpointerup=D.onpointercancel=e=>{Y72.drag=0;if(!mv&&e.type==='pointerup')y72Tap();else Y72.spd=Math.max(-14,Math.min(14,v))}}
function y72Mv(m){return m>0?`<span class="mv up">▲${m}</span>`:m<0?`<span class="mv dn">▼${-m}</span>`:'<span class="mv">—</span>'}
function y72Rank(){const mx=Y72T[0][1];const [t0,n0,a0,b0,m0]=Y72T[0];
  return `<section class="zrk"><div class="zrh"><b>きのうの タグ ランキング</b><small>WORLD ・ TOP 8</small></div>
   <button class="zk1" data-tg="${t0}"><i style="background-image:url(${PH[a0]})"></i><i style="background-image:url(${PH[b0]})"></i><u></u>
    <span class="rk">01</span>${y72Mv(m0)}<div class="tx"><b><em>#</em>${t0}</b><small>${n0.toLocaleString('en-US')} 枚 ・ 92 都市 ・ いちばん 撮られた タグ</small></div></button>
   <div class="zk2">${Y72T.slice(1,3).map(([t,n,a,,m],k)=>`<button data-tg="${t}"><i style="background-image:url(${PH[a]})"></i><u></u><span class="rk">0${k+2}</span>${y72Mv(m)}<b><em>#</em>${t}</b><small>${n.toLocaleString('en-US')} 枚</small></button>`).join('')}</div>
   <div class="zk3">${Y72T.slice(3).map(([t,n,a,b2,m],k)=>`<button data-tg="${t}"><span class="rk">0${k+4}</span><span class="th"><i style="background-image:url(${PH[a]})"></i><i style="background-image:url(${PH[b2]})"></i></span><b><em>#</em>${t}</b><span class="bar"><i style="width:${(n/mx*100).toFixed(0)}%"></i></span><small>${n}</small>${y72Mv(m)}</button>`).join('')}</div></section>`}
function y72Explain(){return `<section class="zxp"><div class="zrh"><b>Mondo って?</b><small>SWIPE →</small></div><div class="zxs">
  <div class="zxc"><svg viewBox="0 0 220 120"><rect x="22" y="22" width="44" height="78" rx="9" fill="none" stroke="#fff" stroke-width="2"/><rect x="29" y="32" width="30" height="40" rx="3" fill="#3BD35A" opacity=".85"/><path class="zx1" d="M70 58 Q 115 8 160 52" fill="none" stroke="#C8F25A" stroke-width="2" stroke-dasharray="4 5"/><circle cx="178" cy="62" r="26" fill="#07130b" stroke="#C8F25A" stroke-width="1.6"/><path d="M152 62h52M178 36c10 9 10 43 0 52M178 36c-10 9-10 43 0 52" fill="none" stroke="rgba(59,211,90,.6)" stroke-width="1.2"/><rect class="zx1d" x="-5" y="-5" width="10" height="12" rx="2" fill="#C8F25A"/></svg><b>撮った 1枚が 世界へ</b><small>公開を えらんだ 写真だけ</small></div>
  <div class="zxc"><svg viewBox="0 0 220 120"><path d="M30 96 A 80 80 0 0 1 190 96" fill="none" stroke="rgba(255,255,255,.15)" stroke-width="1.5" stroke-dasharray="3 5"/><circle class="zx2s" cx="110" cy="96" r="10" fill="#C8F25A"/><circle cx="110" cy="62" r="34" fill="#0d0e10" stroke="#fff" stroke-width="2"/><g stroke="#fff" stroke-width="2" stroke-linecap="round"><path d="M110 32v5M110 87v5M80 62h5M135 62h5"/></g><path class="zx2h" d="M110 62 L110 40" stroke="#C8F25A" stroke-width="3" stroke-linecap="round"/><path d="M110 62 L94 62" stroke="#fff" stroke-width="3" stroke-linecap="round"/><circle cx="110" cy="62" r="3" fill="#C8F25A"/></svg><b>次の 朝 9:00 に ひらく</b><small>どの 国も 同じ 9:00</small></div>
  <div class="zxc"><svg viewBox="0 0 220 120"><rect x="46" y="30" width="50" height="66" rx="6" fill="#2a2b2e" transform="rotate(-10 71 63)"/><rect x="124" y="30" width="50" height="66" rx="6" fill="#2a2b2e" transform="rotate(10 149 63)"/><g class="zx3"><rect x="84" y="20" width="52" height="70" rx="6" fill="#3BD35A"/><path d="M96 14l6 8 8-10 8 10 6-8 -3 14h-22z" fill="#C8F25A"/></g></svg><b>TODAY'S ONE</b><small>いちばん 見られた 1枚が 表紙に</small></div>
  <div class="zxc"><svg viewBox="0 0 220 120"><g class="zx4"><rect x="20" y="26" width="70" height="24" rx="12" fill="#C8F25A"/><text x="33" y="43" style="font:900 12px var(--sans)" fill="#0B0C0D"># 夕焼け</text></g><g class="zx4 b"><rect x="110" y="18" width="78" height="24" rx="12" fill="rgba(255,255,255,.12)"/><text x="123" y="35" style="font:800 12px var(--sans)" fill="#fff"># 帰り道</text></g><g class="zx4 c"><rect x="60" y="62" width="74" height="24" rx="12" fill="rgba(255,255,255,.12)"/><text x="73" y="79" style="font:800 12px var(--sans)" fill="#fff"># 放課後</text></g><path d="M160 64v32M174 76v20M188 86v10" stroke="#C8F25A" stroke-width="7" stroke-linecap="round"/></svg><b># で 世界の 気分が わかる</b><small>きのう 多かった タグの ランキング</small></div>
 </div></section>`}
function y72Mondo(lk){
  if(Y72.ms!=='posted')return `<section class="zno2"><i class="stars"></i><div class="zdg nt"><svg viewBox="0 0 580 580">${Y72D}<g data-sp="night"></g><circle cx="290" cy="290" r="271" fill="url(#y72sh)"/></svg></div>
   <div class="tx"><small>MONDO ・ ${new Date(Date.now()-864e5).getMonth()+1}/${new Date(Date.now()-864e5).getDate()}</small><b>No Mondo<br><em>today.</em></b><p>今日の Mondo は ありません</p><span>きのう、世界の だれも 公開しなかった 日。<br>地球は ひと休み して います。</span></div>
   <div class="cdc"><small>次の Mondo まで</small><b id="y72cd">--:--:--</b><i><u id="y72cb"></u></i><div class="bt"><button data-a="shoot">あなたの 1枚で はじめる</button><button class="nf" data-a="nf"><svg viewBox="0 0 24 24"><path d="M6 16.5V11a6 6 0 0112 0v5.5l1.5 2H4.5z"/><path d="M10 20.5a2.2 2.2 0 004 0"/></svg><span>9:00 に 知らせる</span></button></div></div></section>`;
  if(Y72.mo!=='open')return y72Stage();
  const W=[['b','PARIS','08:14','帰り道'],['c','SEOUL','19:02','放課後'],['d','L.A.','12:30','おやつ'],['e','NAIROBI','16:48','夕焼け'],['f','BERLIN','21:05','雨の日'],['a','SAO PAULO','07:40','帰り道'],['a','KAMAKURA','17:42','夕焼け'],['c','TOKYO','18:20','夕焼け']].filter(x=>!Y72.ft||x[3]===Y72.ft);
  return `<section class="zmh"><div class="gl"><svg viewBox="0 0 360 360">${Y72D}<g data-sp="big"></g></svg></div>
   <div class="ct"><div><b data-n="2431">2,431</b>SHOTS</div><div><b data-n="128">128</b>CITIES</div><div><b>9:00</b>OPENS</div></div></section>`+y72Rank()+y72Explain()+
   `<div class="zt1"><i class="mn" style="background-image:url(${PH.a});${lk?'filter:blur(26px) brightness(.6);transform:scale(1.2)':''}"></i><i class="sh"></i><div class="tp">TODAY'S ONE ・ 9:00</div><div class="bt"><b>鎌倉市</b><small>${lk?'今日 1枚 撮ると ひらく':'JAPAN ・ 17:42 ・ #夕焼け'}</small></div></div>
    <div class="zgh" id="y72grid"><b>${Y72.ft?`<span class="ftg">#${Y72.ft}<button data-a="ftx" aria-label="もどす">×</button></span>`:'世界の きのう'}</b><small>${W.length} PHOTOS</small></div><div class="zgr${lk?' bl':''}">${W.map(([p,c,t,g])=>`<i style="background-image:url(${PH[p]})"><u>#${g}</u><em>${c}<small>${t}</small></em></i>`).join('')}</div>`}
function y72Intro(W){if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;const H=W.querySelector('.zmh');if(!H)return;
  
  H.querySelectorAll('.wm span').forEach((s,i)=>s.animate([{opacity:0,transform:'translateY(46px) scale(.9)',filter:'blur(10px)'},{opacity:1,transform:'none',filter:'blur(0)'}],{duration:820,delay:60+i*70,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}));
  H.querySelector('.gl').animate([{opacity:0,transform:'scale(1.9)',filter:'blur(8px)'},{opacity:1,transform:'none',filter:'blur(0)'}],{duration:1000,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'});
  H.querySelector('.ct').animate([{opacity:0,transform:'translateY(12px)'},{opacity:1,transform:'none'}],{duration:600,delay:800,easing:'cubic-bezier(.3,1,.4,1)',fill:'backwards'});
  H.querySelectorAll('.ct b[data-n]').forEach(b=>{const n=+b.dataset.n;if(!n)return;const t0=performance.now()+800;const f=t=>{const k=Math.max(0,Math.min(1,(t-t0)/1100)),v=Math.round(n*(1-Math.pow(1-k,3)));b.textContent=v.toLocaleString('en-US');if(k<1)requestAnimationFrame(f)};requestAnimationFrame(f)});
  W.querySelectorAll('.zrk .zk1,.zrk .zk2 button,.zrk .zk3 button').forEach((r,i)=>{r.animate([{opacity:0,transform:'translateX(-18px)'},{opacity:1,transform:'none'}],{duration:520,delay:1000+i*80,easing:'cubic-bezier(.3,1.1,.4,1)',fill:'backwards'});const b=r.querySelector('.bar i');b&&b.animate([{transform:'scaleX(0)'},{transform:'scaleX(1)'}],{duration:700,delay:1100+i*80,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'})});
  [0,1,2,3].forEach(i=>setTimeout(()=>hap('tick',null,{norip:1}),1000+i*80))}
const Y72N=[['a','あや','あなたの <b>#夕焼け</b> に リアクション','2分'],['c','れな','コメント「この 空 すき」','14分'],['b','ひなた','友だち申請が とどきました','1時間'],[null,'Lattag','きのうの 3枚が ひらきました','9:00'],[null,'Mondo','<b>#夕焼け</b> が 世界 1位に','9:00'],['d','そら','あなたの <b>#帰り道</b> に リアクション','きのう']];
function y72Notif(on){const W=document.querySelector('#yst .y72');if(!W)return;let P=W.querySelector('.znp');
  if(!P){W.insertAdjacentHTML('beforeend','<div class="znp" aria-hidden="true"><div class="zns"><div class="znh"><b>通知</b><button data-a="ntx" aria-label="とじる">×</button></div><div class="znl"></div></div></div>');P=W.querySelector('.znp');
    P.onclick=e=>{if(e.target===P||e.target.closest('[data-a="ntx"]'))y72Notif(false)}}
  if(on){P.querySelector('.znl').innerHTML=Y72N.map(([p,n,t,tm],i)=>`<div class="zni${i<3?' nw':''}">${p?`<i style="background-image:url(${PH[p]})"></i>`:`<i class="ic">${n==='Mondo'?Y72I.globe:'#'}</i>`}<p><b>${n}</b> ${t}<small>${tm}</small></p>${n==='ひなた'?'<button>承認</button>':''}</div>`).join('');
    P.classList.add('on');hap('pop','ぷにっ(通知)');const b=W.querySelector('.zbl i');b&&(b.style.display='none');
    if(!matchMedia('(prefers-reduced-motion:reduce)').matches)P.querySelectorAll('.zni').forEach((r,i)=>r.animate([{opacity:0,transform:'translateY(-10px)'},{opacity:1,transform:'none'}],{duration:380,delay:120+i*50,easing:'cubic-bezier(.3,1.1,.4,1)',fill:'backwards'}))}
  else{P.classList.remove('on');hap('soft',null,{norip:1})}}
function y72Mine(on,k){const W=document.querySelector('#yst .y72');if(!W)return;let V=W.querySelector('.zmv');
  if(!V){W.insertAdjacentHTML('beforeend','<div class="zmv" aria-hidden="true"></div>');V=W.querySelector('.zmv')}
  if(!on){V.classList.remove('on');hap('soft',null,{norip:1});return}
  const M=[['b','9:12','#帰り道'],['d','13:40','#放課後'],['e','18:05','#夕焼け']];Y72.mk=k==null?(Y72.mk||0):k;const [p,t,g]=M[Y72.mk];
  V.innerHTML=`<div class="zmvh"><button data-a="mx" aria-label="とじる">×</button><div><b>あなたの きのう</b><small>${Y72.mk+1} / 3 ・ ${t}</small></div><button aria-label="メニュー">···</button></div>
   <div class="zmvp" style="background-image:url(${PH[p]})"><button class="l" data-a="mp" aria-label="前"></button><button class="r" data-a="mn" aria-label="次"></button><div class="zmvd">${M.map((_,j)=>`<i class="${j===Y72.mk?'on':''}"></i>`).join('')}</div></div>
   <div class="ztg">${M.map(([,,g],j)=>`<button class="${j===Y72.mk?'on':''}" data-mk="${j}"><i>#</i>${g.slice(1)}</button>`).join('')}</div>
   <p class="zcp">キャプションを 追加…</p><div class="zmvr"><span>リアクション</span>${['a','c','f'].map(p=>`<i style="background-image:url(${PH[p]})"></i>`).join('')}<b>3</b></div>`;
  V.classList.add('on');
  V.querySelector('[data-a="mx"]').onclick=()=>y72Mine(false);
  V.querySelector('[data-a="mp"]').onclick=()=>{y72Mine(true,(Y72.mk+2)%3);hap('tick',null,{norip:1})};
  V.querySelector('[data-a="mn"]').onclick=()=>{y72Mine(true,(Y72.mk+1)%3);hap('tick',null,{norip:1})};
  V.querySelectorAll('[data-mk]').forEach(b=>b.onclick=()=>{y72Mine(true,+b.dataset.mk);hap('pop')})}
function y72Render(){const W=y72Mount();if(!W)return;const lk=y72Lock();
  W.querySelector('.zsc').innerHTML=y72Head()+(Y72.tab==='f'?y72Friends(lk):y72Mondo(lk));
  W.querySelector('.ztb').innerHTML=`<button data-t="f" class="${Y72.tab==='f'?'on':''}">${Y72I.people}Friends</button><button data-t="m" class="${Y72.tab==='m'?'on':''}">${Y72I.globe}Mondo</button>`;
  y72Bind(W);y72StageBind(W);y72Cd();y72Shrink(W);if(Y72.tab==='m'){y72Spin();if(Y72.mo==='open'&&Y72.anim)y72Intro(W)}Y72.anim=0}
function y72Shrink(W){const S=W.querySelector('.zsc'),H=W.querySelector('.zhd2');if(!S||!H)return;const f=()=>{const on=S.scrollTop>24;if(on!==H.classList.contains('cp')){H.classList.toggle('cp',on);hap('tick',null,{norip:1,gap:300})}};H.classList.toggle('cp',S.scrollTop>24);if(!S._y72s){S._y72s=1;S.addEventListener('scroll',()=>{const h=W.querySelector('.zhd2');if(!h)return;const on=S.scrollTop>24;if(on!==h.classList.contains('cp')){h.classList.toggle('cp',on);hap('tick',null,{norip:1,gap:300})}},{passive:true})}}
function y72Cd(){clearInterval(Y72.ct);const T=$('y72cd');if(!T)return;const f=()=>{const n=new Date(),t=new Date(n);t.setHours(9,0,0,0);if(t<=n)t.setDate(t.getDate()+1);const d=Math.floor((t-n)/1000),h=Math.floor(d/3600),m=Math.floor(d%3600/60),s2=d%60;if(!document.contains(T)){clearInterval(Y72.ct);return}T.innerHTML=`${h}:${String(m).padStart(2,'0')}<em>:${String(s2).padStart(2,'0')}</em>`;const B=$('y72cb');B&&(B.style.width=(100-d/864).toFixed(1)+'%')};f();Y72.ct=setInterval(f,1000)}
function y72Bind(W){W.querySelectorAll('.ztb button').forEach(b=>b.onclick=()=>{if(Y72.tab===b.dataset.t)return;Y72.tab=b.dataset.t;Y72.anim=1;y72Render();W.querySelector('.zsc').scrollTop=0;hap('sel','カチ(タブ)')});
  const ds=W.querySelector('[data-a="today"]');if(ds){let lt=0;ds.onclick=()=>{const n=performance.now();if(n-lt<380){lt=0;cancelAnimationFrame(Y72.raf);hap('pop','ぷにっ(今日へ)');try{closeY($('dsw'))}catch(e){closeY()}}else{lt=n;hap('tick',null,{norip:1});ds.classList.remove('hint');void ds.offsetWidth;ds.classList.add('hint')}}}
  W.querySelectorAll('[data-sw]').forEach(b=>b.onclick=()=>{const i=+b.dataset.sw,p=+b.dataset.p;Y72.sw[i]=p;y72Render();hap('pop','ぷにっ(入れかえ)')});
  const nt=W.querySelector('[data-a="nt"]');nt&&(nt.onclick=()=>y72Notif(true));const mi=W.querySelector('[data-a="mine"]');mi&&(mi.onclick=()=>{hap('pop','ぷにっ(あなたの きのう)');y72Mine(true,2)});const m2=W.querySelector('[data-a="mine2"]');m2&&(m2.onclick=()=>{hap('pop');y72Mine(true,0)});
  W.querySelectorAll('.zmyb button').forEach(b=>b.onclick=()=>hap('pop'));
  W.querySelectorAll('[data-tg]').forEach(b=>b.onclick=()=>{Y72.ft=b.dataset.tg;Y72.anim=0;y72Render();hap('pop','ぷにっ(タグ)');const g=$('y72grid');g&&g.scrollIntoView({behavior:'smooth',block:'start'})});
  const fx=W.querySelector('[data-a="ftx"]');fx&&(fx.onclick=()=>{Y72.ft=null;Y72.anim=0;y72Render();hap('soft')});
  
  const nf=W.querySelector('[data-a="nf"]');nf&&(nf.onclick=()=>{nf.classList.toggle('on');nf.querySelector('span').textContent=nf.classList.contains('on')?'知らせます ✓':'9:00 に 知らせる';hap(nf.classList.contains('on')?'success':'soft')});
  W.querySelectorAll('[data-a="rj"]').forEach(b=>b.onclick=()=>hap('pop','ぷにっ(リアクション)'));
  W.querySelectorAll('[data-a="shoot"]').forEach(b=>b.onclick=()=>{hap('pop');cancelAnimationFrame(Y72.raf);try{closeY()}catch(e){}setTimeout(()=>{try{window.__api.goShoot()}catch(e){}},420)})}
renderYAll=function(){try{Y72.anim=Y72.tab==='m';y72Render()}catch(e){console.error(e)}};
Object.assign(window.__kit||(window.__kit={}),{y72Tap:()=>y72Tap(),y72Notif:o=>y72Notif(o!==false),y72Mine:k=>y72Mine(true,k||0),y72:(o={})=>{if(o.tab)Y72.tab=o.tab;if(o.ms)Y72.ms=o.ms;if(o.mo)Y72.mo=o.mo;if('ft' in o)Y72.ft=o.ft;if(o.sw)Y72.sw=o.sw;Y72.anim=o.anim!==undefined?o.anim:0;y72Render();const s=document.querySelector('#yst .y72 .zsc');if(s&&o.top!=null)s.scrollTop=o.top}});

/* モック だけ:Lattag yesterday ・ Mondo を 動かす ボタン */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-y72]'))return;
  C.insertAdjacentHTML('beforeend',[['y','きのう を ひらく'],['mp','Mondo:投稿 あり'],['me','Mondo:投稿 なし'],['mg','Mondo:地球に もどす'],['fr','Friends へ']].map(([k,t])=>`<button data-y72="${k}">${t}</button>`).join(''));
  C.querySelectorAll('[data-y72]').forEach(b=>b.onclick=()=>{const k=b.dataset.y72,Y=$('yst'),op=Y&&Y.classList.contains('on');
    const go=o=>{if(!op){try{openY()}catch(e){}setTimeout(()=>__kit.y72(o),700)}else __kit.y72(o)};
    if(k==='y'){if(!op)try{openY()}catch(e){}}
    if(k==='mp')go({tab:'m',ms:'posted',mo:'closed',top:0});
    if(k==='me')go({tab:'m',ms:'empty',top:0});
    if(k==='mg')go({tab:'m',mo:'closed',top:0});
    if(k==='fr')go({tab:'f',top:0})})})();
