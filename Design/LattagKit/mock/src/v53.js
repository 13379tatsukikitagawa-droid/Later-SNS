/* ================= v53 カメラの 4つの ボタン:まわせる ダイヤル + ひらく カード =================
   ・4つの ボタンは レンズの まわりの「レール」に のっている。指で まわすと 90°ごとに カチッと とまる
   ・右下(親指の いちばん 近く)= READY の 席。そこに 来た ボタンは 大きく なって 中身の 数字が 出る
   ・1回 押す = その ボタンから カードが ひらく(中身の プレビュー + 大きな GO)
   ・ながおし → そのまま GO まで すべらせて はなす = 1動作で ひらく
   ・カードを 左右に はらう = ダイヤルが まわって となりの ボタンの カードへ
   ・ボタンを つかんで まわしても、レールの 上を なぞっても ダイヤルが まわる */
const DLB=[225,315,135,45];            // 4つの 席(左上・右上・左下・右下)。角度は 画面の 時計まわり
const DLR={a:158,b:168};               // レール(角が まるい 四角)の 半径
const DLT={shoot:'Shoot',yday:'Yesterday',dev:'Develop',chat:'Chat',group:'Trip',mondo:'Mondo',friends:'Friends',join:'Join'};
const DLG={shoot:'Shoot',yday:'Open',dev:'Develop',chat:'Chat',group:'New trip',mondo:'Explore',friends:'Friends',join:'Join'};
var DL={phi:0,keys:[],cx:195,cy:300,open:null,drag:null,raf:0,v:0,hint:true,dealt:false,pos:{},spark:0,lastT:0,lastD:0};
const dlRad=d=>d*Math.PI/180;
const dlNorm=d=>((d%360)+360)%360;
function dlPos(th){const t=dlRad(th),c=Math.cos(t),s=Math.sin(t);
  return[DLR.a*Math.sign(c)*Math.pow(Math.abs(c),.5),DLR.b*Math.sign(s)*Math.pow(Math.abs(s),.5)]}
function dlRail(a,b,n=96){let d='';for(let i=0;i<=n;i++){const t=i/n*Math.PI*2,c=Math.cos(t),s=Math.sin(t);
  d+=(i?'L':'M')+(a*Math.sign(c)*Math.pow(Math.abs(c),.5)).toFixed(1)+' '+(b*Math.sign(s)*Math.pow(Math.abs(s),.5)).toFixed(1)}return d+'Z'}
function dlMeasure(){const O=$('orb'),L=$('lens');if(!O||!L)return;const o=O.getBoundingClientRect(),l=L.getBoundingClientRect();
  if(o.width<10||l.width<10)return;DL.cx=(l.left+l.width/2-o.left)/SC;DL.cy=(l.top+l.height/2-o.top)/SC;
  const X=$('odx');if(X){X.style.left=DL.cx+'px';X.style.top=DL.cy+'px'}}

/* ---------- つくる ---------- */
function dlBuild(){const O=$('orb');if(!O||!ORB)return;let X=$('odx');
  if(!X){X=document.createElement('div');X.className='odx';X.id='odx';O.appendChild(X);
    X.innerHTML=`<i class="odsc" id="odsc"></i><svg class="odr" id="odr" viewBox="-230 -250 460 500" aria-hidden="true">
      <path class="hit" id="odhit" d="${dlRail(DLR.a+58,DLR.b+60,72)} M100 0 A100 100 0 1 0 -100 0 A100 100 0 1 0 100 0Z" fill-rule="evenodd"/>
      <path class="rail" d="${dlRail(DLR.a,DLR.b)}"/>
      ${DLB.map(a=>{const[x,y]=dlPos(a);return `<circle class="slot" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="38"/>`}).join('')}
      <circle class="spk" id="odspk" r="3.2" cx="0" cy="0"/></svg>
      <span class="odhint" id="odhint"><svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 0 1 14-5.3M20 12a8 8 0 0 1-14 5.3"/><path d="M18 3v4h-4M6 21v-4h4"/></svg>TURN</span>
      <div class="odbs" id="odbs"></div>`;
    dlBindDial()}
  dlMeasure();
  const keys=ORB.sat.slice(0,4),same=keys.join()===DL.keys.join();DL.keys=keys;
  if(!same){if(DL.open)dlClose(true);
    $('odbs').innerHTML=keys.map((k,i)=>`<button class="odb" data-k="${k}" data-i="${i}" aria-label="${ORB.A[k].l}"><span class="w"><i>${OI[k]}<u></u></i><span class="lb"><b></b><small></small></span></span></button>`).join('');
    $('odbs').querySelectorAll('.odb').forEach(dlBindBtn)}
  $('odbs').querySelectorAll('.odb').forEach(b=>{const a=ORB.A[b.dataset.k];b.classList.toggle('lk',!!a.lock);b.classList.toggle('dot',!!a.dot);
    b.querySelector('.lb b').textContent=a.l;b.querySelector('.lb small').textContent=a.s});
  dlLayout();
  if(!DL.dealt&&O.getBoundingClientRect().width>10){DL.dealt=true;setTimeout(dlDeal,250)}}

/* ---------- ならべる(毎フレーム) ---------- */
function dlLayout(){const bs=document.querySelectorAll('#odbs .odb');bs.forEach(b=>{const i=+b.dataset.i,th=DLB[i]+DL.phi,[x,y]=dlPos(th);
    const w=Math.pow(Math.max(0,Math.cos(dlRad(th-45))),10),s=1+.2*w;DL.pos[b.dataset.k]=[x,y,th];
    b.style.transform=`translate(${x.toFixed(2)}px,${y.toFixed(2)}px) scale(${s.toFixed(3)})`;b.classList.toggle('rdy',w>.82);b.style.zIndex=b.classList.contains('sel')?9:Math.round(3+w*2)});
  const r=$('ring');if(r)r.style.rotate=DL.phi.toFixed(2)+'deg';
  const ls=document.querySelector('#lens .lnsc');if(ls)ls.style.rotate=(-DL.phi).toFixed(2)+'deg'}
function dlSet(p){DL.phi=p;dlLayout();
  const t=Math.floor(p/15),d=Math.round(p/90);
  if(t!==DL.lastT){DL.lastT=t;if(d===DL.lastD)hap('tick',null,{norip:1,gap:28})}
  if(d!==DL.lastD){DL.lastD=d;hap('click','カチッ(ダイヤル)',{norip:1})}
  if(DL.hint&&Math.abs(p)>20){DL.hint=false;const h=$('odhint');h&&h.classList.add('off')}}

/* ---------- ばね(まわしたあと 90°に とまる) ---------- */
function dlSpring(target,v0,done){cancelAnimationFrame(DL.raf);let x=DL.phi,v=v0||0,last=performance.now();
  const k=.00062,c=.032;
  const step=now=>{let dt=Math.min(32,now-last);last=now;
    for(let s=0;s<dt;s+=4){const a=-k*(x-target)-c*v;v+=a*4;x+=v*4}
    if(Math.abs(x-target)<.06&&Math.abs(v)<.003){DL.phi=target;dlLayout();DL.raf=0;done&&done();return}
    DL.phi=x;dlLayout();const d=Math.round(x/90);if(d!==DL.lastD){DL.lastD=d;hap('click',null,{norip:1})}DL.raf=requestAnimationFrame(step)};
  DL.raf=requestAnimationFrame(step)}
function dlSnap(v){const tgt=Math.round((DL.phi+(v||0)*170)/90)*90;
  dlSpring(tgt,v,()=>{hap('soft','トン(はまった)',{norip:1});DL.phi=dlNorm(tgt)%360;DL.lastD=Math.round(DL.phi/90);DL.lastT=Math.floor(DL.phi/15);dlLayout();if(DL.open)dlRefreshCard()})}

/* ---------- まわす(レールの 上 / ボタンを つかんで) ---------- */
function dlPt(e){const o=$('orb').getBoundingClientRect();return[(e.clientX-o.left)/SC-DL.cx,(e.clientY-o.top)/SC-DL.cy]}
function dlAng(p){return Math.atan2(p[1],p[0])*180/Math.PI}
function dlDragStart(e,from){cancelAnimationFrame(DL.raf);const p=dlPt(e);DL.drag={a:dlAng(p),phi0:DL.phi,acc:0,hist:[[performance.now(),DL.phi]],from};
  $('odx').classList.add('turn');hap('sel','コツッ(つかんだ)',{norip:1})}
function dlDragMove(e){const D=DL.drag;if(!D)return;const a=dlAng(dlPt(e));let da=a-D.a;if(da>180)da-=360;if(da<-180)da+=360;D.a=a;D.acc+=da;
  dlSet(D.phi0+D.acc);const now=performance.now();D.hist.push([now,DL.phi]);while(D.hist.length>2&&now-D.hist[0][0]>90)D.hist.shift()}
function dlDragEnd(){const D=DL.drag;if(!D)return;DL.drag=null;$('odx').classList.remove('turn');
  const h=D.hist,f=h[0],l=h[h.length-1],v=l[0]-f[0]>8?(l[1]-f[1])/(l[0]-f[0]):0;
  dlSnap(Math.max(-1.6,Math.min(1.6,v)))}
function dlBindDial(){const H=$('odhit');
  H.addEventListener('pointerdown',e=>{if(DL.open)return;e.stopPropagation();H.setPointerCapture(e.pointerId);dlDragStart(e,'rail')});
  H.addEventListener('pointermove',dlDragMove);H.addEventListener('pointerup',dlDragEnd);H.addEventListener('pointercancel',dlDragEnd);
  $('odsc').addEventListener('click',e=>{e.stopPropagation();dlClose()})}

/* ---------- ボタン:タップ = ひらく / ながおし→すべらせて GO / つかんで まわす ---------- */
function dlBindBtn(b){let st=null;
  b.addEventListener('pointerdown',e=>{e.stopPropagation();b.setPointerCapture(e.pointerId);b.classList.add('dn');hap('click','カチッ(おした)',{norip:1});
    st={x:e.clientX,y:e.clientY,held:false,mv:false,t:setTimeout(()=>{if(!st||st.mv)return;st.held=true;b.classList.remove('dn');dlOpen(b.dataset.k,{held:true})},360)}});
  b.addEventListener('pointermove',e=>{if(!st)return;if(st.mv){dlDragMove(e);if(st.held)dlHoverGo(e);return}
    if(st.held){dlHoverGo(e);return}
    if(Math.hypot(e.clientX-st.x,e.clientY-st.y)/SC>9&&!DL.open){st.mv=true;clearTimeout(st.t);b.classList.remove('dn');dlDragStart(e,'btn')}});
  const end=e=>{if(!st)return;clearTimeout(st.t);b.classList.remove('dn');const s=st;st=null;
    if(s.mv){dlDragEnd();return}
    if(s.held){const el=document.elementFromPoint(e.clientX,e.clientY);dlHoverGo(null);if(el&&el.closest('.odgo'))dlGo();return}
    if(e.type==='pointercancel')return;
    const k=b.dataset.k;if(DL.open===k)dlGo();else dlOpen(k)};
  b.addEventListener('pointerup',end);b.addEventListener('pointercancel',end);
  b.addEventListener('click',e=>e.stopPropagation())}
function dlHoverGo(e){const g=document.querySelector('#odx .odgo');if(!g)return;let on=false;
  if(e){const el=document.elementFromPoint(e.clientX,e.clientY);on=!!(el&&el.closest('.odgo'))}
  if(on!==g.classList.contains('hv')){g.classList.toggle('hv',on);if(on)hap('sel','コツッ(GO の 上)',{norip:1})}}

/* ---------- カードの 中身 ---------- */
function dlBody(k){const a=ORB.A[k],lk=!!a.lock;
  if(k==='shoot')return `<div class="odfm">${[0,1,2].map(j=>`<i class="${j<shots?'u':''}"><s></s></i>`).join('')}</div><div class="odbig">${3-shots}<small>left</small></div>`;
  if(k==='yday')return `<div class="odfan${lk?' lk':''}">${YD.map((y,j)=>`<i style="background-image:url(${PH[y.p]});--r:${(j-1)*9}deg;--x:${(j-1)*34}px"></i>`).join('')}${lk?`<em>${ICO.lock}</em>`:''}</div>`;
  if(k==='dev'){const [h,m]=untilNine().split(':').map(Number),f=Math.max(.04,Math.min(1,1-(h*60+m)/(24*60)));
    return `<div class="oddev">${[0,1,2].map(j=>`<i class="${j<shots?'on':''}" style="--b:${(14*(1-f)+2).toFixed(1)}px"></i>`).join('')}</div><div class="odbar"><i style="width:${(f*100).toFixed(0)}%"></i></div><div class="odmono">OPENS 9:00 · ${untilTxt()}</div>`}
  if(k==='chat'){const g=GRP.find(g=>g.un&&!g.pend)||GRP.find(g=>!g.pend);return `<div class="odbub"><b>${rmEsc(g?g.n:'')}</b><span>${rmEsc((g&&g.last)||'…')}</span></div>`}
  if(k==='group'){const t=GRP.find(g=>g.trip),c=t?(t.cnt||0):0;return `<div class="odtrip">${Array.from({length:23},(_,j)=>`<i class="${j<c?'on':''}"></i>`).join('')}</div><div class="odside"><div class="odbig">${t?c:23}<small>${t?'/ 23':'/ day'}</small></div><div class="odmono">${t?rmEsc(t.n):'みんなで 撮る'}</div></div>`}
  if(k==='mondo')return `<div class="odmo${lk?' lk':''}"><svg class="glb2" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/></svg>${['#夕焼け','#放課後','#帰り道'].map((t,j)=>`<span style="--j:${j}">${j+1} ${t}</span>`).join('')}${lk?`<em>${ICO.lock}</em>`:''}</div>`;
  if(k==='friends'){const n=FR.length,td=FR.filter(f=>f.k>0).length;
    return `<div class="odav">${Array.from({length:6},(_,j)=>FR[j]?`<i style="background:${avBg(FR[j])};--j:${j}">${FR[j].n[0]}</i>`:`<i class="e" style="--j:${j}"></i>`).join('')}</div><div class="odbig">${td}<small>today</small></div>${(window.REQ&&REQ.length)?`<div class="odmono g">● 申請が とどいています</div>`:''}`}
  if(k==='join')return `<div class="odbub"><b>${rmEsc(INV?INV.n:'')}</b><span>${rmEsc(INV?INV.from+' から':'')}</span></div>`;
  return ''}
function dlCard(k){const a=ORB.A[k],lk=!!a.lock,i=DL.keys.indexOf(k);
  return `<div class="odch"><i class="ic">${OI[k]}</i><span class="dots">${DL.keys.map((x,j)=>`<b class="${x===k?'on':''}"></b>`).join('')}</span><button class="odcx" aria-label="とじる"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
    <b class="odt">${DLT[k]}</b><div class="odbd">${dlBody(k)}</div>
    <button class="odgo${lk?' lk':''}"><span>${lk?'Shoot first':DLG[k]}</span><i>${lk?OI.shoot:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'}</i></button>`}

/* ---------- ひらく / とじる ---------- */
function dlOpen(k,o={}){if(DL.open===k)return;if(DL.open)dlClose(true);if(!ORB.A[k])return;
  const X=$('odx'),b=X.querySelector(`.odb[data-k="${k}"]`);if(!b)return;DL.open=k;dlMeasure();
  const [bx,by]=DL.pos[k],W=258,H=262,cx=Math.max(-DL.cx+14+W/2,Math.min(390-DL.cx-14-W/2,bx*.14)),cy=by*.1,L=cx-W/2,T=cy-H/2;
  DL.cardAt=[bx,by,L,T];
  const C=document.createElement('div');C.className='odc';C.id='odc';C.style.cssText=`left:${L}px;top:${T}px;width:${W}px;height:${H}px`;C.innerHTML=dlCard(k);X.appendChild(C);
  X.classList.add('op');$('orb').classList.add('dlo');b.classList.add('sel');dlLayout();
  const ox=bx-L,oy=by-T,rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
  if(!rm){C.animate([{clipPath:`circle(30px at ${ox}px ${oy}px)`,transform:'scale(.92)'},{clipPath:`circle(420px at ${ox}px ${oy}px)`,transform:'none'}],{duration:520,easing:'cubic-bezier(.3,.9,.25,1)'});
    [...C.children].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,delay:110+i*55,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}));
    b.querySelector('i').animate([{rotate:'0deg'},{rotate:'-14deg'},{rotate:'8deg'},{rotate:'0deg'}],{duration:480,easing:'ease-out'})}
  hap(o.held?'thud':'pop',o.held?'ドン(ながおしで ひらく)':'ぷにっ(ひらく)',{norip:1});
  if(ORB.A[k].lock)setTimeout(()=>hap('warn','やわらかく2回(まだ)',{norip:1}),360);
  dlBindCard(C)}
function dlBindCard(C){C.querySelector('.odcx').onclick=e=>{e.stopPropagation();dlClose()};
  C.querySelector('.odgo').onclick=e=>{e.stopPropagation();dlGo()};
  let sx=null,sy=0;C.addEventListener('pointerdown',e=>{if(e.target.closest('button'))return;sx=e.clientX;sy=e.clientY});
  C.addEventListener('pointerup',e=>{if(sx===null)return;const dx=(e.clientX-sx)/SC,dy=(e.clientY-sy)/SC;sx=null;
    if(Math.abs(dx)>44&&Math.abs(dx)>Math.abs(dy))dlTurn(dx<0?1:-1);else if(dy>60)dlClose()});
  C.addEventListener('click',e=>e.stopPropagation())}
function dlClose(fast){const X=$('odx'),C=$('odc');if(!DL.open)return;const k=DL.open;DL.open=null;
  X.classList.remove('op');$('orb').classList.remove('dlo');X.querySelectorAll('.odb.sel').forEach(b=>b.classList.remove('sel'));dlLayout();
  if(!C)return;if(fast){C.remove();return}
  const p=DL.pos[k]||[0,0],[,,L,T]=DL.cardAt,ox=p[0]-L,oy=p[1]-T;
  C.style.pointerEvents='none';C.animate([{clipPath:`circle(420px at ${ox}px ${oy}px)`},{clipPath:`circle(28px at ${ox}px ${oy}px)`,opacity:.6}],{duration:300,easing:'cubic-bezier(.5,0,.7,.3)',fill:'forwards'}).onfinish=()=>C.remove();
  hap('soft','やわらかく1回(とじる)',{norip:1})}
function dlGo(){const k=DL.open;if(!k)return;const a=ORB.A[k],C=$('odc');
  if(a.lock){const s=ORB.A.shoot;if(s){hap('pop','ぷにっ(さきに 撮る)');dlClose(true);setTimeout(()=>s.run(),120)}else{hap('warn');shake(C)}return}
  hap('land','トン(ひらく)',{norip:1});
  if(C){C.style.pointerEvents='none';C.animate([{transform:'scale(1)'},{transform:'scale(.95)',offset:.3},{transform:'scale(1.12)',opacity:0}],{duration:300,easing:'cubic-bezier(.3,.7,.3,1)',fill:'forwards'})}
  setTimeout(()=>{dlClose(true);a.run()},170)}
function dlTurn(dir){const k=DL.open;if(!k)return;const th=dlNorm(DL.pos[k][2]);
  const nk=DL.keys.find((x,i)=>Math.abs(dlNorm(DLB[i]+DL.phi+dir*90)-th)<1);
  DL.turnTo={k:nk,dir};dlSnap(dir*.55)}
function dlRefreshCard(){const T=DL.turnTo;DL.turnTo=null;if(!T||!T.k||!DL.open)return;const C=$('odc'),X=$('odx');
  X.querySelectorAll('.odb').forEach(b=>b.classList.toggle('sel',b.dataset.k===T.k));DL.open=T.k;dlLayout();
  const parts=[...C.children];const out=parts.map(e=>e.animate([{opacity:1,transform:'none'},{opacity:0,transform:`translateX(${-T.dir*40}px)`}],{duration:140,fill:'forwards'}));
  setTimeout(()=>{C.innerHTML=dlCard(T.k);dlBindCard(C);[...C.children].forEach((e,i)=>e.animate([{opacity:0,transform:`translateX(${T.dir*46}px)`},{opacity:1,transform:'none'}],{duration:360,delay:i*40,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));hap('pop',null,{norip:1})},150)}

/* ---------- とうじょう:レンズから 4つが とびだして 席に つく ---------- */
function dlDeal(){if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;dlMeasure();
  const R=document.querySelector('#odr .rail');if(R){const L=R.getTotalLength();R.animate([{strokeDashoffset:L,opacity:0},{strokeDashoffset:0,opacity:1}],{duration:900,easing:'cubic-bezier(.3,.8,.3,1)'})}
  document.querySelectorAll('#odbs .odb').forEach((b,i)=>{const p=DL.pos[b.dataset.k];if(!p)return;
    b.querySelector('.w').animate([{transform:`translate(${-p[0]}px,${-p[1]}px) scale(.2) rotate(-160deg)`,opacity:0},{transform:'translate(0,0) scale(1.14) rotate(8deg)',opacity:1,offset:.7},{transform:'none'}],{duration:760,delay:180+i*90,easing:'cubic-bezier(.3,1.1,.4,1)',fill:'backwards'});
    setTimeout(()=>hap('tick','ポン(席に つく)',{norip:1}),180+i*90+520)});
  if(DL.hint)setTimeout(()=>{if(DL.drag||DL.open||!DL.hint)return;dlSpring(26,0,()=>dlSpring(0,0,()=>{DL.lastD=0}))},1700)}
{const _hi=homeIn;homeIn=function(s){_hi(s);setTimeout(()=>{dlMeasure();dlDeal()},60)}}

/* ---------- ひまなとき:光が レールを 1周して ボタンを 軽く 光らせる ---------- */
function dlSparkRun(){const S=$('odspk');if(!S||DL.open||DL.drag||cur!=='home'||$('home').classList.contains('arcm')||matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  const t0=performance.now(),dur=2000,st=DL.phi+225;const hit={};S.classList.add('on');
  const f=now=>{const k=Math.min(1,(now-t0)/dur),e=k<.5?2*k*k:1-Math.pow(-2*k+2,2)/2,th=st+e*360,[x,y]=dlPos(th);S.setAttribute('cx',x.toFixed(1));S.setAttribute('cy',y.toFixed(1));
    document.querySelectorAll('#odbs .odb').forEach(b=>{const bt=DLB[+b.dataset.i]+DL.phi;let d=Math.abs(dlNorm(th)-dlNorm(bt));d=Math.min(d,360-d);
      if(d<9&&!hit[b.dataset.k]){hit[b.dataset.k]=1;b.querySelector('i').animate([{scale:'1'},{scale:'1.14'},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}});
    if(k<1&&!DL.open&&!DL.drag)requestAnimationFrame(f);else S.classList.remove('on')};requestAnimationFrame(f)}
setInterval(dlSparkRun,9000);

/* ---------- まんなかの 万能ボタンに つなぐ ---------- */
{const _r=renderOrb;renderOrb=function(){_r();try{dlBuild()}catch(e){console.error(e)}};window.renderOrb=renderOrb;renderOrb()}
addEventListener('resize',()=>setTimeout(dlMeasure,50));
{const _cA=closeAll;closeAll=function(){if(DL.open)dlClose(true);return _cA.apply(this,arguments)}}
window.DL=DL;window.dlClose=dlClose;window.dlOpen=dlOpen;Object.defineProperty(window,'SC',{get:()=>SC,configurable:true});
