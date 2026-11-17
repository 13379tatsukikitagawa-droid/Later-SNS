/* ================= v46 ================= */
/* --- 数字が ころがる(numericText ふう) --- */
function roll(el,str){if(!el)return;const ch=[...String(str)];
  const same=el._s!==undefined&&el._s.length===ch.length&&[...el._s].every((c,i)=>/\d/.test(c)===/\d/.test(ch[i]));
  if(!same){el.classList.add('rl');el.innerHTML=ch.map(c=>/\d/.test(c)?`<span class="rd"><span class="rs">${'0123456789'.split('').map(d=>`<i>${d}</i>`).join('')}</span></span>`:`<span class="rx">${c===' '?'&nbsp;':c}</span>`).join('');
    void el.offsetWidth;requestAnimationFrame(()=>ch.forEach((c,i)=>{if(/\d/.test(c)){const s=el.children[i].firstChild;s.style.transitionDelay=(i*45)+'ms';s.style.transform=`translateY(${-c*10}%)`}}))}
  else ch.forEach((c,i)=>{const n=el.children[i];if(/\d/.test(c)){const s=n.firstChild;s.style.transitionDelay='0ms';s.style.transform=`translateY(${-c*10}%)`}else n.innerHTML=c===' '?'&nbsp;':c});
  el._s=ch.join('')}
const minTo=(h)=>{const d=new Date(),t=new Date(d);t.setHours(h,0,0,0);if(t<=d)t.setDate(t.getDate()+1);return (t-d)/1000};
const secLO=()=>{const d=new Date();return Math.max(0,86400-(d.getHours()*3600+d.getMinutes()*60+d.getSeconds()))};
const secOP=()=>minTo(9);
const hm=s=>{s=Math.floor(s/60);const h=Math.floor(s/60),m=s%60;return h>0?`${h}h ${p2(m)}m`:`${m}m`};
const hms=s=>{s=Math.floor(s);const h=Math.floor(s/3600),m=Math.floor(s%3600/60),x=s%60;return [h,p2(m),p2(x)]};

/* --- うえの ライブ ピル(消灯まで / ひらくまで) --- */
function lpFilm(){const left=3-shots;return [0,1,2].map(i=>`<i class="${i<left?'':'o'}"></i>`).join('')+`<b>${left}</b>`}
function lpTick(){const lo=secLO(),op=secOP();
  const H=$('hst');if(H){roll($('hlod'),hm(lo));H.style.setProperty('--lpp',(100-lo/864).toFixed(1))}
  const Y=$('ypill');if(Y){roll($('ypd'),hm(op));Y.style.setProperty('--lpp',(100-op/864).toFixed(1))}
  if(LP.on)lpLive()}
renderYMeta=function(){if(!$('ypill'))return;$('ypt').textContent='ひらくまで';$('ybars').innerHTML=lpFilm();$('ylock')&&$('ylock').classList.toggle('hide',shots>0);lpTick()};
{const _rh=renderHome;renderHome=function(a){_rh(a);try{$('ybars').innerHTML=lpFilm()}catch(e){}lpTick()}}
setInterval(lpTick,1000);

/* --- ライブ パネル(ピルが ひろがる:Dynamic Island ふう) --- */
var LP={on:false,from:null,k:'op'};
function lpTrack(){const d=new Date(),nowH=d.getHours()+d.getMinutes()/60+d.getSeconds()/3600,T=33,X=h=>(h/T*100).toFixed(2);
  const sh=TM.slice(0,shots).map(t=>{const [a,b]=t.split(':').map(Number);return a+b/60});
  return `<div class="bar"><i class="z1"></i><i class="z2" style="left:${X(24)}%"></i><i class="fill" style="width:${X(nowH)}%"></i>
    ${sh.map((h,i)=>`<i class="sh" style="left:${X(h)}%;--i:${i}"></i>`).join('')}
    <i class="mk" style="left:${X(9)}%"></i><i class="mk lo" style="left:${X(24)}%"></i><i class="now" id="lpnow" style="left:${X(nowH)}%"></i></div>
    <div class="lbs"><span style="left:0">0:00</span><span style="left:${X(9)}%">9:00</span><span class="r" style="left:${X(24)}%">24:00</span><span class="e" style="left:100%">9:00 OPEN</span></div>`}
function lpFrames(){const P=['c','a','e'];return [0,1,2].map(i=>i<shots?`<button class="lf on" data-i="${i}" style="--bg:url(${PH[P[i]]})"><i></i><span>DEV</span></button>`:`<button class="lf" data-i="${i}" aria-label="撮る"><svg viewBox="0 0 24 24"><path d="M12 7v10M7 12h10"/></svg></button>`).join('')}
function lpBuild(){const K=$('lpk'),op=LP.k==='op',full=shots>=3;
  K.innerHTML=`<div class="lpin"><div class="lph"><span class="lv"><i></i>LIVE</span><span class="lt" id="lpclk"></span><button class="lpxx" id="lpxx" aria-label="とじる"><svg viewBox="0 0 12 12"><path d="M3 7.5l3-3 3 3"/></svg></button></div>
    <div class="lpm"><span class="k">${op?'ひらくまで':'消灯まで'}</span><div class="big"><b id="lpH"></b><em>:</em><b id="lpM"></b><small id="lpS"></small></div>
      <span class="k2">${op?'消灯まで':'ひらくまで'} <b id="lpk2"></b></span></div>
    <div class="lptr" id="lptr">${lpTrack()}</div>
    <div class="lpbt"><div class="lpfr" id="lpfr">${lpFrames()}</div>
      <button class="lpgo${full?' dv':''}" id="lpgo">${full?`<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg><span>develop<small>opens 9:00</small></span>`:`${ICO.cam}<span>shoot<small>${3-shots} left</small></span>`}</button></div></div>`;
  $('lpxx').onclick=e=>{e.stopPropagation();closeLive()};
  $('lpgo').onclick=()=>{hap(full?'pop':'shutter',full?'ぷにっ(現像を のぞく)':'カシャッ(撮影へ)');closeLive(true);if(full)setTimeout(()=>{closeAll();setTimeout(()=>openDvx(2),380)},260);else setTimeout(shootAny,220)};
  K.querySelectorAll('.lf').forEach(b=>b.onclick=()=>{const i=+b.dataset.i;if(i<shots){hap('pop','ぷにっ(現像を のぞく)');closeLive(true);setTimeout(()=>{closeAll();setTimeout(()=>openDvx(i),380)},260)}else{hap('shutter','カシャッ(撮影へ)');closeLive(true);setTimeout(shootAny,220)}})}
function lpLive(){const d=new Date(),op=LP.k==='op',s=op?secOP():secLO(),[h,m,x]=hms(s);roll($('lpH'),String(h));roll($('lpM'),m);roll($('lpS'),x);
  $('lpclk')&&($('lpclk').textContent=HM()+':'+p2(d.getSeconds()));$('lpk2')&&roll($('lpk2'),hm(op?secLO():secOP()));
  const n=$('lpnow');if(n){const nowH=d.getHours()+d.getMinutes()/60+d.getSeconds()/3600;n.style.left=(nowH/33*100).toFixed(2)+'%'}
  if(x==='00'&&LP.on)hap('tick',null,{norip:1})}
function openLive(from){if(LP.on)return;LP.on=true;LP.from=from;LP.k=from.dataset.lp;const X=$('lpx'),K=$('lpk');lpBuild();
  const r=rel(from),W=366,Hh=0;K.style.setProperty('--w',W+'px');const inn=K.querySelector('.lpin');
  X.classList.add('on');X.setAttribute('aria-hidden','false');const H2=inn.offsetHeight;
  const L=(390-W)/2,T=Math.max(52,r.y-8);from.classList.add('lpo');
  K.style.cssText=`--w:${W}px;left:${L}px;top:${T}px;width:${W}px;height:${H2}px`;
  K.animate([{left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px',borderRadius:r.h/2+'px'},{left:(L-4)+'px',top:(T-2)+'px',width:(W+8)+'px',height:(H2+6)+'px',borderRadius:'38px',offset:.62},{left:L+'px',top:T+'px',width:W+'px',height:H2+'px',borderRadius:'36px'}],{duration:620,easing:'cubic-bezier(.3,.9,.3,1)'});
  inn.animate([{opacity:0,filter:'blur(8px)',transform:'scale(.96)'},{opacity:1,filter:'blur(0)',transform:'none'}],{duration:420,delay:150,easing:'cubic-bezier(.2,.9,.3,1)',fill:'both'});
  [...inn.querySelectorAll('.lf,.lpgo,.lptr .sh')].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(10px) scale(.9)'},{opacity:1,transform:'none'}],{duration:460,delay:300+i*50,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'backwards'}));
  hap('pop','ぷにっ(ライブが ひらく)');[200,300,400,500].forEach(t=>setTimeout(()=>hap('tick',null,{norip:1}),t));lpLive()}
function closeLive(fast){if(!LP.on)return;LP.on=false;const X=$('lpx'),K=$('lpk'),from=LP.from,r=rel(from),inn=K.querySelector('.lpin');
  inn.getAnimations().forEach(a=>a.cancel());inn.animate([{opacity:1},{opacity:0,filter:'blur(6px)'}],{duration:160,fill:'forwards'});
  const a=K.animate([{left:K.style.left,top:K.style.top,width:K.style.width,height:K.style.height,borderRadius:'36px'},{left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px',borderRadius:r.h/2+'px'}],{duration:fast?300:440,easing:'cubic-bezier(.5,0,.2,1)',fill:'forwards'});
  X.classList.remove('on');X.setAttribute('aria-hidden','true');if(!fast)hap('soft','ふわっ(しまう)',{norip:1});
  a.onfinish=()=>{from.classList.remove('lpo');K.getAnimations().forEach(x=>x.cancel());K.style.cssText='';K.innerHTML=''}}
$('lpsc').onclick=()=>closeLive();
{let y0=null;$('lpk').addEventListener('pointerdown',e=>{if(e.target.closest('button'))return;y0=e.clientY});$('lpk').addEventListener('pointerup',e=>{if(y0!==null&&e.clientY-y0<-24)closeLive();y0=null})}
$('ypill').onclick=e=>{e.stopPropagation();openLive($('ypill'))};
$('hst').onclick=e=>{e.stopPropagation();openLive($('hst'))};

/* --- どこからでも 撮影へ(ひらいている 画面を しめてから) --- */
function closeAll(){if(LP.on)closeLive(true);try{if(RM.on)closeRoom()}catch(e){}try{if(GN.on)closeGnw()}catch(e){}try{if(AV)closeAv()}catch(e){}
  try{if(DXopen)closeDvx()}catch(e){}if($('fscr').classList.contains('on'))closeFriend();['shs','acs','pkf'].forEach(ovClose);
  document.querySelectorAll('.sheet.on').forEach(s=>s.classList.remove('on'));if(YOPEN)closeY()}
function shootAny(){const any=LP.on||YOPEN||(RM&&RM.on)||$('fscr').classList.contains('on')||!!AV;closeAll();setTimeout(()=>{if(cur!=='home'){toHome();setTimeout(goShoot,500)}else goShoot()},any?420:0)}
function lockGo(el){hap('pop','ぷにっ(撮りに いく)');if(el)el.animate([{scale:'1'},{scale:'.9'},{scale:'1.06'},{scale:'1'}],{duration:360,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(shootAny,200)}
phone.addEventListener('click',e=>{const k=e.target.closest('.lkp,.yolk,.molk,#ylock');if(!k)return;e.stopPropagation();lockGo(k)},true);

/* --- トースト:できる ことが あれば ボタンつきに --- */
const _toast=toast;
function toastA(m,lab,fn){const t=$('toast');t.innerHTML=`<span>${m}</span><button>${lab} →</button>`;t.classList.add('on','act');clearTimeout(t._t);
  t.querySelector('button').onclick=e=>{e.stopPropagation();t.classList.remove('on','act');fn()};t._t=setTimeout(()=>t.classList.remove('on','act'),3400)}
toast=function(m){const t=$('toast');t.classList.remove('act');
  if(/撮ると/.test(m)&&shots<3)return toastA(m,'撮る',shootAny);
  if(/^共有シートを/.test(m))return openShare();
  if(m==='カメラで 相手の QR を よみとる')return openScan('fr');
  if(m==='QR を よむ(カメラ)')return openScan('join');
  if(m==='グループの 大きな画面へ')return goActive();
  if(/^ME\(/.test(m))return goMe();
  if(/^メンバー ・ 通知/.test(m))return roomMenu();
  if(m==='ともだちを えらぶ(招待カードが とどく)'||/^まだ ともだちが いません/.test(m))return openPickFr();
  if(m==='下の「今日を撮る」から 撮れます')return shootAny();
  return _toast(m)};

function goMe(){hap('pop','ぷにっ(ME)');closeAll();setTimeout(()=>{const s=$('ayh');if(!s||!s.offsetParent){openAv({p:YD[0].p,n:'you',s:'yesterday · '+YD[0].tm,t:YD[0].t,own:'y',i:0});return}
  $('hs').scrollTo({top:s.offsetTop-120,behavior:'smooth'});setTimeout(()=>{s.animate([{boxShadow:'0 0 0 0 rgba(36,160,60,.0)'},{boxShadow:'0 0 0 4px rgba(36,160,60,.9)'},{boxShadow:'0 0 0 0 rgba(36,160,60,0)'}],{duration:900});hap('tick',null,{norip:1})},700)},420)}
function goActive(){hap('pop','ぷにっ(グループ)');if(YOPEN){const a=$('yact');if(a){$('ybody').scrollTo({top:a.offsetTop-150,behavior:'smooth'});return}}
  closeAll();setTimeout(()=>{const a=$('aact');if(a)$('hs').scrollTo({top:a.offsetTop-150,behavior:'smooth'})},420)}

/* --- 共有シート(モック) --- */
function ovOpen(id){const o=$(id);o.classList.add('on');o.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1})}
function ovClose(id){const o=$(id);if(!o||!o.classList.contains('on'))return;o.classList.remove('on');o.setAttribute('aria-hidden','true')}
document.querySelectorAll('.ovsc').forEach(s=>s.onclick=()=>{ovClose(s.dataset.x);hap('soft',null,{norip:1})});
const SHT=[['メッセージ','#34C759','<path d="M4 11.5c0-4 3.6-7 8-7s8 3 8 7-3.6 7-8 7c-1 0-2-.1-2.9-.4L5 19.5l1.2-3.3C4.8 15 4 13.3 4 11.5z"/>'],['LINE','#06C755','<rect x="4" y="5" width="16" height="13" rx="6"/><path d="M8 10v3M11 10v3M14 10l2 3v-3"/>'],['Instagram','#E1306C','<rect x="4.5" y="4.5" width="15" height="15" rx="4.5"/><circle cx="12" cy="12" r="3.6"/>'],['AirDrop','#0A84FF','<circle cx="12" cy="12" r="2"/><path d="M7.5 16.5a6.4 6.4 0 119 0M4.6 19.4a10.5 10.5 0 1114.8 0"/>'],['メール','#2F7CF6','<rect x="4" y="6" width="16" height="12" rx="2.5"/><path d="M4.5 7l7.5 6 7.5-6"/>']];
function shareCtx(){try{if(GN.on&&GN.lk)return{t:GN.lk,h:GN.name}}catch(e){}
  try{if(RM.on&&RM.g)return{t:inviteText(RM.g.n,'https://www.icloud.com/share/0'+gnHash(RM.g.n).toString(36)+'Lattag'),h:RM.g.n}}catch(e){}
  return{t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい の フレンドカード'}}
function openShare(c){c=c||shareCtx();const P=$('shsp'),first=c.t.split('\n')[0],url=(c.t.split('\n')[1]||'').replace(/^https?:\/\//,'');
  P.innerHTML=`<i class="grab"></i><div class="shh"><span class="ap">L</span><span class="tx"><b>${rmEsc(first)}</b><small>${rmEsc(url.slice(0,34))}${url.length>34?'…':''}</small></span><button class="x" data-a="x" aria-label="とじる">✕</button></div>
   <div class="sht">${SHT.map(([n,c,g],i)=>`<button data-i="${i}"><i style="background:${c}"><svg viewBox="0 0 24 24">${g}</svg></i><span>${n}</span></button>`).join('')}</div>
   <div class="shl"><button data-a="cp"><span>コピー</span><svg viewBox="0 0 24 24"><rect x="8" y="8" width="11" height="12" rx="2"/><path d="M5 15V6a2 2 0 012-2h8"/></svg></button><button data-a="qr"><span>QR コードで 見せる</span><svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg></button></div>`;
  P.querySelector('[data-a="x"]').onclick=()=>ovClose('shs');
  P.querySelectorAll('.sht button').forEach(b=>b.onclick=()=>{const n=SHT[+b.dataset.i][0];b.animate([{scale:'1'},{scale:'.86'},{scale:'1'}],{duration:260});hap('success','トトトン(おくった)',{norip:1});setTimeout(()=>{ovClose('shs');_toast(n+' で おくりました(モック)')},280)});
  P.querySelector('[data-a="cp"]').onclick=()=>{try{navigator.clipboard.writeText(c.t).catch(()=>{})}catch(e){}hap('click','カチッ(コピー)');ovClose('shs');_toast('コピーしました')};
  P.querySelector('[data-a="qr"]').onclick=()=>{hap('pop');ovClose('shs');setTimeout(()=>openSheet('shf'),250)};
  ovOpen('shs');[...P.querySelectorAll('.sht button')].forEach((b,i)=>b.animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,delay:120+i*40,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}))}

/* --- アクション シート(部屋の メニュー) --- */
function actSheet(title,items){const P=$('acsp');P.innerHTML=`<div class="acg"><div class="act">${title}</div>${items.map((it,i)=>`<button class="${it.red?'red':''}" data-i="${i}"><span>${it.l}</span>${it.r?`<em>${it.r}</em>`:''}</button>`).join('')}</div><button class="acc" data-a="c">キャンセル</button>`;
  P.querySelectorAll('.acg button').forEach(b=>b.onclick=()=>{const it=items[+b.dataset.i];hap(it.red?'warn':'sel',it.red?'やわらかく2回':'コツッ');it.fn(b)});P.querySelector('.acc').onclick=()=>{hap('soft');ovClose('acs')};ovOpen('acs')}
var RMNT=true;
function roomMenu(){if(!RM.on)return;const g=RM.g;hap('sel','コツッ(メニュー)');
  actSheet(rmEsc(g.n)+' ・ '+(g.m.length+1)+'人',[
    {l:'メンバー',r:(g.m.length+1)+'人',fn:()=>{ovClose('acs');$('rmav').querySelectorAll('.rma').forEach((b,i)=>b.animate([{scale:'1'},{scale:'1.3'},{scale:'1'}],{duration:420,delay:i*80,easing:'cubic-bezier(.3,1.6,.4,1)'}))}},
    {l:'通知',r:RMNT?'オン':'オフ',fn:b=>{RMNT=!RMNT;b.querySelector('em').textContent=RMNT?'オン':'オフ';hap('click','カチッ')}},
    {l:'リンクで よぶ',fn:()=>{ovClose('acs');setTimeout(()=>openShare(),260)}},
    {l:'グループを ぬける',red:1,fn:b=>{if(!b.dataset.ok){b.dataset.ok=1;b.querySelector('span').textContent='もういちど おすと ぬけます';return}ovClose('acs');const nm=g.n;setTimeout(()=>{closeRoom();GRP=GRP.filter(x=>x!==g);renderGroups();_toast('「'+nm+'」から ぬけました')},260)}}])}

/* --- ともだちを えらんで 招待(できた画面の Add) --- */
function openPickFr(){const P=$('pkfp'),S=new Set();hap('pop','ぷにっ(ともだちを 追加)');
  const draw=()=>{P.innerHTML=`<i class="grab"></i><div class="pkh"><b>Add</b><span>${FR.length?S.size+' / '+FR.length:'0'}</span></div>`+
    (FR.length?`<div class="pkl">${FR.map((f,i)=>`<button class="${S.has(i)?'on':''}" data-i="${i}"><i style="background:${avBg(f)}">${f.n[0]}</i><b>${f.n}</b><u></u></button>`).join('')}</div>
      <button class="pkgo${S.size?' on':''}" data-a="go">${S.size?S.size+'人に 招待カードを おくる':'えらんでください'}</button>`
    :`<div class="pke"><span class="ring"></span><b>まだ ともだちが いません</b><small>Link で よべます</small></div><button class="pkgo on" data-a="lk">Link で よぶ</button>`);
    P.querySelectorAll('.pkl button').forEach(b=>b.onclick=()=>{const i=+b.dataset.i;S.has(i)?S.delete(i):S.add(i);hap(S.has(i)?'pop':'tick');draw()});
    const go=P.querySelector('[data-a="go"]');go&&(go.onclick=()=>{if(!S.size){hap('warn');shake(go);return}hap('success','トトトン(おくった)',{norip:1});ovClose('pkf');setTimeout(()=>_toast(S.size+'人に 招待カードを おくりました ・ 承認まち'),260)});
    const lk=P.querySelector('[data-a="lk"]');lk&&(lk.onclick=()=>{ovClose('pkf');setTimeout(()=>openShare(),260)})};
  draw();ovOpen('pkf')}

/* --- QR を よむ(モック カメラ) --- */
function openScan(mode){const Q=$('qrs');hap('sel','コツッ(カメラ)');
  Q.innerHTML=`<i class="qbg" style="background-image:url(${PH.b})"></i><div class="qtop"><button class="qx" aria-label="とじる">✕</button><span>${mode==='join'?'SCAN GROUP CODE':'SCAN FRIEND CODE'}</span><i></i></div>
   <div class="qfr" id="qfr"><i class="c1"></i><i class="c2"></i><i class="c3"></i><i class="c4"></i><i class="ls"></i></div><p class="qtx" id="qtx">わくに うつしてください</p>`;
  Q.classList.add('on');Q.setAttribute('aria-hidden','false');
  const end=()=>{clearTimeout(Q._t);Q.classList.remove('on');Q.setAttribute('aria-hidden','true')};Q.querySelector('.qx').onclick=()=>{hap('soft');end()};
  Q._t=setTimeout(()=>{$('qfr').classList.add('ok');$('qtx').textContent=mode==='join'?'グループを 見つけた':'ともだちを 見つけた';hap('success','トトトン(よめた)',{norip:1});
    Q._t=setTimeout(()=>{end();if(mode==='join'){$('jpaste').onclick()}else{document.querySelectorAll('.sheet.on').forEach(s=>s.classList.remove('on'));setTimeout(askBump,250)}},750)},1900)}

/* --- 部屋:撮った 人を おすと / 自分を おすと --- */
{const _rh=rmHead;rmHead=function(){_rh();const g=RM.g;$('rmav').querySelectorAll('.rma').forEach(b=>{const i=b.dataset.i,o=b.onclick;
  b.onclick=e=>{if(i==='me'){if(shots>0){hap('pop','ぷにっ(現像を のぞく)');closeAll();setTimeout(()=>openDvx(shots-1),400);return}return lockGo(b)}
    const f=g.m[+i];if(f&&f.k>0){hap('sel','コツッ');b.animate([{scale:'1'},{scale:'1.18'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'});_toast(`${f.n} ・ 今日 ${f.k}/3 撮った ・ 9:00 に ひらく`);return}o&&o(e)}})}}

/* --- Mondo:ことばの ボタン・ロック → ほんとうに Mondo へ --- */
{const _ao=orbActs;orbActs=function(){const R=_ao();if(R.A.mondo)R.A.mondo.run=()=>{if(!shots){toast('今日 1枚 撮ると、ひらきます');return false}openY();setTimeout(()=>ytab('ytm'),420)};return R}}
{const _am=arcMondo;arcMondo=function(){_am();$('amd').querySelectorAll('.amc').forEach(b=>b.onclick=()=>{if(!shots){hap('warn','やわらかく2回(まだ)');shake(b);toast('今日 1枚 撮ると、ひらきます');return}hap('pop','ぷにっ(ことばへ)');MO.tag=b.dataset.t;openY();setTimeout(()=>ytab('ytm'),420)})}}
{const _ay=arcYesterday;arcYesterday=function(){_ay();const H=$('ayh');const m=H.querySelector('[data-a="mondo"]');if(m)m.onclick=()=>{if(!shots){hap('warn','やわらかく2回(まだ)');shake(m);toast('今日 1枚 撮ると、ひらきます');return}hap('pop','ぷにっ(Mondo)');openY();setTimeout(()=>ytab('ytm'),420)};
  const pp=H.querySelector('.sts div:last-child');if(pp){pp.style.cursor='pointer';pp.onclick=()=>{hap('pop','ぷにっ(ひと)');if(!shots){toast('今日 1枚 撮ると、ひらきます');return}openY()}}}}
{const _yo=yOnce;yOnce=function(){_yo();const S=document.querySelectorAll('#yon .yos > div');if(S.length===3){S[0].onclick=()=>{hap('pop');GRP.length?goActive():openGnw()};S[1].onclick=()=>openLive($('ypill'))}};window.yOnce=yOnce}
{const _ym=yMondo;yMondo=function(){_ym();const k=document.querySelector('#ymo .mokp');if(k)k.onclick=()=>{if(MO.pick>=0){const m=MW[MO.pick];hap('pop');openAv({p:m.p,n:m.l,s:'your one · results at 9:00',t:m.t});return}
  hap('sel','コツッ');const f=document.querySelector('#ymo .mofd');if(f){$('ybody').scrollTo({top:f.offsetTop-160,behavior:'smooth'});setTimeout(()=>f.querySelectorAll('.mof').forEach((c,i)=>i<4&&c.animate([{rotate:'0deg'},{rotate:'-2.5deg'},{rotate:'2.5deg'},{rotate:'0deg'}],{duration:420,delay:i*60})),500);_toast('1枚を 長押しで えらぶ')}}};renderYM=yMondo;window.yMondo=yMondo}

/* --- ON THIS DAY(★で のこした 1枚が かえってくる) --- */
const OTD=[{ago:'1 MONTH AGO',d:30,p:'c',t:'#放課後',tm:'16:42',pl:'鎌倉市'},{ago:'1 WEEK AGO',d:7,p:'b',t:'#雨の日',tm:'07:58',pl:'渋谷区'},{ago:'2 MONTHS AGO',d:61,p:'f',t:'#夕焼け',tm:'17:20',pl:'江ノ島'}];var OTI=0;
function arcOTD(){const B=$('otd');if(!B)return;const o=OTD[OTI],d=new Date(Date.now()-o.d*864e5),dd=MON[d.getMonth()]+' '+d.getDate(),ex=new Date(d);ex.setFullYear(ex.getFullYear()+1);
  const left=Math.max(0,Math.round((ex-Date.now())/864e5)),stp=`'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}`;$('otdd').textContent=o.ago;
  B.innerHTML=`<button class="otc" id="otc" aria-label="うらがえす"><span class="fr"><i class="ph" style="background-image:url(${PH[o.p]})"></i><span class="st">${stp}</span>${ICO.star}</span><span class="bk"><b>${o.t}</b><small>${o.tm} ・ ${o.pl}</small><em>kept ★</em></span></button>
   <div class="otx"><b>${dd}</b><small>${o.ago.toLowerCase()}</small><div class="yr"><i style="width:${(left/365*100).toFixed(1)}%"></i></div><span class="dl">${left} days left</span>
   <div class="dots">${OTD.map((_,i)=>`<i class="${i===OTI?'on':''}"></i>`).join('')}</div><button class="nx" id="otnx" aria-label="つぎ">›</button></div>`;
  const C=$('otc');let t0=0,tm=0;C.addEventListener('pointerdown',()=>{t0=performance.now();tm=setTimeout(()=>{tm=0;hap('heart','ドクン(ひらく)',{norip:1});openAv({p:o.p,n:dd,s:o.ago.toLowerCase()+' · kept ★',t:o.t})},520)});
  C.addEventListener('pointerup',()=>{if(tm){clearTimeout(tm);tm=0;C.classList.toggle('fl');hap('sel','コツッ(うらがえす)')}});C.addEventListener('pointerleave',()=>{clearTimeout(tm);tm=0});
  $('otnx').onclick=()=>{OTI=(OTI+1)%OTD.length;hap('tick');arcOTD();$('otc').animate([{transform:'translateX(40px) rotate(6deg)',opacity:0},{transform:'rotate(-4deg)',opacity:1}],{duration:460,easing:'cubic-bezier(.3,1.4,.5,1)'})}}

/* --- FRIENDS:12の 席(時計の 文字盤) --- */
var AFS=-1,POKED=new Set();
arcFriends=function(ni){const B=$('afc');if(!B)return;$('afcn').textContent='';const took=FR.filter(f=>f.k>0).length;const nx=FR.length;
  const seats=Array.from({length:12},(_,i)=>{const a=i*30,f=FR[i];if(!f)return `<button class="seat e${i===nx?' nx':''}" data-i="${i}" style="--a:${a}deg" aria-label="あいている 席"><i></i></button>`;
    const k=f.k,ring=`<svg viewBox="0 0 56 56"><circle cx="28" cy="28" r="25.5" class="t"/><circle cx="28" cy="28" r="25.5" class="p" pathLength="3" style="stroke-dasharray:${k} 3"/></svg>`;
    return `<button class="seat f${k>0?' k':''}${AFS===i?' sel':''}${POKED.has(i)?' pkd':''}" data-i="${i}" style="--a:${a}deg;--d:${i*.07}s" aria-label="${f.n}">${ring}<span class="av" style="background:${avBg(f)}">${f.n[0]}</span>${k>0?`<em>${k}</em>`:''}</button>`}).join('');
  const sel=AFS>=0&&FR[AFS]?FR[AFS]:null;
  const core=sel?`<div class="cf"><span class="av" style="background:${avBg(sel)}">${sel.n[0]}</span><b>${sel.n}</b><small>${sel.k>0?`today ${sel.k} / 3`:'not yet today'}</small>
      <div class="cbt">${sel.k>0?`<button data-a="open">open ›</button>`:`<button class="pk" data-a="poke">${POKED.has(AFS)?'poked':'poke'}</button><button data-a="open">›</button>`}</div></div>`
    :`<button class="cd2" data-a="open" aria-label="friend">${fCrowd(FR.length+1)}</button>`;
  B.innerHTML=`<i class="rad"></i><svg class="tk" viewBox="0 0 300 300">${Array.from({length:60},(_,i)=>{const a=i*6*Math.PI/180,r1=i%5?143:138,r2=147;return `<line x1="${150+Math.sin(a)*r1}" y1="${150-Math.cos(a)*r1}" x2="${150+Math.sin(a)*r2}" y2="${150-Math.cos(a)*r2}" class="${i%5?'':'h'}"/>`}).join('')}</svg>
    <div class="dial">${seats}</div><div class="core" id="afcore">${core}</div>`;
  B.querySelectorAll('.seat').forEach(s=>s.onclick=e=>{e.stopPropagation();const i=+s.dataset.i;
    if(s.classList.contains('e')){hap('pop','ぷにっ(席に よぶ)');s.animate([{scale:'1'},{scale:'.8'},{scale:'1.12'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(()=>openSheet('shf'),180);return}
    AFS=AFS===i?-1:i;hap('sel','コツッ('+FR[i].n+')');arcFriends();const c=$('afcore');c.animate([{opacity:0,transform:'scale(.85)'},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'})});
  B.onclick=e=>{if(e.target.closest('.seat,.core button'))return;if(AFS>=0){AFS=-1;hap('soft',null,{norip:1});arcFriends()}};
  const sb=B.querySelector('[data-a="shake"]');if(sb)sb.onclick=e=>{e.stopPropagation();hap('buzz','ブルブル(ふる)',{norip:1});B.classList.remove('shk2');void B.offsetWidth;B.classList.add('shk2');
    setTimeout(()=>{if(FR.length>=999){_toast('12の 席が うまりました');return}bumpBurst($('afcore'),()=>askBump())},620)};
  const pk=B.querySelector('[data-a="poke"]');if(pk)pk.onclick=e=>{e.stopPropagation();if(POKED.has(AFS)){hap('warn','やわらかく2回(きょうは もう つついた)');shake(pk);return}POKED.add(AFS);hap('heart','ドクン(つついた)',{norip:1});const n=FR[AFS].n;
    const st=B.querySelector(`.seat[data-i="${AFS}"]`);st&&st.animate([{rotate:'0deg'},{rotate:'-14deg'},{rotate:'12deg'},{rotate:'-6deg'},{rotate:'0deg'}],{duration:520});setTimeout(()=>{arcFriends();_toast(n+' を つついた')},380)};
  const op=B.querySelector('[data-a="open"]');if(op)op.onclick=e=>{e.stopPropagation();hap('pop');openFriend()};
  if(ni!==undefined&&ni>=0){const s=B.querySelector(`.seat[data-i="${ni}"]`);if(s){s.animate([{scale:'0',filter:'brightness(3)'},{scale:'1.3',offset:.55},{scale:'1',filter:'none'}],{duration:760,easing:'cubic-bezier(.3,1.5,.5,1)'});const r=document.createElement('i');r.className='land';s.appendChild(r);setTimeout(()=>r.remove(),900)}}}
{const _rf=renderFriends;renderFriends=function(n){_rf(n);try{arcFriends(n);renderOrb()}catch(e){}}}
{const _ra=renderArc;renderArc=function(){_ra();try{arcOTD()}catch(e){}}}

/* --- いちばん下:暗室の ひも(セーフライト) --- */
(function(){const C=$('hcord'),K=$('hck');if(!C)return;let y0=null,pl=0,fired=false;
  const set=v=>{pl=v;C.style.setProperty('--pl',v+'px')};
  K.addEventListener('pointerdown',e=>{y0=e.clientY;fired=false;try{K.setPointerCapture(e.pointerId)}catch(_){}hap('soft','そっと(ひもを つまむ)',{norip:1});K.getAnimations().forEach(a=>a.cancel())});
  K.addEventListener('pointermove',e=>{if(y0===null)return;const d=Math.max(0,(e.clientY-y0)/SC);const v=d<60?d:60+(d-60)*.25;set(v);if(v>46&&!fired){fired=true;hap('click','カチッ(スイッチ)')}});
  const up=()=>{if(y0===null)return;y0=null;const was=fired;const from=pl;const st=performance.now();
    (function sp(){const t=(performance.now()-st)/520;const v=from*Math.exp(-5*t)*Math.cos(t*12);set(Math.max(-8,v));if(t<1)requestAnimationFrame(sp);else set(0)})();
    if(was||from<6){if(from<6){/* タップ */const s=performance.now();(function sp2(){const t=(performance.now()-s)/600;set(Math.sin(Math.min(1,t)*Math.PI)*34*(1-t));if(t<1)requestAnimationFrame(sp2);else set(0)})();hap('click','カチッ(スイッチ)')}
      const on=$('home').classList.toggle('safe');setTimeout(()=>hap(on?'thud':'soft',on?'ドン(あかい 明かり)':'ふわっ(明かりを 消す)',{norip:1}),120);$('hcn').textContent=on?'SAFELIGHT':'PULL'}};
  K.addEventListener('pointerup',up);K.addEventListener('pointercancel',up)})();
{const h=$('home');if(h&&!h.querySelector(':scope>.sfl')){const i=document.createElement('i');i.className='sfl';h.insertBefore(i,$('hhd'))}}
renderArc();try{renderYMeta()}catch(e){}lpTick();
