/* ===== v118(案):Trip の 一覧(TripHubView)を プロっぽく ・ 3案  名前:v8h =====
   U9.th = 'now'(いま)/ 'a' Clean / 'b' Peek / 'c' Pass   ・ __kit.th(k) で 切りかえ */
U9.th=U9.th||'c';  /* v118:たつきさん 決定 = 案C Pass + 案B の「ひらいた 写真」の 列 */
const V8H={front:null,cf:-1,raf:0,log:[]};
const V8HRM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const V8HMON=['January','February','March','April','May','June','July','August','September','October','November','December'];
const v8hDayN=t=>Math.round((g9Day(0)-t.from)/864e5)+1,v8hLen=t=>Math.round((t.to-t.from)/864e5)+1,v8hUntil=t=>Math.round((t.from-g9Day(0))/864e5);
function v8hParts(){const T=G9.trips;return{now:T.filter(t=>g9State(t)==='now'),next:T.filter(t=>g9State(t)==='next').sort((a,b)=>a.from-b.from),done:T.filter(t=>g9State(t)==='done').sort((a,b)=>b.to-a.to)}}
const v8hHead=(en,jp,it)=>`<h3 class="v8hh"><b class="${it?'v8hit':''}">${en}</b>${jp?`<small>${jp}</small>`:''}</h3>`;
const v8hMem=(t,s=30,bg)=>`<div class="v8hmm">${['あなた',...t.m].slice(0,3).map(n=>n==='あなた'?`<i class="g9av me" style="width:${s}px;height:${s}px;background-image:url(${PH.c})"></i>`:g9Av(n,s)).join('')}</div>`;
const v8hPg=(t,sh)=>`<div class="v8hpg"><p><b>${t.shot||0}</b><small>/ ${t.cap||23}枚${sh?'':' ・ 9:00 現像'}</small></p><i><u style="width:${(t.shot||0)/(t.cap||23)*100}%"></u></i></div>`;
const v8hState=t=>{const s=g9State(t);return s==='now'?`DAY ${v8hDayN(t)} / ${v8hLen(t)}`:s==='next'?`あと ${v8hUntil(t)}日`:'おわった'};
const V8HPH=['a','d','f','b','e'];

/* ---------- 週の 帯 ---------- */
function v8hWeek(photo,hl){const s=g9WeekStart(G9.wk),e=new Date(s);e.setDate(s.getDate()+6);const today=+g9Day(0);
  const days=[...Array(7)].map((_,i)=>{const d=new Date(s);d.setDate(s.getDate()+i);return d});
  const cells=days.map((d,i)=>{const t=G9.trips.find(t=>t.from<=d&&t.to>=d);let x='',th='';
    if(t){const st=+d===+t.from,en=+d===+t.to,lb=st||i===0;x=`<i class="v8hln${st?' v8hs':''}${en?' v8he':''}"></i>${lb?`<em class="${i>=5?'v8hrtl':''}">${g9E(t.n)}</em>`:''}`;
      if(photo){th=+d<today?`<i class="v8hth v8hop" style="background-image:url(${PH[V8HPH[i%5]]})"></i>`:+d===today?`<i class="v8hth v8hlk" style="--bgi:url(${PH[t.cv]})">${G9I.lock}</i>`:`<i class="v8hth v8hfu"></i>`}}
    else if(photo)th=`<i class="v8hth v8hno"></i>`;
    return `<button class="v8hdy${+d===today?' v8htd':''}${G9.sel===+d?' v8hsel':''}${hl&&t&&t.id!==hl?' v8hdim':''}" data-d="${+d}" data-tp="${t?t.id:''}" style="${t?'--c:'+G9C[t.c]:''}" aria-label="${g9Dd(d)}${t?' ・ '+g9E(t.n):''}"><small>${G9W[d.getDay()]}</small>${th}<b>${d.getDate()}</b>${x}</button>`}).join('');
  return `<section class="v8hwk"><div class="v8hwh"><b>${V8HMON[s.getMonth()]}</b><small>${g9Dd(s)} 〜 ${g9Dd(e)}</small><i class="v8hsp"></i>${G9.wk?'<button class="v8hnow" data-w="0">今週</button>':''}<button class="v8har" data-w="-1" aria-label="前の 週"><i>${G9I.back}</i></button><button class="v8har" data-w="1" aria-label="次の 週"><i>${G9I.go}</i></button></div>
    <div class="v8hwd${photo?' v8hph':''}">${cells}</div></section>`}
function v8hAlbum(done){if(!done.length)return '';return v8hHead('Album','おわった ・ アルバム')+`<div class="v8hal">${done.map((t,i)=>`<button class="v8hab" data-trip="${t.id}" style="--c:${G9C[t.c]};--t:${i%2?2.2:-2.2}deg"><div class="v8hck"><div class="v8hckp" style="background-image:url(${PH[t.cv]})"></div><p>${g9E(t.n)}</p></div><small>${g9Dd(t.from)} ・ ${t.shot}枚</small></button>`).join('')}</div>`}
const v8hActs=()=>`<div class="v8hact"><button class="g9btn g9ghost" data-a="new">${G9I.plus}<span>新しい Trip</span></button><button class="g9btn g9ghost" data-a="key">${G9I.key}<span>KEY で 入る</span></button></div>`;

/* ---------- A Clean(BeReal 型) ---------- */
function v8hA(){const {now,next,done}=v8hParts();const t=now[0];
  return v8hWeek(0)+
  (t?v8hHead('Now','いま 旅の とちゅう',1)+`<div class="v8hlw"><button class="v8hlive" data-trip="${t.id}" style="--c:${G9C[t.c]}">
    <i class="v8hcv" style="background-image:url(${PH[t.cv]})"></i><i class="v8hsh"></i><i class="v8hgl"></i>
    ${g9Tag(v8hState(t),t.c)}
    <div class="v8hbt"><b class="v8hnm">${g9E(t.n)}</b><p class="v8hsub">${g9Dd(t.from)} 〜 ${g9Dd(t.to)} ・ ${t.m.length+1}人</p>
      <div class="v8hft">${v8hMem(t,30)}${v8hPg(t)}<i class="v8hgo">${G9I.go}</i></div></div></button></div>`:'')+
  (next.length?v8hHead('Next','これから')+`<div class="v8hrows">${next.map(t=>`<button class="v8hrow" data-trip="${t.id}" style="--c:${G9C[t.c]}"><i class="v8hrth" style="background-image:url(${PH[t.cv]})"></i>
    <div class="v8hrtx"><b>${g9E(t.n)}</b><small>${g9Dd(t.from)}(${G9W[t.from.getDay()]})〜 ・ ${v8hLen(t)}日 ・ ${t.m.length+1}人</small></div><em class="v8hrcd">あと ${v8hUntil(t)}日</em><i class="v8hrar">${G9I.go}</i></button>`).join('')}</div>`:'')+
  v8hActs()+v8hAlbum(done)}

/* ---------- B Peek(Instagram 型) ---------- */
function v8hOrder(){const {now,next,done}=v8hParts();return [...done.slice().reverse(),...now,...next]}
function v8hB(){const O=v8hOrder();const {now}=v8hParts();const c0=now[0]||O[0];
  return v8hWeek(1,c0.id)+
  `<div class="v8hcf" id="v8hcf">${O.map(t=>{const s=g9State(t);
    return `<button class="v8hcard" data-trip="${t.id}" style="--c:${G9C[t.c]}"><i class="v8hcv" style="background-image:url(${PH[t.cv]})"></i><i class="v8hsh"></i>
      <div class="v8htp">${g9Tag(v8hState(t),t.c)}<div class="v8hrg">${['あなた',...t.m].slice(0,3).map((n,i)=>`<i class="v8hrn${s==='now'&&i<2?' v8hrnon':''}">${n==='あなた'?`<i class="g9av me" style="width:28px;height:28px;background:url(${PH.c}) center/cover"></i>`:g9Av(n,28)}</i>`).join('')}</div></div>
      <div class="v8hbt"><b class="v8hnm">${g9E(t.n)}</b><p class="v8hsub">${g9Dd(t.from)} 〜 ${g9Dd(t.to)} ・ ${t.m.length+1}人</p>
        <p class="v8hst">${s==='now'?`${G9I.lock}<em>${t.shot} / ${t.cap}枚</em> ・ 9:00 に ひらく`:s==='next'?`${G9I.go}${g9Dd(t.from)} に 出発`:`${t.shot}枚 の アルバム`}</p></div></button>`}).join('')}</div>
  <button class="g9btn lime v8hopen" id="v8hopen"><span>ひらく</span>${G9I.go}</button>
  <div class="v8hpk" id="v8hpk"></div>`+v8hActs()}
function v8hPeek(t){const s=g9State(t);
  if(s==='now')return `<div class="v8hlb"><b>ひらいた 写真</b><small>DAY 1 ・ 18枚</small></div><div class="v8hrl">${['a','b','d','f'].map((k,i)=>`<i class="v8hmc" style="--t:${i%2?3:-3}deg"><i style="background-image:url(${PH[k]})"></i></i>`).join('')}<i class="v8hmc v8hlk" style="--t:2deg"><i style="background-image:url(${PH.e})"></i>${G9I.lock}</i></div>`;
  if(s==='next')return `<div class="v8hlb"><b>まだ 写真なし</b><small>${g9Dd(t.from)} から</small></div><div class="v8hrl">${[0,1,2].map(i=>`<i class="v8hmc v8hem" style="--t:${i%2?3:-3}deg"><i></i></i>`).join('')}</div>`;
  return `<div class="v8hlb"><b>アルバム</b><small>${t.shot}枚 ・ ${g9Dd(t.from)}</small></div><div class="v8hrl">${['f','c','a','d'].map((k,i)=>`<i class="v8hmc" style="--t:${i%2?3:-3}deg"><i style="background-image:url(${PH[k]})"></i></i>`).join('')}</div>`}

/* ---------- C Pass(Lattag 型) ---------- */
function v8hDeckList(){const {now,next}=v8hParts();const L=[...now,...next];const f=V8H.front&&L.find(t=>t.id===V8H.front)||L[0];return f?[f,...L.filter(t=>t!==f)]:[]}
const V8HPK=56;
function v8hC(){const {done}=v8hParts();const L=v8hDeckList();const n=L.length;
  return v8hWeek(0)+v8hHead('Boarding','いま と これから',1)+
  `<div class="v8hdeck" id="v8hdeck" style="height:${(n-1)*V8HPK+240}px">${L.map(t=>{const s=g9State(t);
    return `<button class="v8hpass" data-trip="${t.id}" style="--c:${G9C[t.c]}"><div class="v8hmn">
      <div class="v8hphd"><b class="v8hnm">${g9E(t.n)}</b>${s==='now'?`<small>${G9I.lock}9:00 に ひらく</small>`:`<small class="v8hnx">${g9Dd(t.from)} 出発</small>`}</div>
      <div class="v8hprt"><p><small>出発</small><b>${g9Dd(t.from)}</b></p><i class="v8hpl"></i><p><small>帰り</small><b>${g9Dd(t.to)}</b></p></div>
      <div class="v8hpft">${v8hMem(t,28)}${s==='now'?v8hPg(t,1):`<div class="v8hpg"><p><b>${v8hLen(t)}日</b><small>・ ${t.m.length+1}人</small></p></div>`}<i class="v8hgo">${G9I.go}</i></div></div>
      <div class="v8hsb">${s==='now'?`<small>DAY</small><b>${v8hDayN(t)}/${v8hLen(t)}</b>`:`<small>あと</small><b>${v8hUntil(t)}日</b>`}<i class="v8hbc"></i></div></button>`}).join('')}</div>
  <div class="v8hpk v8hpkc" id="v8hpk">${L[0]?v8hPeek(L[0]):''}</div>
  <div class="v8hcact"><button class="v8hnew" data-a="new">${G9I.plus}新しい Trip を つくる</button><button class="g9btn g9ghost" data-a="key">${G9I.key}<span>KEY</span></button></div>`+v8hAlbum(done)}
function v8hDeckLay(anim){const D=$('v8hdeck');if(!D)return;const L=v8hDeckList(),n=L.length,rm=V8HRM();
  L.forEach((t,k)=>{const el=D.querySelector(`.v8hpass[data-trip="${t.id}"]`);if(!el)return;
    const y=(n-1-k)*V8HPK,tf=k===0?`translateY(${y}px)`:`translateY(${y}px) scale(${1-k*.045}) rotateX(${rm?0:k*7}deg)`;
    el.style.zIndex=10-k;el.classList.toggle('v8hbk',k>0);el.style.transform=tf;el.dataset.k=k;
    if(anim&&!rm){el.animate([{transform:`translateY(${y+220}px) rotateX(-58deg) scale(.9)`,opacity:0},{transform:tf,opacity:1}],{duration:720,delay:(n-1-k)*90,easing:'cubic-bezier(.34,1.3,.64,1)',fill:'backwards'})}})}

/* ---------- つなぐ ---------- */
{const _o=g9TripHTML;g9TripHTML=function(){const on=U9.th!=='now'&&G9.trips.length>0;const S=$('g9');S&&S.classList.toggle('v8hon',on);
  if(!on)return _o.apply(this,arguments);$('g9sub').textContent='';return {a:v8hA,b:v8hB,c:v8hC}[U9.th]()}}
{const _f=g9FriendsHTML;g9FriendsHTML=function(){const S=$('g9');S&&S.classList.remove('v8hon');return _f.apply(this,arguments)}}
{const _b=g9TripBind;g9TripBind=function(){_b.apply(this,arguments);if(U9.th==='now'||!G9.trips.length)return;const P=$('g9pg');P.classList.add('v8h','v8h-'+U9.th);
  P.querySelectorAll('.v8hdy').forEach(b=>b.onclick=()=>{const d=+b.dataset.d;G9.sel=G9.sel===d?null:d;g9Hap('sel');P.querySelectorAll('.v8hdy').forEach(x=>x.classList.toggle('v8hsel',+x.dataset.d===G9.sel));
    const id=b.dataset.tp;if(!id){if(G9.sel)g9Toast(g9Dd(new Date(d))+' は Trip なし ・ 「新しい Trip」で 作れます');return}
    if(U9.th==='b'){v8hCfTo(id);return}if(U9.th==='c'&&P.querySelector(`.v8hpass[data-trip="${id}"]`)){v8hFront(id);return}g9Ping(id)});
  if(U9.th==='a')v8hTiltBind();if(U9.th==='b')v8hCfBind();if(U9.th==='c')v8hDeckBind();V8H.log.push('bind:'+U9.th)}}

/* A:指(実機は ジャイロ)で かたむく 1枚 + 光の すじ */
function v8hTilt(el,rx,ry){el.style.setProperty('--rx',rx+'deg');el.style.setProperty('--ry',ry+'deg');el.style.setProperty('--gx',(-ry*6)+'%');el.style.setProperty('--go',Math.min(1,(Math.abs(rx)+Math.abs(ry))/10).toFixed(2))}
function v8hTiltBind(){const el=$('g9pg').querySelector('.v8hlive');if(!el||V8HRM())return;
  el.addEventListener('pointermove',e=>{const r=el.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;el.classList.add('v8hdrag');v8hTilt(el,(-y*16).toFixed(1),(x*20).toFixed(1))});
  el.addEventListener('pointerleave',()=>{el.classList.remove('v8hdrag');v8hTilt(el,0,0)});
  /* ひらいた 時に 1回 だけ:下から 立ちあがる */
  el.animate([{transform:'rotateX(18deg) translateY(40px) scale(.94)',opacity:0},{transform:'rotateX(0) translateY(0) scale(1)',opacity:1}],{duration:700,easing:'cubic-bezier(.34,1.3,.64,1)'})}

/* B:横に めくる(位置で rotateY ・ scale ・ opacity を 計算) */
function v8hCfUpd(){const C=$('v8hcf');if(!C)return;const cx=C.scrollLeft+C.clientWidth/2,rm=V8HRM();let best=0,bd=1e9;
  [...C.children].forEach((el,i)=>{const c=el.offsetLeft+el.offsetWidth/2,d=Math.max(-1.6,Math.min(1.6,(c-cx)/el.offsetWidth));
    if(Math.abs(d)<bd){bd=Math.abs(d);best=i}
    el.style.transform=rm?`scale(${1-Math.abs(d)*.1})`:`rotateY(${(-d*28).toFixed(2)}deg) translateZ(${(-Math.abs(d)*70).toFixed(1)}px) scale(${(1-Math.abs(d)*.06).toFixed(3)})`;
    el.style.opacity=(1-Math.min(1,Math.abs(d))*.42).toFixed(2);el.style.zIndex=10-Math.round(Math.abs(d)*3)});
  if(best!==V8H.cf){const first=V8H.cf<0;V8H.cf=best;const t=G9.trips.find(x=>x.id===C.children[best].dataset.trip);if(!first)g9Hap('notch','カチ(めくる)');v8hCfSel(t)}}
function v8hCfSel(t){const P=$('g9pg');const pk=$('v8hpk');if(pk)pk.innerHTML=v8hPeek(t);const o=$('v8hopen');if(o){o.querySelector('span').textContent=g9State(t)==='done'?`『${t.n}』の アルバム`:`『${t.n}』を ひらく`;o.dataset.id=t.id}
  P.querySelectorAll('.v8hdy').forEach(x=>x.classList.toggle('v8hdim',!!x.dataset.tp&&x.dataset.tp!==t.id))}
function v8hCfTo(id,inst){const C=$('v8hcf');if(!C)return;const el=C.querySelector(`[data-trip="${id}"]`);if(!el)return;C.scrollTo({left:el.offsetLeft+el.offsetWidth/2-C.clientWidth/2,behavior:inst||V8HRM()?'auto':'smooth'})}
function v8hCfBind(){const C=$('v8hcf');if(!C)return;V8H.cf=-1;const {now}=v8hParts();
  [...C.children].forEach((el,i)=>{const open=el.onclick;el.onclick=e=>{if(i!==V8H.cf){v8hCfTo(el.dataset.trip);return}open&&open.call(el,e)}});
  C.addEventListener('scroll',()=>{cancelAnimationFrame(V8H.raf);V8H.raf=requestAnimationFrame(v8hCfUpd)},{passive:true});
  const o=$('v8hopen');o.onclick=()=>{const el=C.children[V8H.cf];el&&el.click()};
  v8hCfTo((now[0]||G9.trips[0]).id,1);v8hCfUpd()}

/* C:パスの 束(うしろの パスを タップ → 前へ) */
function v8hFront(id){if(V8H.front===id&&v8hDeckList()[0].id===id)return;V8H.front=id;g9Hap('land','トン(パスが 前へ)');
  const D=$('v8hdeck');const el=D&&D.querySelector(`.v8hpass[data-trip="${id}"]`);
  if(el&&!V8HRM()){el.style.zIndex=20;const y0=el.style.transform;el.animate([{transform:y0},{transform:y0.replace(/translateY\(([-\d.]+)px\)/,(m,v)=>`translateY(${+v-34}px)`)+' rotateX(-10deg)',offset:.35}],{duration:260,easing:'ease-out'})}
  setTimeout(()=>{v8hDeckLay(0);const pk=$('v8hpk'),t=G9.trips.find(x=>x.id===id);if(pk&&t&&U9.th==='c'){pk.innerHTML=v8hPeek(t);if(!V8HRM())pk.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:320,easing:'ease-out'})}},V8HRM()?0:140)}
function v8hDeckBind(){const D=$('v8hdeck');if(!D)return;
  D.querySelectorAll('.v8hpass').forEach(el=>{const open=el.onclick;el.onclick=e=>{if(+el.dataset.k>0){v8hFront(el.dataset.trip);return}open&&open.call(el,e)}});
  v8hDeckLay(1)}

/* ---------- デモ ---------- */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-v8h]'))return;
  C.insertAdjacentHTML('beforeend',['now:★ v118 Trip 一覧:いま','a:★ v118 Trip 一覧:案A Clean','b:★ v118 Trip 一覧:案B Peek','c:★ v118 Trip 一覧:案C Pass + 写真(決定)','tilt:案A:かたむける','flip:案B:次へ めくる','swap:案C:うしろの パスを 前へ'].map(s=>{const i=s.indexOf(':');return `<button data-v8h="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-v8h]').forEach(b=>b.onclick=()=>v8hDemo(b.dataset.v8h))})();
function v8hDemo(k){if(['now','a','b','c'].includes(k)){U9.th=k;V8H.front=null;g9Demo('trip');return}
  const P=$('g9pg');
  if(k==='tilt'){const el=P&&P.querySelector('.v8hlive');if(el){el.classList.add('v8hdrag');v8hTilt(el,7,-11)}}
  else if(k==='flip'){const C=$('v8hcf');if(C&&C.children[V8H.cf+1])v8hCfTo(C.children[V8H.cf+1].dataset.trip)}
  else if(k==='swap'){const L=v8hDeckList();if(L[1])v8hFront(L[1].id)}}
window.__kit=Object.assign(window.__kit||{},{th:k=>v8hDemo(k),V8H:()=>({th:U9.th,front:V8H.front,cf:V8H.cf,log:V8H.log.slice()})});
