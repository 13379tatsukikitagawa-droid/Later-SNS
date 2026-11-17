
/* ================= v77(PROMPT v83)・ Trip:わかりやすい 入力(1問ずつ)・ できた 後は Trip の ホーム(チャットは サブ)================= */
const TW77={on:false,s:0,g:null};const TH77={t:null,via:0};
const TW77C=['京都','沖縄','大阪','北海道','修学旅行','卒業旅行','合宿','ライブ遠征','部活の 遠征'];
const W77D=['日','月','火','水','木','金','土'];
const t77d=d=>`${d.getMonth()+1}/${d.getDate()}`;
const t77av=(f,s)=>f&&f.me?`<i class="av77" style="width:${s}px;height:${s}px;background-image:url(${PH.f})"></i>`:`<i class="av77" style="width:${s}px;height:${s}px;background:${avBg(f)}">${f.n[0]}</i>`;
function tw77Open(){const t0=new Date();t0.setHours(0,0,0,0);TW77.on=true;TW77.s=0;TW77.g={n:'',cover:'a',from:t0,to:new Date(+t0+2*864e5),m:FR.slice(0,2),pick:0};
  let W=$('tw77');if(!W){$('phone').insertAdjacentHTML('beforeend','<section class="tw77" id="tw77" aria-label="New trip"></section>');W=$('tw77')}
  tw77Draw();requestAnimationFrame(()=>W.classList.add('on'));hap('pop','ぷにっ(New trip)')}
function tw77Close(){const W=$('tw77');if(!W)return;TW77.on=false;W.classList.remove('on');hap('soft',null,{norip:1})}
function tw77Ticket(g){const d=Math.max(1,Math.round((g.to-g.from)/864e5)+1);
  return `<div class="tk77"><i class="cv" style="background-image:url(${PH[g.cover]})"></i><div class="tx"><span>LATTAG ・ TRIP PASS</span><b class="${g.n?'':'ph'}">${g.n||'どこへ?'}</b>
   <small>${t77d(g.from)} → ${t77d(g.to)} ・ ${d} DAYS</small><div class="mm">${[{me:1},...g.m].slice(0,6).map(f=>t77av(f,22)).join('')}<em>${g.m.length+1}人 ・ 1日 23枚</em></div></div><i class="nt"></i></div>`}
function tw77Step(){const g=TW77.g,s=TW77.s;
  if(s===0)return `<h2>どこへ 行く?</h2><label class="in77"><input id="tw77n" maxlength="20" placeholder="どこへ?" value="${g.n.replace(/"/g,'&quot;')}" autocomplete="off" enterkeyhint="next"></label>
    <div class="ch77">${TW77C.map(c=>`<button data-c="${c}" class="${g.n.startsWith(c)?'on':''}">${c}</button>`).join('')}</div><p class="ht">行き先 でも、イベント名 でも OK。あとで 変えられます。</p>`;
  if(s===1){const days=Array.from({length:21},(_,i)=>new Date(+new Date(new Date().setHours(0,0,0,0))+i*864e5)),n=Math.round((g.to-g.from)/864e5)+1;
    return `<h2>いつ?</h2><div class="ch77">${[['日帰り',1],['1泊2日',2],['2泊3日',3],['3泊4日',4]].map(([l,k])=>`<button data-len="${k}" class="${n===k?'on':''}">${l}</button>`).join('')}</div>
    <div class="cal77"><div class="wd">${W77D.map(w=>`<span>${w}</span>`).join('')}</div><div class="gd">${Array.from({length:days[0].getDay()},()=>'<i></i>').join('')}${days.map(d=>{const a=+d===+g.from,b=+d===+g.to,inr=d>g.from&&d<g.to;return `<button data-d="${+d}" class="${a?'a':''}${b?' b':''}${inr?' r':''}${a||b?' on':''}">${d.getDate()===1||+d===+days[0]?`<small>${d.getMonth()+1}月</small>`:''}${d.getDate()}</button>`}).join('')}</div></div>
    <p class="ht">${TW77.g.pick?'おわりの 日を タップ':'はじまりの 日 → おわりの 日 の 順に タップ'} ・ <b>${t77d(g.from)}(${W77D[g.from.getDay()]})→ ${t77d(g.to)}(${W77D[g.to.getDay()]})・ ${n}日</b></p>`}
  if(s===2){const pool=FR.concat((typeof FPOOL!=='undefined'?FPOOL:[]).slice(0,4)).filter((f,i,a)=>a.findIndex(x=>x.n===f.n)===i);
    return `<h2>だれと?</h2><div class="fr77">${pool.map((f,i)=>{const on=g.m.some(x=>x.n===f.n);return `<button data-f="${i}" class="${on?'on':''}">${t77av(f,44)}<b>${f.n}</b><u>${on?'✓':''}</u></button>`}).join('')}</div>
    <button class="ln77" data-a="link"><i>↗</i><span><b>リンクで よぶ</b><small>あとから QR ・ KEY でも 入れます</small></span></button><p class="ht"><b>${g.m.length+1}人</b> ・ 1日 23枚を みんなで 撮る</p>`}
  return `<h2>表紙を えらぶ</h2><div class="cv77">${['a','b','c','d','e','f'].map(p=>`<button data-p="${p}" class="${g.cover===p?'on':''}" style="background-image:url(${PH[p]})"></button>`).join('')}</div>
    <div class="sm77"><button data-go="0"><small>どこへ</small><b>${g.n}</b><em>変える</em></button><button data-go="1"><small>いつ</small><b>${t77d(g.from)} → ${t77d(g.to)}</b><em>変える</em></button><button data-go="2"><small>だれと</small><b>${g.m.length+1}人</b><em>変える</em></button></div>`}
function tw77Draw(dir){const W=$('tw77'),g=TW77.g,s=TW77.s,ok=s!==0||g.n.trim();
  W.innerHTML=`<div class="h"><button data-a="bk" aria-label="${s?'もどる':'とじる'}">${s?'‹':'×'}</button><div class="pg">${[0,1,2,3].map(i=>`<i class="${i<=s?'on':''}"></i>`).join('')}</div><span>${s+1} / 4</span></div>
   ${tw77Ticket(g)}<div class="q">${tw77Step()}</div><div class="f"><button class="nx${s===3?' go':''}" data-a="nx" ${ok?'':'disabled'}>${s===3?'Trip を つくる':'つぎへ'}</button></div>`;
  const q=W.querySelector('.q');if(dir&&!matchMedia('(prefers-reduced-motion:reduce)').matches)q.animate([{opacity:0,transform:`translateX(${dir*28}px)`},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.1,.4,1)'});
  const A=(sel,f)=>W.querySelectorAll(sel).forEach(b=>b.onclick=f);
  A('[data-a="bk"]',()=>{if(TW77.s){TW77.s--;tw77Draw(-1);hap('sel')}else tw77Close()});
  A('[data-a="nx"]',()=>{if(TW77.s<3){TW77.s++;tw77Draw(1);hap('click','カチッ(つぎへ)')}else tw77Make()});
  const I=$('tw77n');if(I){I.oninput=()=>{g.n=I.value;W.querySelector('.tk77 b').textContent=g.n||'どこへ?';W.querySelector('.tk77 b').classList.toggle('ph',!g.n);W.querySelector('[data-a="nx"]').disabled=!g.n.trim();hap('tick',null,{norip:1,gap:60})};setTimeout(()=>{try{I.focus({preventScroll:true})}catch(e){}},300)}
  A('[data-c]',e=>{const c=e.currentTarget.dataset.c;g.n=/旅行|合宿|遠征/.test(c)?c:c+' '+['日帰り','1泊2日','2泊3日','3泊4日'][Math.min(3,Math.round((g.to-g.from)/864e5))];tw77Draw();hap('sel','コツッ(えらぶ)')});
  A('[data-len]',e=>{const k=+e.currentTarget.dataset.len;g.to=new Date(+g.from+(k-1)*864e5);g.pick=0;tw77Draw();hap('sel')});
  A('[data-d]',e=>{const d=new Date(+e.currentTarget.dataset.d);if(!g.pick||d<g.from){g.from=d;g.to=d;g.pick=1}else{g.to=d;g.pick=0}tw77Draw();hap('tick',null,{norip:1})});
  A('[data-f]',e=>{const pool=FR.concat((typeof FPOOL!=='undefined'?FPOOL:[]).slice(0,4)).filter((f,i,a)=>a.findIndex(x=>x.n===f.n)===i);const f=pool[+e.currentTarget.dataset.f];const i=g.m.findIndex(x=>x.n===f.n);i>=0?g.m.splice(i,1):g.m.push(f);tw77Draw();hap(i>=0?'soft':'pop')});
  A('[data-a="link"]',()=>{hap('pop');try{openShare({t:'Lattag の Trip に 入ろう\nhttps://lattag.app/t/'+encodeURIComponent(g.n||'trip'),h:g.n||'Trip'})}catch(e){}});
  A('[data-p]',e=>{g.cover=e.currentTarget.dataset.p;tw77Draw();hap('sel');const t=$('tw77').querySelector('.tk77');!matchMedia('(prefers-reduced-motion:reduce)').matches&&t.animate([{transform:'scale(.97)'},{transform:'none'}],{duration:320,easing:'cubic-bezier(.3,1.5,.5,1)'})});
  A('[data-go]',e=>{TW77.s=+e.currentTarget.dataset.go;tw77Draw(-1);hap('sel')})}
function tw77Make(){const g=TW77.g;const t={n:g.n.trim(),en:tEn(g.n.trim()),cover:g.cover,from:g.from,to:g.to,m:g.m.slice(),trip:true,cnt:0,by:[],key:tKey(),sub:(g.m.length+1)+'人',un:0,last:'Trip が はじまりました'};
  GRP.unshift(t);hap('projector','ジジジ(パスを 印刷)',{norip:1});const k=$('tw77').querySelector('.tk77');
  !matchMedia('(prefers-reduced-motion:reduce)').matches&&k.animate([{transform:'none'},{transform:'translateY(6px) scale(.98)',offset:.2},{transform:'translateY(-10px) rotate(-1.5deg)'},{transform:'none'}],{duration:800,easing:'cubic-bezier(.3,1.3,.5,1)'});
  setTimeout(()=>{hap('success','トトトン(できた)',{norip:1});tw77Close();try{renderGroups();renderOrb()}catch(e){}openPass(t,true)},850)}
/* ---------- Trip の ホーム(メイン)---------- */
function th77Open(t){if(!t)return;TH77.t=t;let S=$('th77');if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="th77" id="th77" aria-label="Trip"></section>');S=$('th77')}th77Draw();requestAnimationFrame(()=>S.classList.add('on'));hap('pop','ぷにっ(Trip)')}
function th77Close(){const S=$('th77');S&&S.classList.remove('on');hap('soft',null,{norip:1})}
function th77Draw(){const S=$('th77'),t=TH77.t,D=tDays(t),dn=tDayNo(t),c=Math.min(23,t.cnt||0),mem=[{me:1},...(t.m||[])],P=['a','b','c','d','e','f'];
  const days=Array.from({length:D},(_,i)=>{const d=new Date(+t.from+i*864e5);return{i:i+1,d}});
  const msgs=[['れな','あと そらだけ。はよ 撮って'],['あや','きのうの 夕焼け、だれ?']];
  S.innerHTML=`<div class="sc">
   <div class="hero" style="background-image:url(${PH[t.cover||'a']})"><i class="sh"></i>
    <div class="bar"><button data-a="x" aria-label="もどる">‹</button><span>TRIP ・ DAY ${dn} / ${D}</span><div><button data-a="qr" aria-label="パス"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/></svg></button><button data-a="set" aria-label="設定">···</button></div></div>
    <div class="ttl"><b>${t.en||t.n}</b><small>${t.n} ・ ${t77d(t.from)} — ${t77d(t.to)}</small>
     <div class="mem">${mem.slice(0,7).map(f=>t77av(f,30)).join('')}<button data-a="inv">+ よぶ</button></div></div></div>
   <section class="tdy"><div class="r"><div><small>TODAY ・ DAY ${dn}</small><b>${c}<em> / 23</em></b></div><div class="by">${mem.slice(0,Math.min(mem.length,1+Math.floor(c/3))).map(f=>t77av(f,26)).join('')}<span>が 撮った</span></div></div>
    <div class="film">${Array.from({length:23},(_,i)=>`<i class="${i<c?'on':''}"></i>`).join('')}</div>
    <p>撮った 写真は <b>あした 9:00</b> に みんなで 現像</p>
    <button class="shoot" data-a="shoot"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>Trip で 撮る</button></section>
   <section class="dys"><h3>日ごとの フィルム</h3>${days.map(({i,d})=>{const past=i<dn,now=i===dn;
     return `<div class="dy ${past?'past':now?'now':'fut'}"><div class="dh"><b>DAY ${i}</b><span>${t77d(d)}(${W77D[d.getDay()]})</span><em>${past?'23枚 ひらいた':now?'あした 9:00 に ひらく':'まだ'}</em></div>
      <div class="dg">${past?P.concat(P).slice(0,7).map((p,j)=>`<i style="background-image:url(${PH[P[(j+i)%6]]})"></i>`).join('')+'<i class="mo">+16</i>':now?Array.from({length:4},(_,j)=>`<i class="lk" style="background-image:url(${PH[P[(j+2)%6]]})"><u>🔒</u></i>`).join(''):Array.from({length:4},()=>'<i class="em"></i>').join('')}</div></div>`}).join('')}</section>
  </div>
  <button class="cpk" data-a="chat"><span><b>${msgs[0][0]}</b> ${msgs[0][1]}</span></button>
  <button class="cbt" data-a="chat" aria-label="チャット"><svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1116 0 8 8 0 01-11.6 7.1L4 20l1-4.2A7.9 7.9 0 014 12z"/></svg>${t.un?`<u>${t.un}</u>`:'<u>2</u>'}</button>`;
  const A=(sel,f)=>S.querySelectorAll(sel).forEach(b=>b.onclick=f);
  A('[data-a="x"]',th77Close);A('[data-a="qr"]',()=>{hap('pop');openPass(t)});A('[data-a="set"]',()=>tripSet(t));
  A('[data-a="inv"]',()=>{hap('pop');openPass(t)});
  A('[data-a="chat"]',()=>{hap('pop','ぷにっ(チャット)');TH77.via=1;openRoom(t)});
  A('[data-a="shoot"]',()=>{if((t.cnt||0)>=23){hap('warn');try{_toast('今日の 23枚が うまりました ・ あした 9:00 に 現像')}catch(e){}return}hap('shutter','カシャッ(Trip に 1枚)');t.cnt=(t.cnt||0)+1;(t.by=t.by||[]).push('me');
    const y=S.querySelector('.sc').scrollTop;th77Draw();S.querySelector('.sc').scrollTop=y;const f=S.querySelectorAll('.film i')[t.cnt-1];f&&!matchMedia('(prefers-reduced-motion:reduce)').matches&&f.animate([{transform:'scaleY(1.8)',filter:'brightness(2)'},{transform:'none',filter:'none'}],{duration:520,easing:'cubic-bezier(.3,1.5,.5,1)'})})}
/* つなぐ:New trip = 新しい 入力 ・ trip の 部屋 = Trip の ホーム(チャットは そこから)*/
{const _o=openTrip;openTrip=function(edit){if(edit)return _o(edit);tw77Open()}}
{const _r=openRoom;openRoom=function(g){if(g&&g.trip&&!TH77.via){th77Open(g);return}TH77.via=0;return _r(g)}}
{const _p=openPass;openPass=function(t,fresh){_p(t,fresh);if(fresh){const b=document.querySelector('#tpv .dn[data-a="x"]');b&&b.addEventListener('click',()=>setTimeout(()=>th77Open(t),380))}}}
{const _t=tripPage;tripPage=function(){_t();const C=$('hpc2'),t=GRP.find(g=>g.trip);if(!C||!t)return;const ch=C.querySelector('[data-a="chat"]');ch&&(ch.onclick=e=>{e.stopPropagation();TH77.via=1;openRoom(t)});
  if(!C._th77){C._th77=1;C.addEventListener('click',e=>{if(e.target.closest('button'))return;const tt=GRP.find(g=>g.trip);tt&&th77Open(tt)})}}}
Object.assign(window.__kit||(window.__kit={}),{openTrip:()=>openTrip(),tw77:(s,o={})=>{if(!TW77.on)tw77Open();Object.assign(TW77.g,o);TW77.s=s||0;tw77Draw()},tw77Make:()=>tw77Make(),th77:()=>{const t=GRP.find(g=>g.trip);t&&th77Open(t)}});
