
/* ================= v65 ・ 最終ブラッシュアップ =================
   A. Home:ぼかした 写真を 画面 いっぱいに(フルブリード)。ページを めくると うしろの 写真が ゆっくり 入れかわる
   B. Friends:BeReal の ような 黒い 一覧。写真の 丸 ・ 申請 ・ つつく ・ チャット。キャラクターは 使わない
   C. Shake:となりで いっしょに ふると つながる 全画面モード(モックでは 丸を 押すと「ふった」ことに なる)*/
const ME65=()=>PH.f;                 /* 自分の プロフィール写真(モックでは 写真 f)*/

/* ---------- A. Home ---------- */
function h65Build(){const S=$('hs'),B=$('hxb');if(!S||!B||$('h65'))return;
  const W=document.createElement('div');W.className='h65';W.id='h65';
  W.innerHTML=[1,2,3,4].map(i=>`<i class="pg" data-i="${i}"></i>`).join('')+'<i class="pgv"></i>';
  S.insertBefore(W,S.firstChild);W.insertBefore(B,W.firstChild);
  const av=document.querySelector('#hhd .av');if(av)av.style.backgroundImage=`url(${ME65()})`;
  S.addEventListener('scroll',()=>{const y=S.scrollTop;W.style.transform=`translate3d(0,${(y*.32).toFixed(1)}px,0)`;W.style.opacity=Math.max(0,1-Math.max(0,y-420)/380).toFixed(3);$('hhd').classList.toggle('sc',y>24)},{passive:true});
  h65Pg()}
function h65Pg(){const W=$('h65');if(!W)return;[1,2,3,4].forEach(i=>{const C=$('hpc'+i),p=W.querySelector(`.pg[data-i="${i}"]`);if(!C||!p||i===3)return;
  const b=C.querySelector('.hpbg');if(b&&b.style.backgroundImage)p.style.backgroundImage=b.style.backgroundImage})}
{const _hl=hpLayout;hpLayout=function(px){_hl(px);const W=$('h65');if(!W)return;const pos=-px/390;let mx=0;
  W.querySelectorAll('.pg').forEach(p=>{const o=Math.max(0,1-Math.abs(+p.dataset.i-pos));p.style.opacity=o.toFixed(3);if(o>mx)mx=o});
  W.querySelector('.pgv').style.opacity=mx.toFixed(3)}}
{const _hr=hpRender;hpRender=function(only){_hr(only);h65Pg()};window.hpRender=hpRender}
{const _hi=homeIn;homeIn=function(s){_hi(s);const W=$('h65');if(!W)return;W.classList.remove('in');void W.offsetWidth;W.classList.add('in')}}
try{h65Build()}catch(e){console.error(e)}

/* ---------- B. Friends ---------- */
const I65={
  q:'<svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg>',
  ph:'<svg viewBox="0 0 24 24"><rect x="7.5" y="3" width="9" height="18" rx="2.4"/><path d="M3.5 9v6M20.5 9v6"/></svg>',
  go:'<svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg>',
  lk:'<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>',
  id:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M16 8v5a2.5 2.5 0 005 0v-1a9 9 0 10-3.5 7.1"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>'};
const f65Arc=j=>{const r=27,c=29,a0=(-90+j*120+9)*Math.PI/180,a1=(-90+(j+1)*120-9)*Math.PI/180;return `M${(c+r*Math.cos(a0)).toFixed(1)} ${(c+r*Math.sin(a0)).toFixed(1)}A${r} ${r} 0 0 1 ${(c+r*Math.cos(a1)).toFixed(1)} ${(c+r*Math.sin(a1)).toFixed(1)}`};
var F65Q='';
function f65Row(f){const i=FR.indexOf(f),T=fTimes(f),pk=POKED.has(i);
  return `<div class="f65r" role="button" tabindex="0" data-i="${i}"${F65Q&&!f.n.includes(F65Q)&&!FID(f).includes(F65Q)?' hidden':''}>
    <span class="f65a"><svg viewBox="0 0 58 58">${[0,1,2].map(j=>`<path d="${f65Arc(j)}" class="${j<f.k?'on':''}"/>`).join('')}</svg><i style="background-image:url(${fPic(f)})"></i></span>
    <span class="f65x"><b>${f.n}</b>${f.k?`<small class="on">${T[f.k-1]} に 撮った</small>`:`<small>まだ 撮って いない</small>`}</span>
    ${f.k?`<span class="f65t">${T.map(()=>`<i><b style="background-image:url(${fPic(f)})"></b></i>`).join('')}</span>`:`<button class="f65b f65pk${pk?' dn':''}" data-a="poke" aria-label="つつく">${IHAND}</button>`}
    <button class="f65b" data-a="chat" aria-label="チャット">${ICH}</button></div>`}
fRender=function(ni){const B=$('frbody'),F=$('fscr');if(!B)return;F.classList.add('v58','v65');try{v54Counts()}catch(e){}
  /* うしろ:友だちの 写真を ぼかして 敷く(0人の ときは 緑の ひかり)*/
  let G=F.querySelector('.f65bg');if(!G){G=document.createElement('div');G.className='f65bg';F.insertBefore(G,F.firstChild)}
  if(!F.querySelector('.f65hd')){const h=document.createElement('i');h.className='f65hd';F.insertBefore(h,G.nextSibling);const fb=$('fbody');fb&&fb.addEventListener('scroll',()=>F.classList.toggle('sc',fb.scrollTop>16),{passive:true})}
  G.classList.toggle('e0',!FR.length);G.innerHTML=(FR.length?FR.slice(0,3).map((f,i)=>`<i class="${i?'':'on'}" style="background-image:url(${fPic(f)})"></i>`).join(''):'')+'<b></b>';
  const tl=F.querySelector('.ftl em');if(tl)tl.textContent='Friends';
  const ad=$('fcall');if(ad){ad.innerHTML=I65.qr;ad.setAttribute('aria-label','自分の QR と ID');ad.onclick=()=>{hap('pop','ぷにっ(QR)');openAdd()}}
  const V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0);
  const st=FR.length?`<p class="f65st">${took.length?`<span class="f65as">${took.slice(0,3).map(f=>`<i style="background-image:url(${fPic(f)})"></i>`).join('')}</span><span>きょう <b>${took.length}人</b>が 撮った</span>`:'<span>きょうは まだ だれも 撮って いない</span>'}<em>9:00 OPEN</em></p>`:'';
  const sk=`<button class="f65sk${FR.length?'':' big'}" data-a="shake"><span class="f65g"><i></i><i></i><i></i><u>${I65.ph}</u></span><span class="f65x"><b>ふって、つながる</b><small>となりの 友だちと いっしょに${FR.length?'<br>':' '}スマホを ふる</small></span><span class="f65go">${I65.go}</span></button>
    <div class="f65w"><button data-a="qr">${I65.qr}QR</button><button data-a="link">${I65.lk}Link</button><button data-a="id">${I65.id}ID</button></div>`;
  const rq=REQ.length?`<div class="f65h"><b>Requests</b><i></i></div>${REQ.map((r,i)=>`<div class="f65rq" data-i="${i}"><span class="f65a"><i style="background-image:url(${fPic(r.f)})"></i></span><span class="f65x"><b>${r.f.n}</b><small>${FID(r.f)} ・ ${r.at}</small></span><button class="f65ok" data-a="ok">承認</button><button class="f65no" data-a="no" aria-label="あとで">${I65.x}</button></div>`).join('')}`:'';
  const ls=FR.length?`<div class="f65h"><b>Friends</b>${took.length?`<span>● ${took.length} SHOT TODAY</span>`:''}</div>${V.map(f65Row).join('')}`:`<p class="f65e">さいしょの 友だちを よぼう。<br>つながると、あしたの 朝 9:00 に きのうを 見せあえます。</p>`;
  B.innerHTML=st+(FR.length?`<label class="f65q">${I65.q}<input id="fq2" placeholder="名前 か ID で さがす" value="${F65Q}" autocomplete="off"></label>`:'')+sk+rq+ls+`<p class="f65n">知らない人には 見つかりません ・ 友だちの 数は どこにも 出ません</p>`;
  f65Bind(B);
  if(ni!=null&&FR[ni]){const c=B.querySelector(`.f65r[data-i="${ni}"]`);if(c){c.classList.add('f65nw');setTimeout(()=>c.scrollIntoView({block:'center',behavior:'smooth'}),60)}}};
function f65Bind(B){
  B.querySelectorAll('[data-a="shake"]').forEach(b=>b.onclick=()=>openShake());
  B.querySelector('.f65w [data-a="qr"]').onclick=()=>{hap('pop','ぷにっ(QR)');openAdd()};
  B.querySelector('.f65w [data-a="link"]').onclick=()=>{hap('pop','ぷにっ(リンク)');openShare({t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい'})};
  B.querySelector('.f65w [data-a="id"]').onclick=()=>{hap('pop','ぷにっ(ID)');openAdd();setTimeout(()=>{const i=$('adin');i&&i.focus()},420)};
  B.querySelectorAll('.f65rq').forEach(c=>{const i=+c.dataset.i;
    c.querySelector('[data-a="ok"]').onclick=e=>{e.stopPropagation();hap('click','カチッ(承認)',{norip:1});c.animate([{opacity:1,transform:'none'},{opacity:0,transform:'translateX(40px) scale(.96)'}],{duration:300,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'});setTimeout(()=>reqAccept(i),260)};
    c.querySelector('[data-a="no"]').onclick=e=>{e.stopPropagation();c.animate([{opacity:1},{opacity:0,transform:'translateX(-40px)'}],{duration:240,fill:'forwards'});setTimeout(()=>reqLater(i),220)}});
  B.querySelectorAll('.f65r').forEach(c=>{const i=+c.dataset.i,f=FR[i];
    c.onclick=e=>{const a=e.target.closest('[data-a]');if(a&&a.dataset.a==='chat'){e.stopPropagation();hap('pop','ぷにっ(チャット)');openDM(f);return}if(a&&a.dataset.a==='poke'){e.stopPropagation();fPoke2(i,a);return}openFC(f,c)}});
  const q=$('fq2');if(q){q.oninput=()=>{F65Q=q.value.trim();B.querySelectorAll('.f65r').forEach(c=>{const f=FR[+c.dataset.i];c.hidden=!!F65Q&&!f.n.includes(F65Q)&&!FID(f).includes(F65Q)})};
    q.addEventListener('keydown',e=>{if(e.key==='Enter'&&F65Q&&![...B.querySelectorAll('.f65r')].some(c=>!c.hidden)){openAdd();setTimeout(()=>{const i=$('adin');if(i){i.value=F65Q.replace(/^@/,'');addSearch(i.value)}},380)}})}}
{const _of=openFriend;openFriend=function(){_of();$('phone').classList.add('f65on');const F=$('fscr');if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  F.querySelectorAll('.f65st,.f65q,.f65sk,.f65w,.f65h').forEach((x,i)=>x.animate([{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'none'}],{duration:460,delay:80+i*45,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
  F.querySelectorAll('.f65rq,.f65r').forEach((x,i)=>x.animate([{opacity:0,transform:'translateX(-18px)'},{opacity:1,transform:'none'}],{duration:420,delay:300+i*45,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'}))}}
{const _cf=closeFriend;closeFriend=function(){$('phone').classList.remove('f65on');return _cf.apply(this,arguments)};$('fback').onclick=closeFriend;if(window.__api)window.__api.closeFriend=closeFriend}
/* Add シートの Shake も 同じ 全画面へ */
{const _ab=addBuild;addBuild=function(){_ab();const b=document.querySelector('#shf .adw [data-a="shake"]');if(b&&!b.dataset.v65){b.dataset.v65=1;b.onclick=()=>{closeSheet('shf');setTimeout(()=>openShake(),260)}}}}

/* ---------- C. Shake ---------- */
var SK={on:false,s:'idle',c:null,tm:[],mo:null};
const skT=(f,ms)=>{const t=setTimeout(f,ms);SK.tm.push(t);return t};
const skSet=(s,t,sub)=>{SK.s=s;const S=$('shk');S.dataset.s=s;if(t!=null)$('shkt').textContent=t;if(sub!=null)$('shks').textContent=sub};
function skBuild(){let S=$('shk');if(S)return S;S=document.createElement('section');S.className='shk';S.id='shk';S.dataset.s='idle';S.setAttribute('aria-label','ふって つながる');
  S.innerHTML=`<i class="skbg"></i><i class="skbgp" id="shkbg"></i><i class="skgr"></i><i class="skfl" id="shkfl"></i>
    <button class="skx" data-a="x" aria-label="とじる">${I65.x}</button><div class="skttl">Shake</div><span class="skdemo">DEMO ・ まんなかの 丸を 押すと「ふる」</span>
    <div class="skrad"><i class="skr skr4"></i><i class="skr skr3"></i><i class="skr skr2"></i><i class="skr skr1"></i><i class="sksw"></i><i class="skpl"></i><i class="skpl sk2"></i><i class="skpl sk3"></i><i class="skwv" id="shkwv"></i>
      <svg class="sklnk" viewBox="0 0 224 156"><rect x="6" y="6" width="212" height="144" rx="72" pathLength="100"/></svg>
      <button class="skdc skfr" id="shkfr" aria-hidden="true"></button><button class="skdc skme" id="shkme" aria-label="ふる(デモ)" style="background-image:url(${ME65()})"></button></div>
    <span class="skhint">${I65.ph}</span>
    <div class="skmsg"><b id="shkt"></b><small id="shks"></small></div>
    <p class="skpv">ふった 人 どうし だけに 見えます</p>
    <div class="skalt"><button data-a="qr">${I65.qr}QR で つながる</button><button data-a="id">${I65.id}ID で さがす</button></div>
    <div class="skcard"><b class="sknm" id="shkn"></b><span class="skid" id="shki"></span><div class="sktg" id="shkg"></div>
      <button class="skok" data-a="ok"><i></i><span id="shko">つながる</span></button><button class="skno" data-a="no">ちがう人</button><p class="skpr">ふたりとも「つながる」を 押すと 友だちに なります</p></div>`;
  $('phone').appendChild(S);
  S.querySelector('[data-a="x"]').onclick=()=>closeShake();
  $('shkme').onclick=()=>{skAsk();skShake()};
  S.querySelector('.skalt [data-a="qr"]').onclick=()=>{closeShake(true);setTimeout(()=>{hap('pop');openAdd()},280)};
  S.querySelector('.skalt [data-a="id"]').onclick=()=>{closeShake(true);setTimeout(()=>{hap('pop');openAdd();setTimeout(()=>{const i=$('adin');i&&i.focus()},420)},280)};
  S.querySelector('.skcard [data-a="ok"]').onclick=()=>skOk();
  S.querySelector('.skcard [data-a="no"]').onclick=()=>{hap('soft','やわらかく1回(ちがう人)',{norip:1});skIdle()};
  return S}
function skIdle(){SK.tm.forEach(clearTimeout);SK.tm=[];SK.c=null;skSet('idle','スマホを ふって','となりの 友だちも いっしょに')}
function openShake(){const S=skBuild();if(SK.on)return;SK.on=true;skIdle();S.classList.add('on');$('phone').classList.add('k65on');hap('sel','コツッ(Shake へ)');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches){S.querySelector('.skrad').animate([{transform:'scale(.6)',opacity:0},{transform:'none',opacity:1}],{duration:620,easing:'cubic-bezier(.3,1.3,.4,1)'});
    S.querySelectorAll('.skmsg,.skalt,.skpv').forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:460,delay:180+i*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
  /* 本物の スマホでは、ふった ゆれを ひろう */
  if(!SK.mo){let last=0,n=0;SK.mo=e=>{if(!SK.on||SK.s!=='idle')return;const a=e.accelerationIncludingGravity;if(!a)return;const m=Math.hypot(a.x||0,a.y||0,a.z||0);const t=performance.now();
      if(Math.abs(m-9.8)>13){if(t-last<650)n++;else n=1;last=t;if(n>=2){n=0;skShake()}}};window.addEventListener('devicemotion',SK.mo)}}
function skAsk(){try{if(window.DeviceMotionEvent&&typeof DeviceMotionEvent.requestPermission==='function')DeviceMotionEvent.requestPermission().catch(()=>{})}catch(e){}}
function closeShake(q){const S=$('shk');if(!S||!SK.on)return;SK.on=false;SK.tm.forEach(clearTimeout);SK.tm=[];S.classList.remove('on');$('phone').classList.remove('k65on');if(!q)hap('soft','やわらかく1回(とじる)')}
function skShake(){if(!SK.on||SK.s!=='idle')return;const S=$('shk');
  SK.c=FPOOL.find(f=>!FR.includes(f)&&!REQ.some(r=>r.f===f))||null;
  skSet('seek','さがして います…','そのまま ちかくに');hap('buzz','ブルブル(ふった)',{norip:1});
  [140,300,440,560,660,740].forEach(t=>skT(()=>hap('tick',null,{norip:1,noq:1}),t));
  if(!SK.c){skT(()=>{skSet('none','見つからなかった','もう いちど、いっしょに ふって みて');hap('warn','やわらかく2回(見つからない)',{norip:1});skT(()=>skIdle(),2600)},1700);return}
  skT(()=>skFound(),1500)}
function skFound(){const S=$('shk'),f=SK.c;if(!f||!SK.on)return;
  $('shkfr').style.backgroundImage=`url(${fPic(f)})`;$('shkbg').style.backgroundImage=`url(${fPic(f)})`;
  $('shkn').textContent=f.n;$('shki').textContent=FID(f);$('shko').textContent='つながる';
  $('shkg').innerHTML=[fTag(f),fTag2(f)].map(t=>`<span style="background:${tgc(t)[0]};color:${tgc(t)[1]}">${t}</span>`).join('');
  skSet('found','見つけた','ちかくで いっしょに ふった 人');
  /* ぶつかる:ドン → 白い 光 → 波紋 */
  skT(()=>{hap('thud','ドン(ぶつかった)',{norip:1});
    if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
    $('shkfl').animate([{opacity:0},{opacity:.22},{opacity:0}],{duration:420,easing:'cubic-bezier(.2,.8,.3,1)'});
    $('shkwv').animate([{transform:'scale(.9)',opacity:.9},{transform:'scale(6)',opacity:0}],{duration:900,easing:'cubic-bezier(.2,.7,.2,1)'});
    S.querySelector('.skrad').animate([{transform:'translateY(-58px) scale(1)'},{transform:'translateY(-58px) scale(1.08)'},{transform:'translateY(-58px) scale(1)'}],{duration:360,easing:'cubic-bezier(.3,1.6,.4,1)'});
    $('shkg').querySelectorAll('span').forEach((s,k)=>s.animate([{scale:'0'},{scale:'1.22'},{scale:'1'}],{duration:400,delay:260+k*100,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'}))},430);
  skT(()=>hap('success','トトトン(見つけた)',{norip:1}),620)}
function skOk(){if(SK.s!=='found')return;const f=SK.c;hap('click','カチッ(つながる)',{norip:1});skSet('wait');$('shko').textContent=f.n+' を まって います…';
  skT(()=>{skSet('done','つながった','あしたの 朝 9:00 から、きのうを 見せあえる');hap('success','トトトン(つながった)',{norip:1});skT(()=>hap('heart','ドクン',{norip:1}),380);
    if(!FR.includes(f))FR.unshift(f);
    skT(()=>{closeShake(true);try{renderFriends(0)}catch(e){}try{renderPick()}catch(e){}try{renderOrb()}catch(e){}if(!$('fscr').classList.contains('on'))openFriend()},1900)},1100)}
{const _ca=closeAll;closeAll=function(){try{closeShake(true)}catch(e){}return _ca.apply(this,arguments)}}
window.openShake=openShake;
/* デモの ボタン */
try{const C=$('ctl');if(C&&!C.querySelector('[data-c="shake65"]')){const b=document.createElement('button');b.dataset.c='shake65';b.textContent='ふって つながる(Shake)';
  b.onclick=()=>{try{closeAll()}catch(e){}show('home');if(!$('fscr').classList.contains('on'))openFriend();setTimeout(()=>{openShake();setTimeout(()=>skShake(),1300)},500)};C.appendChild(b)}}catch(e){}
try{renderFriends()}catch(e){console.error(e)}
Object.assign(window.__kit||(window.__kit={}),{openShake:()=>openShake(),skShake:()=>skShake(),skOk:()=>skOk(),closeShake:()=>closeShake(true),SK:()=>SK,openFriend:()=>openFriend(),hs:()=>$('hs')});
