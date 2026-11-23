/* ===== v118(モック v118 ・ PROMPT v132 案):プロフィールを プロの 形に ・ 3案  名前:vpr =====
   案 a = カード(いちばん シンプル)/ b = アーカイブ(中身が 見える ・ おすすめ)/ c = めくる チェキ(3D は これ 1つ)/ now = いま(v117)
   データ:full = 2週間 使った 人 / new = はじめての 日 */
const VPRO={v:'b',data:'full',tab:'days'};
const VPRRM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const VPRI={
  grid:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9.3 4v16M14.7 4v16M4 9.3h16M4 14.7h16"/></svg>',
  lock:'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>',
  flip:'<svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 0113.7-5.6L20 8.5"/><path d="M20 4v4.5h-4.5"/><path d="M20 12a8 8 0 01-13.7 5.6L4 15.5"/><path d="M4 20v-4.5h4.5"/></svg>',
  cam:'<svg viewBox="0 0 24 24"><path d="M4 8.5A1.5 1.5 0 015.5 7h2l1.5-2h6l1.5 2h2A1.5 1.5 0 0120 8.5v9a1.5 1.5 0 01-1.5 1.5h-13A1.5 1.5 0 014 17.5z"/><circle cx="12" cy="13" r="3.4"/></svg>'};
const vprI=k=>`<span class="vpri">${VPRI[k]||H9XI[k]||''}</span>`;
function vprData(){const fresh=VPRO.data==='new',now=new Date(),before9=now.getHours()<9;
  const keys=['a','f','d','b','e','a','d','f','b','e','a','d','f','b'];
  const pos=['50% 50%','30% 40%','70% 30%','50% 70%','20% 50%','80% 60%','40% 20%','60% 80%','30% 70%','70% 50%','50% 30%','20% 80%','80% 20%','40% 60%'];
  const days=[];if(!fresh)for(let i=1;i<=13;i++){const d=new Date(now);d.setDate(d.getDate()-i);days.push({d,k:keys[i],p:pos[i],n:i%4===0?2:3,lk:i===1&&before9})}
  return {fresh,before9,today:fresh?0:2,streak:fresh?1:14,shots:fresh?2:38,opened:fresh?0:(before9?12:13),since:'2026年11月から',
    days,trips:fresh?[]:[{n:'修学旅行',s:'11/12 〜 11/14 ・ 5人 ・ 61枚',k:'e'},{n:'部活の 合宿',s:'11/02 〜 11/03 ・ 9人 ・ 40枚',k:'b'}],
    week:fresh?[...Array(13)].map(()=>0).concat([1]):[...Array(14)].map((_,i)=>i===0?0:1)}}
const vprDt=d=>`${String(d.getMonth()+1).padStart(2,'0')}.${String(d.getDate()).padStart(2,'0')}`;
const vprNum=D=>`<div class="vprnum"><div><b class="vprl">${D.streak}</b><small>日 れんぞく</small></div><div><b>${D.shots}</b><small>枚 撮った</small></div><div><b>${D.opened}</b><small>日 ひらいた</small></div></div>`;
const vprTags=()=>`<div class="vprtg"><p style="--c:${G9C.lime}">#朝型</p><p style="--c:${G9C.pink}">#散歩</p></div>`;
const vprBar=()=>`<div class="h9bar"><button class="h9cb" data-a="x" aria-label="とじる">${h9Ic('down')}</button><b class="vprid">@${K9.id}</b>
  <div class="vprmini" aria-hidden="true"><i style="background-image:url(${PH.c})"></i><b>たつき</b></div><button class="h9cb" aria-label="設定" data-a="set">${h9Ic('gear')}</button></div>`;
function vprGrid(D){
  const td=`<button class="vprtd" data-a="today" aria-label="きょうの 写真"><i class="vprdots">${[0,1,2].map(i=>`<i class="${i<D.today?'vpron':''}"></i>`).join('')}</i><b>きょう ${D.today}/3</b><small>あした 9:00<br>に ひらく</small></button>`;
  if(D.fresh)return `<div class="vprg">${td}</div><div class="vpremp"><b>ここに ひらいた 日が 並びます</b><small>きょう 撮った 写真は、あしたの 9:00 に<br>友だちと いっしょに ひらきます</small></div>`;
  return `<div class="vprg">${td}${D.days.map(x=>x.lk
     ?`<button class="vprlk" data-a="day" aria-label="${vprDt(x.d)} まだ ひらいて いない"><i class="vprbg" style="background-image:url(${PH[x.k]});background-position:${x.p}"></i><span class="vprlkc">${vprI('lock')}</span><small>9:00 に ひらく</small></button>`
     :`<button data-a="day" aria-label="${vprDt(x.d)} の 写真"><i class="vprbg" style="background-image:url(${PH[x.k]});background-position:${x.p}"></i><span class="vprct">${x.n}</span><span class="vprst">${vprDt(x.d)}</span></button>`).join('')}</div>`}
function vprTrips(D){if(!D.trips.length)return `<div class="vpremp"><b>Trip は まだ ありません</b><small>旅行や 合宿で みんなと 撮ると、ここに のこります</small></div>`;
  return `<div class="vprtrip">${D.trips.map(t=>`<button data-a="trip"><i style="background-image:url(${PH[t.k]})"></i><span><b>${t.n}</b><small>${t.s}</small></span></button>`).join('')}</div>`}
function vprA(D){return `<div class="vprsc">
   <div class="vprck"><i class="vprtp"></i><i class="vprph" style="background-image:url(${PH.c})"></i><button class="vprchg" data-a="photo" aria-label="写真を かえる">${vprI('cam')}</button><b class="vprnm">たつき</b></div>
   <p class="vprsub">${D.since}</p>${vprTags()}${vprNum(D)}
   <button class="vprb vprpri vprprim" data-a="share">${h9Ic('share')}プロフィールを 送る</button>
   <div class="vprrow"><button class="vprb" data-a="qr">${vprI('qr')}QR を 見せる</button><button class="vprb" data-a="scan">${vprI('scan')}QR を 読む</button><button class="vprb" data-a="edit">${vprI('pen')}編集</button></div></div>`}
function vprB(D){return `<div class="vprsc">
   <div class="vprhd"><div class="vprck"><i class="vprtp"></i><i class="vprph" style="background-image:url(${PH.c})"></i><button class="vprchg" data-a="photo" aria-label="写真を かえる">${vprI('cam')}</button></div>
     <div class="vprtx"><b class="vprnm">たつき</b><p class="vprsub">${D.since}</p>${vprTags()}</div></div>
   ${vprNum(D)}
   <div class="vprbtns"><button class="vprb" data-a="edit">編集</button><button class="vprb vprpri" data-a="share">${vprI('share')}送る</button><button class="vprb vpric" data-a="qr" aria-label="QR を 見せる">${vprI('qr')}</button><button class="vprb vpric" data-a="scan" aria-label="QR を 読む">${vprI('scan')}</button></div>
   <div class="vprtab" role="tablist"><button data-t="days" class="${VPRO.tab==='days'?'vpron':''}">${vprI('grid')}毎日<em>${D.opened}</em></button><button data-t="trip" class="${VPRO.tab==='trip'?'vpron':''}">${vprI('plane')}Trip<em>${D.trips.length}</em></button></div>
   <div class="vprbody">${VPRO.tab==='trip'?vprTrips(D):vprGrid(D)}</div></div>`}
function vprC(D){const back=`<div class="vprck vprbk">${p9Qr('meadow95','c')}<b>@later_6sd6dr7v</b><small>読みとると 友だち申請が とどく</small></div>`;
  return `<div class="vprsc">
   <div class="vprfl" id="vprfl"><div class="vprin"><div class="vprck vprfr"><i class="vprtp"></i><i class="vprph" style="background-image:url(${PH.c})"></i><b class="vprnm">たつき</b><i class="vprgl"></i></div>${back}</div></div>
   <button class="vprhint" data-a="flip">${vprI('flip')}<span class="vprlb">タップで QR</span></button>
   <p class="vprsub">${D.since} ・ #朝型 ・ #散歩</p>
   <div class="vprstk"><div class="vprt"><b>${D.streak}</b><small>日 れんぞく</small><em>この 2週間</em></div>
     <div class="vprd">${D.week.map((v,i)=>`<i class="${v?'vpron':''}${i===13?' vprtd':''}"></i>`).join('')}</div>
     <div class="vprf"><span><b>${D.shots}</b> 枚 撮った</span><span><b>${D.opened}</b> 日 ひらいた</span></div></div>
   <div class="vprbtns"><button class="vprb vprpri" data-a="share">${vprI('share')}プロフィールを 送る</button><button class="vprb vpric" data-a="scan" aria-label="QR を 読む">${vprI('scan')}</button><button class="vprb vpric" data-a="edit" aria-label="編集">${vprI('pen')}</button></div>
   <div class="vprreel"><h4>ひらいた 日<small>${D.opened} 日</small></h4><div class="vprr">${D.fresh?'':D.days.filter(x=>!x.lk).slice(0,8).map(x=>`<button data-a="day"><i style="background-image:url(${PH[x.k]});background-position:${x.p}"></i><small>${vprDt(x.d)}</small></button>`).join('')}</div>
   ${D.fresh?'<div class="vpremp" style="padding-top:6px"><small>あしたの 9:00 から ここに 並びます</small></div>':''}</div></div>`}
function vprQr(){const P=$('phone');let Q=$('vprq');if(!Q){P.insertAdjacentHTML('beforeend','<div class="vprq" id="vprq" role="dialog" aria-label="自分の QR"></div>');Q=$('vprq')}
  Q.innerHTML=`<div class="vprck">${p9Qr('meadow95','c')}<b>@later_6sd6dr7v</b><small>読みとると 友だち申請が とどく</small></div><button class="vprx">とじる</button>`;
  Q.querySelector('.vprx').onclick=()=>{Q.classList.remove('vpron');g9Hap('soft')};requestAnimationFrame(()=>Q.classList.add('vpron'));g9Hap('pop','ぷにっ(QR)')}
function vprFlip(S,to){const F=S.querySelector('#vprfl');if(!F)return;const b=to!=null?to:!F.classList.contains('vprback');F.classList.toggle('vprback',b);
  const L=S.querySelector('.vprhint .vprlb');if(L)L.textContent=b?'タップで もどす':'タップで QR';g9Hap('click','パタン(めくる)')}
function vprTilt(S){const F=S.querySelector('#vprfl');if(!F||VPRRM())return;let st=null,moved=0;
  F.addEventListener('pointerdown',e=>{st=[e.clientX,e.clientY];moved=0;F.classList.add('vprdrag')});
  F.addEventListener('pointermove',e=>{if(!st)return;const dx=e.clientX-st[0],dy=e.clientY-st[1];moved=Math.max(moved,Math.hypot(dx,dy));
    F.style.setProperty('--ry',Math.max(-14,Math.min(14,dx/6))+'deg');F.style.setProperty('--rx',Math.max(-12,Math.min(12,-dy/6))+'deg');F.style.setProperty('--gx',(50+dx/3)+'%')});
  const up=()=>{if(!st)return;st=null;F.classList.remove('vprdrag');F.style.setProperty('--ry','0deg');F.style.setProperty('--rx','0deg');F.style.setProperty('--gx','50%');if(moved<6)vprFlip(S)};
  F.addEventListener('pointerup',up);F.addEventListener('pointerleave',up);F.addEventListener('pointercancel',up)}
const vprOrigProf=h9ProfOpen;
function vprOpen(){if(VPRO.v==='now'){const S0=$('h9p');if(S0)S0.className='h9L h9prof'+(S0.classList.contains('on')?' on':'');return vprOrigProf()}
  const S=h9Layer('h9p','h9prof','プロフィール'),was=S.classList.contains('on');S.className='h9L h9prof vpr vpr-'+VPRO.v+(was?' on':'');
  const D=vprData();S.innerHTML=vprBar()+(VPRO.v==='a'?vprA(D):VPRO.v==='c'?vprC(D):vprB(D));
  S.querySelector('[data-a="x"]').onclick=()=>{S.classList.remove('on');g9Hap('soft')};
  S.querySelector('[data-a="set"]').onclick=()=>{g9Hap('pop');h9NotifOpen()};
  const go={share:()=>{g9Hap('pop');try{openShare({t:'たつき の Lattag\nhttps://lattag.app/u/later_6sd6dr7v'})}catch(e){g9Toast('プロフィールを 送る(モック)')}},
    qr:()=>vprQr(),scan:()=>{try{openScan()}catch(e){g9Toast('QR を 読む(モック)')}},edit:()=>{g9Hap('pop');g9Toast('編集(モック)')},
    photo:()=>{g9Hap('pop');g9Toast('写真を かえる(モック)')},flip:()=>vprFlip(S),
    today:()=>{g9Hap('warn','コツッ(まだ ひらけない)');g9Toast('あしたの 9:00 に ひらきます')},
    day:e=>{const b=e.currentTarget;if(b.classList.contains('vprlk')){g9Hap('warn');g9Toast('9:00 に ひらきます');return}g9Hap('pop');try{openY()}catch(_){g9Toast('その日の 写真(モック)')}},
    trip:()=>{g9Hap('pop');try{h9TripOpen()}catch(_){}}};
  S.querySelectorAll('[data-a]').forEach(b=>{const a=b.dataset.a;if(go[a])b.onclick=e=>{e.stopPropagation();go[a](e)}});
  S.querySelectorAll('.vprtab [data-t]').forEach(b=>b.onclick=()=>{if(VPRO.tab===b.dataset.t)return;VPRO.tab=b.dataset.t;g9Hap('sel','カチッ(タブ)');const sc=S.querySelector('.vprsc'),y=sc.scrollTop;vprOpen();S.querySelector('.vprsc').scrollTop=y});
  const sc=S.querySelector('.vprsc');sc.addEventListener('scroll',()=>S.classList.toggle('vprmin',VPRO.v==='b'&&sc.scrollTop>150),{passive:true});
  vprTilt(S);
  if(!was){requestAnimationFrame(()=>S.classList.add('on'));g9Hap('pop','ぷにっ(プロフィール)')}try{H9X.log.push('prof')}catch(_){}}
h9ProfOpen=vprOpen;
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-vpr]'))return;
  C.insertAdjacentHTML('beforeend',['now:★ v118 プロフィール:いま','a:★ v118 プロフィール:案1 カード','b:★ v118 プロフィール:案2 アーカイブ(決定)','c:★ v118 プロフィール:案3 めくる チェキ','new:★ v118 プロフィール:はじめての 日'].map(s=>{const i=s.indexOf(':');return `<button data-vpr="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-vpr]').forEach(b=>b.onclick=()=>{const k=b.dataset.vpr;if(k==='new')VPRO.data=VPRO.data==='new'?'full':'new';else VPRO.v=k;vprOpen()})})();
window.__kit=Object.assign(window.__kit||{},{vpr:(k,data)=>{if(k)VPRO.v=k;if(data)VPRO.data=data;VPRO.tab='days';const Q=$('vprq');if(Q)Q.classList.remove('vpron');vprOpen()},
  vprFlip:b=>vprFlip($('h9p'),b),vprTab:t=>{VPRO.tab=t;vprOpen()},vprQr:()=>vprQr(),VPR:()=>Object.assign({},VPRO)});
