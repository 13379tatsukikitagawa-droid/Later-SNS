/* ===== v118(モック):Today の カード 3案 ― 印 x9t =====
   'now' = いま(v117)/ 'a' = シンプル / 'b' = 3D の 束 / 'c' = 暗室の ひも(既定 = おすすめ)
   動き:出て くる 時に 1回 着地 ・ 指で 3D に 傾く(±12°)+ 光の すじ ・ C は スクロールで ゆれる。くり返す 動きは なし。 */
const X9T={v:'c',key:'',tilt:null};
const x9tRM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const X9TP=['c','a','e'];
/* Lattag の 1日 = 9:00 → あした 9:00(24時間)。24:00 = 消灯 は 62.5% */
function x9tPos(h,m){let x=h+m/60-9;if(x<0)x+=24;return Math.max(0,Math.min(1,x/24))}
function x9tNow(){const d=new Date();return x9tPos(d.getHours(),d.getMinutes())}
function x9tLeft(){const [h,m]=untilNine().split(':').map(Number);return {h,m,t:h+':'+p2(m),j:h>0?`${h}時間${m}分`:`${m}分`}}
function x9tState(){const L=x9tLeft();
  if(!shots)return `まだ 0枚 ・ <b>24:00</b> まで 撮れる`;
  if(shots>=3)return `3枚 そろった ・ <b>9:00</b> に ひらく`;
  return `現像中 ・ のこり <b>${3-shots}枚</b>`}
function x9tCheki(i,rz){const p=dvProgress(i);
  return `<div class="x9f ph" data-i="${i}" style="--rz:${rz}deg"><div class="x9c" style="--mk:${(0.92-p*.62).toFixed(2)};--bl:${(10-p*8).toFixed(1)}px;--sa:${(.15+p*.6).toFixed(2)};--br:${(1.45-p*.4).toFixed(2)}"><div class="x9p"><img src="${PH[X9TP[i]]}" alt=""></div><b class="x9tm">${TM[i]}</b><i class="x9g"></i></div></div>`}
function x9tShoot(sub){return `<button class="x9s" data-a="shoot" aria-label="撮る">${ICO.plus}<b class="x9sl">撮る</b>${sub?`<b class="x9ss">${sub}</b>`:''}</button>`}
function x9tEmpty(n){return `<div class="x9e"><b class="x9en">${n}</b></div>`}
function x9tLine(){const p=(x9tNow()*100).toFixed(1),L=x9tLeft();const dots=[0,1,2].filter(i=>i<shots).map(i=>{const [h,m]=TM[i].split(':').map(Number);return `<i class="x9ld" style="left:${(x9tPos(h,m)*100).toFixed(1)}%"></i>`}).join('');
  return `<div class="x9l${shots>=3?' x9end':''}" style="--p:${p}%"><i class="x9lf"></i><i class="x9lo"></i>${dots}<i class="x9le"></i><i class="x9lb"></i></div>
    <div class="x9lq"><p class="qa">あと <b>${L.j}</b></p><p class="q0">24:00 消灯</p><p class="q1">9:00 ひらく</p></div>`}
const X9RZ=[-2.4,1.8,-1.3];
function x9tA(){const fr=[0,1,2].map(i=>i<shots?x9tCheki(i,X9RZ[i]):i===shots?x9tShoot():x9tEmpty(i+1)).join('');
  return `<div class="x9t a"><div class="x9h"><div><b class="x9tt">Today</b><p class="x9d">${x9tState()}</p></div><b class="x9n">${shots}<s>/3</s></b></div>
    <div class="x9r">${fr}</div>${x9tLine()}</div>`}
function x9tB(){const RZ=[-7,6,-2.5];let st='';
  if(shots){const ord=[...Array(shots).keys()];st=ord.map((i,k)=>x9tCheki(i,RZ[2-(shots-1-k)])).join('')+`<b class="x9cnt">${shots}/3</b>`}
  else st=`<div class="x9e"><p class="x9et">1枚目は<br>ここに 入る</p></div>`;
  const pips=[0,1,2].map(i=>`<i class="${i<shots?'f':i===shots?'n':'e'}"></i>`).join('');
  return `<div class="x9t b"><div class="x9bg"><div class="x9st" data-a="stack" role="button" aria-label="現像を のぞく">${st}</div>
    <div class="x9rc"><b class="x9tt">Today</b><p class="x9d">${shots?(shots>=3?'3枚 そろった':'現像中 ・ のこり '+(3-shots)+'枚'):'まだ 0枚'}</p><div class="x9pp">${pips}</div>
    ${shots<3?x9tShoot('24:00 まで'):'<div class="x9dn">今日は ここまで</div>'}</div></div>${x9tLine()}</div>`}
/* C:ひもの 形(2次ベジェ)。左の くぎ → 右の 9:00 の 札 */
const X9S={w:330,p0:[6,30],p1:[150,58],p2:[300,8]};
function x9tBz(t){const [a,b,c]=[X9S.p0,X9S.p1,X9S.p2];const u=1-t;return [u*u*a[0]+2*u*t*b[0]+t*t*c[0],u*u*a[1]+2*u*t*b[1]+t*t*c[1]]}
function x9tYat(x){let lo=0,hi=1;for(let k=0;k<24;k++){const m=(lo+hi)/2;if(x9tBz(m)[0]<x)lo=m;else hi=m}return x9tBz((lo+hi)/2)[1]}
function x9tC(){const L=x9tLeft();const p=x9tNow();const xs=[58,165,272];
  const d=`M${X9S.p0} Q${X9S.p1} ${X9S.p2}`;
  const slots=xs.map((x,i)=>{const y=x9tYat(x);const inner=i<shots?x9tCheki(i,X9RZ[i]):i===shots?x9tShoot(`のこり ${3-shots}`):x9tEmpty(i+1);
    return `<div class="x9slot${i<shots?' ph':''}" style="left:${x}px;top:${(y+4).toFixed(1)}px">${inner}<i class="x9clip"></i></div>`}).join('');
  return `<div class="x9t c"><div class="x9h"><div><b class="x9tt">Today</b><p class="x9d">${x9tState()}</p></div>
      <div class="x9tg${shots>=3?' x9end':''}"><b class="x9tn">9:00</b><b class="x9ts">${shots>=3?'あと '+L.t+' で ひらく':'ひらく ・ あと '+L.t}</b></div></div>
    <div class="x9hang"><svg class="x9str" viewBox="0 0 ${X9S.w} 64" preserveAspectRatio="none"><path class="bg" d="${d}"/><path class="fg" d="${d}" pathLength="1" stroke-dasharray="${p.toFixed(3)} 1"/><circle class="nail" cx="${X9S.p0[0]}" cy="${X9S.p0[1]}" r="4"/></svg>${slots}</div></div>`}

/* 指で 傾く(3D)+ 光の すじ */
function x9tTilt(c,rx,ry,on){c.style.setProperty('--rx',rx.toFixed(1)+'deg');c.style.setProperty('--ry',ry.toFixed(1)+'deg');
  c.style.setProperty('--gx',(50-ry*4).toFixed(0)+'%');c.style.setProperty('--go',on?Math.min(1,(Math.abs(rx)+Math.abs(ry))/14).toFixed(2):'0')}
function x9tBind(T){if(x9tRM())return;
  T.querySelectorAll('.x9f.ph').forEach(f=>{const c=f.querySelector('.x9c');
    const mv=e=>{const tgt=T.querySelector('.x9t.b')?T.querySelector('.x9st'):f;const r=tgt.getBoundingClientRect();const nx=((e.clientX-r.left)/r.width)*2-1,ny=((e.clientY-r.top)/r.height)*2-1;
      const k=T.querySelector('.x9t.b')?T.querySelectorAll('.x9st .x9c'):[c];k.forEach(cc=>{cc.classList.add('live');x9tTilt(cc,-ny*12,nx*12,1)})};
    const up=()=>{(T.querySelector('.x9t.b')?T.querySelectorAll('.x9st .x9c'):[c]).forEach(cc=>{cc.classList.remove('live');x9tTilt(cc,0,0,0)})};
    f.addEventListener('pointermove',mv);f.addEventListener('pointerdown',e=>{mv(e);hap('tick',null,{norip:1,gap:200})});f.addEventListener('pointerleave',up);f.addEventListener('pointerup',up);f.addEventListener('pointercancel',up)})}
/* 出て くる 時に 1回 だけ 着地(上から 少し 傾いて 落ち、ばねで 止まる) */
function x9tEnter(T){const fs=[...T.querySelectorAll('.x9f,.x9s,.x9e')];
  if(x9tRM()){fs.forEach(f=>f.animate([{opacity:0},{opacity:1}],{duration:260,fill:'backwards'}));return}
  const hang=!!T.querySelector('.x9t.c');
  fs.forEach((f,j)=>{const ph=f.classList.contains('x9f');
    if(hang&&ph){f.animate([{transform:'rotate(9deg)',opacity:0,offset:0},{transform:'rotate(-6deg)',opacity:1,offset:.32},{transform:'rotate(3deg)',offset:.62},{transform:'rotate(-1deg)',offset:.84},{transform:'none'}],{duration:1100,delay:60+j*90,easing:'ease-out',fill:'backwards'});return}
    f.animate([{transform:'translateY(-18px) perspective(700px) rotateX(28deg)',opacity:0},{transform:'translateY(2px) perspective(700px) rotateX(-4deg)',opacity:1,offset:.7},{transform:'none'}],{duration:620,delay:60+j*80,easing:'cubic-bezier(.3,1.25,.5,1)',fill:'backwards'})});
  T.querySelectorAll('.x9tg').forEach(g=>g.animate([{transform:'translateY(-10px) rotate(6deg)',opacity:0},{transform:'none',opacity:1}],{duration:560,delay:40,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}));
  const lb=T.querySelector('.x9lf');if(lb)lb.animate([{transform:'scaleX(0)',transformOrigin:'0 50%'},{transform:'scaleX(1)',transformOrigin:'0 50%'}],{duration:800,delay:200,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'});
  const fg=T.querySelector('.x9str .fg');if(fg){const p=x9tNow();fg.animate([{strokeDasharray:'0 1'},{strokeDasharray:p.toFixed(3)+' 1'}],{duration:900,delay:200,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'})}}
let X9IO=null,X9SEEN=false;
function x9tWatch(T){if(X9IO)return;const R=$('hs');X9IO=new IntersectionObserver(es=>es.forEach(e=>{if(e.isIntersecting&&!X9SEEN){X9SEEN=true;x9tEnter(T)}else if(!e.isIntersecting&&e.intersectionRatio===0)X9SEEN=false}),{root:R,threshold:.35});X9IO.observe(T)}
/* C:スクロールの 速さで チェキが ゆれる(ばねで もどる ・ 画面外では 計算 しない) */
(()=>{const R=$('hs');if(!R)return;let last=R.scrollTop,sw=0,v=0,raf=0;
  const step=()=>{const T=$('tdv');const fs=T?T.querySelectorAll('.x9t.c .x9slot.ph .x9c'):[];if(!fs.length){sw=0;v=0;raf=0;return}
    v+=(-sw)*.12;v*=.82;sw+=v;fs.forEach(c=>c.style.setProperty('--sw',sw.toFixed(2)+'deg'));if(Math.abs(sw)>.03||Math.abs(v)>.03)raf=requestAnimationFrame(step);else{fs.forEach(c=>c.style.setProperty('--sw','0deg'));raf=0}};
  R.addEventListener('scroll',()=>{const d=R.scrollTop-last;last=R.scrollTop;if(X9T.v!=='c'||x9tRM()||!X9SEEN)return;v+=Math.max(-2.2,Math.min(2.2,-d*.05));if(!raf)raf=requestAnimationFrame(step)},{passive:true})})();

const _x9tArc=arcToday;
arcToday=function(){const T=$('tdv');if(!T)return;
  if(X9T.v==='now'){T.classList.remove('x9on');return _x9tArc.apply(this,arguments)}
  const key=X9T.v+shots+'|'+x9tLeft().t;if(T.classList.contains('x9on')&&T.dataset.x9k===key&&!X9T.force)return;X9T.force=false;
  const fresh=T.dataset.x9k?T.dataset.x9k.slice(0,2)!==key.slice(0,2):true;T.dataset.x9k=key;
  T.classList.add('x9on');T.innerHTML=X9T.v==='a'?x9tA():X9T.v==='b'?x9tB():x9tC();x9tBind(T);x9tWatch(T);if(fresh&&X9SEEN)x9tEnter(T);
  if(X9T.tilt)T.querySelectorAll('.x9f.ph .x9c').forEach((c,j)=>{const t=X9T.tilt[j%X9T.tilt.length];x9tTilt(c,t[0],t[1],1)});
  T.onclick=e=>{if(e.target.closest('[data-a="shoot"]')){hap('pop','ぷにっ(撮りに いく)');goShoot();return}
    const st=e.target.closest('[data-a="stack"]');if(st&&shots){if(!x9tRM()){st.classList.add('fan');hap('sel','コツッ(束が ひらく)')}setTimeout(()=>{st.classList.remove('fan');openDvx(shots-1)},x9tRM()?0:420);return}
    if(!shots){hap('pop','ぷにっ(撮りに いく)');goShoot();return}
    const f=e.target.closest('.x9f.ph');hap('pop','ぷにっ(現像を のぞく)');openDvx(f?+f.dataset.i:Math.max(0,shots-1))}};
setInterval(()=>{if($('home').classList.contains('on')&&X9T.v!=='now')try{arcToday()}catch(e){}},30000);
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-x9t]'))return;
  C.insertAdjacentHTML('beforeend',['now:★ v118 Today:いま(v117)','a:★ v118 Today:A シンプル','b:★ v118 Today:B 3D の 束','c:★ v118 Today:C 暗室の ひも(決定)'].map(s=>{const i=s.indexOf(':');return `<button data-x9t="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-x9t]').forEach(b=>b.onclick=()=>{X9T.v=b.dataset.x9t;X9T.force=true;try{arcToday()}catch(e){console.warn(e)}})})();
window.__kit=Object.assign(window.__kit||{},{x9t:(k,o)=>{o=o||{};if(k)X9T.v=k;X9T.tilt=o.tilt||null;X9T.force=true;if(o.enter)X9SEEN=false;try{arcToday()}catch(e){console.warn(e)}return X9T.v},
  x9tEnter:()=>{X9SEEN=true;x9tEnter($('tdv'))},x9tFan:()=>{const s=document.querySelector('#tdv .x9st');if(s)s.classList.add('fan')}});
try{arcToday()}catch(e){console.warn(e)}
