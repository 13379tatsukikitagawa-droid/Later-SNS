/* ===== v95(モック v95 ・ PROMPT v106) =====
   1. Name:「なまえ」と「0 / 12」が かさなる → 字数は 線の 下 ・ 右
   2. Friends:フィードの さいごに「きょうの フィルムは ここまで」(絵 ・ 9:00 まで)
   3. Trip:右上の 2つを 字つきの ボタンに(招待 ・ 設定)・ チャットは 右下の 丸 と 上の 字
   4. Trip の 設定:1枚の シート(上に パスの 見本が 動く)
   5. ぬける / おわる:パスが やぶれる 長押し → Home へ もどり、Trip が 消える
   名前:e9 */
const E9={log:[],hold:0};
const E9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const E9I={x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2zM14 18h2"/></svg>',
  gear:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M5.5 18.5l1.7-1.7M16.8 7.2l1.7-1.7"/></svg>',
  img:'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9.5" cy="10" r="1.6"/><path d="M5 17l4.5-4 3 2.5 3-3L19 16"/></svg>',
  door:'<svg viewBox="0 0 24 24"><path d="M14 4H6.5A1.5 1.5 0 005 5.5v13A1.5 1.5 0 006.5 20H14"/><path d="M10 12h10M16.5 8.5L20 12l-3.5 3.5"/></svg>',
  key:'<svg viewBox="0 0 24 24"><circle cx="8" cy="12" r="3.5"/><path d="M11.5 12H20M17 12v3M20 12v2"/></svg>',
  ppl:'<svg viewBox="0 0 24 24"><circle cx="9" cy="8.5" r="3.2"/><path d="M3 19c.6-3.2 3-5 6-5s5.4 1.8 6 5"/><circle cx="17" cy="9" r="2.5"/><path d="M16 14.2c2.4.2 4.2 1.8 4.8 4.8"/></svg>',
  clock:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
  bell:'<svg viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 1112 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 004 0"/></svg>',
  plus:'<svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg>',
  min:'<svg viewBox="0 0 24 24"><path d="M5 12h14"/></svg>'};

/* ================= 2. Friends:フィードの さいご ================= */
function e9Cd(){const d=new Date(),t=new Date(d);t.setHours(9,0,0,0);if(t<=d)t.setDate(t.getDate()+1);const s=Math.floor((t-d)/1000);return [Math.floor(s/3600),Math.floor(s%3600/60),s%60].map(n=>String(n).padStart(2,'0')).join(':')}
const e9EndArt=()=>`<svg class="e9art" viewBox="0 0 300 150" aria-hidden="true">
  <defs><linearGradient id="e9cn" x1="0" x2="1"><stop offset="0" stop-color="#1C1C1F"/><stop offset=".5" stop-color="#2A2A2E"/><stop offset="1" stop-color="#151517"/></linearGradient></defs>
  <g class="e9strip"><rect x="-60" y="58" width="250" height="40" rx="3" fill="#18181B" stroke="#2E2E33"/>
   ${Array.from({length:14},(_,i)=>`<rect x="${-54+i*17}" y="62" width="9" height="6" rx="1.5" fill="#0A0A0B"/><rect x="${-54+i*17}" y="88" width="9" height="6" rx="1.5" fill="#0A0A0B"/>`).join('')}
   ${[0,1,2,3].map(i=>`<rect x="${-50+i*52}" y="71" width="40" height="14" rx="2" fill="${i===3?'#C8F25A':'#26262A'}" opacity="${i===3?.9:1}"/>`).join('')}</g>
  <g class="e9can"><rect x="186" y="30" width="72" height="96" rx="14" fill="url(#e9cn)" stroke="#2E2E33"/>
   <rect x="180" y="24" width="84" height="14" rx="6" fill="#26262A"/><rect x="180" y="118" width="84" height="14" rx="6" fill="#26262A"/>
   <rect x="196" y="52" width="52" height="52" rx="10" fill="#C8F25A"/><text x="222" y="88" text-anchor="middle" font-family="Inter,sans-serif" font-weight="900" font-size="34" fill="#111">#</text>
   <rect x="214" y="12" width="16" height="14" rx="3" fill="#2E2E33"/></g>
  <g class="e9spk" fill="#C8F25A"><circle cx="276" cy="36" r="2.4"/><circle cx="288" cy="54" r="1.6"/><circle cx="170" cy="22" r="1.8"/></g></svg>`;
function e9FeedOpen(){let S=$('e9fd');if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="e9fd" id="e9fd" aria-label="Friends"></section>');S=$('e9fd')}
  const f=FR.find(x=>x.k)||FPOOL[0];
  S.innerHTML=`<div class="e9fh"><button class="e9ib" aria-label="お知らせ">${E9I.bell}</button><b>Friends</b><button class="e9ib av" data-a="x" aria-label="とじる(モック)" style="background-image:url(${PH.c})"></button></div>
    <div class="e9sc">
      <article class="e9po"><div class="e9poh"><span class="e9av" style="background:${avBg(f)}">${f.n[0]}</span><span><b>${f.n}</b><small>12:40 ・ 3枚</small></span></div>
        <div class="e9ph lk" style="background-image:url(${PH.b})"><i></i><span>${E9I.clock}あした 9:00 に ひらく</span></div></article>
      <section class="e9end">${e9EndArt()}<small class="e9k">END OF TODAY'S ROLL</small><b>きょうの フィルムは ここまで</b><p>あしたの 9:00 に、みんなの 1枚が ひらきます</p>
        <div class="e9cd"><em>9:00 まで</em><span id="e9cd">${e9Cd()}</span></div>
        <div class="e9eb"><button data-a="find">友だちを ふやす</button><button class="p" data-a="shoot">今日の 1枚を 撮る</button></div></section>
    </div>
    <nav class="e9tb"><button class="on">${E9I.ppl}<span>Friends</span></button><button><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.6 3.5 5.6 3.5 8.5s-.9 5.9-3.5 8.5c-2.6-2.6-3.5-5.6-3.5-8.5s.9-5.9 3.5-8.5z"/></svg><span>Mondo</span></button></nav>`;
  S.querySelector('[data-a="x"]').onclick=()=>{S.classList.remove('on');clearInterval(E9.cd)};
  S.querySelector('[data-a="find"]').onclick=()=>{hap('pop');try{toast('さがす 画面へ(モック)')}catch(e){}};
  S.querySelector('[data-a="shoot"]').onclick=()=>{hap('click');try{toast('撮影へ(モック)')}catch(e){}};
  S.classList.add('on');hap('soft',null,{norip:1});clearInterval(E9.cd);E9.cd=setInterval(()=>{const c=$('e9cd');if(c)c.textContent=e9Cd()},1000);
  const end=S.querySelector('.e9end'),sc=S.querySelector('.e9sc');
  sc.onscroll=()=>{if(end.dataset.seen)return;const r=end.getBoundingClientRect(),p=sc.getBoundingClientRect();if(r.top<p.bottom-80){end.dataset.seen=1;end.classList.add('in');hap('soft','ふわっ(さいご)',{norip:1})}};
  setTimeout(()=>sc.onscroll(),60)}

/* ================= 3. Trip:右上の ボタン ================= */
{const _d=th77Draw;th77Draw=function(){_d.apply(this,arguments);const S=$('th77');if(!S)return;const q=S.querySelector('.bar [data-a="qr"]'),s=S.querySelector('.bar [data-a="set"]');
  if(q){q.className='e9pb';q.innerHTML=E9I.qr+'<span>招待</span>';q.setAttribute('aria-label','招待(QR と KEY)')}
  if(s){s.className='e9pb';s.innerHTML=E9I.gear+'<span>設定</span>';s.setAttribute('aria-label','Trip の 設定');s.onclick=()=>e9SetOpen(TH77.t)}}}
tripSet=function(t){e9SetOpen(t)};

/* ================= 4. Trip の 設定 ================= */
function e9Pass(g){const mem=[{me:1},...(g.m||[])];return `<div class="e9ps" style="--cv:url(${g.img||PH[g.cover||'a']})"><i class="cv"></i><i class="sh"></i>
  <div class="e9pt"><small>TRIP PASS</small><b>${rmEsc(g.en||g.n||'Trip')}</b><span>${rmEsc(g.n||'')}</span></div>
  <div class="e9pf"><span>${t77d(g.from)} → ${t77d(g.to)} ・ ${tDays(g)}日</span><span class="e9pm">${mem.slice(0,5).map(f=>t77av(f,22)).join('')}</span></div>
  <i class="e9pk">${rmEsc(g.key||'#meadow95')}</i></div>`}
function e9SetOpen(t){if(!t)return;E9.t=t;E9.g={n:t.n,en:t.en,cover:t.cover||'a',img:null,from:new Date(+t.from),to:new Date(+t.to),m:(t.m||[]).slice(),key:t.key,nt:t.nt!==false};
  let S=$('e9s');if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="e9s" id="e9s" aria-label="Trip の 設定"></section>');S=$('e9s')}
  e9SetDraw();requestAnimationFrame(()=>S.classList.add('on'));hap('pop','ぷにっ(設定)');E9.log.push('set')}
function e9Dirty(){const g=E9.g,t=E9.t;return g.n!==t.n||g.cover!==(t.cover||'a')||!!g.img||+g.from!==+t.from||+g.to!==+t.to||g.m.length!==(t.m||[]).length||g.nt!==(t.nt!==false)}
function e9SetDraw(){const S=$('e9s'),g=E9.g,P=['a','b','c','d','e','f'];
  S.innerHTML=`<div class="e9sh"><button class="e9x" data-a="x" aria-label="とじる">${E9I.x}</button><b>Trip の 設定</b><button class="e9sv" data-a="save" ${e9Dirty()?'':'disabled'}>保存</button></div>
   <div class="e9sb">
    <div class="e9pv">${e9Pass(g)}</div>
    <section class="e9sec"><h4>表紙</h4><div class="e9cv"><button class="add" data-a="lib">${E9I.img}<span>写真を えらぶ</span></button>${P.map(p=>`<button class="${!g.img&&g.cover===p?'on':''}" data-p="${p}" style="background-image:url(${PH[p]})" aria-label="表紙 ${p}"></button>`).join('')}</div><small class="e9hn">この Trip の 写真から ・ カメラロールから</small></section>
    <section class="e9sec"><h4>名前</h4><label class="e9in"><input id="e9nm" maxlength="16" value="${rmEsc(g.n)}" aria-label="Trip の 名前"><em id="e9nc">${[...g.n].length} / 16</em></label></section>
    <section class="e9sec"><h4>日にち</h4><div class="e9dt"><div><small>はじまり</small><b>${t77d(g.from)}(${W77D[g.from.getDay()]})</b></div><i>→</i><div><small>おわり</small><b>${t77d(g.to)}(${W77D[g.to.getDay()]})</b></div>
      <span class="e9st"><button data-a="dm" aria-label="1日 へらす">${E9I.min}</button><em>${tDays(g)}日</em><button data-a="dp" aria-label="1日 ふやす">${E9I.plus}</button></span></div></section>
    <section class="e9sec"><h4>メンバー <em>${g.m.length+1}人</em></h4><div class="e9mm">${[{me:1},...g.m].map((f,i)=>`<span class="e9mr">${t77av(f,40)}<small>${f.me?'あなた':f.n}</small>${f.me?'':`<button data-r="${i-1}" aria-label="${f.n} を はずす">${E9I.x}</button>`}</span>`).join('')}<button class="e9inv" data-a="inv">${E9I.plus}<small>よぶ</small></button></div></section>
    <section class="e9sec"><h4>お知らせ</h4><button class="e9tg${g.nt?' on':''}" data-a="nt" role="switch" aria-checked="${g.nt}"><span><b>Trip の チャット</b><small>みんなが 書いた 時</small></span><i><u></u></i></button></section>
    <section class="e9dz"><button data-a="leave">${E9I.door}<span><b>Trip を ぬける</b><small>あなた だけ 外れる</small></span></button><button data-a="end">${E9I.door}<span><b>Trip を おわる</b><small>みんな 入れなく なる(作った 人 だけ)</small></span></button></section>
   </div>`;
  const A=(s,f)=>S.querySelectorAll(s).forEach(b=>b.onclick=f);
  const re=()=>{const y=S.querySelector('.e9sb').scrollTop;e9SetDraw();S.querySelector('.e9sb').scrollTop=y;const p=S.querySelector('.e9ps');p&&!E9RM()&&p.animate([{transform:'scale(.97)'},{transform:'scale(1.02)'},{transform:'none'}],{duration:320,easing:'cubic-bezier(.3,1.5,.4,1)'})};
  A('[data-a="x"]',()=>{S.classList.remove('on');hap('soft')});
  A('[data-a="save"]',()=>{if(!e9Dirty())return;Object.assign(E9.t,{n:E9.g.n,cover:E9.g.cover,from:E9.g.from,to:E9.g.to,m:E9.g.m,nt:E9.g.nt});hap('success','トトトン(保存)');S.classList.remove('on');try{th77Draw();tripPage()}catch(e){}try{toast('Trip を 更新しました')}catch(e){}});
  A('.e9cv [data-p]',e=>{E9.g.cover=e.currentTarget.dataset.p;E9.g.img=null;hap('sel','コツッ(表紙)');re()});
  A('[data-a="lib"]',()=>{hap('pop');E9.g.img=PH.e;try{toast('(モック)カメラロールから えらんだ ことに')}catch(e){}re()});
  A('[data-a="dm"]',()=>{if(tDays(E9.g)<=1){hap('warn');return}E9.g.to=new Date(+E9.g.to-864e5);hap('tick');re()});
  A('[data-a="dp"]',()=>{if(tDays(E9.g)>=14){hap('warn');return}E9.g.to=new Date(+E9.g.to+864e5);hap('tick');re()});
  A('.e9mr button',e=>{const i=+e.currentTarget.dataset.r;E9.g.m.splice(i,1);hap('tick','ごく軽く(はずす)');re()});
  A('[data-a="inv"]',()=>{hap('pop');try{openPass(E9.t)}catch(x){}});
  A('[data-a="nt"]',()=>{E9.g.nt=!E9.g.nt;hap('click');re()});
  A('[data-a="leave"]',()=>e9LeaveOpen('leave'));A('[data-a="end"]',()=>e9LeaveOpen('end'));
  const I=$('e9nm');I.oninput=()=>{E9.g.n=I.value.trim()||E9.t.n;$('e9nc').textContent=[...I.value].length+' / 16';S.querySelector('.e9pt b').textContent=E9.g.en&&E9.g.n===E9.t.n?E9.g.en:E9.g.n;S.querySelector('.e9pt span').textContent=E9.g.n;S.querySelector('.e9sv').disabled=!e9Dirty()}}

/* ================= 5. ぬける / おわる ================= */
function e9LeaveOpen(k){const t=E9.t||TH77.t;if(!t)return;E9.k=k;let S=$('e9l');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="e9l" id="e9l" aria-hidden="true"><i class="sc"></i><div class="pn" role="alertdialog"></div></div>');S=$('e9l');S.querySelector('.sc').onclick=()=>e9LeaveClose()}
  const end=k==='end',P=S.querySelector('.pn');
  P.innerHTML=`<i class="grab"></i>
   <div class="e9tk" id="e9tk"><div class="h l">${e9Pass(t)}</div><div class="h r">${e9Pass(t)}</div><i class="perf"></i></div>
   <h2>『${rmEsc(t.n)}』を<br>${end?'おわりますか?':'ぬけますか?'}</h2>
   <ul class="e9ls">${end?`<li>${E9I.ppl}<span>みんなが この Trip に 入れなく なります</span></li><li>${E9I.key}<span>招待の リンク ・ QR ・ KEY(<code>${rmEsc(t.key||'#meadow95')}</code>)が 使えなく なります</span></li><li>${E9I.clock}<span>写真は すぐには 消えません(撮ってから 7日で 消える)</span></li>`
     :`<li>${E9I.ppl}<span>あなた だけ 外れます。みんなは つづけられます</span></li><li>${E9I.key}<span>もう一度 入る には、招待を もらいなおす</span></li><li>${E9I.clock}<span>あなたが 撮った 写真は のこります(7日で 消える)</span></li>`}</ul>
   <button class="e9hd" id="e9hd"><i class="fill"></i><span>長押しで ${end?'おわる':'ぬける'}</span></button>
   <button class="e9no" data-a="no">やめる</button>`;
  P.querySelector('[data-a="no"]').onclick=()=>e9LeaveClose();e9Hold($('e9hd'));
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('warn','やわらかく2回(だいじな 確認)',{norip:1});E9.log.push('ask:'+k)}
function e9LeaveClose(){const S=$('e9l');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true');hap('soft',null,{norip:1})}
function e9Hold(b){const D=1200;let raf=0,t0=0,on=false,lt=0;const F=b.querySelector('.fill'),T=$('e9tk');
  const set=p=>{F.style.transform=`scaleX(${p})`;if(T){T.style.setProperty('--p',p);T.querySelector('.h.l').style.transform=`rotate(${-p*3}deg) translateX(${-p*4}px)`;T.querySelector('.h.r').style.transform=`rotate(${p*3}deg) translateX(${p*4}px)`}};
  const stop=()=>{if(!on)return;on=false;cancelAnimationFrame(raf);F.style.transition='transform .3s';set(0);setTimeout(()=>F.style.transition='',300);hap('soft','ふわっ(はなした)',{norip:1})};
  const step=t=>{if(!on)return;const p=Math.min(1,(t-t0)/D);set(p);const gap=Math.max(60,220-p*170);if(t-lt>gap){lt=t;hap(p>.7?'buzz':'tick',null,{norip:1})}
    if(p>=1){on=false;e9Tear();return}raf=requestAnimationFrame(step)};
  b.onpointerdown=e=>{e.preventDefault();on=true;t0=performance.now();lt=0;F.style.transition='';raf=requestAnimationFrame(step)};
  b.onpointerup=b.onpointerleave=b.onpointercancel=stop;
  b.onkeydown=e=>{if(e.key===' '||e.key==='Enter'){e.preventDefault();e9Tear()}};
  E9.hold=()=>e9Tear()}
/* パスが やぶれる → シートが さがる → Trip が とじる → Home で カードが 消える */
function e9Tear(){const t=E9.t||TH77.t,T=$('e9tk'),k=E9.k;hap('knock','ゴトッ(やぶれる)',{norip:1});E9.log.push('done:'+k);
  const go=()=>{e9LeaveClose();const S=$('e9s');S&&S.classList.remove('on');
    setTimeout(()=>{const H=$('th77');if(H){if(!E9RM())H.animate([{transform:'none',opacity:1},{transform:'translateY(40px) scale(.94)',opacity:0}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'}).onfinish=()=>{H.classList.remove('on');H.getAnimations().forEach(a=>a.cancel())};else H.classList.remove('on')}
      setTimeout(()=>e9Gone(t,k),E9RM()?0:440)},260)};
  if(E9RM()||!T){setTimeout(go,200);return}
  T.querySelector('.perf').style.opacity=0;
  T.querySelector('.h.l').animate([{transform:'rotate(-3deg) translateX(-4px)'},{transform:'translate(-70px,180px) rotate(-28deg)',opacity:0}],{duration:620,easing:'cubic-bezier(.5,0,.8,.4)',fill:'forwards'});
  T.querySelector('.h.r').animate([{transform:'rotate(3deg) translateX(4px)'},{transform:'translate(70px,200px) rotate(32deg)',opacity:0}],{duration:640,easing:'cubic-bezier(.5,0,.8,.4)',fill:'forwards'});
  setTimeout(()=>hap('thud','ドスッ(おちた)',{norip:1}),420);setTimeout(go,620)}
function e9Gone(t,k){const i=GRP.indexOf(t);try{if($('fscr').classList.contains('on'))closeFriend()}catch(e){}try{if(RM.on)closeRoom()}catch(e){}try{toHome()}catch(e){}
  setTimeout(()=>{try{hpGo(2)}catch(e){}const C=$('hpc2');
    const fin=()=>{if(i>=0)GRP.splice(i,1);try{tripPage()}catch(e){}try{renderGroups()}catch(e){}try{hpRender()}catch(e){}hap('success','トトトン(おわった)',{norip:1});try{toast(k==='end'?`『${t.n}』を おわりました`:`『${t.n}』を ぬけました`)}catch(e){}
      const C2=$('hpc2');C2&&!E9RM()&&C2.animate([{opacity:0,transform:'scale(.96)'},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.3,.5,1)'})};
    if(C&&!E9RM()){C.animate([{transform:'none',opacity:1},{transform:'scale(.9) rotate(-2deg)',opacity:.6,offset:.4},{transform:'scale(.2) rotate(8deg)',opacity:0}],{duration:520,easing:'cubic-bezier(.5,0,.75,0)'}).onfinish=fin}else fin()},500)}

/* ================= デモ ================= */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-e9]'))return;
  C.insertAdjacentHTML('beforeend',['name:Name(字数)','feed:Friends:フィードの さいご','trip:Trip の 中','set:Trip の 設定','leave:Trip を ぬける','end:Trip を おわる'].map(s=>{const[k,l]=s.split(':');return `<button data-e9="${k}">${l}</button>`}).join(''));
  C.querySelectorAll('[data-e9]').forEach(b=>b.onclick=()=>e9Demo(b.dataset.e9))})();
function e9Trip(){let t=GRP.find(g=>g.trip);if(!t){try{[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='trip54').click()}catch(e){}t=GRP.find(g=>g.trip)}return t}
function e9Demo(k){
  if(k==='name'){try{__kit.j9Kb('name')}catch(e){}return}
  if(!FR.length){try{[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='fr3').click()}catch(e){}}
  try{Z9.seen={friends:1,trip:1,mondo:1};z9Close()}catch(e){}
  setTimeout(()=>{if(k==='feed'){e9FeedOpen();return}const t=e9Trip();if(!t)return;try{z9Close()}catch(e){}
    if(k==='trip'){th77Open(t);return}
    th77Open(t);setTimeout(()=>{e9SetOpen(t);if(k==='leave'||k==='end')setTimeout(()=>e9LeaveOpen(k),500)},400)},900)}
window.__kit=Object.assign(window.__kit||{},{e9:k=>e9Demo(k),e9Tear:()=>E9.hold&&E9.hold(),E9:()=>({log:E9.log.slice(),trips:GRP.filter(g=>g.trip).length})});
