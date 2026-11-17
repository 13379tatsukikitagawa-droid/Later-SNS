/* ================= v56 Trip を Once ふうに(旅の フィルム 1本 ・ QR の パスで みんなを 呼ぶ) =================
   ・Home の Trip ページ:表紙の 写真 + 行き先 + 23こまの フィルム + カウンター
   ・New trip:上に「パス(チケット)」の 見本、下に 表紙 / 行き先 / 日にち / ともだち。入力すると パスが その場で 変わる
   ・できたら パスが 印刷されて 出てくる → QR と KEY で みんなを 呼ぶ
   ・⋯ = Trip の 設定(パス ・ 変える ・ メンバー ・ おわる ・ ぬける) */
const TPW=['maple','peach','cocoa','sunny','lemon','ocean','berry','cloud','mango','olive','pearl','minty'];
const TPC=['a','d','b','f','c','e'];
const TPS=[['京都','Kyoto'],['沖縄','Okinawa'],['修学旅行','School trip'],['卒業旅行','Grad trip'],['合宿','Camp'],['ライブ遠征','Live tour']];
const tKey=()=>'#'+TPW[Math.floor(Math.random()*TPW.length)]+(10+Math.floor(Math.random()*890));
const tMD=d=>MON[d.getMonth()].toUpperCase()+' '+d.getDate();
const tDot=d=>p2(d.getMonth()+1)+'.'+p2(d.getDate());
function tDays(g){return Math.max(1,Math.round((g.to-g.from)/864e5)+1)}
function tDayNo(g){return Math.max(1,Math.min(tDays(g),Math.floor((Date.now()-g.from)/864e5)+1))}
function tEn(n){const h=TPS.find(s=>n.startsWith(s[0]));return h?h[1]:n.replace(/\s.*$/,'')}
/* QR っぽい 模様(見た目だけ。本番は CoreImage の CIQRCodeGenerator) */
function tQR(seed,sz){let h=0;for(const c of seed)h=(h*31+c.charCodeAt(0))>>>0;const N=25,r=()=>{h^=h<<13;h>>>=0;h^=h>>17;h^=h<<5;h>>>=0;return h%100};
  let s='';for(let y=0;y<N;y++)for(let x=0;x<N;x++){const f=(a,b)=>x>=a&&x<a+7&&y>=b&&y<b+7;if(f(0,0)||f(N-7,0)||f(0,N-7))continue;if(r()<47)s+=`<rect x="${x}" y="${y}" width="1" height="1"/>`}
  const fp=(a,b)=>`<rect x="${a}" y="${b}" width="7" height="7"/><rect x="${a+1}" y="${b+1}" width="5" height="5" fill="#F4F1EA"/><rect x="${a+2}" y="${b+2}" width="3" height="3"/>`;
  return `<svg class="tqr" viewBox="-1 -1 ${N+2} ${N+2}" width="${sz}" height="${sz}" shape-rendering="crispEdges"><g fill="#111">${s}${fp(0,0)}${fp(N-7,0)}${fp(0,N-7)}</g></svg>`}
function tKeyHtml(k){const m=k.match(/^#([a-z]+)(\d+)$/);return m?`<b>#${m[1]}</b><em>${m[2]}</em>`:`<b>${k}</b>`}

/* ---------- パス(チケット)── New trip の 見本 と QR の 共有で 同じ もの ---------- */
function tPass(g,o={}){const days=tDays(g),mem=[{me:1},...(g.m||[])];
  return `<div class="tps${o.big?' big':''}${o.blank?' blank':''}">
    <div class="tpt"><i class="cv" style="background-image:url(${PH[g.cover||'a']})"></i>
      <div class="tph"><span>LATTAG</span><span>TRIP PASS</span></div>
      <b class="tpd">${rmEsc(g.en||tEn(g.n||'')) || '—'}</b><small class="tpj">${rmEsc(g.n||'どこへ?')}</small>
      <div class="tpr"><div><span>FROM</span><b>${tMD(g.from)}</b></div><i class="ar">→</i><div><span>TO</span><b>${tMD(g.to)}</b></div><div class="r"><span>DAYS</span><b>${days}</b></div></div>
      <div class="tpm"><span class="avs">${mem.slice(0,6).map(f=>f.me?`<i class="me">ゆ</i>`:`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span><span>${mem.length} aboard ・ 23 / day</span></div></div>
    <div class="tpp"><i></i></div>
    <div class="tpb">${o.blank?`<div class="tqr0"><span>QR</span></div>`:tQR(g.key||'x',o.big?118:74)}
      <div class="tpk"><span>KEY</span><div class="k">${o.blank?'<b>#·····</b>':tKeyHtml(g.key)}</div><small>SCAN TO JOIN ・ あした 9:00 に 現像</small></div>
      <i class="st"></i></div></div>`}

/* ---------- Home の Trip ページ(2枚目)---------- */
function tFilm(g,n){const c=g.cnt||0;return `<div class="tfm"><i class="sp"></i><div class="fr">${Array.from({length:23},(_,j)=>{const w=g.by&&g.by[j];const f=w==='me'?null:(g.m||[])[w];
    return `<span class="${j<c?'on':''}${j===c?' nx':''}" style="${j<c?`--c:${w==='me'?'#C8F25A':(f?f.g[1]:'#9ED6A5')}`:''}">${(j+1)%5===0||j===0?`<s>${p2(j+1)}</s>`:''}</span>`}).join('')}</div><i class="sp"></i></div>`}
function tripPage(){const C=$('hpc2');if(!C)return;const t=GRP.find(g=>g.trip);C.className='hpc pt2'+(t?'':' none');
  if(!t){C.innerHTML=`<div class="t0st hpe">${['f','b','d'].map((p,j)=>`<i style="background-image:url(${PH[p]});--r:${(j-1)*8}deg;--x:${(j-1)*46}px;--y:${Math.abs(j-1)*10}px"></i>`).join('')}</div>
      <div class="t0tx hpe"><span class="mono">02 / 04 ・ TRIP</span><b>Take a trip,<br><em>together.</em></b><small>旅行 ・ 合宿 ・ イベント。1日 23枚を、みんなで。</small></div>
      <div class="t0bt hpe"><button class="w" data-a="new"><span>New trip</span><i><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></i></button><button class="s" data-a="scan" aria-label="QR で 参加"><svg viewBox="0 0 24 24"><path d="M4 8V5h3M17 5h3v3M20 16v3h-3M7 19H4v-3M4 12h16"/></svg></button></div>`;
    C.querySelector('[data-a="new"]').onclick=()=>{hap('pop','ぷにっ(New trip)');openTrip()};C.querySelector('[data-a="scan"]').onclick=()=>{hap('pop');openScan('fr')};return}
  const c=t.cnt||0,d=tDayNo(t),days=tDays(t);
  C.innerHTML=`<i class="tbg" style="background-image:url(${PH[t.cover||'a']})"></i><i class="tsh"></i>
    <div class="ttp hpe"><span class="mono">TRIP ・ DAY ${d} / ${days}</span><button data-a="qr" aria-label="パスを 見せる"><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg></button><button data-a="set" aria-label="設定"><svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18" cy="12" r="1.6"/></svg></button></div>
    <div class="ttl hpe"><b>${rmEsc(t.en||tEn(t.n))}</b><small>${rmEsc(t.n)} ・ ${tDot(t.from)} — ${tDot(t.to)}</small></div>
    <div class="tcn hpe"><div class="tcw"><b>${p2(c)}</b></div><div class="tx"><span class="mono">SHOTS TODAY</span><b>${c}<s>/ 23</s></b><span class="avs">${[{me:1},...t.m].slice(0,5).map(f=>f.me?`<i class="me">ゆ</i>`:`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span></div></div>
    <div class="hpe tfw">${tFilm(t)}</div>
    <span class="ttdv mono hpe">あした 9:00、みんなで 現像</span>
    <div class="tbt hpe"><button class="w" data-a="shot">${OI.shoot}<span>Shoot for trip</span></button><button class="s" data-a="chat" aria-label="チャット">${ICH}${t.un?`<u>${t.un}</u>`:''}</button></div>`;
  C.querySelector('[data-a="shot"]').onclick=()=>{if(c>=23){hap('warn');shake(C);_toast('今日の 23枚が うまりました ・ あした 9:00 に 現像');return}
    hap('shutter','カシャッ(Trip に 1枚)');const fl=document.createElement('i');fl.className='trfl';C.appendChild(fl);fl.animate([{opacity:0},{opacity:.9,offset:.15},{opacity:0}],{duration:480}).onfinish=()=>fl.remove();
    t.cnt=c+1;(t.by=t.by||[]).push('me');setTimeout(()=>{tripPage();const s=C.querySelectorAll('.tfm .fr span')[t.cnt-1];s&&s.animate([{scale:'1.8',filter:'brightness(2)'},{scale:'1',filter:'none'}],{duration:520,easing:'cubic-bezier(.3,1.5,.5,1)'});
      const w=C.querySelector('.tcw b');w&&w.animate([{translate:'0 -100%',opacity:0},{translate:'0 0',opacity:1}],{duration:360,easing:'cubic-bezier(.3,1.4,.5,1)'});hap('tick',null,{norip:1})},240)};
  C.querySelector('[data-a="chat"]').onclick=()=>openRoom(t);
  C.querySelector('[data-a="qr"]').onclick=()=>{hap('pop');openPass(t)};
  C.querySelector('[data-a="set"]').onclick=()=>tripSet(t)}
{const _h=hpRender;hpRender=function(only){_h(only);if(!only||only===2)tripPage()}}

/* ---------- New trip(作る / 変える) ---------- */
var TW={on:false,g:null,edit:null,sel:null};
function openTrip(edit){if(TW.on)return;TW.on=true;const today=new Date();today.setHours(0,0,0,0);
  TW.edit=edit||null;TW.g=edit?{...edit,m:[...edit.m]}:{n:'',en:'',cover:'a',from:today,to:new Date(+today+2*864e5),m:FR.slice(0,3),key:''};TW.sel=null;
  let W=$('trw');if(!W){W=document.createElement('section');W.className='trw';W.id='trw';$('phone').appendChild(W)}
  const g=TW.g,days=Array.from({length:12},(_,i)=>new Date(+today+i*864e5));
  W.innerHTML=`<div class="twh"><button class="x" data-a="x" aria-label="とじる"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button><span class="mono">${edit?'TRIP SETTINGS':'NEW TRIP'}</span><span class="sp"></span></div>
    <div class="twb" id="twb"><div class="twp" id="twp">${tPass(g,{blank:!edit})}</div>
      <section class="tws"><span class="lb">Cover</span><div class="twc">${TPC.map(p=>`<button data-p="${p}" class="${g.cover===p?'on':''}" style="background-image:url(${PH[p]})"></button>`).join('')}<button class="roll" data-p="roll"><svg viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="14" rx="2.5"/><circle cx="9" cy="10" r="1.8"/><path d="M20.5 16l-5-5-8 8"/></svg></button></div></section>
      <section class="tws"><span class="lb">Where</span><label class="twn"><input id="twn" maxlength="14" placeholder="どこへ?" value="${rmEsc(g.n)}"></label>
        <div class="twch">${TPS.map(([j,e])=>`<button data-n="${j}" data-e="${e}">${j}</button>`).join('')}</div></section>
      <section class="tws"><span class="lb">When</span><span class="lr mono" id="twdn">${tDays(g)} DAYS</span><div class="twd" id="twd">${days.map((d,i)=>`<button data-i="${i}"><span>${WD[d.getDay()].slice(0,2)}</span><b>${d.getDate()}</b></button>`).join('')}</div>
        <small class="hn">はじまりの日 → おわりの日 を 押す</small></section>
      <section class="tws"><span class="lb">Who</span><span class="lr mono" id="twmn"></span><div class="twf">${FR.map((f,i)=>`<button data-i="${i}" class="${g.m.includes(f)?'on':''}"><i style="background:${avBg(f)}">${f.n[0]}</i><small>${f.n}</small></button>`).join('')}<button class="tql" data-a="qrlater"><i><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg></i><small>あとで QR</small></button></div></section>
      <section class="tws rl"><span>1日 23枚 ・ みんなで</span><span>あした 9:00 に 現像</span><span>7日で きえる</span></section>
      ${edit?`<section class="tws dz"><button data-a="end">Trip を おわる</button><button data-a="leave">ぬける</button></section>`:''}</div>
    <div class="twg"><button class="go" id="twgo" ${g.n?'':'disabled'}><span>${edit?'Save':'Create trip'}</span><i><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg></i></button></div>`;
  twDraw(true);twBind();W.classList.add('on');hap('soft','ふわっ(はじまる)');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches){$('twp').animate([{transform:'translateY(-40px) rotate(-3deg)',opacity:0},{transform:'none',opacity:1}],{duration:640,delay:80,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'});
    W.querySelectorAll('.tws').forEach((s,i)=>s.animate([{opacity:0,transform:'translateY(20px)'},{opacity:1,transform:'none'}],{duration:480,delay:200+i*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}}
function twDraw(first){const g=TW.g,W=$('trw');if(!W)return;
  if(!first){const P=$('twp');P.innerHTML=tPass(g,{blank:!TW.edit})}
  const today=new Date();today.setHours(0,0,0,0);const a=Math.round((g.from-today)/864e5),b=Math.round((g.to-today)/864e5);
  W.querySelectorAll('#twd button').forEach(x=>{const i=+x.dataset.i;x.classList.toggle('in',i>a&&i<b);x.classList.toggle('a',i===a);x.classList.toggle('b',i===b);x.classList.toggle('pk',TW.sel===i)});
  $('twdn').textContent=tDays(g)+(tDays(g)>1?' DAYS':' DAY');$('twmn').textContent=(g.m.length+1)+' PEOPLE';
  $('twgo').disabled=!g.n.trim()}
function twBind(){const W=$('trw'),g=TW.g;
  W.querySelector('[data-a="x"]').onclick=()=>closeTrip();
  W.querySelectorAll('.twc button').forEach(b=>b.onclick=()=>{if(b.dataset.p==='roll'){hap('pop');_toast('カメラロールから えらぶ(モック)');return}
    g.cover=b.dataset.p;W.querySelectorAll('.twc button').forEach(x=>x.classList.toggle('on',x===b));hap('sel','コツッ(表紙)');twDraw();
    $('twp').querySelector('.cv').animate([{opacity:0,scale:'1.1'},{opacity:1,scale:'1'}],{duration:420})});
  const N=$('twn');N.oninput=()=>{g.n=N.value;g.en=tEn(N.value.trim());twDraw();const d=$('twp').querySelector('.tpd');d&&d.animate([{opacity:.4},{opacity:1}],{duration:200})};
  W.querySelectorAll('.twch button').forEach(b=>b.onclick=()=>{N.value=b.dataset.n;g.n=b.dataset.n;g.en=b.dataset.e;hap('sel','コツッ('+b.dataset.n+')');twDraw();
    $('twp').querySelector('.tpd').animate([{transform:'translateY(10px)',opacity:0},{transform:'none',opacity:1}],{duration:360,easing:'cubic-bezier(.3,1.4,.5,1)'})});
  W.querySelectorAll('#twd button').forEach(b=>b.onclick=()=>{const i=+b.dataset.i,today=new Date();today.setHours(0,0,0,0);const d=new Date(+today+i*864e5);
    if(TW.sel===null){TW.sel=i;g.from=d;g.to=d;hap('tick','コツ(はじまり)',{norip:1})}else{const s=Math.min(TW.sel,i),e=Math.max(TW.sel,i);g.from=new Date(+today+s*864e5);g.to=new Date(+today+e*864e5);TW.sel=null;hap('click','カチッ(おわり)',{norip:1})}twDraw()});
  W.querySelectorAll('.twf button[data-i]').forEach(b=>b.onclick=()=>{const f=FR[+b.dataset.i],k=g.m.indexOf(f);if(k>=0)g.m.splice(k,1);else g.m.push(f);b.classList.toggle('on',k<0);hap(k<0?'pop':'soft',null,{norip:1});
    b.querySelector('i').animate([{scale:'1'},{scale:k<0?'1.18':'.86'},{scale:'1'}],{duration:300,easing:'cubic-bezier(.3,1.6,.4,1)'});twDraw()});
  W.querySelector('[data-a="qrlater"]').onclick=()=>{hap('sel');_toast('作ったあと、パスの QR で だれでも 参加できます')};
  const en=W.querySelector('[data-a="end"]');if(en)en.onclick=()=>{if(!en.dataset.ok){en.dataset.ok=1;en.textContent='もういちど 押すと おわる';hap('warn');return}const i=GRP.indexOf(TW.edit);if(i>=0)GRP.splice(i,1);closeTrip(true);_toast('Trip を おわりました ・ 写真は 7日 のこる');renderGroups();try{renderOrb()}catch(e){}};
  const lv=W.querySelector('[data-a="leave"]');if(lv)lv.onclick=()=>{if(!lv.dataset.ok){lv.dataset.ok=1;lv.textContent='もういちど 押すと ぬける';hap('warn');return}const i=GRP.indexOf(TW.edit);if(i>=0)GRP.splice(i,1);closeTrip(true);_toast('Trip を ぬけました');try{renderOrb()}catch(e){}};
  $('twgo').onclick=()=>{if(!g.n.trim())return;tripCreate()}}
function closeTrip(fast){const W=$('trw');if(!W||!TW.on)return;TW.on=false;W.classList.remove('on');if(!fast)hap('soft','やわらかく1回(もどる)')}
function tripCreate(){const g=TW.g,W=$('trw');
  if(TW.edit){Object.assign(TW.edit,{n:g.n.trim(),en:g.en||tEn(g.n),cover:g.cover,from:g.from,to:g.to,m:g.m});hap('success','トトトン(保存)',{norip:1});closeTrip(true);try{renderOrb()}catch(e){}_toast('Trip を 変えました');return}
  const t={n:g.n.trim(),en:g.en||tEn(g.n),cover:g.cover,from:g.from,to:g.to,m:g.m,trip:true,cnt:0,by:[],key:tKey(),sub:(g.m.length+1)+'人',un:0,last:'Trip が はじまりました'};
  GRP.unshift(t);const P=$('twp');P.innerHTML=tPass(t);
  /* パスが 印刷されて 出てくる */
  hap('projector','ジジジ(印刷)',{norip:1});
  const q=P.querySelector('.tqr');if(q)q.animate([{clipPath:'inset(0 0 100% 0)'},{clipPath:'inset(0 0 0 0)'}],{duration:900,easing:'steps(12)'});
  P.animate([{transform:'none'},{transform:'translateY(6px) scale(.98)',offset:.2},{transform:'translateY(-8px) rotate(-1.5deg)'},{transform:'none'}],{duration:900,easing:'cubic-bezier(.3,1.3,.5,1)'});
  $('twb').scrollTo({top:0,behavior:'smooth'});
  setTimeout(()=>{hap('success','トトトン(できた)',{norip:1});closeTrip(true);renderGroups();try{renderOrb()}catch(e){}openPass(t,true)},1000)}

/* ---------- パスを 見せる(QR で みんなを 呼ぶ)---------- */
function openPass(t,fresh){let S=$('tpv');if(!S){S=document.createElement('section');S.className='tpv';S.id='tpv';$('phone').appendChild(S)}
  S.innerHTML=`<i class="tpvs" data-a="x"></i><div class="in"><span class="mono hd">${fresh?'YOUR TRIP IS READY':'TRIP PASS'}</span>${tPass(t,{big:1})}
    <div class="acts"><button data-a="share"><svg viewBox="0 0 24 24"><path d="M12 15V4M7 9l5-5 5 5M5 14v6h14v-6"/></svg><span>Share</span></button><button data-a="save"><svg viewBox="0 0 24 24"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg><span>Save</span></button><button data-a="copy"><svg viewBox="0 0 24 24"><rect x="8" y="8" width="12" height="12" rx="2.5"/><path d="M16 8V5.5A1.5 1.5 0 0014.5 4h-9A1.5 1.5 0 004 5.5v9A1.5 1.5 0 005.5 16H8"/></svg><span>Copy key</span></button></div>
    <button class="dn" data-a="x">${fresh?'Start the trip':'閉じる'}</button></div>`;
  S.classList.add('on');const T=S.querySelector('.tps');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches){T.animate([{transform:'translateY(120%) rotate(8deg)'},{transform:'translateY(-14px) rotate(-2deg)',offset:.7},{transform:'none'}],{duration:760,easing:'cubic-bezier(.3,1.1,.4,1)'});
    const q=T.querySelector('.tqr');q&&q.animate([{clipPath:'inset(0 0 100% 0)'},{clipPath:'inset(0 0 0 0)'}],{duration:800,delay:420,easing:'steps(14)',fill:'backwards'});
    S.querySelectorAll('.acts button,.dn').forEach((b,i)=>b.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,delay:600+i*60,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}))}
  hap('land','トン(パス)',{norip:1});setTimeout(()=>hap('projector',null,{norip:1}),440);
  S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=()=>{S.classList.remove('on');hap('soft')});
  S.querySelector('[data-a="share"]').onclick=()=>{hap('pop');openShare({t:`Lattag の Trip「${t.n}」に 参加しよう\nKEY ${t.key}\nhttps://lattag.app/t/${t.key.slice(1)}`,h:t.n})};
  S.querySelector('[data-a="save"]').onclick=e=>{hap('success',null,{norip:1});_toast('パスを 写真に 保存しました(モック)')};
  S.querySelector('[data-a="copy"]').onclick=()=>{hap('click');try{navigator.clipboard&&navigator.clipboard.writeText(t.key)}catch(_){}_toast('KEY '+t.key+' を コピーしました')}}

/* ---------- ⋯ = Trip の 設定 ---------- */
function tripSet(t){hap('sel','コツッ(設定)');actSheet(`${t.n} ・ ${tDot(t.from)} — ${tDot(t.to)}`,[
  {l:'パスを 見せる(QR ・ KEY)',fn:()=>{ovClose('acs');setTimeout(()=>openPass(t),260)}},
  {l:'行き先 ・ 日にち ・ 表紙 ・ メンバーを 変える',fn:()=>{ovClose('acs');setTimeout(()=>openTrip(t),260)}},
  {l:'チャット',fn:()=>{ovClose('acs');setTimeout(()=>openRoom(t),260)}},
  {l:'Trip を おわる',red:1,fn:b=>{if(!b.dataset.ok){b.dataset.ok=1;b.querySelector('span').textContent='もういちど 押すと おわる(写真は 7日 のこる)';return}ovClose('acs');const i=GRP.indexOf(t);if(i>=0)GRP.splice(i,1);setTimeout(()=>{renderGroups();try{renderOrb()}catch(e){}_toast('Trip を おわりました')},260)}}])}

/* ---------- デモの Trip も 新しい 形に ---------- */
{const _ts=tripSeed;tripSeed=function(){const had=GRP.find(g=>g.trip);_ts();const t=GRP.find(g=>g.trip);if(t&&!had){const d=new Date();d.setHours(0,0,0,0);Object.assign(t,{en:'Kyoto',cover:'b',from:new Date(+d-864e5),to:new Date(+d+864e5),key:'#maple24'});try{renderOrb();renderGroups()}catch(e){}}};window.tripSeed=tripSeed}
/* Lattag yesterday の Trips の カードも Once ふうに */
tripCards=function(){const T=GRP.filter(g=>g.trip);
  return `<div class="axh yax"><span>TRIPS</span><em>1日 23枚 ・ みんなで</em></div><div class="trs">${T.map(g=>`<div class="trc v56" data-i="${GRP.indexOf(g)}"><i class="bg" style="background-image:url(${PH[g.cover||'a']})"></i><i class="sh2"></i>
      <span class="mono tk">DAY ${tDayNo(g)} / ${tDays(g)}</span><b class="tn">${rmEsc(g.en||tEn(g.n))}</b><small class="tj">${rmEsc(g.n)} ・ ${tDot(g.from)} — ${tDot(g.to)}</small>
      ${tFilm(g)}<div class="trb"><span class="ct"><b>${g.cnt||0}</b>/23</span><button class="trsh" data-a="shot" aria-label="撮る">${OI.shoot}</button><button class="cht" data-a="chat" aria-label="チャット">${ICH}${g.un?`<u>${g.un}</u>`:''}</button></div></div>`).join('')}
    <button class="trc nw v56" data-a="new"><span class="pl">${ICO.plus}</span><b>New trip</b><small>旅行 ・ 合宿 ・ イベント</small></button></div>`};
{const _tb=tripBind;tripBind=function(R){_tb(R);const n=R.querySelector('.trc.nw');if(n)n.onclick=()=>{hap('pop','ぷにっ(New trip)');closeY();setTimeout(()=>openTrip(),350)}}}
/* カメラの TRIP ボタン:Trip が なければ New trip を ひらく */
{const _oa=orbActs;orbActs=function(){const R=_oa();if(R.A.group&&!GRP.find(g=>g.trip))R.A.group.run=()=>openTrip();return R}}
{const _ca=closeAll;closeAll=function(){if(TW.on)closeTrip(true);const p=$('tpv');if(p)p.classList.remove('on');return _ca.apply(this,arguments)}}
try{renderOrb()}catch(e){}
window.openTrip=openTrip;window.openPass=openPass;
