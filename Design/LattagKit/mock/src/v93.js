/* ===== v93(モック v93 ・ PROMPT v104) =====
   1. サインイン:Google ・ メールを やめて Apple の ロゴだけ ・ 見出し「昨日を 共有する SNS」・ メールは かくす
   2. Name:アイコンの 写真が キーボードの 上でも 見える ・ 文字数は 入力欄の 中
   3. ID シート:空白を なくす(中身の 高さ + キーボードの 上)
   4. 招待シート:中身の 高さ(半分くらい)= 見た目は v90 の まま ・ 実機で 合わせる
   5. ウィジェット:先に えらぶ → ホームで 置く ガイド → もどると 自動で たしかめる
   名前:c9 */
const C9={hm:1,cancel:0,fail:0,pick:'lens',from:'tour',done:0,t:[],log:[]};
const C9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const C9APL='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12.152 6.896c-.948 0-2.415-1.078-3.96-1.04-2.04.027-3.91 1.183-4.961 3.014-2.117 3.675-.546 9.103 1.519 12.09 1.013 1.454 2.208 3.09 3.792 3.039 1.52-.065 2.09-.987 3.935-.987 1.831 0 2.35.987 3.96.948 1.637-.026 2.676-1.48 3.676-2.948 1.156-1.688 1.636-3.325 1.662-3.415-.039-.013-3.182-1.221-3.22-4.857-.026-3.04 2.48-4.494 2.597-4.559-1.429-2.09-3.623-2.324-4.39-2.376-2-.156-3.675 1.09-4.61 1.09zM15.53 3.83c.843-1.012 1.4-2.427 1.245-3.83-1.207.052-2.662.805-3.532 1.818-.78.896-1.454 2.338-1.273 3.714 1.338.104 2.715-.688 3.559-1.701"/></svg>';
const C9EYE='<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M3 12s3.4-6 9-6 9 6 9 6-3.4 6-9 6-9-6-9-6z"/><circle cx="12" cy="12" r="2.6"/><path d="M4 20L20 4"/></svg>';

/* ================= 1. サインイン ================= */
const c9Ap=()=>`<div class="c9a"><button class="c9ap" data-a="apple" aria-label="Apple で つづける"><i class="c9r r1"></i><i class="c9r r2"></i><i class="c9dash"></i><span class="c9lg">${C9APL}</span></button>
  <p class="c9al">Apple で つづける</p>
  <button class="c9hm${C9.hm?' on':''}" id="c9hm" data-a="c9hm" role="switch" aria-checked="${C9.hm?'true':'false'}">${C9EYE}<span>メールは かくす</span><i class="c9sw"><b></b></i></button>
  <p class="c9hs" id="c9hs">${C9.hm?'Lattag は メールアドレスを うけとりません':'Apple の 画面で メールの あつかいを えらべます'}</p>
  <p class="a9er" id="a9er" role="alert" hidden></p></div>`;
{const _t=obTpl;obTpl=function(st){
  if(st==='back')return[`<span class="obk2 a9k">SIGNING IN</span><div class="a9sp" aria-hidden="true"><i></i><b>#</b></div><h2 class="obh">はいって います</h2><p class="obsb">Apple で つづけて います</p>`,``];
  const r=_t(st);
  if(st==='in'){
    r[0]=`<span class="obk2">FILM FOR TOMORROW</span><h2 class="obh c9h">昨日を<br>共有する <em>SNS</em></h2>`;
    r[1]=r[1].replace(/<button class="ob1" data-a="apple">[\s\S]*?data-a="mail">[^<]*<\/button>/,c9Ap())}
  if(st==='name')r[0]=r[0].replace(/<\/label><div class="obct" id="obcnt">([^<]*)<\/div>/,'<span class="obct c9ct" id="obcnt">$1</span></label>');
  return r}}
function c9HmSync(){const b=$('c9hm'),s=$('c9hs');if(!b)return;b.classList.toggle('on',!!C9.hm);b.setAttribute('aria-checked',C9.hm?'true':'false');
  if(s)s.textContent=C9.hm?'Lattag は メールアドレスを うけとりません':'Apple の 画面で メールの あつかいを えらべます'}
function c9Apple(b){if(OB.busy)return;OB.busy=true;b.classList.add('go');b.setAttribute('aria-busy','true');hap('click','カチッ(Apple)');const E=$('a9er');if(E)E.hidden=true;
  setTimeout(()=>{OB.busy=false;b.classList.remove('go');b.removeAttribute('aria-busy');if(!OB.on)return;
    if(C9.cancel){C9.cancel=0;hap('soft','ふわっ(とじた ・ 何も 出さない)',{norip:1});return}
    if(C9.fail){C9.fail=0;a9Err('サインインできませんでした。もう一度 どうぞ',A9.err||'auth/network-request-failed (17020)');hap('warn','やわらかく2回(できない)');return}
    b.classList.add('ok');hap('success','トトトン(サインイン できた)',{norip:1});
    setTimeout(()=>{b.classList.remove('ok');if(OB.on&&OB.st==='in')obStep('name')},460)},900)}
{const _a=obAct;obAct=function(a,b){
  if(a==='c9hm'){C9.hm=C9.hm?0:1;c9HmSync();hap('sel','コツッ(メール)');return}
  if(a==='apple'){c9Apple(b);return}
  return _a(a,b)}}

/* ================= 2. Name:アイコンの 写真の 席 ================= */
{const _b=obBind;obBind=function(){_b();
  if(OB.st==='name'){const set=()=>{const R=document.querySelector('#obx .ob76');if(!R||R.dataset.c9)return;R.dataset.c9=1;R.addEventListener('click',e=>{if(e.target.closest('button'))return;try{avOpen()}catch(x){}});
      const p=R.querySelector('p');if(p)p.innerHTML='<b>アイコンの 写真</b>タップして えらぶ ・ あとで かえられます'};
    set();setTimeout(set,80);setTimeout(set,600)}}}

/* ================= 3. ID シート ・ キーボードの 上に ぴったり ================= */
{const _o=k9IdOpen;k9IdOpen=function(){_o.apply(this,arguments);const S=$('k9is');if(!S)return;S.classList.add('c9k');
  let K=S.querySelector('.c9kb');if(!K){S.insertAdjacentHTML('beforeend','<div class="j9kbw c9kb"></div>');K=S.querySelector('.c9kb')}K.innerHTML=j9Kbd('en')}}
{const _c=k9IdClose;k9IdClose=function(){const S=$('k9is');if(S){S.classList.remove('c9k');const K=S.querySelector('.c9kb');if(K)K.remove()}return _c.apply(this,arguments)}}

/* ================= 5. ウィジェット ================= */
const C9W=[
  {k:'lens',n:'レンズ',s:'押すと すぐ 撮れる'},
  {k:'until',n:'9:00 まで',s:'現像が ひらくまで'},
  {k:'friend',n:'友だちの 1枚',s:'きのうの 友だちを 1枚ずつ'},
  {k:'mondo',n:'Mondo',s:'世界の きのうの お題'}];
const c9Tile=k=>({
  lens:'<i class="c9tl t-lens"><b>#</b></i>',
  until:'<i class="c9tl t-until"><b>16:10</b><small>9:00 まで</small></i>',
  friend:'<i class="c9tl t-friend"><b></b><small>きのう</small></i>',
  mondo:'<i class="c9tl t-mondo"><b>M</b><small>今日の お題</small></i>'}[k]);
function c9wBuild(){let S=$('c9w');if(S)return S;
  $('phone').insertAdjacentHTML('beforeend','<div class="c9w" id="c9w" aria-hidden="true"><i class="c9wc"></i><div class="c9wp" role="dialog" aria-label="ウィジェット"></div></div><div class="c9g" id="c9g" aria-hidden="true"></div>');
  S=$('c9w');S.querySelector('.c9wc').onclick=()=>c9wLater();return S}
function c9wOpen(from){const S=c9wBuild(),P=S.querySelector('.c9wp');C9.from=from||'tour';C9.log.push('open:'+C9.from);
  P.innerHTML=`<i class="grab"></i><h2>ウィジェット、置きますか?</h2><p class="c9ws">ホーム画面に 置くと、撮りたくなる ・ 待ちたくなる。<br>1つ えらんで ください。</p>
    <div class="c9wl" role="radiogroup" aria-label="ウィジェットの しゅるい">${C9W.map(w=>`<button class="c9wo${w.k===C9.pick?' on':''}" role="radio" aria-checked="${w.k===C9.pick}" data-k="${w.k}">${c9Tile(w.k)}<span><b>${w.n}</b><small>${w.s}</small></span><em class="c9rd"></em></button>`).join('')}</div>
    <button class="c9wgo" data-a="go">ホームで 置く</button>
    <button class="c9wno" data-a="later">${C9.from==='tour'?'あとで ・ 設定から できます':'とじる'}</button>`;
  P.querySelectorAll('.c9wo').forEach(b=>b.onclick=()=>{C9.pick=b.dataset.k;P.querySelectorAll('.c9wo').forEach(x=>{const on=x===b;x.classList.toggle('on',on);x.setAttribute('aria-checked',on)});hap('sel','コツッ(えらぶ)',{norip:1})});
  P.querySelector('[data-a="go"]').onclick=()=>{hap('click','カチッ(ホームで 置く)');S.classList.remove('on');S.setAttribute('aria-hidden','true');setTimeout(()=>c9gOpen(),260)};
  P.querySelector('[data-a="later"]').onclick=()=>c9wLater();
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1})}
function c9wLater(){const S=$('c9w');if(!S)return;if(S.classList.contains('on'))hap('soft','ふわっ(あとで)',{norip:1});C9.log.push('later');S.classList.remove('on');S.setAttribute('aria-hidden','true')}

/* ホームで 置く ガイド:アプリの 中に かいた 動く 絵(iOS は アプリから ホームへ いけない) */
const C9S=[
  {t:'下から 上へ スワイプ',d:'ホーム画面に 出ます。',ms:2200},
  {t:'空いている 所を 長押し',d:'アイコンの ない 所を 1秒 ほど。',ms:2200},
  {t:'左上の「+」を 押す',d:'アイコンが ゆれていれば OK。',ms:1800},
  {t:'「Lattag」を さがす',d:'検索欄に Lattag。',ms:2400},
  {t:'「ウィジェットを 追加」',d:'ホームに のります。',ms:2600}];
function c9gIcons(){return Array.from({length:20},(_,i)=>`<i class="c9ic${i===10?' lt':''}" style="--j:${(i*37)%9}"></i>`).join('')}
function c9gOpen(){const G=$('c9g');if(!G)return;const w=C9W.find(x=>x.k===C9.pick);C9.done=0;
  G.innerHTML=`<div class="c9gw"></div><div class="c9gi" id="c9gi">${c9gIcons()}</div>
    <i class="c9gpr" id="c9gpr"></i><button class="c9gpl" tabindex="-1" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></button>
    <div class="c9gsw" id="c9gsw"><b></b><i></i></div>
    <div class="c9gsh" id="c9gsh"><i class="grab"></i><div class="c9gse"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg><span id="c9gq"></span></div><div class="c9gcd"><small>Lattag</small>${c9Tile(w.k)}<span class="c9gnm">${w.n}</span><button class="c9gad" id="c9gad" tabindex="-1">ウィジェットを 追加</button></div></div>
    <div class="c9gwg" id="c9gwg">${c9Tile(w.k)}</div>
    <div class="c9gt" role="status" aria-live="polite"><em id="c9gn">1 / 5</em><b id="c9gtt"></b><small id="c9gtd"></small><div class="c9gd">${C9S.map(()=>'<i></i>').join('')}</div></div>
    <div class="c9gb"><button class="c9gbk" data-a="back">Lattag に もどる</button><button class="c9gre" data-a="again">もういちど</button></div>`;
  G.querySelector('[data-a="back"]').onclick=()=>c9gBack();G.querySelector('[data-a="again"]').onclick=()=>{hap('tick',null,{norip:1});c9gPlay(0)};
  G.classList.add('on');G.setAttribute('aria-hidden','false');G.dataset.s='-1';hap('soft','ふわっ(ホームへ)',{norip:1});c9gPlay(0)}
function c9gPlay(i){C9.t.forEach(clearTimeout);C9.t=[];const G=$('c9g');if(!G||!G.classList.contains('on'))return;
  if(C9RM()){c9gSet(i);return}
  const run=k=>{c9gSet(k);if(k<C9S.length-1)C9.t.push(setTimeout(()=>run(k+1),C9S[k].ms));else C9.t.push(setTimeout(()=>{C9.done=1},C9S[k].ms*.5))};run(i)}
function c9gSet(k){const G=$('c9g');if(!G)return;G.dataset.s=k;const s=C9S[k];$('c9gn').textContent=(k+1)+' / '+C9S.length;$('c9gtt').textContent=s.t;$('c9gtd').textContent=s.d;
  G.querySelectorAll('.c9gd i').forEach((d,j)=>d.classList.toggle('on',j<=k));
  if(k===3){const q=$('c9gq');q.textContent='';[...'Lattag'].forEach((c,j)=>C9.t.push(setTimeout(()=>{q.textContent+=c;hap('tick',null,{norip:1})},300+j*110)))}
  if(k===1)C9.t.push(setTimeout(()=>hap('thud','ブルッ(長押し)',{norip:1}),1000));
  if(k===4)C9.t.push(setTimeout(()=>{hap('success','トトトン(おいた)',{norip:1});C9.done=1},1500))}
function c9gBack(){const G=$('c9g');if(!G||!G.classList.contains('on'))return;C9.t.forEach(clearTimeout);C9.t=[];const done=C9.done||+G.dataset.s>=4;
  hap('click','カチッ(もどる)');G.classList.remove('on');G.setAttribute('aria-hidden','true');C9.log.push('back:'+(done?'placed':'none'));
  setTimeout(()=>c9Detect(done),420)}
/* 実機:scenePhase が active に なった とき WidgetCenter.getCurrentConfigurations() で たしかめる */
function c9Detect(placed){if(placed){hap('success','トトトン(置けた)',{norip:1});try{toast('ウィジェットを 置けました')}catch(e){}}
  else{hap('soft','ふわっ(まだ)',{norip:1});try{toast('あとで 設定 › ウィジェット から できます')}catch(e){}}}

/* ================= デモ ================= */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-c9]'))return;
  [...C.querySelectorAll('[data-a9]')].forEach(b=>{if(b.dataset.a9!=='wb')b.remove()});
  C.insertAdjacentHTML('beforeend',['in:サインイン(Apple だけ)','cancel:Apple とじた','fail:Apple できない','id:ID シート','inv:招待シート','wgt:ウィジェット(えらぶ)','wgh:ウィジェット(ホームで 置く)'].map(s=>{const[k,l]=s.split(':');return `<button data-c9="${k}">${l}</button>`}).join(''));
  C.querySelectorAll('[data-c9]').forEach(b=>b.onclick=()=>c9Demo(b.dataset.c9))})();
function c9Demo(k){const go=()=>{try{obIntroEnd()}catch(e){}
    if(k==='in'||k==='cancel'||k==='fail'){C9.cancel=k==='cancel'?1:0;C9.fail=k==='fail'?1:0;obStep('in');if(k!=='in')setTimeout(()=>{const b=document.querySelector('#ob [data-a="apple"]');b&&b.click()},700)}};
  if(k==='id'){try{closeOb()}catch(e){}k9IdOpen();return}
  if(k==='inv'){j9InvOpen();return}
  if(k==='wgt'){c9wOpen('tour');return}
  if(k==='wgh'){c9wBuild();c9gOpen();return}
  if(!OB.on){try{[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='ob').click()}catch(e){}setTimeout(go,900)}else go()}
window.__kit=Object.assign(window.__kit||{},{c9:k=>c9Demo(k),c9w:f=>c9wOpen(f),c9g:p=>{if(p)C9.pick=p;c9wBuild();c9gOpen()},c9gs:k=>c9gSet(k),c9gb:()=>c9gBack(),C9:()=>({st:OB.st,on:OB.on,hm:C9.hm,pick:C9.pick,done:C9.done,log:C9.log.slice()})});
