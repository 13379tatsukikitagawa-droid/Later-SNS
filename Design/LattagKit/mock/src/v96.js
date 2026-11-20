/* ===== v96(モック v96 ・ PROMPT v108) =====
   1. Home の 上:Lattag を まんなか ・ 左に お知らせ(ベル + 数)・ 右は 今の アイコン
   2. お知らせ:友だち申請を 承認(= フォローバック)で 相互 ・ Trip の 招待も ここで 参加
   3. 相互に なった 時の 通知(端末の 通知の 見本)
   4. LINE などで 送る 文 と リンクの 見え方(見本)
   名前:f9 */
const F9={tab:'all',log:[],read:new Set(),trips:[{id:'osaka',n:'大阪',en:'Osaka',from:'たつき',cover:'d',days:'11/21 → 11/23',mem:3,at:'10分'}],done:{}};
const F9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const F9I={bell:'<svg viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 1112 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 004 0"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>',
  chat:'<svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1116 0 8 8 0 01-11.6 7.1L4 20l1-4.2A7.9 7.9 0 014 12z"/></svg>',
  trip:'<svg viewBox="0 0 24 24"><rect x="4" y="7.5" width="16" height="12" rx="2.5"/><path d="M9 7.5V5.5h6v2"/></svg>',
  link:'<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>'};
const f9Count=()=>REQ.length+F9.trips.filter(t=>!F9.done[t.id]).length;

/* ================= 1. Home の 上 ================= */
function f9Head(){const H=document.querySelector('#hhd .hh');if(!H)return;let B=$('f9bell');
  if(!B){H.insertAdjacentHTML('afterbegin',`<button class="f9bell" id="f9bell" aria-label="お知らせ">${F9I.bell}<u id="f9bn"></u></button>`);B=$('f9bell');
    B.addEventListener('click',e=>{e.stopPropagation();f9Open()})}
  const n=f9Count(),U=$('f9bn');U.textContent=n>9?'9+':n;U.hidden=!n;B.setAttribute('aria-label',n?`お知らせ ${n}件`:'お知らせ')}
{const _r=renderHome;renderHome=function(a){_r(a);try{f9Head()}catch(e){}}}
{const _g=j9NxGo;j9NxGo=function(){const N=$('j9nx');if(N&&N.dataset.a==='req'){j9Bump(N);hap('pop','ぷにっ(NEXT)');f9Open('fr');return}return _g.apply(this,arguments)}}
try{f9Head()}catch(e){}

/* ================= 2. お知らせ ================= */
function f9Rows(){const req=REQ.map((r,i)=>({k:'req',i,f:r.f,at:r.at}));const tr=F9.trips.filter(t=>!F9.done[t.id]).map(t=>({k:'trip',t}));
  const past=[...(F9.past||[])];return {req,tr,past}}
function f9Mut(f){const n=(f.n.charCodeAt(0)%3);return FR.slice(0,Math.min(FR.length,n))}
function f9Draw(){const S=$('f9'),P=S.querySelector('.f9b'),{req,tr,past}=f9Rows(),tab=F9.tab;
  const showF=tab!=='trip',showT=tab!=='fr';
  const reqH=req.map(r=>{const m=f9Mut(r.f);return `<div class="f9r" data-k="req" data-i="${r.i}"><span class="f9av" style="background:${avBg(r.f)}">${r.f.n[0]}</span>
      <span class="f9t"><b>${r.f.n} <small>${FID(r.f)}</small></b><em>友だち申請 ・ ${r.at}</em>${m.length?`<i class="f9mu">${m.map(x=>`<s style="background:${avBg(x)}">${x.n[0]}</s>`).join('')}共通の 友だち ${m.length}人</i>`:''}</span>
      <span class="f9bt"><button class="ok" data-a="acc">承認</button><button class="no" data-a="del" aria-label="${r.f.n} の 申請を 消す">${F9I.x}</button></span></div>`}).join('');
  const trH=tr.map(({t})=>`<div class="f9r" data-k="trip" data-t="${t.id}"><span class="f9cv" style="background-image:url(${PH[t.cover]})"><i>${F9I.trip}</i></span>
      <span class="f9t"><b>『${t.n}』に 招待</b><em>${t.from} から ・ ${t.days} ・ ${t.mem}人 ・ ${t.at}</em></span>
      <span class="f9bt"><button class="ok" data-a="join">参加</button><button class="no" data-a="dec" aria-label="ことわる">${F9I.x}</button></span></div>`).join('');
  const pastH=past.filter(p=>tab==='all'||(tab==='fr'&&p.k==='fr')||(tab==='trip'&&p.k==='trip')).map(p=>`<div class="f9r done"><span class="f9av" style="${p.bg}">${p.c}</span><span class="f9t"><b>${p.h}</b><em>${p.s}</em></span>${p.k==='fr'?`<span class="f9bt"><button class="sub" data-a="chat" data-n="${p.n}">${F9I.chat}</button></span>`:''}</div>`).join('');
  const empty=!((showF&&req.length)||(showT&&tr.length)||pastH);
  P.innerHTML=`${(showF&&req.length)?`<h4>友だち申請 <em>${req.length}</em></h4>${reqH}`:''}${(showT&&tr.length)?`<h4>Trip の 招待 <em>${tr.length}</em></h4>${trH}`:''}${pastH?`<h4>これまで</h4>${pastH}`:''}
    ${empty?`<div class="f9e"><i>${F9I.bell}</i><b>お知らせは ありません</b><small>友だち申請 と Trip の 招待が ここに 来ます</small></div>`:''}`;
  S.querySelectorAll('.f9tab button').forEach(b=>{b.classList.toggle('on',b.dataset.t===tab);const c=b.dataset.t==='fr'?req.length:b.dataset.t==='trip'?tr.length:req.length+tr.length;b.querySelector('u').textContent=c||'';b.querySelector('u').hidden=!c});
  P.querySelectorAll('[data-a="acc"]').forEach(b=>b.onclick=()=>f9Accept(b.closest('.f9r')));
  P.querySelectorAll('[data-a="del"]').forEach(b=>b.onclick=()=>f9Drop(b.closest('.f9r'),'req'));
  P.querySelectorAll('[data-a="join"]').forEach(b=>b.onclick=()=>f9Join(b.closest('.f9r')));
  P.querySelectorAll('[data-a="dec"]').forEach(b=>b.onclick=()=>f9Drop(b.closest('.f9r'),'trip'));
  P.querySelectorAll('[data-a="chat"]').forEach(b=>b.onclick=()=>{const f=FR.find(x=>x.n===b.dataset.n);hap('pop');f9Close();f&&setTimeout(()=>{try{openDM(f)}catch(e){}},300)})}
function f9Open(tab){let S=$('f9');if(!S){$('phone').insertAdjacentHTML('beforeend',`<section class="f9" id="f9" aria-label="お知らせ"><div class="f9h"><button class="f9x" data-a="x" aria-label="とじる">${F9I.x}</button><b>お知らせ</b><button class="f9ln" data-a="link" aria-label="招待の リンクを 送る">${F9I.link}</button></div>
    <div class="f9tab" role="tablist"><button data-t="all" role="tab">すべて<u></u></button><button data-t="fr" role="tab">友だち<u></u></button><button data-t="trip" role="tab">Trip<u></u></button></div><div class="f9b"></div></section>`);S=$('f9');
    S.querySelector('[data-a="x"]').onclick=()=>f9Close();S.querySelector('[data-a="link"]').onclick=()=>{hap('pop');f9ShareOpen('friend')};
    S.querySelectorAll('.f9tab button').forEach(b=>b.onclick=()=>{F9.tab=b.dataset.t;hap('sel',null,{norip:1});f9Draw()})}
  F9.tab=tab||'all';f9Draw();requestAnimationFrame(()=>S.classList.add('on'));hap('soft','ふわっ(お知らせ)',{norip:1});F9.log.push('open:'+F9.tab)}
function f9Close(){const S=$('f9');if(!S)return;S.classList.remove('on');hap('soft',null,{norip:1});try{f9Head()}catch(e){}}
/* 承認 = フォローバック → 相互 */
function f9Accept(row){const i=+row.dataset.i,r=REQ[i];if(!r)return;const f=r.f;F9.log.push('acc:'+f.n);
  const bt=row.querySelector('.f9bt');bt.innerHTML=`<span class="f9okd">${F9I.ok}</span>`;row.classList.add('acc');hap('success','トトトン(友だちに なった)',{norip:1});
  if(!F9RM()){row.animate([{transform:'scale(1)'},{transform:'scale(1.03)'},{transform:'scale(1)'}],{duration:360,easing:'cubic-bezier(.3,1.6,.4,1)'});f9Burst(row)}
  row.querySelector('.f9t em').textContent='友だちに なりました ・ あしたの 9:00 から 見せあえます';
  setTimeout(()=>{const k=REQ.indexOf(r);if(k>=0){REQ.splice(k,1);if(!FR.includes(f))FR.unshift(f)}
    (F9.past=F9.past||[]).unshift({k:'fr',n:f.n,c:f.n[0],bg:`background:${avBg(f)}`,h:`${f.n} と 友だちに なりました`,s:'たった今 ・ おたがいに 見られる'});
    try{renderFriends()}catch(e){}try{renderHome()}catch(e){}f9Draw();f9Head();
    setTimeout(()=>f9Banner({t:`${f.n} と 友だちに なりました`,b:'あしたの 9:00 に、おたがいの 1枚が ひらきます',av:f}),400)},1100)}
function f9Join(row){const t=F9.trips.find(x=>x.id===row.dataset.t);if(!t)return;F9.log.push('join:'+t.n);
  row.querySelector('.f9bt').innerHTML=`<span class="f9okd">${F9I.ok}</span>`;row.classList.add('acc');hap('success','トトトン(Trip に 入った)',{norip:1});!F9RM()&&f9Burst(row);
  row.querySelector('.f9t em').textContent='参加しました ・ Home の Trip に ならびます';
  setTimeout(()=>{F9.done[t.id]=1;const d0=new Date();d0.setHours(0,0,0,0);
    const g={n:t.n,en:t.en,trip:1,cover:t.cover,from:new Date(+d0+864e5),to:new Date(+d0+3*864e5),m:FR.slice(0,2),cnt:0,key:'#maple24'};try{GRP.unshift(g);tripPage();renderGroups()}catch(e){}
    (F9.past=F9.past||[]).unshift({k:'trip',c:'',bg:`background:url(${PH[t.cover]}) center/cover`,h:`『${t.n}』に 参加しました`,s:'たった今'});f9Draw();f9Head()},1100)}
function f9Drop(row,k){hap('tick','ごく軽く(けす)',{norip:1});F9.log.push('drop:'+k);
  const fin=()=>{if(k==='req'){const i=+row.dataset.i;REQ.splice(i,1)}else F9.done[row.dataset.t]=1;f9Draw();f9Head()};
  if(F9RM()){fin();return}row.animate([{transform:'none',opacity:1},{transform:'translateX(-40px)',opacity:0}],{duration:260,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'}).onfinish=fin}
function f9Burst(row){const r=row.getBoundingClientRect(),P=$('phone').getBoundingClientRect(),x=(r.right-P.left-50)/SC,y=(r.top-P.top+r.height/2)/SC;
  for(let k=0;k<7;k++){const s=document.createElement('i');s.className='f9sp';s.style.left=x+'px';s.style.top=y+'px';$('phone').appendChild(s);const a=k/7*6.283;
    s.animate([{transform:'translate(-50%,-50%) scale(.4)',opacity:1},{transform:`translate(calc(-50% + ${Math.cos(a)*40}px),calc(-50% + ${Math.sin(a)*40}px)) scale(1)`,opacity:0}],{duration:520,easing:'cubic-bezier(.2,.8,.3,1)'}).onfinish=()=>s.remove()}}

/* ================= 3. 通知の 見本(端末の 上に 出る)================= */
function f9Banner(o){let B=$('f9nb');if(!B){$('phone').insertAdjacentHTML('beforeend','<div class="f9nb" id="f9nb" role="status"></div>');B=$('f9nb')}
  B.innerHTML=`<span class="ic">#</span><span class="tx"><small>LATTAG ・ いま</small><b>${o.t}</b><em>${o.b}</em></span>${o.av?`<span class="f9av sm" style="background:${avBg(o.av)}">${o.av.n[0]}</span>`:''}`;
  B.classList.remove('on');void B.offsetWidth;B.classList.add('on');hap('sig','ラ・タッ・グ(通知)',{norip:1});clearTimeout(F9.nb);F9.nb=setTimeout(()=>B.classList.remove('on'),3600);
  B.onclick=()=>{B.classList.remove('on');f9Open('fr')};F9.log.push('banner')}
/* 相手が 承認した(自分が 送った 申請が 相互に なった) */
function f9Mutual(f){f=f||FPOOL[3];if(!FR.includes(f))FR.unshift(f);(F9.past=F9.past||[]).unshift({k:'fr',n:f.n,c:f.n[0],bg:`background:${avBg(f)}`,h:`${f.n} が 承認しました`,s:'たった今 ・ 友だちに なりました'});
  try{renderFriends();renderHome()}catch(e){}f9Banner({t:`${f.n} が 承認しました`,b:'友だちに なりました ・ あしたの 9:00 に 見せあえます',av:f})}

/* ================= 4. 送る 文 と リンク(見本)================= */
const F9HOST='later-app-f2606.firebaseapp.com';
function f9Msg(k){const me=(()=>{try{return fMe()}catch(e){return{n:'ゆい',id:'@yui_0612'}}})(),id=(me.id||'@yui_0612').replace('@','');
  if(k==='trip')return{text:`${me.n} から Trip の 招待です\n『大阪』11/21〜11/23 ・ 3人 参加中\n\n↓ タップで 参加(アプリが ひらきます)\nhttps://${F9HOST}/t/Kx7Qm2pL?openExternalBrowser=1\n\nKEY:#maple24(アプリの「KEY で 入る」でも OK ・ 24時間)`,
    og:{t:'『大阪』の Trip に 招待されました',d:'1日 23枚、みんなで 撮って、あした 9:00 に ひらく。',img:'trip'}};
  return{text:`${me.n}(@${id})から Lattag の 友だち申請です\n\n↓ タップで ひらく(アプリが ひらきます)\nhttps://${F9HOST}/u/${id}?openExternalBrowser=1\n\nアプリが ない 時は、ひらいた ページから 入れられます`,
    og:{t:`Lattag で 友だちに なろう`,d:'1日 3枚 撮って、あした 9:00 に おたがいの 写真が ひらく。',img:'friend'}}}
function f9ShareOpen(k){let S=$('f9sh');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="f9sh" id="f9sh" aria-hidden="true"><i class="sc"></i><div class="pn" role="dialog" aria-label="送る 文の 見本"></div></div>');S=$('f9sh');S.querySelector('.sc').onclick=()=>f9ShareClose()}
  const m=f9Msg(k),P=S.querySelector('.pn');
  P.innerHTML=`<i class="grab"></i><div class="f9shh"><b>こう とどきます</b><span class="f9seg"><button data-k="friend" class="${k==='friend'?'on':''}">友だち</button><button data-k="trip" class="${k==='trip'?'on':''}">Trip</button></span></div>
    <div class="f9chat"><div class="bub">${rmEsc(m.text).replace(/\n/g,'<br>').replace(/(https:\/\/[^\s<]+)/,'<u>$1</u>')}</div>
      <div class="f9og"><i class="f9oi og-${m.og.img}"><b>#</b><span>${m.og.img==='trip'?'TRIP PASS':'FRIEND'}</span></i><span><b>${m.og.t}</b><small>${m.og.d}</small><em>${F9HOST}</em></span></div></div>
    <ul class="f9pts"><li>タップ → アプリが ひらく(入って いれば)</li><li>アプリが ない → ページ → App Store → もどって「招待リンクを 貼りつける」</li><li>LINE の 中の ブラウザで 止まらない ように <code>openExternalBrowser=1</code></li></ul>
    <button class="f9go" data-a="send">LINE などで 送る</button>`;
  P.querySelectorAll('.f9seg button').forEach(b=>b.onclick=()=>{hap('sel',null,{norip:1});f9ShareOpen(b.dataset.k)});
  P.querySelector('[data-a="send"]').onclick=()=>{hap('pop');try{openShare({t:m.text,h:'Lattag'})}catch(e){try{toast('共有シート(モック)')}catch(_){}}};
  S.classList.add('on');S.setAttribute('aria-hidden','false');F9.log.push('share:'+k)}
function f9ShareClose(){const S=$('f9sh');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}

/* ================= デモ ================= */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-f9]'))return;
  C.insertAdjacentHTML('beforeend',['open:お知らせ','mut:相手が 承認した(通知)','share:送る 文(友だち)','strip:送る 文(Trip)','page:リンクの ページ(アプリ なし)'].map(s=>{const[k,l]=s.split(':');return `<button data-f9="${k}">${l}</button>`}).join(''));
  C.querySelectorAll('[data-f9]').forEach(b=>b.onclick=()=>f9Demo(b.dataset.f9))})();
function f9Demo(k){if(k==='open'){f9Open();return}if(k==='mut'){f9Mutual();return}if(k==='share'){f9ShareOpen('friend');return}if(k==='strip'){f9ShareOpen('trip');return}
  if(k==='page'){window.open('link_pages/u.html#yui_0612','_blank')}}
window.__kit=Object.assign(window.__kit||{},{f9:k=>f9Demo(k),f9Open:t=>f9Open(t),F9:()=>({log:F9.log.slice(),req:REQ.length,fr:FR.length,trips:GRP.filter(g=>g.trip).map(g=>g.n),badge:f9Count()})});
