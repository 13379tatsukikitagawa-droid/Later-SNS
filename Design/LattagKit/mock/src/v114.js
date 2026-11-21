/* ===== v114(モック v115 ・ PROMPT v129):Trip の 部屋を 作り直す + 本当に 使える チャット ===== */
const U9T={t:null,chat:null,un:0,typing:null,tm:[]};
const U9TI={back:'<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>',gear:H9XI.gear,plus:'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  yobu:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.6"/><path d="M2.8 19.5c.5-3.4 3-5.4 6.2-5.4s5.7 2 6.2 5.4M18.5 7.5v6M15.5 10.5h6"/></svg>',
  cam:'<svg viewBox="0 0 24 24"><path d="M4 8.5A1.5 1.5 0 015.5 7H8l1.5-2h5L16 7h2.5A1.5 1.5 0 0120 8.5v9a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>',
  chat:'<svg viewBox="0 0 24 24"><path d="M5 18.5V7a2 2 0 012-2h10a2 2 0 012 2v7a2 2 0 01-2 2H8.5z"/></svg>',
  send:'<svg viewBox="0 0 24 24"><path d="M12 19V5M6 11l6-6 6 6"/></svg>',
  img:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9.5" r="1.6"/><path d="M5 18l5-5 3.5 3.5L16 14l3 3"/></svg>',
  stk:'<svg viewBox="0 0 24 24"><path d="M20 12.5V7a3 3 0 00-3-3H7a3 3 0 00-3 3v10a3 3 0 003 3h5.500z"/><path d="M12.5 20c0-4.300 3.200-7.500 7.500-7.500"/><circle cx="9" cy="10" r=".8"/><circle cx="14.5" cy="10" r=".8"/></svg>',
  plane:'<svg viewBox="0 0 24 24"><path d="M3 13l18-8-6 16-3-6z"/></svg>'};
const U9TC={pink:'#FF9CC8',sky:'#7CCBFF',sun:'#FFD84D',lime:'#C8F25A'};
const u9Now=()=>{const d=new Date();return `${d.getHours()}:${String(d.getMinutes()).padStart(2,'0')}`};
const u9MeAv=s=>`<i class="u9me" style="width:${s}px;height:${s}px;background-image:url(${PH.c})"></i>`;
function u9Av(n,s){return n==='me'?u9MeAv(s):g9Av(n,s)}
function u9TData(g){const from=new Date(g.from),to=new Date(g.to||g.from),D=Math.max(1,Math.round((to-from)/864e5)+1),now=new Date();now.setHours(0,0,0,0);const f0=new Date(from);f0.setHours(0,0,0,0);
  const dn=Math.min(D,Math.max(1,Math.round((now-f0)/864e5)+1));
  return {g,n:g.n,en:g.en||g.n,from,to,D,dn,m:(g.m||[]).map(x=>x.n||x),cnt:Math.min(23,g.cnt||0),cv:g.cover||'b',key:g.key||'#maple24',c:g.c&&U9TC[g.c]?g.c:'sky',by:g.by||[]}}
function u9Seed(T){if(U9T.chat&&U9T.chat._for===T.n)return;const W=G9W,d1=new Date(T.from),d2=new Date(+T.from+864e5),M=T.m.length?T.m:['れな','あや'];
  const last=(T.g.last||'').split(/[:：]\s*/);
  U9T.chat=[{sys:`DAY 1 ・ ${g9Dd(d1)}(${W[d1.getDay()]})`},{sys:`${M[0]} が 乗りました`,k:'in'},
    {who:M[0],t:'のった〜!',tm:'8:02'},{who:M[1]||M[0],st:['star','sun'],tm:'8:03'},{me:1,t:'あした 9:00 に ひらくの 楽しみ',tm:'8:10',rd:M.length},
    {sys:`DAY 2 ・ ${g9Dd(d2)}(${W[d2.getDay()]})`},
    {who:last[0]&&last[1]?last[0]:(M[1]||M[0]),ph:'f',t:last[1]||'ついた!',tm:'10:24'},
    {who:M[0],t:'あと そらだけ。はよ 撮って',tm:'10:31'}];
  U9T.chat._for=T.n;U9T.un=T.g.un||2}
/* ---------- Trip の 部屋 ---------- */
function u9TripOpen(g){if(!g)return;const T=U9T.t=u9TData(g);u9Seed(T);let S=$('u9tr');
  if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="u9tr" id="u9tr" aria-label="Trip"></section>');S=$('u9tr')}
  u9TripDraw();requestAnimationFrame(()=>S.classList.add('on'));g9Hap('pop','ぷにっ(Trip)')}
function u9TripDraw(){const S=$('u9tr'),T=U9T.t;if(!S||!T)return;const tc=U9TC[T.c];S.style.setProperty('--tc',tc);
  const mem=['me',...T.m],P=['a','b','c','d','e','f'],took=[...new Set(T.by.slice(0,T.cnt))].slice(0,3);
  const last=[...U9T.chat].reverse().find(m=>!m.sys);
  const days=Array.from({length:T.D},(_,i)=>{const d=new Date(+T.from+i*864e5),k=i+1,h=`<div class="r"><b>DAY ${k}</b><small>${g9Dd(d)}(${G9W[d.getDay()]})</small>`;
    if(k<T.dn)return `<div class="u9td">${h}<em>23枚 ひらいた</em></div><div class="g">${[0,1,2].map(j=>`<i style="background-image:url(${PH[P[(i*3+j)%6]]})"></i>`).join('')}<i class="more" style="background-image:url(${PH[P[(i+4)%6]]})"><span>+20</span></i></div></div>`;
    if(k===T.dn)return `<div class="u9td">${h}<em class="lk">あした 9:00 に ひらく</em></div><div class="g">${[...Array(4)].map((_,j)=>j<Math.min(4,T.cnt)?`<span class="lkw"><i class="lk" style="display:block;background-image:url(${PH[P[(j+2)%6]]})"></i></span>`:'<i style="box-shadow:inset 0 0 0 1.5px rgba(255,255,255,.1);background:none"></i>').join('')}</div></div>`;
    return `<div class="u9td">${h}<em>まだ</em></div><div class="g no">${'<i></i>'.repeat(4)}</div></div>`}).join('');
  S.innerHTML=`<div class="u9tb"><button class="cb" data-a="x" aria-label="もどる">${U9TI.back}</button><div class="mid"><b>${g9E(T.en)}</b><small>DAY ${T.dn} / ${T.D}</small></div><button class="cb" data-a="set" aria-label="Trip の 設定">${U9TI.gear}</button></div>
   <div class="u9tsc" id="u9tsc">
    <section class="u9th" style="--cv:url(${PH[T.cv]})"><i class="cv"></i><h1>${g9E(T.en)}</h1><p>${g9E(T.n)} ・ ${g9Dd(T.from)} 〜 ${g9Dd(T.to)}</p>
      <div class="u9tm"><span class="avs">${mem.slice(0,5).map(n=>u9Av(n,34)).join('')}</span><b>${mem.length}人</b><button class="yobu" data-a="inv">${U9TI.yobu}よぶ</button></div></section>
    <section class="u9tt"><div class="hd"><span>DAY ${T.dn} ・ きょう</span><em>あした 9:00 に 現像</em></div>
      <div class="ct"><b>${T.cnt}<small>/ 23</small></b>${took.length?`<span class="who"><span class="avs">${took.map(x=>u9Av(x==='me'?'me':(T.m[x]||T.m[0]),26)).join('')}</span>が 撮った</span>`:''}</div>
      <div class="cells">${[...Array(23)].map((_,i)=>`<i class="${i<T.cnt?'on':''}"></i>`).join('')}</div>
      <p>みんなで <b>1日 23枚</b>。撮った 写真は あした 9:00 に いっしょに ひらく</p>
      <button class="shoot" data-a="shoot">${U9TI.cam}Trip で 撮る</button></section>
    <div class="u9tdh"><b>Film</b><small>日ごとの 写真</small></div>${days}
   </div>
   <button class="u9tcb" data-a="chat" aria-label="チャットを ひらく">${last?(last.me?u9MeAv(36):g9Av(last.who,36)):''}<span class="tx"><b>${last?(last.me?'あなた':g9E(last.who)):'チャット'}</b><small>${last?(last.st?'ステッカー':last.ph?'写真':g9E(last.t)):'最初の ひとことを 送ろう'}</small></span>${U9T.un?`<em class="ub">${U9T.un}</em>`:''}<i class="go">${U9TI.chat}</i></button>`;
  const sc=S.querySelector('#u9tsc');sc.addEventListener('scroll',()=>S.classList.toggle('sc',sc.scrollTop>80),{passive:true});
  const A=(k,f)=>{const b=S.querySelector(`[data-a="${k}"]`);if(b)b.onclick=f};
  A('x',()=>{S.classList.remove('on');g9Hap('soft')});
  A('set',()=>{g9Hap('pop');try{e9SetOpen(T.g)}catch(e){g9Toast('Trip の 設定')}});
  A('inv',()=>{g9Hap('pop','ぷにっ(よぶ)');try{__api.openShare()}catch(e){g9Toast('招待:リンク ・ QR ・ KEY '+T.key)}});
  A('shoot',()=>{g9Hap('shutter','パシャ');T.cnt=Math.min(23,T.cnt+1);T.g.cnt=T.cnt;T.by=[...T.by.slice(0,T.cnt-1),'me'];T.g.by=T.by;u9TripDraw();u9Push({sys:`たつき が 1枚 撮った(${T.cnt}/23)`,k:'shot'},1)});
  A('chat',()=>u9ChatOpen())}
/* ---------- チャット ---------- */
function u9Msg(m,i,arr){if(m.sys)return `<div class="u9sys">${m.k==='in'?U9TI.plane:m.k==='shot'?U9TI.cam:''}${g9E(m.sys)}</div>`;
  if(m.typing)return `<div class="u9m you first last"><span class="av">${g9Av(m.who,30)}</span><div class="mb"><small>${g9E(m.who)}</small><span class="u9typ"><i></i><i></i><i></i></span></div></div>`;
  const p=arr[i-1],n=arr[i+1],same=(a)=>a&&!a.sys&&!a.typing&&!!a.me===!!m.me&&a.who===m.who,first=!same(p),lastG=!same(n);
  const av=m.me?'':(lastG?g9Av(m.who,30):'');
  const body=m.st?`<i class="u9stk" style="--r:${m.me?6:-6}deg">${G9S[m.st[0]](G9C[m.st[1]])}</i>`:m.ph?`<div class="u9cph" style="--r:${m.me?2:-2}deg;--ph:url(${PH[m.ph]})"><i></i><b>${g9E(m.t||'')}</b></div>`:`<p class="u9bub">${g9E(m.t)}</p>`;
  const meta=lastG?`<span class="tm">${m.me&&m.rd?`<em>既読 ${m.rd}</em>`:''}${m.tm||''}</span>`:'';
  return `<div class="u9m ${m.me?'me':'you'}${first?' first':''}${lastG?' last':''}"><span class="av">${av}</span><div class="mb">${first&&!m.me?`<small>${g9E(m.who)}</small>`:''}<div class="meta">${body}${meta}</div></div></div>`}
function u9ChatDraw(pop){const L=$('u9tcl');if(!L)return;const arr=U9T.typing?[...U9T.chat,{typing:1,who:U9T.typing}]:U9T.chat;L.innerHTML=arr.map(u9Msg).join('');L.scrollTop=L.scrollHeight;
  if(pop&&!J9RM()){const e=L.lastElementChild;e&&e.animate([{transform:'translateY(14px) scale(.7)',opacity:0},{transform:'none',opacity:1}],{duration:380,easing:'cubic-bezier(.34,1.56,.64,1)'})}}
function u9Push(m,quiet){U9T.chat.push(m);const open=$('u9tc')&&$('u9tc').classList.contains('on');if(open)u9ChatDraw(1);else{if(!m.me&&!m.sys&&!quiet)U9T.un++;if($('u9tr')&&$('u9tr').classList.contains('on'))u9TripDraw()}}
const U9TR={q:['いま 祇園!','駅の まえ','おみやげ 見てる','あと 5分で つく'],ph:['え、いい 写真','それ あした 見たい','天才'],st:[['heart','pink'],['star','sun'],['spark','sky']],any:['それな','えらい','まって 今 行く','あした 9:00 楽しみ すぎ','笑','写真 撮った?','いいね']};
function u9Reply(src){const T=U9T.t;if(!T||!T.m.length)return;const who=T.m[Math.floor(Math.random()*T.m.length)];U9T.tm.forEach(clearTimeout);
  U9T.tm=[setTimeout(()=>{U9T.typing=who;if($('u9tc').classList.contains('on'))u9ChatDraw()},700),
   setTimeout(()=>{U9T.typing=null;const lastMe=[...U9T.chat].reverse().find(m=>m.me);if(lastMe)lastMe.rd=T.m.length;
     const r=src.st?{st:U9TR.st[Math.floor(Math.random()*3)]}:{t:(src.ph?U9TR.ph:/[?？]|どこ/.test(src.t||'')?U9TR.q:U9TR.any)[Math.floor(Math.random()*(src.ph?3:/[?？]|どこ/.test(src.t||'')?4:7))]};
     g9Hap('tick');u9Push(Object.assign({who,tm:u9Now()},r))},2300)]}
function u9ChatOpen(){const T=U9T.t;if(!T)return;let S=$('u9tc');
  if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="u9tc" id="u9tc" aria-label="Trip の チャット"></section>');S=$('u9tc')}
  S.style.setProperty('--tc',U9TC[T.c]);U9T.un=0;
  const stk=[['heart','pink'],['star','sun'],['spark','sky'],['flower','pink'],['hash','lime'],['star','lime'],['heart','sky'],['spark','sun']].filter(([k])=>G9S[k]);
  S.innerHTML=`<div class="u9tch"><button class="cb" data-a="x" aria-label="もどる">${U9TI.back}</button><span class="tt"><b>${g9E(T.en)}</b><small><i></i>${T.m.length+1}人 ・ DAY ${T.dn} / ${T.D}</small></span><span class="avs">${['me',...T.m].slice(0,4).map(n=>u9Av(n,28)).join('')}</span></div>
   <div class="u9tcl" id="u9tcl"></div>
   <div class="u9tin" id="u9tin">
     <div class="u9tq">${['はよ 撮って','いま どこ?','撮った!','9:00 たのしみ','おつかれ'].map(q=>`<button data-q="${q}">${q}</button>`).join('')}</div>
     <div class="u9tray ph" id="u9tph"><small class="u9trl">ひらいた 写真 だけ 送れる(きょうの 分は あした 9:00 から)</small>${['d','b','f','e'].map(p=>`<button data-ph="${p}" style="--ph:url(${PH[p]})" aria-label="写真を 送る"><i></i></button>`).join('')}</div>
     <div class="u9tray" id="u9tst">${stk.map(([k,c])=>`<button data-st="${k}" data-c="${c}" aria-label="ステッカー">${G9S[k](G9C[c])}</button>`).join('')}</div>
     <div class="u9tbar"><button class="ib" data-a="ph" aria-label="ひらいた 写真を 送る">${U9TI.img}</button><button class="ib" data-a="st" aria-label="ステッカー">${U9TI.stk}</button>
       <label><input id="u9tx" placeholder="メッセージ" maxlength="200" autocomplete="off" enterkeyhint="send"></label>
       <button class="go" data-a="send" disabled aria-label="送る">${U9TI.send}</button></div></div>`;
  const tx=S.querySelector('#u9tx'),go=S.querySelector('[data-a="send"]'),IN=S.querySelector('#u9tin'),PHT=S.querySelector('#u9tph'),STT=S.querySelector('#u9tst'),L=S.querySelector('#u9tcl');
  const fit=()=>{requestAnimationFrame(()=>{S.style.setProperty('--ib',IN.offsetHeight+'px');L.scrollTop=L.scrollHeight})};
  const tray=k=>{const a=k==='ph'?PHT:STT,b=k==='ph'?STT:PHT;const on=!a.classList.contains('on');a.classList.toggle('on',on);b.classList.remove('on');
    S.querySelector('[data-a="ph"]').classList.toggle('on',k==='ph'&&on);S.querySelector('[data-a="st"]').classList.toggle('on',k==='st'&&on);g9Hap('sel');fit()};
  const closeTray=()=>{PHT.classList.remove('on');STT.classList.remove('on');S.querySelectorAll('.ib').forEach(b=>b.classList.remove('on'));fit()};
  const send=m=>{const msg=Object.assign({me:1,tm:u9Now()},m);U9T.chat.push(msg);g9Hap(m.st?'heart':'pop','ぷにっ(送る)');u9ChatDraw(1);u9Reply(msg)};
  tx.oninput=()=>{go.disabled=!tx.value.trim();IN.classList.toggle('typing',!!tx.value);fit()};
  tx.onfocus=closeTray;
  const sendTx=()=>{const v=tx.value.trim();if(!v)return;tx.value='';go.disabled=true;IN.classList.remove('typing');fit();send({t:v})};
  go.onclick=sendTx;tx.onkeydown=e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();sendTx()}};
  S.querySelectorAll('[data-q]').forEach(b=>b.onclick=()=>send({t:b.dataset.q}));
  S.querySelector('[data-a="ph"]').onclick=()=>tray('ph');S.querySelector('[data-a="st"]').onclick=()=>tray('st');
  PHT.querySelectorAll('[data-ph]').forEach(b=>b.onclick=()=>{closeTray();send({ph:b.dataset.ph,t:`DAY 1 の 1枚`})});
  STT.querySelectorAll('[data-st]').forEach(b=>b.onclick=()=>{closeTray();send({st:[b.dataset.st,b.dataset.c]})});
  S.querySelector('[data-a="x"]').onclick=()=>{S.classList.remove('on');g9Hap('soft');u9TripDraw()};
  u9ChatDraw();fit();requestAnimationFrame(()=>S.classList.add('on'));g9Hap('pop','ぷにっ(チャット)')}
/* ---------- 古い 部屋(th77)と v98 の Trip 画面を この 部屋に まとめる ---------- */
th77Open=function(t){u9TripOpen(t)};th77Close=function(){const S=$('u9tr');S&&S.classList.remove('on')};
(()=>{const _h=h9TripOpen;h9TripOpen=function(t){const g=(typeof GRP!=='undefined'&&GRP.find(x=>x.trip));if(g&&!t){u9TripOpen(g);return}const T=Object.assign(h9Trip(),t||{});
  u9TripOpen({n:T.n,en:T.en&&T.en!=='SCHOOL TRIP'?T.en:T.n,from:+T.from,to:+T.from+864e5*2,m:(T.m||[]).filter(x=>!x.me).map(x=>({n:x.n})),cnt:T.shot||0,cover:T.cv||'f',key:T.key,c:T.c,un:0})}})();
window.__kit=Object.assign(window.__kit||{},{u9trip:()=>{const g=GRP.find(x=>x.trip);g&&u9TripOpen(g)},u9chat:()=>{const g=GRP.find(x=>x.trip);if(g){u9TripOpen(g);setTimeout(u9ChatOpen,400)}},U9T});
