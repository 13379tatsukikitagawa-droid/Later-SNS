/* ===== v97(モック v97 ・ PROMPT v110) =====
   1. Mondo を なくす(タブ ・ 使いかた ・ ウィジェット から 消す)
   2. 下の タブは Friends | Trip
   3. Trip:上に 週の 帯(Trip の 日に 色の 線)・ 下に いま / これから / おわった の カード
   4. Friends:ステッカー × チェキ で 作りなおし(今日の あなた ・ 友だちの 列 ・ チェキの フィード ・ まだ の 人)
   5. 全体の ポップ:ライム + ピンク ・ 空色 ・ 黄色(ステッカーと Trip の 色分け だけ)・ ぷにっと 跳ねる
   名前:g9 */
const G9={tab:'friends',log:[],wk:0,sel:null,shot:0,react:{}};
const G9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const G9C={lime:'#C8F25A',pink:'#FF7AB6',sky:'#6EC8FF',sun:'#FFD84D'};
const G9I={
  bell:'<svg viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 1112 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 004 0"/></svg>',
  ppl:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2"/><path d="M3 19c.6-3.2 3-5 6-5s5.4 1.8 6 5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.2c2.4.2 4.2 1.8 4.8 4.8"/></svg>',
  tkt:'<svg viewBox="0 0 24 24"><path d="M4 7.5A1.5 1.5 0 015.5 6h13A1.5 1.5 0 0120 7.5V10a2 2 0 000 4v2.5a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 16.5V14a2 2 0 000-4z"/><path d="M14.5 6.5v11" stroke-dasharray="1.6 2"/></svg>',
  cam:'<svg viewBox="0 0 24 24"><path d="M4 8.5A1.5 1.5 0 015.5 7H8l1.5-2h5L16 7h2.5A1.5 1.5 0 0120 8.5v9a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>',
  plus:'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  key:'<svg viewBox="0 0 24 24"><circle cx="8" cy="12" r="3.5"/><path d="M11.5 12H20M17 12v3M20 12v2"/></svg>',
  lock:'<svg viewBox="0 0 24 24"><rect x="5.5" y="10.5" width="13" height="9" rx="2.2"/><path d="M8.5 10.5V8a3.5 3.5 0 017 0v2.5"/></svg>',
  more:'<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="18" cy="12" r="1.4"/></svg>',
  go:'<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>',
  back:'<svg viewBox="0 0 24 24"><path d="M15 6l-6 6 6 6"/></svg>',
  poke:'<svg viewBox="0 0 24 24"><path d="M8 13V6.5a1.5 1.5 0 013 0V12M11 11.5V5a1.5 1.5 0 013 0v6.5M14 11.5V7a1.5 1.5 0 013 0v6c0 4-2.5 7-6 7-2.4 0-3.7-1-5-3l-2-3.3a1.4 1.4 0 012.3-1.6L8 14"/></svg>',
  search:'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6"/><path d="M16 16l4 4"/></svg>'};
/* ステッカー(キャラクター なし ・ 形と 字 だけ) */
const G9S={
  heart:c=>`<svg viewBox="0 0 40 40"><path d="M20 34S5 25 5 14.5A7.5 7.5 0 0120 11a7.5 7.5 0 0115 3.5C35 25 20 34 20 34z" fill="${c}" stroke="#fff" stroke-width="3" stroke-linejoin="round"/></svg>`,
  star:c=>`<svg viewBox="0 0 40 40"><path d="M20 3l4.9 10.6 11.6 1.3-8.6 7.9 2.4 11.4L20 28.4 9.7 34.2l2.4-11.4-8.6-7.9 11.6-1.3z" fill="${c}" stroke="#fff" stroke-width="3" stroke-linejoin="round"/></svg>`,
  spark:c=>`<svg viewBox="0 0 40 40"><path d="M20 2c1.6 9 4.4 12 14 14-9.6 2-12.4 5-14 14-1.6-9-4.4-12-14-14 9.6-2 12.4-5 14-14z" fill="${c}" stroke="#fff" stroke-width="3" stroke-linejoin="round" transform="translate(0 4)"/></svg>`,
  flower:c=>`<svg viewBox="0 0 40 40"><g fill="${c}" stroke="#fff" stroke-width="3">${[0,72,144,216,288].map(a=>`<circle cx="20" cy="10" r="7.5" transform="rotate(${a} 20 20)"/>`).join('')}</g><circle cx="20" cy="20" r="6" fill="#fff"/><circle cx="20" cy="20" r="3.2" fill="#111"/></svg>`,
  hash:c=>`<svg viewBox="0 0 40 40"><rect x="3" y="3" width="34" height="34" rx="10" fill="${c}" stroke="#fff" stroke-width="3"/><text x="20" y="29" text-anchor="middle" font-family="Inter,sans-serif" font-weight="900" font-size="24" fill="#111">#</text></svg>`};
const g9St=(k,c,cls='',st='')=>`<i class="g9st ${cls}" style="${st}" aria-hidden="true">${G9S[k](G9C[c]||c)}</i>`;
const g9Tag=(t,c,cls='',st='')=>`<i class="g9tag ${cls}" style="--c:${G9C[c]||c};${st}" aria-hidden="true">${t}</i>`;
const g9E=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function g9Hap(n,w,o){try{hap(n,w,Object.assign({norip:1},o||{}))}catch(e){}}
function g9Toast(t){try{toast(t)}catch(e){}}
function g9Cd(){const d=new Date(),t=new Date(d);t.setHours(9,0,0,0);if(t<=d)t.setDate(t.getDate()+1);const s=Math.floor((t-d)/1000);return [Math.floor(s/3600),Math.floor(s%3600/60)].map(n=>String(n).padStart(2,'0')).join(':')}
const g9Day=n=>{const d=new Date();d.setHours(0,0,0,0);d.setDate(d.getDate()+n);return d};
const g9Dd=d=>`${d.getMonth()+1}/${d.getDate()}`;
const G9W=['日','月','火','水','木','金','土'];

/* ---------------- 見本の データ ---------------- */
const G9F=[
  {n:'ようこ',c:'pink',p:'b',t:'22:14',cap:'夜の コンビニ、最高',tilt:-1.6,st:['heart','pink'],posted:1},
  {n:'れな',c:'sky',p:'e',t:'18:02',cap:'部活 おわり!',tilt:1.4,st:['star','sun'],posted:1},
  {n:'かい',c:'sun',p:'d',t:'12:40',cap:'学食の カレー',tilt:-1,st:['flower','sky'],posted:1},
  {n:'みお',c:'lime',posted:0},{n:'そら',c:'pink',posted:0}];
function g9Trips(){return [
  {id:'osaka',n:'大阪',en:'OSAKA',c:'pink',cv:'b',from:g9Day(-1),to:g9Day(1),m:['ようこ','れな','かい'],shot:14,cap:23},
  {id:'camp',n:'部活の 合宿',en:'CAMP',c:'sun',cv:'d',from:g9Day(4),to:g9Day(6),m:['かい','そら','みお','れな']},
  {id:'okinawa',n:'沖縄',en:'OKINAWA',c:'sky',cv:'e',from:g9Day(13),to:g9Day(16),m:['ようこ','みお']},
  {id:'kyoto',n:'京都',en:'KYOTO',c:'lime',cv:'c',from:g9Day(-24),to:g9Day(-22),m:['れな','そら'],shot:41},
  {id:'izu',n:'伊豆',en:'IZU',c:'sky',cv:'f',from:g9Day(-48),to:g9Day(-47),m:['かい'],shot:18}]}
G9.trips=g9Trips();
const g9State=t=>{const now=g9Day(0);return t.to<now?'done':t.from>now?'next':'now'};
const g9Av=(n,s=28)=>{const f=(typeof FPOOL!=='undefined'&&FPOOL.find(x=>x.n===n))||{n,g:['#fff','#ccc','#999']};let bg='#333';try{bg=avBg(f)}catch(e){}return `<i class="g9av" style="width:${s}px;height:${s}px;background:${bg};font-size:${Math.round(s*.42)}px">${g9E(n[0])}</i>`};

/* ---------------- 外がわ(上 ・ 下の タブ) ---------------- */
function g9Open(tab){let S=$('g9');if(!S){$('phone').insertAdjacentHTML('beforeend',`<section class="g9" id="g9" aria-label="Home">
   <header class="g9hd"><button class="g9ib" data-a="bell" aria-label="お知らせ">${G9I.bell}<em class="g9bd">2</em></button>
    <div class="g9tt"><b id="g9tt">Friends</b><small id="g9sub"></small></div>
    <button class="g9ib g9me" data-a="me" aria-label="プロフィール" style="background-image:url(${PH.c})"></button></header>
   <div class="g9pg" id="g9pg"></div>
   <nav class="g9tb" role="tablist"><i class="g9tbk"></i>
    <button role="tab" data-t="friends">${G9I.ppl}<span>Friends</span></button>
    <button role="tab" data-t="trip">${G9I.tkt}<span>Trip</span></button></nav></section>`);S=$('g9');
    S.querySelectorAll('.g9tb button').forEach(b=>b.onclick=()=>{if(b.dataset.t===G9.tab){S.querySelector('.g9pg').scrollTo({top:0,behavior:'smooth'});return}g9Hap('sel','コツッ(タブ)');g9Go(b.dataset.t)});
    S.querySelector('[data-a="bell"]').onclick=()=>{g9Hap('pop');try{f9Open()}catch(e){g9Toast('お知らせ')}};
    S.querySelector('[data-a="me"]').onclick=()=>{g9Hap('pop');g9Toast('プロフィール(モック)')};
    }
  S.classList.add('on');g9Go(tab||G9.tab,1);G9.log.push('open:'+(tab||G9.tab))}
function g9Close(){const S=$('g9');if(S)S.classList.remove('on');clearInterval(G9.cd)}
function g9Go(t,first){G9.tab=t;const S=$('g9'),P=$('g9pg');
  S.querySelectorAll('.g9tb button').forEach(b=>{const on=b.dataset.t===t;b.classList.toggle('on',on);b.setAttribute('aria-selected',on)});
  S.querySelector('.g9tb').dataset.t=t;
  $('g9tt').textContent=t==='trip'?'Trip':'Friends';
  P.className='g9pg is-'+t;P.innerHTML=t==='trip'?g9TripHTML():g9FriendsHTML();P.scrollTop=0;
  if(!first&&!G9RM()){P.classList.add('in');setTimeout(()=>P.classList.remove('in'),420)}
  t==='trip'?g9TripBind():g9FriendsBind();G9.log.push('tab:'+t)}

/* ================= Friends ================= */
function g9FriendsHTML(){const posted=G9F.filter(f=>f.posted),wait=G9F.filter(f=>!f.posted),sh=G9.shot;
  $('g9sub').textContent=`きのう ・ ${posted.length}人が 公開 ・ ${wait.length}人 まだ`;
  const dots=[0,1,2].map(i=>`<i class="${i<sh?'on':''}"></i>`).join('');
  return `
  <section class="g9me-card${sh?' has':''}">
    <div class="g9mc-ck" style="--r:-6deg">
      ${sh?`<div class="g9ck sm"><i class="ph lk" style="background-image:url(${PH.a})"></i><b class="cp">今日の 1枚</b></div>`
          :`<button class="g9ck sm empty" data-a="shoot" aria-label="撮る"><i class="ph">${G9I.cam}</i><b class="cp">まだ 0枚</b></button>`}
      <i class="g9tape" style="--c:${G9C.sun}"></i>
      ${g9St('star','pink','','right:-12px;top:-14px;width:34px;--r:14deg')}
    </div>
    <div class="g9mc-tx">
      <small class="g9k">TODAY'S ROLL</small>
      <b>${sh?`あと ${3-sh}枚 撮れる`:'今日の 1枚を 撮ろう'}</b>
      <span class="g9dots" aria-label="${sh} / 3 枚">${dots}<em>${sh} / 3</em></span>
      <span class="g9cd">${G9I.lock}9:00 に ひらく ・ あと <u id="g9cd">${g9Cd()}</u></span>
      <button class="g9btn lime" data-a="shoot">${G9I.cam}<span>撮る</span></button>
    </div>
  </section>

  <section class="g9row" aria-label="ともだち">
    <button class="g9fr g9add" data-a="find"><i class="g9rg">${G9I.search}</i><small>さがす</small></button>
    ${G9F.map((f,i)=>`<button class="g9fr${f.posted?' ok':''}" data-f="${i}" style="--c:${G9C[f.c]}"><i class="g9rg">${g9Av(f.n,52)}</i>${f.posted?g9St('hash',f.c,'fx'):''}<small>${f.n}</small></button>`).join('')}
  </section>

  <h3 class="g9h"><span>きのうの 1枚</span>${g9Tag('9:00 OPEN','sun','','--r:-4deg')}</h3>
  ${posted.map((f,i)=>`
  <article class="g9po" style="--t:${f.tilt}deg;--c:${G9C[f.c]}" data-i="${i}">
    <div class="g9poh">${g9Av(f.n,36)}<span><b>${f.n}</b><small>${f.t}</small></span><button class="g9mo" aria-label="その他">${G9I.more}</button></div>
    <div class="g9ck big">
      <i class="ph" style="background-image:url(${PH[f.p]})"></i>
      <b class="cp">${g9E(f.cap)}</b>
      ${g9St(f.st[0],f.st[1],'g9pin',`right:-14px;top:-16px;width:46px;--r:${i%2?-12:12}deg`)}
      ${i===0?`<i class="g9tape" style="--c:${G9C.sky};left:-10px;top:14px;--r:-38deg"></i>`:''}
    </div>
    <div class="g9re">${[['heart','pink','すき'],['star','sun','いいね'],['spark','sky','すごい']].map(([k,c,l])=>{const n=(G9.react[i+k]||0)+[[5,2,1],[3,4,2],[2,1,3]][i%3][['heart','star','spark'].indexOf(k)];return `<button data-r="${k}" data-c="${c}" aria-label="${l}"><i>${G9S[k](G9C[c])}</i><em>${n}</em></button>`}).join('')}
      <button class="g9cm" data-a="chat">チャット</button></div>
  </article>`).join('')}

  <section class="g9wait"><h3 class="g9h"><span>まだ の 人</span><em>${wait.length}人</em></h3>
    ${wait.map(f=>`<div class="g9wr">${g9Av(f.n,40)}<span><b>${f.n}</b><small>まだ 公開して いません</small></span><button class="g9btn sky sm" data-poke="${f.n}">${G9I.poke}<span>つつく</span></button></div>`).join('')}
  </section>

  <section class="g9end">
    <div class="g9roll">${['pink','sun','sky','lime'].map((c,i)=>`<i style="--c:${G9C[c]};--i:${i}"></i>`).join('')}</div>
    ${g9St('spark','sun','','left:22%;top:6px;width:26px;--r:-10deg')}${g9St('flower','pink','','right:20%;top:30px;width:30px;--r:16deg')}
    <small class="g9k">END OF ROLL</small><b>きのうの フィルムは ここまで</b><p>あした 9:00 に、また みんなの 1枚が ひらきます</p>
  </section>`}
function g9FriendsBind(){const P=$('g9pg');
  P.querySelectorAll('[data-a="shoot"]').forEach(b=>b.onclick=()=>{g9Hap('shutter','パシャ(撮る)');G9.shot=Math.min(3,G9.shot+1);g9Go('friends',1);const c=P.querySelector('.g9mc-ck');if(c&&!G9RM()){c.classList.add('pop')}});
  P.querySelector('[data-a="find"]').onclick=()=>{g9Hap('pop');g9Toast('さがす 画面へ(モック)')};
  P.querySelectorAll('[data-f]').forEach(b=>b.onclick=()=>{g9Hap('pop','ぷにっ');const f=G9F[+b.dataset.f];if(!f.posted){g9Toast(f.n+' は まだ 撮って いません');return}const el=P.querySelectorAll('.g9po')[G9F.filter(x=>x.posted).indexOf(f)];if(el){el.scrollIntoView({behavior:G9RM()?'auto':'smooth',block:'center'});el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash')}});
  P.querySelectorAll('.g9re [data-r]').forEach(b=>b.onclick=()=>{const po=b.closest('.g9po'),i=+po.dataset.i,k=b.dataset.r;G9.react[i+k]=(G9.react[i+k]||0)+1;const em=b.querySelector('em');em.textContent=+em.textContent+1;g9Hap('heart','トクン(ステッカー)');g9Burst(b,k,b.dataset.c)});
  P.querySelectorAll('[data-poke]').forEach(b=>b.onclick=()=>{g9Hap('knock','コンコン(つつく)');b.classList.add('done');b.querySelector('span').textContent='つついた';b.disabled=true});
  P.querySelectorAll('[data-a="chat"]').forEach(b=>b.onclick=()=>{g9Hap('pop');g9Toast('チャット(モック)')});
  clearInterval(G9.cd);G9.cd=setInterval(()=>{const c=$('g9cd');if(c)c.textContent=g9Cd()},1000)}
/* ステッカーが ぽんっと 飛ぶ */
function g9Burst(b,k,c){if(G9RM())return;const r=b.getBoundingClientRect(),ph=$('phone').getBoundingClientRect();
  const s=document.createElement('i');s.className='g9fly';s.innerHTML=G9S[k](G9C[c]);s.style.left=(r.left-ph.left+r.width/2-20)+'px';s.style.top=(r.top-ph.top-10)+'px';
  $('phone').appendChild(s);s.animate([{transform:'translateY(0) scale(.4) rotate(0)',opacity:0},{transform:'translateY(-30px) scale(1.25) rotate(-12deg)',opacity:1,offset:.35},{transform:'translateY(-70px) scale(1) rotate(10deg)',opacity:0}],{duration:700,easing:'cubic-bezier(.2,.8,.2,1)'}).onfinish=()=>s.remove()}

/* ================= Trip ================= */
function g9WeekStart(off){const d=g9Day(0);const w=(d.getDay()+6)%7;d.setDate(d.getDate()-w+off*7);return d}
function g9WeekHTML(off){const s=g9WeekStart(off),days=[...Array(7)].map((_,i)=>{const d=new Date(s);d.setDate(s.getDate()+i);return d}),today=+g9Day(0),e=new Date(days[6]);
  const lanes=[];G9.trips.filter(t=>t.to>=s&&t.from<=e).sort((a,b)=>a.from-b.from).forEach(t=>{let L=lanes.findIndex(l=>l.every(x=>x.to<t.from||x.from>t.to));if(L<0){lanes.push([]);L=lanes.length-1}lanes[L].push(t)});
  const bar=(t,L)=>{const a=Math.max(0,Math.round((t.from-s)/864e5)),b=Math.min(6,Math.round((t.to-s)/864e5)),st=t.from>=s,en=t.to<=e;
    return `<button class="g9bar${st?' st':''}${en?' g9en':''}" data-trip="${t.id}" style="--c:${G9C[t.c]};grid-column:${a+1}/${b+2};grid-row:${L+1}"><span>${b-a>=1?g9E(t.n):''}</span></button>`};
  return `<div class="g9wk"><div class="g9wd">${days.map(d=>{const has=G9.trips.some(t=>t.from<=d&&t.to>=d);return `<button class="g9dy${+d===today?' td':''}${G9.sel===+d?' sel':''}" data-d="${+d}" aria-label="${g9Dd(d)}"><small>${G9W[d.getDay()]}</small><b>${d.getDate()}</b>${has?'<i></i>':''}</button>`}).join('')}</div>
    <div class="g9ln" style="grid-template-rows:repeat(${Math.max(1,lanes.length)},18px)">${lanes.map((l,L)=>l.map(t=>bar(t,L)).join('')).join('')||'<span class="g9no">この 週は Trip なし</span>'}</div></div>`}
function g9TripHTML(){const T=G9.trips,now=T.filter(t=>g9State(t)==='now'),next=T.filter(t=>g9State(t)==='next').sort((a,b)=>a.from-b.from),done=T.filter(t=>g9State(t)==='done').sort((a,b)=>b.to-a.to);
  $('g9sub').textContent=`いま ${now.length} ・ これから ${next.length} ・ おわった ${done.length}`;
  const ws=g9WeekStart(G9.wk),we=new Date(ws);we.setDate(ws.getDate()+6);
  const dayN=t=>Math.round((g9Day(0)-t.from)/864e5)+1,len=t=>Math.round((t.to-t.from)/864e5)+1,until=t=>Math.round((t.from-g9Day(0))/864e5);
  if(!T.length)return `<section class="g9emp">${g9St('hash','lime','','position:relative;width:64px;display:block;margin:0 auto 14px;--r:-8deg')}<b>まだ Trip が ありません</b><p>旅の あいだ、みんなで 1日 23枚</p><div class="g9act"><button class="g9btn lime" data-a="new">${G9I.plus}<span>新しい Trip</span></button><button class="g9btn g9ghost" data-a="key">${G9I.key}<span>KEY で 入る</span></button></div></section>`;
  return `
  <section class="g9cal">
    <div class="g9calh"><button class="g9ar" data-w="-1" aria-label="前の 週">${G9I.back}</button><b>${ws.getMonth()+1}月 <small>${g9Dd(ws)} 〜 ${g9Dd(we)}</small></b>${G9.wk?'<button class="g9now" data-w="0">今週</button>':''}<button class="g9ar" data-w="1" aria-label="次の 週">${G9I.go}</button></div>
    ${g9WeekHTML(G9.wk)}
  </section>
  <div class="g9act"><button class="g9btn lime" data-a="new">${G9I.plus}<span>新しい Trip</span></button><button class="g9btn g9ghost" data-a="key">${G9I.key}<span>KEY で 入る</span></button></div>

  ${now.length?`<h3 class="g9h"><span>いま</span>${g9Tag('LIVE','pink','live','--r:-3deg')}</h3>`:''}
  ${now.map(t=>`<button class="g9now-card" data-trip="${t.id}" style="--c:${G9C[t.c]}">
    <i class="cv" style="background-image:url(${PH[t.cv]})"></i><i class="g9sh"></i>
    <i class="g9tape" style="--c:${G9C[t.c]};right:22px;top:-8px;--r:6deg"></i>
    ${g9Tag(`DAY ${dayN(t)} / ${len(t)}`,t.c,'dy','')}
    <span class="nm"><small>${t.en}</small><b>${g9E(t.n)}</b><em>${g9Dd(t.from)} 〜 ${g9Dd(t.to)}</em></span>
    <span class="ft"><span class="mm">${['あなた',...t.m].slice(0,4).map(n=>n==='あなた'?`<i class="g9av me" style="width:28px;height:28px;background-image:url(${PH.c})"></i>`:g9Av(n,28)).join('')}${t.m.length>3?`<em>+${t.m.length-3}</em>`:''}</span>
      <span class="pg"><b>${t.shot}<small> / ${t.cap}枚</small></b><i><u style="width:${t.shot/t.cap*100}%"></u></i></span>
      <i class="g9go">${G9I.go}</i></span></button>`).join('')}

  ${next.length?`<h3 class="g9h"><span>これから</span><em>${next.length}</em></h3>`:''}
  <div class="g9list">${next.map(t=>`<button class="g9nx" data-trip="${t.id}" style="--c:${G9C[t.c]}">
    <span class="dt"><small>${G9W[t.from.getDay()]}</small><b>${t.from.getDate()}</b><em>${t.from.getMonth()+1}月</em></span>
    <span class="tx"><b>${g9E(t.n)}</b><small>${g9Dd(t.from)} 〜 ${g9Dd(t.to)} ・ ${len(t)}日 ・ ${t.m.length+1}人</small></span>
    ${g9Tag(`あと ${until(t)}日`,t.c,'cd','')}
    <i class="cv" style="background-image:url(${PH[t.cv]})"></i></button>`).join('')}</div>

  ${done.length?`<h3 class="g9h"><span>おわった</span><em>アルバム</em></h3>`:''}
  <div class="g9al">${done.map((t,i)=>`<button class="g9ab" data-trip="${t.id}" style="--c:${G9C[t.c]};--t:${i%2?2.5:-2.5}deg">
    <span class="g9stk"><i class="g9ck xs b2" style="--r:7deg"><i class="ph" style="background-image:url(${PH[['a','d','f','b'][i%4]]})"></i></i><i class="g9ck xs" style="--r:0deg"><i class="ph" style="background-image:url(${PH[t.cv]})"></i><b class="cp">${g9E(t.n)}</b></i></span>
    ${g9St('hash',t.c,'','right:4px;top:-6px;width:30px;--r:12deg')}
    <small>${g9Dd(t.from)} ・ ${t.shot}枚</small></button>`).join('')}</div>
  <p class="g9foot">Trip は 旅の あいだ みんなで 1日 23枚。おわったら アルバムに なります</p>`}
function g9TripBind(){const P=$('g9pg');clearInterval(G9.cd);
  P.querySelectorAll('[data-w]').forEach(b=>b.onclick=()=>{const v=+b.dataset.w;G9.wk=v===0?0:G9.wk+v;g9Hap('notch','カチ(週)');const y=P.scrollTop;g9Go('trip',1);P.scrollTop=y;const c=P.querySelector('.g9wk');if(c&&!G9RM())c.animate([{transform:`translateX(${v>0?24:-24}px)`,opacity:.3},{transform:'none',opacity:1}],{duration:280,easing:'cubic-bezier(.34,1.56,.64,1)'})});
  P.querySelectorAll('.g9dy').forEach(b=>b.onclick=()=>{const d=+b.dataset.d;G9.sel=G9.sel===d?null:d;g9Hap('sel');P.querySelectorAll('.g9dy').forEach(x=>x.classList.toggle('sel',+x.dataset.d===G9.sel));
    const t=G9.trips.find(t=>+t.from<=d&&+t.to>=d);if(t)g9Ping(t.id);else if(G9.sel)g9Toast(g9Dd(new Date(d))+' は Trip なし ・ 「新しい Trip」で 作れます')});
  P.querySelectorAll('[data-trip]').forEach(b=>b.onclick=()=>{const t=G9.trips.find(x=>x.id===b.dataset.trip);g9Hap('pop','ぷにっ(Trip)');if(b.classList.contains('g9bar')){g9Ping(t.id);return}
    try{const g=GRP.find(x=>x.trip);if(g&&typeof th77Open==='function'){th77Open(g);return}}catch(e){}g9Toast(`『${t.n}』を ひらく(モック)`)});
  P.querySelectorAll('[data-a="new"]').forEach(b=>b.onclick=()=>{g9Hap('pop');g9Toast('新しい Trip(日にち → 名前 → よぶ)')});
  P.querySelectorAll('[data-a="key"]').forEach(b=>b.onclick=()=>{g9Hap('pop');g9Toast('KEY で 入る')})}
function g9Ping(id){const P=$('g9pg'),el=[...P.querySelectorAll(`[data-trip="${id}"]`)].find(x=>!x.classList.contains('g9bar'));if(!el)return;el.scrollIntoView({behavior:G9RM()?'auto':'smooth',block:'center'});el.classList.remove('flash');void el.offsetWidth;el.classList.add('flash')}

/* ================= 1. Mondo を なくす ================= */
try{for(const A of [C9W,D9H]){const i=A.findIndex(x=>x.k==='mondo');if(i>=0)A.splice(i,1)}}catch(e){}
try{d9HowOpen=(_o=>function(){_o.apply(this,arguments);const S=$('d9h');const s=S&&S.querySelector('.d9all small');if(s)s.textContent='Friends → Trip ・ 約 30秒';const a=S&&S.querySelector('[data-a="all"]');if(a)a.onclick=()=>{g9Hap('click','カチッ(ぜんぶ)');d9HowClose();setTimeout(()=>z9Open('friends',{then:()=>setTimeout(()=>z9Open('trip',{}),250)}),300)}})(d9HowOpen)}catch(e){}
try{Object.assign(H9NM,{amd:'Trip'})}catch(e){}

/* ================= デモ ================= */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-g9]'))return;
  C.insertAdjacentHTML('beforeend',['friends:★ v97 Friends','trip:★ v97 Trip','shot:Friends:1枚 撮った','next:Trip:次の 週','none:Trip:まだ 0件','close:v97 を とじる'].map(s=>{const i=s.indexOf(':');return `<button data-g9="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-g9]').forEach(b=>b.onclick=()=>g9Demo(b.dataset.g9))})();
function g9Demo(k){G9.trips=g9Trips();
  if(k==='friends'){G9.shot=0;g9Open('friends')}else if(k==='trip'){G9.wk=0;G9.sel=null;g9Open('trip')}
  else if(k==='shot'){G9.shot=1;g9Open('friends')}else if(k==='next'){G9.wk=1;g9Open('trip')}
  else if(k==='none'){G9.trips=[];g9Open('trip')}else if(k==='close')g9Close()}
window.__kit=Object.assign(window.__kit||{},{g9:k=>g9Demo(k),G9:()=>({tab:G9.tab,log:G9.log.slice(),trips:G9.trips.map(t=>t.n+':'+g9State(t)),wk:G9.wk,shot:G9.shot,mondoLeft:[typeof C9W!=='undefined'&&C9W.some(x=>x.k==='mondo'),typeof D9H!=='undefined'&&D9H.some(x=>x.k==='mondo')]})});
