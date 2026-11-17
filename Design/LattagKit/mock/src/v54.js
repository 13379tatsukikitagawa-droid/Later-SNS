/* ================= v54 友だちが 主役(BeReal の 形)+ Trips(グループ = 旅行用 ・ 1日 23枚) =================
   ・申請 → 承認で 2人とも 友だち。人数は 無制限。数は どこにも 出さない
   ・友だちと チャット(1対1 ・ 7日で きえる)
   ・Lattag yesterday の タブは Friends / Mondo。グループは Trips として サブに */

/* ---- デモの 人たち(人数 無制限を 見せるため 増やす) ---- */
FPOOL.push(
 {n:'りこ',g:['#fff0e0','#FFB27A','#E0603A'],k:2},{n:'ゆな',g:['#e6f7ff','#7FD1FF','#2F86D8'],k:0},{n:'さき',g:['#fdeaff','#E59BF0','#9C3FB8'],k:3},
 {n:'はる',g:['#eaffe9','#8EE58A','#2E9A3A'],k:1},{n:'のあ',g:['#fff8d6','#FFDF6B','#C49A00'],k:0},{n:'えま',g:['#ffe6e6','#FF9AA2','#D64554'],k:2},
 {n:'つむぎ',g:['#e9f0ff','#9DB4FF','#4A63D8'],k:1},{n:'しずく',g:['#e8fffb','#7EE3D2','#159E88'],k:0},{n:'ここ',g:['#fff1f7','#FFA6CF','#D2477F'],k:3},
 {n:'あおい',g:['#eef6ff','#8CC4FF','#2B7BD1'],k:1},{n:'まな',g:['#fff4e8','#FFC48A','#D9772C'],k:0},{n:'ひより',g:['#f2ffe8','#B6EE8E','#5DAA2A'],k:2});
const FID=f=>'@'+({'れな':'rena','あや':'aya','そら':'sora','ひなた':'hinata','みお':'mio','かい':'kai','りこ':'riko','ゆな':'yuna','さき':'saki','はる':'haru','のあ':'noa','えま':'ema','つむぎ':'tsumugi','しずく':'shizuku','ここ':'coco','あおい':'aoi','まな':'mana','ひより':'hiyori'}[f.n]||'lattag')+'_'+(1000+(f.n.charCodeAt(0)*7)%9000);
window.REQ=[{f:FPOOL[6],at:'2h'},{f:FPOOL[8],at:'5h'}];var REQL=[],SENT={};
const ICH='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M4 12a8 7 0 1 1 3.6 5.8L4 19.5l1.3-3.6A6.8 6.8 0 0 1 4 12z"/></svg>';
const IOK='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
const IUP='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><circle cx="9" cy="9" r="3.4"/><path d="M3 19c.6-3.4 3-5 6-5s5.4 1.6 6 5M18 8v6M15 11h6"/></svg>';

/* ---- 数を 消す(友だち数 ・ 12人) ---- */
function v54Counts(){['frn','fcnt','shfn','ycnt','afcn'].forEach(id=>{const e=$(id);if(e)e.textContent=''});
  const n=$('fscr').querySelector('.ftl span');if(n)n.textContent=''}
{const _rf=renderFriends;renderFriends=function(n){_rf(n);v54Counts();setTimeout(v54Counts,10);try{renderOrb()}catch(e){}}}
{const _e=renderFriendEntry;renderFriendEntry=function(){_e();v54Counts()};window.renderFriendEntry=renderFriendEntry}

/* ================= 申請を うける ================= */
function reqAccept(i){const r=REQ[i];if(!r)return;REQ.splice(i,1);if(!FR.includes(r.f))FR.unshift(r.f);
  hap('success','トトトン(友だちに なった)',{norip:1});
  renderFriends(0);try{renderPick()}catch(e){}
  setTimeout(()=>{const c=$('fcore');if(c&&$('fscr').classList.contains('on'))bumpBurst(c,()=>{})},120);
  _toast(r.f.n+' と 友だちに なりました')}
function reqLater(i){const r=REQ.splice(i,1)[0];if(r)REQL.push(r);hap('soft','やわらかく1回(あとで)',{norip:1});renderFriends()}
function reqBand(){if(!REQ.length&&!REQL.length)return '';
  return `<div class="rqb"><div class="rqh"><b>Requests</b>${REQ.length?`<i class="rqd"></i>`:''}${REQL.length?`<button class="rql" data-a="later">あとで ${REQL.length} ›</button>`:''}</div>
    <div class="rqs">${REQ.map((r,i)=>`<div class="rqc" data-i="${i}" style="--d:${i*.07}s"><span class="av" style="background:${avBg(r.f)}">${r.f.n[0]}</span><span class="tx"><b>${r.f.n}</b><small>${FID(r.f)} ・ ${r.at}</small></span>
      <button class="ok" data-a="ok" aria-label="承認">${IOK}<span>承認</span></button><button class="no" data-a="no" aria-label="あとで">あとで</button></div>`).join('')}</div></div>`}
function reqBind(root){root.querySelectorAll('.rqc').forEach(c=>{const i=+c.dataset.i;
    c.querySelector('[data-a="ok"]').onclick=e=>{e.stopPropagation();const b=e.currentTarget;b.animate([{scale:'1'},{scale:'.86'},{scale:'1.08'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'});
      c.animate([{transform:'none',opacity:1},{transform:'translateY(-6px) scale(1.02)',opacity:1,offset:.3},{transform:'translateY(30px) scale(.6)',opacity:0}],{duration:420,easing:'cubic-bezier(.5,0,.3,1)',fill:'forwards'});setTimeout(()=>reqAccept(i),380)};
    c.querySelector('[data-a="no"]').onclick=e=>{e.stopPropagation();c.animate([{opacity:1},{opacity:0,transform:'translateX(-30px)'}],{duration:260,fill:'forwards'});setTimeout(()=>reqLater(i),240)}});
  const l=root.querySelector('[data-a="later"]');if(l)l.onclick=e=>{e.stopPropagation();hap('sel');REQ.push(...REQL);REQL=[];renderFriends()}}
function reqIncoming(){const f=FPOOL.find(p=>!FR.includes(p)&&!REQ.some(r=>r.f===p)&&!REQL.some(r=>r.f===p));if(!f){_toast('デモの 人が いません');return}
  REQ.unshift({f,at:'たった今'});hap('pop','ぷにっ(申請が とどいた)',{norip:1});renderFriends();try{renderOrb()}catch(e){}
  toastA(f.n+'('+FID(f)+')から 申請','見る',()=>{closeAll();setTimeout(openFriend,300)})}

/* ================= Friend 画面:申請の 帯 ・ 今日の 輪(最大 12人を 表示)・全員の 一覧 ・ チャット ================= */
const fView=()=>FR.slice().sort((a,b)=>b.k-a.k).slice(0,12);
fSeats=function(ni){const V=fView(),nx=V.length;return Array.from({length:12},(_,i)=>{const a=i*30,f=V[i];
  if(!f)return `<button class="fs e${i===nx?' nx':''}" data-i="-1" style="--a:${a}deg;--d:${i*.04}s" aria-label="ともだちを ふやす"><i></i></button>`;
  const fi=FR.indexOf(f);return `<button class="fs f${f.k>0?' k':''}${FSEL===fi?' sel':''}${POKED.has(fi)?' pkd':''}${fi===ni?' new':''}" data-i="${fi}" style="--a:${a}deg;--d:${i*.04}s" aria-label="${f.n}"><svg viewBox="0 0 60 60"><circle cx="30" cy="30" r="27.5" class="t"/><circle cx="30" cy="30" r="27.5" class="p" pathLength="3" style="stroke-dasharray:${f.k} 3"/></svg><span class="av" style="background:${avBg(f)}">${f.n[0]}</span>${f.k>0?`<em>${f.k}</em>`:''}<small>${f.n}</small></button>`}).join('')};
var FQ='';
{const _fr=fRender;fRender=function(ni){_fr(ni);const B=$('frbody');if(!B)return;v54Counts();
  const H=$('fr0');if(H){H.insertAdjacentHTML('beforebegin',reqBand());reqBind(B);
    if(FR.length>12)H.insertAdjacentHTML('beforeend',`<span class="fmo">TODAY ・ 12 shown</span>`)}
  const L=B.querySelector('.frl');
  if(L){L.insertAdjacentHTML('beforebegin',`<div class="fsr"><b>All</b><label><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg><input id="fq" placeholder="なまえで さがす" value="${FQ}"></label></div>`);
    L.querySelectorAll('.frw').forEach(r=>{const f=FR[+r.dataset.i];r.insertAdjacentHTML('beforeend',`<em class="ch2" data-a="chat" aria-label="チャット">${ICH}</em>`);
      r.querySelector('.tx').insertAdjacentHTML('beforeend',`<small>${FID(f)}</small>`);if(FQ&&!f.n.includes(FQ))r.hidden=true;
      const _oc=r.onclick;r.onclick=e=>{if(e.target.closest('[data-a="chat"]')){e.stopPropagation();openDM(f);return}_oc&&_oc(e)}});
    const q=$('fq');q.oninput=()=>{FQ=q.value.trim();L.querySelectorAll('.frw').forEach(r=>r.hidden=!!FQ&&!FR[+r.dataset.i].n.includes(FQ))};
    q.onclick=e=>e.stopPropagation()}
  B.querySelectorAll('.fs.e').forEach(s=>s.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(ふやす)');s.animate([{scale:'1'},{scale:'.8'},{scale:'1.12'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(openAdd,180)})}}
{const _fs=fSoft;fSoft=function(){_fs();document.querySelectorAll('#fr0 .fs.e').forEach(s=>s.onclick=e=>{e.stopPropagation();hap('pop');setTimeout(openAdd,150)})}}
$('fcall')&&($('fcall').onclick=()=>{hap('pop','ぷにっ(Add)');openAdd()});
fMenu=function(i){const f=FR[i];hap('sel','コツッ('+f.n+')');
  actSheet(`${f.n} ・ ${FID(f)}`,[
    {l:'チャット',fn:()=>{ovClose('acs');setTimeout(()=>openDM(f),260)}},
    ...(f.k>0?[]:[{l:POKED.has(i)?'つついた(きょうは おわり)':'つつく',fn:()=>{ovClose('acs');setTimeout(()=>{const r=document.querySelector(`.frw[data-i="${i}"]`);r&&fPoke(i,r)},260)}}]),
    {l:'Trip に さそう',fn:()=>{ovClose('acs');setTimeout(()=>openGnw(),300)}},
    {l:'友だちを やめる',fn:b=>{if(!b.dataset.ok){b.dataset.ok=1;b.querySelector('span').textContent='もういちど おすと やめる(相手には 通知されません)';return}ovClose('acs');setTimeout(()=>{FR.splice(i,1);FSEL=-1;renderFriends();_toast(f.n+' と 友だちを やめました')},260)}},
    {l:'ブロックする',red:1,fn:b=>{if(!b.dataset.ok){b.dataset.ok=1;b.querySelector('span').textContent='もういちど おすと ブロック';return}ovClose('acs');setTimeout(()=>{FR.splice(i,1);FSEL=-1;renderFriends();_toast(f.n+' を ブロックしました')},260)}},
    {l:'報告する',red:1,fn:()=>{ovClose('acs');setTimeout(()=>_toast('報告しました。Lattag が 確認します'),260)}}])};

/* ================= 友だちを ふやす シート(ID で さがす → 申請 → 承認されたら つながる) ================= */
const DIR=()=>FPOOL.map(f=>({f,id:FID(f)}));
function addBuild(){const P=document.querySelector('#shf .pn');if(!P||P.dataset.v54)return;P.dataset.v54=1;
  P.innerHTML=`<i class="grab"></i><div class="pnh"><b>Add friends</b><span class="mono">@yui_0612</span><span id="shfn" hidden></span></div>
    <label class="adq"><span class="at">@</span><input id="adin" autocomplete="off" autocapitalize="off" spellcheck="false" placeholder="ID を そのまま 入力"><button id="adgo" aria-label="さがす"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg></button></label>
    <div class="adr" id="adr"><span class="adh">知らない人には 見つからない ように、ID が ぴったり 合った ときだけ 出ます</span><span class="adx mono">DEMO ・ ${FID(FPOOL[9])}</span></div>
    <div class="adw"><button data-a="shake">${SHK}<b>Shake</b></button><button data-a="qr" class="pr"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg><b>QR</b></button><button data-a="link"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg><b>Link</b></button><button data-a="scan"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 8V5h3M17 5h3v3M20 16v3h-3M7 19H4v-3M4 12h16"/></svg><b>Scan</b></button></div>
    <p class="pnote">申請して、承認されたら つながる ・ 数は 出ません</p>`;
  const go=()=>addSearch($('adin').value);$('adgo').onclick=go;$('adin').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();go()}});
  P.querySelector('.adx').onclick=()=>{$('adin').value=FID(FPOOL[9]).slice(1);go()};
  P.querySelectorAll('.adw button').forEach(b=>b.onclick=()=>{const a=b.dataset.a;b.animate([{scale:'1'},{scale:'.9'},{scale:'1.04'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(a==='shake'){closeSheet('shf');setTimeout(()=>{if(!$('fscr').classList.contains('on'))openFriend();setTimeout(()=>{const c=$('fcore');c&&bumpBurst(c,()=>askBump())},600)},250)}
    else if(a==='qr'){hap('pop');closeSheet('shf');setTimeout(()=>openPrf(),300)}
    else if(a==='link'){hap('pop');openShare({t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい'})}
    else{hap('pop');openScan('fr')}})}
function addSearch(q){q=String(q||'').trim().replace(/^@/,'').toLowerCase();const R=$('adr');if(!q){hap('warn');shake($('adin').parentElement);return}
  const hit=DIR().find(d=>d.id.slice(1).toLowerCase()===q);hap('sel','コツッ(さがす)',{norip:1});
  if(!hit){R.innerHTML=`<span class="adn">見つかりません<small>ID は 大文字 小文字も ぴったりに</small></span>`;R.firstChild.animate([{opacity:0,transform:'translateY(6px)'},{opacity:1,transform:'none'}],{duration:260});return}
  const st=FR.includes(hit.f)?'fr':SENT[hit.id]?'sent':REQ.some(r=>r.f===hit.f)?'in':'none';
  R.innerHTML=`<div class="adc"><span class="av" style="background:${avBg(hit.f)}">${hit.f.n[0]}</span><span class="tx"><b>${hit.f.n}</b><small>${hit.id}</small></span>
    <button class="rq ${st}" id="adrq">${st==='fr'?'友だち':st==='sent'?'申請中':st==='in'?'承認する':'申請'}</button></div>`;
  R.firstChild.animate([{opacity:0,transform:'translateY(10px) scale(.96)'},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'});
  $('adrq').onclick=e=>{const b=e.currentTarget;if(st==='fr'){hap('sel');closeSheet('shf');setTimeout(()=>openDM(hit.f),300);return}
    if(st==='in'){const i=REQ.findIndex(r=>r.f===hit.f);closeSheet('shf');setTimeout(()=>{openFriend();setTimeout(()=>reqAccept(i),500)},250);return}
    if(SENT[hit.id])return;SENT[hit.id]=1;hap('pop','ぷにっ(申請した)');b.classList.add('sent');b.textContent='申請中';b.animate([{scale:'1'},{scale:'.88'},{scale:'1.06'},{scale:'1'}],{duration:360,easing:'cubic-bezier(.3,1.6,.4,1)'});
    setTimeout(()=>{if(FR.includes(hit.f))return;FR.unshift(hit.f);delete SENT[hit.id];hap('success','トトトン(承認された)',{norip:1});renderFriends(0);
      toastA(hit.f.n+' が 承認しました','チャット',()=>{closeAll();setTimeout(()=>openDM(hit.f),300)})},3200)}}
function openAdd(){addBuild();const i=$('adin');if(i)i.value='';const R=$('adr');if(R&&R.querySelector('.adc,.adn'))R.innerHTML=`<span class="adh">知らない人には 見つからない ように、ID が ぴったり 合った ときだけ 出ます</span><span class="adx mono">DEMO ・ ${FID(FPOOL[9])}</span>`;
  const x=R&&R.querySelector('.adx');if(x)x.onclick=()=>{$('adin').value=FID(FPOOL[9]).slice(1);addSearch($('adin').value)};openSheet('shf')}
addBuild();
{const _os=openSheet;openSheet=function(id){if(id==='shf')addBuild();return _os(id)}}

/* ================= 1対1 チャット(友だち同士だけ ・ 7日で きえる) ================= */
function openDM(f){if(!FR.includes(f)){hap('warn');_toast('友だちに なると チャットできます');return}
  const g={n:f.n,m:[f],dm:true,un:0,chat:f._dm||(f._dm=[{w:'sys',x:'友だちに なりました ・ メッセージは 7日で きえます'},{w:0,t:'text',x:'きのうの 写真 みた?'},{w:0,t:'ph',p:'d',x:'わたしの 帰り道'}])};
  openRoom(g)}
{const _or=openRoom;openRoom=function(g){_or(g);if(g&&g.dm){const s=$('rms');if(s)s.textContent='ふたり ・ 7日で きえる';$('room').classList.add('dm')}else $('room').classList.remove('dm')}}

/* ================= Lattag yesterday:Friends タブ(友だちの きのう)+ Trips ================= */
{const b=document.querySelector('#ynav button[data-t="ytg"] span');if(b)b.textContent='Friends'}
const FTG=['#夕焼け','#放課後','#帰り道','#カフェ','#雨の日','#部活','#ねむい','#散歩'];
const FPH=['a','b','c','d','e','f'];
yOnce=function(){const H=$('yon');if(!H)return;const lk=!shots,d=new Date(Date.now()-864e5),dl=MON[d.getMonth()].toUpperCase()+' '+d.getDate();
  const ph=['a','d','b','f'].map(p=>`<i style="background-image:url(${PH[p]})"></i>`).join('');const took=FR.filter(f=>f.k>0);
  const feed=FR.length?FR.map((f,i)=>({f,i,p:FPH[(i*2+1)%6],t:FTG[i%FTG.length],tm:FTM[(i%3)]})):[];
  H.innerHTML=`<div class="yoh${lk?' lk':''}"><div class="yoc">${ph}</div><span class="yok">FRIENDS · ${dl}</span><h2>Yesterday,<br>friends.</h2>
    ${lk?`<span class="yolk">${ICO.lock}shoot today to open</span>`:''}
    <div class="yos"><div><b>${lk?untilTxt().replace(/\s.*$/,''):'6d'}</b><span>${lk?'To open':'Left'}</span></div><div class="lv"><b>${took.length?'●':'—'}</b><span>${took.length?took.length+' shot today':'まだ'}</span></div><div><b>›</b><span>Friends</span></div></div>
    <div class="yob"><button class="w" data-a="add">${ICO.plus}Add friends</button><button class="s" data-a="qr" aria-label="QR"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><path d="M14 14h2v2h-2zM18 18h2.5M14 19h2"/></svg></button></div></div>
    ${REQ.length?`<button class="yrq" data-a="req"><span class="avs">${REQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>申請が とどいています</b><svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg></button>`:''}
    ${feed.length?`<div class="axh yax"><span>YESTERDAY · FRIENDS</span><em>${lk?'ひらく前':'9:00 OPEN'}</em></div>
    <div class="mofd yfd${lk?' lkd':''}">${feed.map(m=>`<div class="mof" data-i="${m.i}"><img src="${PH[m.p]}" alt=""><span class="l">${m.f.n}</span><span class="tm">${m.tm}</span><span class="tg" style="background:${tgc(m.t)[0]};color:${tgc(m.t)[1]}">${m.t}</span><span class="fav" style="background:${avBg(m.f)}">${m.f.n[0]}</span>${lk?`<em class="lkp">${ICO.lock}</em>`:''}</div>`).join('')}</div>`:
    `<div class="yf00">${fCrowd(1)}<b>友だちを ふやすと、ここに きのうが 並びます</b></div>`}`;
  H.querySelector('[data-a="add"]').onclick=()=>{hap('pop','ぷにっ(Add)');openAdd()};H.querySelector('[data-a="qr"]').onclick=()=>{hap('pop');closeY();setTimeout(()=>openPrf(),350)};
  H.querySelector('.yos div:last-child').onclick=()=>{hap('pop');closeY();setTimeout(openFriend,350)};
  const rq=H.querySelector('[data-a="req"]');if(rq)rq.onclick=()=>{hap('pop');closeY();setTimeout(openFriend,350)};
  H.querySelectorAll('.yfd .mof').forEach(c=>c.onclick=()=>{const m=feed.find(x=>x.i===+c.dataset.i);
    if(lk){hap('warn','やわらかく2回(まだ)');shake(c);_toast('今日 1枚 撮ると、ひらきます');return}
    hap('pop');openAv({p:m.p,n:m.f.n,s:'yesterday · '+m.tm,t:m.t})});
  yFriends()};
window.yOnce=yOnce;

/* ---- Trips(旅行 ・ 1日 23枚を みんなで) ---- */
function tripSeed(){if(GRP.find(g=>g.trip))return;if(FR.length<3)FPOOL.filter(f=>!FR.includes(f)).slice(0,3-FR.length).forEach(f=>FR.push(f));
  GRP.unshift({n:'京都 2泊3日',m:FR.slice(0,4),trip:true,cnt:7,by:[0,1,2,0,'me',1,'me'],dates:'11.20 – 11.22',sub:'4人',un:2,last:'あや: 清水寺 ついた!'});
  renderGroups();renderFriends();try{renderOrb()}catch(e){}hap('success');_toast('Trip「京都 2泊3日」が できました')}
function tripCards(){const T=GRP.filter(g=>g.trip);
  return `<div class="axh yax"><span>TRIPS</span><em>1日 23枚 ・ みんなで</em></div><div class="trs">${T.map((g,gi)=>{const c=g.cnt||0,mem=[{me:1},...g.m];
    return `<div class="trc" data-i="${GRP.indexOf(g)}"><i class="bg" style="background-image:url(${PH['abcdef'[gnHash(g.n)%6]]})"></i>
      <div class="trh"><b>${rmEsc(g.n)}</b><small class="mono">${g.dates||''}</small></div>
      <div class="trf">${Array.from({length:23},(_,j)=>{const w=g.by&&g.by[j];const f=w==='me'?null:g.m[w];return `<i class="${j<c?'on':''}" style="${j<c?`background:${w==='me'?'#C8F25A':avBg(f||g.m[0])}`:''}"></i>`}).join('')}</div>
      <div class="trb"><span class="avs">${mem.slice(0,5).map(f=>f.me?`<i class="me">ゆ</i>`:`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span><span class="ct"><b>${c}</b>/23</span>
        <button class="trsh" data-a="shot" aria-label="撮る">${OI.shoot}</button><button class="cht" data-a="chat" aria-label="チャット">${ICH}${g.un?`<u>${g.un}</u>`:''}</button></div>
      <span class="trn mono">あした 9:00 に みんなで ひらく</span></div>`}).join('')}
    <button class="trc nw" data-a="new"><span class="pl">${ICO.plus}</span><b>New trip</b><small>旅行 ・ イベント ・ 合宿</small></button></div>`}
function tripBind(R){R.querySelectorAll('.trc[data-i]').forEach(c=>{const g=GRP[+c.dataset.i];
    c.querySelector('[data-a="chat"]').onclick=e=>{e.stopPropagation();closeY();setTimeout(()=>openRoom(g),350)};
    c.querySelector('[data-a="shot"]').onclick=e=>{e.stopPropagation();tripShot(g,c)};
    c.onclick=()=>{hap('pop');closeY();setTimeout(()=>openRoom(g),350)}});
  const n=R.querySelector('[data-a="new"]');if(n)n.onclick=()=>{hap('pop','ぷにっ(New trip)');GRP.find(g=>g.trip)?openGnw():tripSeed()}}
function tripShot(g,c){if((g.cnt||0)>=23){hap('warn','やわらかく2回(23枚 おわり)');shake(c);_toast('今日の 23枚が うまりました ・ あした 9:00 に ひらく');return}
  hap('shutter','カシャッ(Trip に 1枚)');const fl=document.createElement('i');fl.className='trfl';c.appendChild(fl);fl.animate([{opacity:0},{opacity:.95,offset:.15},{opacity:0}],{duration:520}).onfinish=()=>fl.remove();
  g.cnt=(g.cnt||0)+1;(g.by=g.by||[]).push('me');
  setTimeout(()=>{const i=c.querySelectorAll('.trf i')[g.cnt-1];if(i){i.classList.add('on');i.style.background='#C8F25A';i.animate([{scale:'0'},{scale:'1.6'},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}
    const ct=c.querySelector('.ct b');if(ct){ct.textContent=g.cnt;ct.animate([{scale:'1'},{scale:'1.4'},{scale:'1'}],{duration:360})}hap('tick',null,{norip:1});
    _toast(`${g.n} に 1枚 ・ ${g.cnt} / 23 ・ あした 9:00 に ひらく`);try{renderOrb()}catch(e){}},260)}
{const _yf=yFriends;yFriends=function(){_yf();const F=$('yfx');if(!F)return;F.insertAdjacentHTML('beforeend',tripCards());tripBind(F)}}
/* ほかの 人も 撮る(デモ:Trip の 数が ふえる) */
setInterval(()=>{const g=GRP.find(g=>g.trip);if(!g||(g.cnt||0)>=23||Math.random()<.5)return;g.cnt++;(g.by=g.by||[]).push(Math.floor(Math.random()*g.m.length));
  const c=document.querySelector(`.trc[data-i="${GRP.indexOf(g)}"]`);if(c){const i=c.querySelectorAll('.trf i')[g.cnt-1];const f=g.m[g.by[g.cnt-1]];if(i){i.classList.add('on');i.style.background=avBg(f);i.animate([{scale:'0'},{scale:'1.5'},{scale:'1'}],{duration:400,easing:'cubic-bezier(.3,1.6,.4,1)'})}const ct=c.querySelector('.ct b');if(ct)ct.textContent=g.cnt}
  try{renderOrb()}catch(e){}},7000);

/* ---- グループ作成の 言葉を Trip に ---- */
{const t=$('gtt');if(t)t.textContent='あたらしい Trip'}
{const h=document.querySelector('#gp1 .ghd');if(h)h.textContent='Trip の なまえ'}
{const _gn=openGnw;openGnw=function(){_gn();const t=$('gtt');if(t)t.textContent='あたらしい Trip'}}

/* ---- デモの ボタン ---- */
{const C=$('ctl');if(C){C.insertAdjacentHTML('beforeend',`<button data-c="req54">申請が とどく</button><button data-c="trip54">Trip を つくる</button>`);
  C.querySelector('[data-c="req54"]').onclick=e=>{e.stopPropagation();reqIncoming()};C.querySelector('[data-c="trip54"]').onclick=e=>{e.stopPropagation();tripSeed()}}}
v54Counts();try{renderOrb()}catch(e){}
window.reqIncoming=reqIncoming;window.tripSeed=tripSeed;window.openDM=openDM;window.openAdd=openAdd;
/* TRIP の アイコンを スーツケースに */
OI.group='<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="7.5" width="16" height="12" rx="2.5"/><path d="M9 7.5V5.5a1.5 1.5 0 011.5-1.5h3A1.5 1.5 0 0115 5.5v2M9 11v5M15 11v5"/></svg>';
DL.keys=[];try{renderOrb()}catch(e){}
/* TRIP が あれば カードは「Open trip」→ Lattag yesterday の Trips へ */
{const _oa=orbActs;orbActs=function(){const R=_oa(),t=GRP.find(g=>g.trip);
  if(t&&R.A.group)R.A.group.run=()=>{openY();setTimeout(()=>{const tr=document.querySelector('#yfx .trs');const b=$('ybody');if(tr&&b)b.scrollTo({top:b.scrollHeight,behavior:'smooth'})},650)};
  DLG.group=t?'Open trip':'New trip';return R}}
DL.keys=[];try{renderOrb()}catch(e){}
