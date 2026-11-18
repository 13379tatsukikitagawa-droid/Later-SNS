
/* ================= v80(PROMPT v87)・ 撮影画面 ・ Home の 上と 下 ・ Friends 初回 ・ Mondo ・ プロフィール + 設定 ================= */
const X8={front:false,first:false,noown:false,nofr:false,lang:'ja',sw:{open:true,fr:true,rc:true}};
const X8RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const X8I={cam:'<svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>',
  flip:'<svg viewBox="0 0 24 24"><path d="M4 8.5h3.2l1.5-2.3h6.6l1.5 2.3H20v10.3H4z"/><path d="M9 12.7a3.2 3.2 0 015.7-1"/><path d="M15 14.5a3.2 3.2 0 01-5.7 1"/><path d="M14.9 9.8v2h-2M9.1 17.2v-2h2"/></svg>',
  bell:'<svg viewBox="0 0 24 24"><path d="M6 16.5V11a6 6 0 0112 0v5.5l1.5 2H4.5z"/><path d="M10 20.5a2.2 2.2 0 004 0"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg>',
  scan:'<svg viewBox="0 0 24 24"><path d="M4 8V5a1 1 0 011-1h3M16 4h3a1 1 0 011 1v3M20 16v3a1 1 0 01-1 1h-3M8 20H5a1 1 0 01-1-1v-3M4 12h16"/></svg>',
  link:'<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.700 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>',
  sw:'<svg viewBox="0 0 12 12"><path d="M3 4.4h6.2L7.4 2.6M9 7.6H2.8l1.8 1.8"/></svg>',
  play:'<svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.500z"/></svg>'};

/* ---------- A. 撮影画面:テーマ色 ・ インカメ ・ もどる = タグ画面 ---------- */
function x8Cam(){const C=$('cam'),S=$('st');if(!C||!S)return;
  if(!$('x8fp')){S.insertAdjacentHTML('afterend',`<div class="side x8fp" id="x8fp" role="button" tabindex="0" aria-label="カメラを 切りかえ(インカメ)"><div class="b glass">${X8I.flip}</div><span id="x8fpt">BACK</span></div>`);
    $('x8fp').onclick=()=>x8Flip();
    let lt=0;C.addEventListener('pointerup',e=>{const id=e.target&&e.target.id;if(id!=='live'&&id!=='win')return;const n=performance.now();if(n-lt<320){lt=0;x8Flip()}else lt=n});
    $('fl')&&$('fl').addEventListener('click',()=>setTimeout(x8CamSync,0));
    /* もどる:すぐ タグ画面へ(動きを 2倍 速く)*/
    $('cback')&&$('cback').addEventListener('click',()=>requestAnimationFrame(()=>['cam','tag','win'].forEach(id=>{const e=$(id);e&&e.getAnimations().forEach(a=>{try{a.updatePlaybackRate(2.2)}catch(_){}})})))}
  x8CamSync()}
function x8CamSync(){const C=$('cam');if(!C)return;C.classList.toggle('x8f',X8.front);const t=$('x8fpt');t&&(t.textContent=X8.front?'FRONT':'BACK');
  const w=$('wtxt');if(w&&/LIVE/.test(w.textContent))w.textContent=X8.front?'LIVE ・ FRONT':'LIVE ・ ISO 400';
  const f=$('flt'),F=$('fl');if(f&&F)f.textContent=F.classList.contains('on')?(X8.front?'SCREEN':'AUTO'):'OFF'}
function x8Flip(){if(X8.fl)return;const L=$('live'),B=$('x8fp');if(!L||!B)return;X8.fl=1;hap('sel','コツッ(カメラを 切りかえ)');
  if(X8RM()){X8.front=!X8.front;x8CamSync();X8.fl=0;return}
  B.querySelector('.b').animate([{transform:'rotate(0)'},{transform:'rotate(180deg)'}],{duration:440,easing:'cubic-bezier(.3,1.2,.4,1)'});
  const m=()=>X8.front?' scaleX(-1)':'';
  const a=L.animate([{transform:'perspective(900px) rotateY(0) scale(1)'+m(),filter:'blur(0) brightness(1)'},{transform:'perspective(900px) rotateY(86deg) scale(.9)'+m(),filter:'blur(8px) brightness(.4)'}],{duration:190,easing:'cubic-bezier(.5,0,.8,.4)',fill:'forwards'});
  a.onfinish=()=>{X8.front=!X8.front;x8CamSync();a.cancel();hap('tick',null,{norip:1});
    L.animate([{transform:'perspective(900px) rotateY(-86deg) scale(.9)'+m(),filter:'blur(8px) brightness(.4)'},{transform:'perspective(900px) rotateY(0) scale(1)'+m(),filter:'blur(0) brightness(1)'}],{duration:250,easing:'cubic-bezier(.2,.8,.3,1)'}).onfinish=()=>{X8.fl=0}}}
{const _r=renderCam;renderCam=function(){_r();try{x8Cam()}catch(e){console.error(e)}}}
try{x8Cam()}catch(e){}

/* ---------- B. Home:アイコン(1回 = プロフィール ・ 2回 = きのうへ)・ 地球の「今日を撮る」---------- */
function x8Home(){const H=document.querySelector('#hhd .hh'),A=H&&H.querySelector('.av');if(!A)return;
  if(!A.querySelector('.x8sw'))A.insertAdjacentHTML('beforeend',`<b class="x8sw" aria-hidden="true">${X8I.sw}</b><em class="x8tip">2回 タップで きのうへ</em>`);
  A.setAttribute('role','button');A.setAttribute('aria-label','プロフィール ・ 2回 タップで きのうへ');
  if(!H._x8){H._x8=1;let t=0,tm=0;
    H.addEventListener('pointerup',e=>{const a=e.target.closest&&e.target.closest('.av');if(!a)return;e.stopPropagation();e.preventDefault();const n=performance.now();
      if(n-t<340){clearTimeout(tm);t=0;hap('sel','カチ(きのうへ)');!X8RM()&&a.animate([{transform:'scale(1)'},{transform:'scale(.84)',offset:.25},{transform:'scale(1.14)',offset:.6},{transform:'scale(1)'}],{duration:440,easing:'cubic-bezier(.3,1.5,.5,1)'});
        const s=a.querySelector('.x8sw');s&&!X8RM()&&s.animate([{transform:'rotate(0)'},{transform:'rotate(180deg)'}],{duration:420,easing:'cubic-bezier(.3,1.3,.5,1)'});
        setTimeout(()=>{try{openY(a)}catch(_){try{openY()}catch(e){}}},120)}
      else{t=n;hap('tick',null,{norip:1});!X8RM()&&a.animate([{transform:'scale(1)'},{transform:'scale(.9)',offset:.4},{transform:'scale(1)'}],{duration:200});
        tm=setTimeout(()=>{t=0;try{openPrf(a)}catch(e){console.error(e)}},340)}},true);
    H.addEventListener('click',e=>{if(e.target.closest&&e.target.closest('.av'))e.stopPropagation()},true)}
  if(!X8.hinted){X8.hinted=1;setTimeout(()=>{const a=document.querySelector('#hhd .av');a&&a.classList.add('x8h');setTimeout(()=>a&&a.classList.remove('x8h'),2600)},1800)}
  x8Dome()}
function x8Dome(){const M=$('hmoon');if(!M)return;if(!$('x8gl')){M.insertAdjacentHTML('afterbegin','<canvas id="x8gl" width="1200" height="440" aria-hidden="true"></canvas><i class="x8rim" aria-hidden="true"></i>');
    M.addEventListener('pointerdown',()=>{X8.spd=3.2});}
  x8DomeRun()}
const X8C=[[62,20],[48,95],[70,170],[38,230],[55,300],[30,150],[44,345]];
function x8DomeDraw(rot){const c=$('x8gl');if(!c)return;const x=c.getContext('2d');x.setTransform(2,0,0,2,0,0);x.clearRect(0,0,600,220);
  const R=300,cx=300,cy=300,a=22*Math.PI/180,ca=Math.cos(a),sa=Math.sin(a),D=Math.PI/180;
  const P=(la,lo)=>{la*=D;lo=(lo+rot)*D;const cl=Math.cos(la),X=cl*Math.sin(lo),Y=Math.sin(la),Z=cl*Math.cos(lo);return [cx+R*X,cy-R*(Y*ca-Z*sa),Y*sa+Z*ca]};
  const line=(pts,al,w)=>{x.beginPath();let pen=false;pts.forEach(([px,py,z])=>{if(z>0&&py<224){pen?x.lineTo(px,py):x.moveTo(px,py);pen=true}else pen=false});x.strokeStyle=`rgba(200,242,90,${al})`;x.lineWidth=w;x.stroke()};
  for(let la=20;la<=80;la+=10){const p=[];for(let lo=0;lo<=360;lo+=4)p.push(P(la,lo-rot));line(p,la>=70?.34:.2,.9)}
  for(let lo=0;lo<360;lo+=15){const p=[];for(let la=6;la<=90;la+=4)p.push(P(la,lo));line(p,.24,.9)}
  X8C.forEach(([la,lo],k)=>{const [px,py,z]=P(la,lo);if(z<.05||py>200)return;const o=Math.min(1,z*1.5);const g=x.createRadialGradient(px,py,0,px,py,11+(k%3)*3);g.addColorStop(0,`rgba(200,242,90,${.55*o})`);g.addColorStop(1,'rgba(200,242,90,0)');x.fillStyle=g;x.beginPath();x.arc(px,py,11+(k%3)*3,0,7);x.fill();x.fillStyle=`rgba(232,255,170,${o})`;x.beginPath();x.arc(px,py,2.2,0,7);x.fill()});
  x.globalCompositeOperation='destination-in';const m=x.createLinearGradient(0,0,0,220);m.addColorStop(0,'rgba(0,0,0,1)');m.addColorStop(.45,'rgba(0,0,0,.75)');m.addColorStop(1,'rgba(0,0,0,.12)');x.fillStyle=m;x.fillRect(0,0,600,220);x.globalCompositeOperation='source-over'}
function x8DomeRun(){cancelAnimationFrame(X8.raf);X8.rot=X8.rot||0;X8.spd=X8.spd||.12;x8DomeDraw(X8.rot);if(X8RM())return;let last=0;
  const f=ts=>{const H=$('home');if(!H||!$('x8gl'))return;if(H.classList.contains('on')&&ts-last>33){X8.rot=(X8.rot+X8.spd)%360;X8.spd+=(.12-X8.spd)*.04;x8DomeDraw(X8.rot);last=ts}X8.raf=requestAnimationFrame(f)};X8.raf=requestAnimationFrame(f)}
{const _r=renderOrb;renderOrb=function(){_r();try{x8Home()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
try{x8Home()}catch(e){}

/* ---------- C. Lattag yesterday:Friends の はじめて ・ Mondo の ない 日 ・ アイコンを 大きく ---------- */
function x8First(){const own=X8.first||X8.noown,nf=X8.first||X8.nofr;let h='';
  if(own)h+=`<section class="x8fs"><div class="x8fan" data-a="shoot" role="button" aria-label="最初の 1枚を 撮る"><i></i><i></i><i>${X8I.cam}</i></div>
   <h2>最初の 1枚を 撮ろう</h2><p>あした 9:00 に、ここで ひらきます</p><button class="x8go" data-a="shoot">${X8I.cam}撮る</button></section>`;
  if(nf)h+=`<section class="x8iv"><div class="x8ih"><b>友だちを よぶ</b><small>0 FRIENDS</small></div>
   <div class="x8ib"><button data-x8="qr"><i>${X8I.qr}</i><b>QR を 見せる</b></button><button data-x8="scan"><i>${X8I.scan}</i><b>QR を 読む</b></button><button data-x8="link"><i>${X8I.link}</i><b>リンク</b></button></div>
   <div class="x8gh" aria-hidden="true">${[0,1].map(()=>'<div class="x8gp"><div class="x8gt"><i></i><span><u></u><u></u></span></div><div class="x8gi"><i></i></div></div>').join('')}</div></section>`;
  return h}
{const _f=y72Friends;y72Friends=function(lk){const own=X8.first||X8.noown,nf=X8.first||X8.nofr;if(!own&&!nf)return _f(lk);let h=_f(lk);
  /* 自分の きのう が ない → 上の かたまりを 入れかえ ・ 友だちが いない → 投稿の 列を 入れかえ */
  const i=h.indexOf('<article'),top=i<0?h:h.slice(0,i),feed=i<0?'':h.slice(i);const F=x8First();
  if(own&&nf)return F;if(own)return F+feed;return top.replace(/<div class="zbn">[^]*?<\/button><\/div>/,'')+F}}
{const _h=y72Head;y72Head=function(){let h=_h();if(Y72.tab==='f'&&(X8.first||X8.nofr))h=h.replace(/<small>[^<]*<\/small>/,`<small>${X8.first?'DAY 1':'きのう'}</small>`);
  return h.replace('<span class="tip">2回 タップで 今日へ</span>',`<b class="x8sw" aria-hidden="true">${X8I.sw}</b><span class="tip">2回 タップで 今日へ</span>`)}}
function x8NoMondo(){const d=new Date(Date.now()-864e5);
  return `<section class="x8nm"><i class="x8stars"></i><div class="x8ng"><svg viewBox="0 0 580 580">${Y72D}<g data-sp="night"></g><circle cx="290" cy="290" r="271" fill="url(#y72sh)"/></svg></div>
   <div class="x8nt"><small>${d.getMonth()+1}/${d.getDate()}</small><b>No Mondo</b></div>
   <div class="x8nc"><small>NEXT</small><b id="y72cd">--:--:--</b><i><u id="y72cb"></u></i></div>
   <div class="x8nb"><button data-a="shoot">${X8I.cam}撮る</button><button class="nf" data-a="nf" aria-label="9:00 に 知らせる">${X8I.bell}<span hidden></span></button></div></section>`}
{const _m=y72Mondo;y72Mondo=function(lk){return Y72.ms!=='posted'?x8NoMondo():_m(lk)}}
{const _b=y72Bind;y72Bind=function(W){_b(W);
  W.querySelectorAll('[data-x8]').forEach(b=>b.onclick=()=>{const k=b.dataset.x8;hap('pop');!X8RM()&&b.animate([{scale:'1'},{scale:'.92'},{scale:'1.04'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'});
    if(k==='qr'){try{openPrf(b)}catch(e){}setTimeout(()=>{const c=$('pck');c&&!c.classList.contains('fl')&&c.classList.add('fl')},700)}
    else if(k==='scan'){try{openScan('fr')}catch(e){}}
    else{try{const m=fMe();openShare({t:`Lattag で つながろう ・ ${m.n}(${m.id})\nhttps://lattag.app/u/${m.id.slice(1)}`,h:m.n})}catch(e){}}});
  const nf=W.querySelector('.x8nb .nf');nf&&nf.addEventListener('click',()=>{nf.setAttribute('aria-pressed',nf.classList.contains('on'));try{_toast(nf.classList.contains('on')?'9:00 に 知らせます':'お知らせを やめました')}catch(e){}})}}
Object.assign(window.__kit||(window.__kit={}),{x8First:(o={})=>{X8.first=o.first!==undefined?!!o.first:true;X8.noown=!!o.noown;X8.nofr=!!o.nofr;Y72.tab='f';Y72.anim=0;y72Render();const s=document.querySelector('#yst .y72 .zsc');s&&(s.scrollTop=o.top||0)},x8Flip:()=>x8Flip(),x8Front:v=>{X8.front=!!v;x8CamSync()}});

/* ---------- D. プロフィール(作りなおし)+ 設定シート ---------- */
function x8Prf(){const P=$('prf'),B=$('pbd');if(!P||!B||!P.classList.contains('on')||P.classList.contains('x8p'))return;P.classList.add('x8p');let m={n:'',id:''};try{m=fMe()}catch(e){}
  /* 1) シールは 自分の 3つ だけ */
  const PS=[[-120,-112,-8,1.04],[118,-84,7,1],[-128,52,5,1]];let k=0;
  P.querySelectorAll('.pst').forEach(s=>{if(!s.classList.contains('me')||k>2){s.remove();return}const [X,Y,R,S]=PS[k++];s.style.setProperty('--x',X+'px');s.style.setProperty('--y',Y+'px');s.style.setProperty('--r',R+'deg');s.style.setProperty('--s',S)});
  /* 2) 上の 帯:スクロールで 小さな アイコン + 名前 */
  const hd=P.querySelector('.phd'),id=P.querySelector('.pid');
  if(hd&&id){id.setAttribute('role','button');id.setAttribute('aria-label','ID を コピー');id.insertAdjacentHTML('afterend',`<span class="x8mn" aria-hidden="true"><i style="background-image:${(()=>{try{return avUrl()}catch(e){return 'none'}})()}"></i><b>${m.n||''}</b></span>`);
    id.onclick=()=>{hap('tick','コツ(コピー)');try{navigator.clipboard&&navigator.clipboard.writeText(m.id).catch(()=>{})}catch(e){}!X8RM()&&id.animate([{scale:'1'},{scale:'.94'},{scale:'1'}],{duration:220});try{_toast('ID を コピーしました')}catch(e){}}}
  /* 3) ME → Recap の カード */
  const me=$('pme');if(me){let lbl='',ph=['c','a','e','b','f','d','a'];try{const R=rcWeeks(m73Days()),L=R.done[0];lbl=rcLbl(L);ph=L.days.map(x=>x.sh.length?x.sh[x.sh.length-1].p:null)}catch(e){}
    me.classList.add('x8rc');me.setAttribute('aria-label','ME ・ Recap を 見る');
    me.innerHTML=`<i class="x8k" style="background-image:url(${PH[ph.find(p=>p)||'c']})"></i><i class="x8s"></i><span class="x8l"><b>ME</b>${lbl?`RECAP ・ ${lbl}`:'RECAP'}</span><span class="x8t">Your <em>week.</em></span><span class="x8pl">${X8I.play}</span><span class="x8f7">${ph.map(p=>p?`<i style="background-image:url(${PH[p]})"></i>`:'<i class="e"></i>').join('')}</span>`;
    if(!X8RM()){const K=me.querySelector('.x8k');K.animate([{transform:'scale(1.16) translate(2%,2%)'},{transform:'scale(1.04) translate(-1%,0)'}],{duration:9000,direction:'alternate',iterations:Infinity,easing:'ease-in-out'})}}
  /* 4) 設定の 一覧は シートへ */
  const S=$('psetl');S&&S.remove();const g=$('pfset');g&&(g.onclick=()=>{!X8RM()&&g.querySelector('svg').animate([{transform:'rotate(0)'},{transform:'rotate(90deg)'}],{duration:420,easing:'cubic-bezier(.3,1.3,.5,1)'});x8Set(true)});
  /* 5) 数字は 数えながら 出る */
  if(!X8RM())P.querySelectorAll('.pstat b').forEach((b,i)=>{const n=parseInt(b.textContent,10);if(!(n>0))return;const t0=performance.now()+260+i*90,d=620;b.textContent='0';const f=ts=>{const q=Math.max(0,Math.min(1,(ts-t0)/d));b.textContent=Math.round(n*(1-Math.pow(1-q,3)));if(q<1&&document.contains(b))requestAnimationFrame(f)};requestAnimationFrame(f)});
  /* 6) スクロールで 上の 帯が まとまる */
  B.addEventListener('scroll',()=>{const on=B.scrollTop>300;if(on!==P.classList.contains('x8c')){P.classList.toggle('x8c',on);hap('tick',null,{norip:1,gap:300})}},{passive:true});
  /* 7) 下から 順に 入る */
  if(!X8RM())B.querySelectorAll('.pnm,.pstat,.pact,#pme,.pyr').forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:520,delay:240+i*70,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}))}
{const _o=openPrf;openPrf=function(from){_o(from);try{x8Prf()}catch(e){console.error(e)}}}
function x8Set(on){let S=$('x8set');if(!on){if(S){S.classList.remove('on');hap('soft',null,{norip:1})}return}let m={n:'',id:''};try{m=fMe()}catch(e){}
  if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="x8set" id="x8set" aria-label="設定" role="dialog"></section>');S=$('x8set')}
  const tg=(k,t,s)=>`<button class="x8tg${X8.sw[k]?' on':''}" data-k="${k}" role="switch" aria-checked="${!!X8.sw[k]}"><span><b>${t}</b>${s?`<small>${s}</small>`:''}</span><i><u></u></i></button>`;
  const row=(a,t,r,c)=>`<button class="x8rw${c?' '+c:''}" data-a="${a}"><span>${t}</span><em>${r||''}</em></button>`;
  S.innerHTML=`<i class="x8sb" data-a="x"></i><div class="x8sh"><div class="x8sg" data-a="drag"><i></i></div><div class="x8st" data-a="drag"><b>設定</b><button data-a="x" aria-label="とじる"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>
   <div class="x8sc">
    <button class="x8me" data-a="edit"><i style="background-image:${(()=>{try{return avUrl()}catch(e){return 'none'}})()}"></i><span><b>${m.n||''}</b><small>${m.id||''}</small></span><em>編集</em></button>
    <div class="x8gr"><small>お知らせ</small>${tg('open','9:00 に ひらく','きのうの 写真が ひらいた 時')}${tg('fr','友だち','申請 ・ リアクション ・ コメント')}${tg('rc','Recap','月曜 9:00 に できた 時')}</div>
    <div class="x8gr"><small>表示</small><div class="x8rw x8lg"><span>言語</span><div class="x8sgm" data-v="${X8.lang}"><i></i><button data-l="ja">日本語</button><button data-l="en">English</button></div></div></div>
    <div class="x8gr"><small>アカウント</small>${row('av','アイコンの 写真','›')}${row('blk','ブロックした 人','0 ›')}</div>
    <div class="x8gr"><small>サポート</small>${row('how','使いかた','›')}${row('terms','利用規約','›')}${row('priv','プライバシー','›')}${row('mail','問い合わせ','›')}</div>
    <div class="x8gr">${row('out','ログアウト','','red')}${row('del','アカウントを 消す','','del')}</div>
    <p class="x8vr">Lattag 1.0 (1)</p></div></div>`;
  const cl=()=>x8Set(false);S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=cl);
  S.querySelectorAll('.x8tg').forEach(b=>b.onclick=()=>{const k=b.dataset.k;X8.sw[k]=!X8.sw[k];b.classList.toggle('on',X8.sw[k]);b.setAttribute('aria-checked',X8.sw[k]);hap('click',X8.sw[k]?'カチッ(オン)':'カチッ(オフ)')});
  S.querySelectorAll('.x8sgm button').forEach(b=>b.onclick=()=>{if(X8.lang===b.dataset.l)return;X8.lang=b.dataset.l;b.parentNode.dataset.v=X8.lang;hap('sel','コツッ(言語)');try{_toast(X8.lang==='en'?'English(モック:次の 起動から)':'日本語')}catch(e){}});
  S.querySelectorAll('.x8rw[data-a],.x8me').forEach(b=>b.onclick=()=>{const a=b.dataset.a;hap('tick',null,{norip:1});
    if(a==='edit'){cl();setTimeout(()=>{try{pfEdit(true)}catch(e){}},380)}
    else if(a==='av'){try{avOpen()}catch(e){}}
    else if(a==='blk')actSheet('ブロックした 人',[{l:'まだ いません',fn:()=>ovClose('acs')}]);
    else if(a==='out')actSheet('ログアウトしますか?',[{l:'ログアウト',red:1,fn:()=>{ovClose('acs');cl();try{_toast('ログアウトしました(モック)')}catch(e){}}},{l:'キャンセル',fn:()=>ovClose('acs')}]);
    else if(a==='del')actSheet('アカウントを 消しますか? 写真と 友だちが すべて 消えます',[{l:'アカウントを 消す',red:1,fn:()=>{ovClose('acs');try{_toast('もう一度 確かめる 画面へ(モック)')}catch(e){}}},{l:'キャンセル',fn:()=>ovClose('acs')}]);
    else{try{_toast({how:'使いかた',terms:'利用規約',priv:'プライバシー',mail:'問い合わせ'}[a]+' を ひらく(モック)')}catch(e){}}});
  /* 下へ 引いて とじる */
  const H=S.querySelector('.x8sh');let y0=0,dy=0,dr=false;S.querySelectorAll('[data-a="drag"]').forEach(g=>{g.onpointerdown=e=>{if(e.target.closest('button'))return;dr=true;y0=e.clientY;dy=0;try{g.setPointerCapture(e.pointerId)}catch(_){}H.style.transition='none'};
    g.onpointermove=e=>{if(!dr)return;dy=Math.max(0,e.clientY-y0);H.style.transform=`translateY(${dy}px)`};
    g.onpointerup=g.onpointercancel=()=>{if(!dr)return;dr=false;H.style.transition='';H.style.transform='';if(dy>110)cl()}});
  void S.offsetWidth;S.classList.add('on');hap('pop','ぷにっ(設定)')}
{const _c=closePrf;closePrf=function(){try{x8Set(false)}catch(e){}_c()}}
Object.assign(window.__kit,{x8Set:v=>x8Set(v!==false),cmHide:()=>{try{cmHide()}catch(e){}}});

/* モック だけ:デモボタン */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-x80]'))return;
  C.insertAdjacentHTML('beforeend',[['ff','Friends:はじめて'],['fn','Friends:友だち 0人'],['fo','Friends:いつも'],['st','設定を ひらく'],['fc','インカメ']].map(([k,t])=>`<button data-x80="${k}">${t}</button>`).join(''));
  C.querySelectorAll('[data-x80]').forEach(b=>b.onclick=()=>{const k=b.dataset.x80,Y=$('yst'),op=Y&&Y.classList.contains('on');
    const go=o=>{if(!op){try{openY()}catch(e){}setTimeout(()=>__kit.x8First(o),700)}else __kit.x8First(o)};
    if(k==='ff')go({first:true});if(k==='fn')go({first:false,nofr:true});if(k==='fo')go({first:false});
    if(k==='st'){try{if(!$('prf').classList.contains('on'))openPrf()}catch(e){}setTimeout(()=>x8Set(true),700)}
    if(k==='fc'){try{window.__api.toCam()}catch(e){}setTimeout(()=>x8Flip(),1100)}})})();
