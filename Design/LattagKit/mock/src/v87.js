/* ===== v87(モック v90 ・ PROMPT v95) =====
   1. はじめての 設定:キーボードが 出ても かさならない(上を 小さく)・ タグの シールの 位置
   2. 招待されて 来ましたか?:リンク ・ Trip の コード ・ @ID
   3. はじめての 説明(5つの ステップ ・ スポットライト + カード)
   4. QR を 読む:わくを まんなかへ ・ 下に 3つ
   5. Trip:写真を 設定(ライブラリから)
   6. Home 横スライド:Friends ページ(作りなおし)
   7. Home まんなか:いま やる こと(NEXT の カプセル)
   8. Home 下:Friends カードを 上へ ・ 4つの ボタンは 別々の 動き
   9. Mondo の Explore を 直す ・ Mondo(ない 日)を 作りなおし ・ Friends タブ(はじめて)を レベルアップ */
const J9={tour:0,next:0,inv:null};
const J9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const J9I={
  go:'<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>',
  share:'<svg viewBox="0 0 24 24"><path d="M12 3v12M7 8l5-5 5 5"/><path d="M5 13v5a2 2 0 002 2h10a2 2 0 002-2v-5"/></svg>',
  paste:'<svg viewBox="0 0 24 24"><rect x="6" y="4" width="12" height="17" rx="2.5"/><path d="M9 4.5V3h6v1.5"/><path d="M9.5 11h5M9.5 15h5"/></svg>',
  ticket:'<svg viewBox="0 0 24 24"><path d="M4 7a2 2 0 012-2h12a2 2 0 012 2v2a2 2 0 000 4v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2a2 2 0 000-4z"/><path d="M14 6v12" stroke-dasharray="2 2"/></svg>',
  at:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M16 8v5a2.5 2.5 0 005 0v-1a9 9 0 10-3.5 7.1"/></svg>',
  bolt:'<svg viewBox="0 0 24 24"><path d="M13 3L5 14h6l-1 7 8-11h-6z"/></svg>',
  hand:'<svg viewBox="0 0 24 24"><path d="M8 12V6a1.5 1.5 0 013 0v5M11 11V4.5a1.5 1.5 0 013 0V11M14 11V6a1.5 1.5 0 013 0v7c0 4-2.5 7-6 7-2.6 0-4-1.400-5.5-3.5L4 13.5a1.5 1.5 0 012.4-1.800L8 13.5"/></svg>',
  moon:'<svg viewBox="0 0 24 24"><path d="M19 14.5A7.5 7.5 0 019.5 5a7.5 7.5 0 109.5 9.5z"/></svg>',
  sun:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/></svg>',
  globe:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.6 3.5 5.6 3.5 8.5s-.9 5.9-3.5 8.5c-2.6-2.6-3.5-5.6-3.5-8.5s.9-5.9 3.5-8.5z"/></svg>',
  img:'<svg viewBox="0 0 24 24"><rect x="4" y="5" width="16" height="14" rx="2.5"/><circle cx="9.5" cy="10" r="1.6"/><path d="M5 17l4.5-4 3 2.5 3-3L19 16"/></svg>'};
const j9Bump=e=>{if(!e||J9RM())return;e.animate([{transform:'scale(1)'},{transform:'scale(.92)'},{transform:'scale(1.04)'},{transform:'scale(1)'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'})};
const j9Cd=(h)=>{const d=new Date(),t=new Date(d);t.setHours(h,0,0,0);if(t<=d)t.setDate(t.getDate()+1);const s=Math.floor((t-d)/1000);return [Math.floor(s/3600),Math.floor(s%3600/60),s%60]};
const j9Shareme=()=>{try{const m=fMe();openShare({t:`Lattag で つながろう ・ ${m.n}(@${K9.id})\nhttps://lattag.app/u/${K9.id}`,h:m.n})}catch(e){}};
const j9Find=()=>{try{openFriend()}catch(e){}setTimeout(()=>{const i=$('k9in');i&&i.focus({preventScroll:true})},460)};

/* ================= 1. はじめての 設定 ・ キーボード ================= */
function j9Kbd(kind){const kana=['あかさ','たなは','まやら','、わ゛'],en=['qwertyuiop','asdfghjkl','zxcvbnm'];
  return kind==='en'?`<div class="j9kbd en">${en.map(r=>`<div>${[...r].map(c=>`<i>${c}</i>`).join('')}</div>`).join('')}<div class="j9kr"><i class="w">123</i><i class="sp"></i><i class="ok">✓</i></div></div>`
    :`<div class="j9kbd ja">${kana.map(r=>`<div><i class="s">→</i>${[...r].map(c=>`<i>${c}</i>`).join('')}<i class="s">⌫</i></div>`).join('')}</div>`}
function j9KbOn(on){const O=$('ob');if(!O)return;O.classList.toggle('j9kb',!!on);let K=O.querySelector('.j9kbw');
  if(on){const kind=OB.st==='id'?'en':'ja';if(!K){O.insertAdjacentHTML('beforeend','<div class="j9kbw"></div>');K=O.querySelector('.j9kbw')}K.innerHTML=j9Kbd(kind)}else if(K)K.remove()}
$('ob')&&$('ob').addEventListener('focusin',e=>{if(e.target.matches('input')&&['name','id'].includes(OB.st))j9KbOn(true)});
$('ob')&&$('ob').addEventListener('focusout',()=>setTimeout(()=>{const a=document.activeElement;if(!a||!a.closest||!a.closest('#ob')||a.tagName!=='INPUT')j9KbOn(false)},80));
{const _s=obStep;obStep=function(st,dir){j9KbOn(false);return _s(st,dir)}}

/* ================= 2. 招待されて 来ましたか? ================= */
function j9InvOpen(){let S=$('j9iv');if(!S){$('phone').insertAdjacentHTML('beforeend','<div class="j9iv" id="j9iv" aria-hidden="true"><i class="j9ivc"></i><div class="j9ivp" role="dialog" aria-label="招待"></div></div>');S=$('j9iv');S.querySelector('.j9ivc').onclick=()=>j9InvClose()}
  const P=S.querySelector('.j9ivp');J9.inv=null;
  P.innerHTML=`<i class="grab"></i><h2>招待されて、来ましたか?</h2><p class="j9ivs">友だち か Trip に すぐ 入れます</p>
    <div class="j9op" data-k="link"><button class="j9oph" data-t="link"><i>${J9I.paste}</i><span><b>招待リンクを 貼りつける</b><small>LINE などで もらった リンク</small></span><em>${J9I.go}</em></button>
      <div class="j9opb"><button class="j9pst" data-a="paste">${J9I.paste}ペースト</button><div class="j9hit" hidden></div></div></div>
    <div class="j9op" data-k="trip"><button class="j9oph" data-t="trip"><i>${J9I.ticket}</i><span><b>Trip の コード</b><small>6文字 ・ パスの 下に ある</small></span><em>${J9I.go}</em></button>
      <div class="j9opb"><label class="j9otp">${[0,1,2,3,4,5].map(i=>`<span data-i="${i}"></span>`).join('')}<input id="j9code" maxlength="6" autocomplete="one-time-code" autocapitalize="characters" spellcheck="false" aria-label="Trip の コード"></label><div class="j9hit" hidden></div></div></div>
    <div class="j9op" data-k="id"><button class="j9oph" data-t="id"><i>${J9I.at}</i><span><b>友だちの @ID</b><small>ID を 知って いる</small></span><em>${J9I.go}</em></button>
      <div class="j9opb"><label class="k9idf j9idq"><span class="at">@</span><input id="j9idq" placeholder="friend_id" autocomplete="off" autocapitalize="off" spellcheck="false"></label><div class="j9hit" hidden></div></div></div>
    <button class="j9no" data-a="no">ちがいます ・ このまま はじめる</button>`;
  P.querySelectorAll('.j9oph').forEach(b=>b.onclick=()=>{const k=b.dataset.t;P.querySelectorAll('.j9op').forEach(o=>o.classList.toggle('on',o.dataset.k===k&&!o.classList.contains('on')));hap('sel','コツッ(ひらく)',{norip:1});
    if(k==='trip')setTimeout(()=>$('j9code')&&$('j9code').focus({preventScroll:true}),260);if(k==='id')setTimeout(()=>$('j9idq')&&$('j9idq').focus({preventScroll:true}),260)});
  const hit=(k,html)=>{const H=P.querySelector(`.j9op[data-k="${k}"] .j9hit`);H.hidden=false;H.innerHTML=html;!J9RM()&&H.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:320,easing:'cubic-bezier(.3,1.3,.5,1)'});H.querySelectorAll('[data-a="join"]').forEach(b=>b.onclick=()=>{hap('success','トトトン(入った)');j9InvClose();try{_toast(b.dataset.m)}catch(e){}})};
  P.querySelector('[data-a="paste"]').onclick=e=>{j9Bump(e.currentTarget);hap('click','カチッ(ペースト)');const f=FPOOL[0];hit('link',`<div class="j9hc">${k9Av(f)}<span><b>${f.n} の 招待</b><small>lattag.app/u/${FID(f).slice(1)}</small></span><button data-a="join" data-m="${f.n} に 申請しました">友だちに なる</button></div>`)};
  const C=$('j9code');C.oninput=()=>{const v=C.value.toUpperCase().replace(/[^A-Z0-9]/g,'').slice(0,6);C.value=v;P.querySelectorAll('.j9otp span').forEach((s,i)=>{s.textContent=v[i]||'';s.classList.toggle('on',i===v.length)});hap('tick',null,{norip:1});
    if(v.length===6)hit('trip',`<div class="j9tp"><i style="background-image:url(${PH.c})"></i><span><small>TRIP PASS</small><b>京都 2泊3日</b><em>11/18 → 11/20 ・ 3人</em></span><button data-a="join" data-m="Trip「京都 2泊3日」に 入りました">入る</button></div>`)};
  const Q=$('j9idq');Q.oninput=()=>{const q=k9Norm(Q.value);const o=k9F().find(x=>x.id===q);if(o)hit('id',`<div class="j9hc">${k9Av(o.f)}<span><b>${o.f.n}</b><small>@${o.id}</small></span><button data-a="join" data-m="${o.f.n} に 申請しました">申請</button></div>`);else{const H=P.querySelector('.j9op[data-k="id"] .j9hit');H.hidden=q.length<3;H.innerHTML='<p class="j9nf">ぴったりの ID が 出ます</p>'}};
  P.querySelector('[data-a="no"]').onclick=()=>{hap('soft');j9InvClose();setTimeout(()=>j9Tour(0),420)};
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(シート)',{norip:1})}
function j9InvClose(){const S=$('j9iv');if(!S)return;S.classList.remove('on');S.setAttribute('aria-hidden','true')}

/* ================= 3. はじめての 説明(ツアー)================= */
const J9T=[
  {t:'#hmoon',y:-40,h:'1日 3こま、撮る',b:'ここを 押して 撮影へ。シャッターは 長押し。',k:'TODAY',ic:'cam'},
  {t:'#hst',h:'24:00 で 消灯',b:'それまでに 撮る。のこりの こまは 右の 3本。',k:'LIGHTS OUT'},
  {t:'#lens',h:'撮った 写真は 現像中',b:'すぐには 見られない。あしたの 9:00 まで ねかせる。',k:'DEVELOP'},
  {t:'#hpi',h:'9:00 に 友だちと ひらく',b:'Friends ・ Trip ・ Mondo は 横に スワイプ。',k:'9:00'},
  {t:'#hhd .av',h:'あなたの アイコン',b:'1回 タップ = プロフィール ・ 2回 = きのう。',k:'YOU'}];
function j9Tour(i){const P=$('phone');let L=$('j9tl');if(i===0&&!L){P.insertAdjacentHTML('beforeend',`<div class="j9tl" id="j9tl"><i class="j9sp" id="j9sp"></i><div class="j9tc" id="j9tc"></div></div>`);L=$('j9tl')}
  if(!L)return;if(i>=J9T.length){j9TourEnd();return}J9.tour=i;try{cmHide()}catch(e){}
  const s=J9T[i],el=document.querySelector(s.t),pr=P.getBoundingClientRect();if(!el){j9Tour(i+1);return}
  const r=el.getBoundingClientRect(),k=pr.width/390,x=(r.left-pr.left)/k,y=(r.top-pr.top)/k,w=r.width/k,h=r.height/k,pad=10;
  let sx=x-pad,sy=y-pad,sw=w+pad*2,sh=h+pad*2;if(s.t==='#hmoon'){sx=22;sy=726;sw=346;sh=98}if(s.t==='#lens'){sx=x-6;sy=y-6;sw=w+12;sh=h+12}
  const S=$('j9sp');S.style.cssText=`left:${sx}px;top:${sy}px;width:${sw}px;height:${sh}px;border-radius:${Math.min(sh/2,s.t==='#lens'?sw/2:30)}px`;
  const C=$('j9tc'),below=sy+sh<430;C.className='j9tc '+(below?'bl':'ab');C.style.top=below?(sy+sh+16)+'px':'';C.style.bottom=below?'':(844-sy+16)+'px';
  C.innerHTML=`<div class="j9pg">${J9T.map((_,j)=>`<i class="${j<i?'d':j===i?'on':''}"></i>`).join('')}</div>
    <small>${String(i+1).padStart(2,'0')} / ${String(J9T.length).padStart(2,'0')} ・ ${s.k}</small><b>${s.h}</b><p>${s.b}</p>
    <div class="j9tb"><button data-a="skip">スキップ</button><button class="nx" data-a="nx">${i===J9T.length-1?'はじめる':'つぎへ'}${J9I.go}</button></div>`;
  L.classList.add('on');hap(i?'sel':'pop',i?'コツッ(つぎ)':'ぷにっ(説明)',{norip:1});
  if(!J9RM())C.animate([{opacity:0,transform:`translateY(${below?-10:10}px) scale(.97)`},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.3,.5,1)'});
  C.querySelector('[data-a="nx"]').onclick=()=>j9Tour(i+1);C.querySelector('[data-a="skip"]').onclick=()=>{hap('soft');j9TourEnd()};
  L.onclick=e=>{if(e.target===L)j9Tour(i+1)}}
function j9TourEnd(){const L=$('j9tl');if(!L)return;L.classList.remove('on');hap('success','トトトン(はじめよう)',{norip:1});setTimeout(()=>L.remove(),320)}
{const _c=cmShow;cmShow=function(d){if(d&&d.k==='first'&&!J9.tourDone){J9.tourDone=1;CMS.add('first');setTimeout(()=>j9Tour(0),200);return}return _c(d)}}

/* ================= 4. QR を 読む:配置を 直す ================= */
{const _k=k9Scan;k9Scan=function(){_k();const Q=$('qrs');if(!Q)return;Q.classList.add('j9q');const B=Q.querySelector('.k9bot');if(!B)return;
  B.innerHTML=`<button data-a="lib"><span>${J9I.img}</span><b>写真から</b></button><button data-a="me" class="me"><span class="j9mq">${tQR('@'+K9.id,44)}</span><b>自分の QR</b></button><button data-a="id"><span>${J9I.at}</span><b>@ID</b></button>`;
  B.insertAdjacentHTML('beforebegin',`<p class="j9qh">画面 でも 紙 でも 読めます ・ 暗い 時は ライト</p>`);
  const end=()=>{Q.classList.remove('on');Q.setAttribute('aria-hidden','true');clearTimeout(Q._t);clearTimeout(Q._t2);setTimeout(()=>{if(!Q.classList.contains('on'))Q.className='qrs'},320)};
  B.querySelector('[data-a="me"]').onclick=e=>{j9Bump(e.currentTarget);hap('pop','ぷにっ(自分の QR)');end();setTimeout(()=>{try{q9Open()}catch(_){}},260)};
  B.querySelector('[data-a="lib"]').onclick=e=>{j9Bump(e.currentTarget);hap('click');try{_toast('(モック)写真から QR を 読みます')}catch(_){}};
  B.querySelector('[data-a="id"]').onclick=e=>{j9Bump(e.currentTarget);hap('pop');end();setTimeout(j9Find,260)}}}

/* ================= 5. Trip:写真を 設定 ================= */
TW8Q[3]='写真を 設定';
const J9LIB=['c','a','e','b','d','f','c','a'];
{const _s=tw8StepHtml;tw8StepHtml=function(){const s=TW77.s,g=TW77.g;if(s!==3)return _s();const base=_s(),i=base.indexOf('<div class="tw8sm">');
  const sum=i>=0?base.slice(i):'';
  return `<p class="j9cvs">Trip の 表紙に なる 1枚。あとで 変えられる</p>
    <div class="j9cv"><button class="j9lib" data-j9="lib"><i>${J9I.img}</i><b>ライブラリから えらぶ</b><small>写真 アプリ の 中から</small></button>
      <div class="j9cvp" style="background-image:url(${PH[g.cover]})"><span>いまの 表紙</span><u>ドラッグで 位置</u></div></div>
    <div class="j9rch"><b>最近の 写真</b><small>ライブラリ</small></div>
    <div class="j9gr">${J9LIB.map((p,j)=>`<button data-p="${p}" data-j="${j}" class="${g.cover===p&&(g.cj??0)===j?'on':''}" style="background-image:url(${PH[p]})"><u>${TW8I.ok}</u></button>`).join('')}</div>${sum}`}}
{const _d=tw77Draw;tw77Draw=function(dir){_d(dir);try{const W=$('tw77');if(!W||TW77.s!==3)return;
  W.querySelectorAll('.j9gr [data-p]').forEach(b=>b.addEventListener('click',()=>{TW77.g.cj=+b.dataset.j},true));
  const L=W.querySelector('[data-j9="lib"]');L&&(L.onclick=()=>{j9Bump(L);hap('pop','ぷにっ(ライブラリ)');try{_toast('(モック)写真 ライブラリが ひらく → 1枚 えらぶ')}catch(e){}
    setTimeout(()=>{const n=['b','d','f'][Math.floor(Math.random()*3)];TW77.g.cover=n;TW77.g.cj=-1;tw77Draw();hap('success','トトトン(表紙)',{norip:1})},700)})}catch(e){console.error(e)}}}

/* ================= 6. Home 横スライド:Friends ページ ================= */
function j9Ring(k){const seg=[0,1,2].map(j=>{const a0=-90+j*120+6,a1=a0+108,r=35,P=a=>[40+r*Math.cos(a*Math.PI/180),40+r*Math.sin(a*Math.PI/180)].map(v=>v.toFixed(1));const[p,q]=[P(a0),P(a1)];return `<path d="M${p[0]} ${p[1]}A${r} ${r} 0 0 1 ${q[0]} ${q[1]}" class="${j<k?'on':''}"/>`}).join('');return `<svg class="j9rg" viewBox="0 0 80 80">${seg}</svg>`}
function j9FrPage(){const took=FR.filter(f=>f.k>0),V=FR.slice().sort((a,b)=>b.k-a.k).slice(0,7),RQ=REQ||[];
  if(!FR.length){const sg=k9Sugs().slice(0,3);
    return `<div class="j9fp0 hpe"><div class="j9orb">${[0,1,2].map(j=>`<span class="j9sat s${j}">${sg[j]?`<i style="background:${avBg(sg[j].f)}">${sg[j].f.n[0]}</i>`:'<i>+</i>'}</span>`).join('')}<span class="j9meav" style="background-image:${(()=>{try{return avUrl()}catch(e){return 'none'}})()}"></span><i class="j9oc"></i><i class="j9oc o2"></i></div>
      <b class="j9fpt">友だちと、毎朝 9:00 に<br>きのうを 見せあう</b></div>
      <div class="j9fpa hpe"><button data-j9="qr">${X8I.qr}<span>QR</span></button><button data-j9="scan">${X8I.scan}<span>読む</span></button><button data-j9="id">${J9I.at}<span>@ID</span></button><button data-j9="link">${J9I.share}<span>リンク</span></button></div>
      ${RQ.length?`<button class="j9rq hpe" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>申請</small><em>承認 ›</em></button>`:''}`}
  return `<div class="j9fpr hpe">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}<button class="j9fa ad" data-j9="add"><span class="j9fav"><i>+</i></span><b>よぶ</b><small>&nbsp;</small></button></div>
    <div class="j9fps hpe"><div><b>${took.length}<small>/${FR.length}</small></b><span>撮った</span></div><div><b>${FR.length-took.length}</b><span>まだ ・ つつける</span></div><div><b>9:00</b><span>ひらく</span></div></div>
    ${RQ.length?`<button class="j9rq hpe" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>申請</small><em>承認 ›</em></button>`:''}`}
{const _hr=hpRender;hpRender=function(only){_hr(only);try{if(only&&only!==1)return;const C=$('hpc1');if(!C)return;const took=FR.filter(f=>f.k>0).length;
  C.className='hpc pf j9fp';C.innerHTML=hpHead(1,'friends',took?`<span class="j9live"><i></i>${took}人 撮った</span>`:(FR.length?'':'0 FRIENDS'))+j9FrPage()+hpGoBtn('Friends を ひらく');
  C.querySelector('[data-a="go"]').onclick=()=>{hap('pop','ぷにっ(Friends)');try{openY();setTimeout(()=>{Y72.tab='f';y72Render()},380)}catch(e){openFriend()}};
  j9Acts(C)}catch(e){console.error(e)}};window.hpRender=hpRender}
function j9Acts(C){C.querySelectorAll('[data-j9]').forEach(b=>b.onclick=e=>{e.stopPropagation();const k=b.dataset.j9;j9Bump(b);
    if(k==='qr'){hap('pop','ぷにっ(QR)');try{q9Open()}catch(_){}}else if(k==='scan'){try{openScan('fr')}catch(_){}}else if(k==='id'||k==='add'||k==='req'){hap('pop');j9Find()}else if(k==='link'){hap('pop','ぷにっ(リンク)');j9Shareme()}});
  C.querySelectorAll('[data-fi]').forEach(b=>b.onclick=e=>{e.stopPropagation();const i=+b.dataset.fi,f=FR[i];if(e.target.closest('s')){try{fPoke2(i,b)}catch(_){}return}hap('sel');try{openFC(f,b)}catch(_){}})}

/* ================= 7. Home まんなか:いま やる こと ================= */
function j9Sugg(){const L=[],RQ=REQ||[],nof=FR.filter(f=>f.k===0);const[lh,lm]=j9Cd(24);
  if(shots===0)L.push({ic:X8I.cam,t:'最初の 1枚を 撮ろう',s:`消灯まで ${lh}:${String(lm).padStart(2,'0')}`,a:'shoot'});
  if(RQ.length)L.push({ic:J9I.at,t:`${RQ[0].f.n} から 申請`,s:'承認すると 9:00 に 見せあえる',a:'req',hot:1});
  if(!FR.length)L.push({ic:J9I.share,t:'友だちを よぼう',s:'QR ・ リンク ・ @ID',a:'find'});
  if(shots>0&&shots<3)L.push({ic:X8I.cam,t:`のこり ${3-shots}こま`,s:`消灯まで ${lh}:${String(lm).padStart(2,'0')}`,a:'shoot'});
  if(FR.length&&nof.length)L.push({ic:J9I.hand,t:`${nof[0].n} が まだ 撮って いない`,s:'つついて 知らせる',a:'poke'});
  if(shots>=3)L.push({ic:J9I.moon,t:'今日は ここまで',s:'あした 9:00 に 友だちと ひらく',a:'live'});
  if(shots>0)L.push({ic:J9I.sun,t:'現像中 ・ のぞいて みる',s:'9:00 まで 少しずつ 濃く なる',a:'dev'});
  return L}
function j9Next(){const H=document.querySelector('.hsl[data-i="0"] .hsi');if(!H)return;let N=$('j9nx');
  if(!N){H.insertAdjacentHTML('beforeend','<div class="j9nx" id="j9nx" role="button" tabindex="0" aria-label="いま やる こと"></div>');N=$('j9nx');
    let x0=null;N.addEventListener('pointerdown',e=>{e.stopPropagation();x0=e.clientX});N.addEventListener('pointerup',e=>{e.stopPropagation();if(x0!==null&&Math.abs(e.clientX-x0)>24){J9.next++;j9NxDraw(e.clientX<x0?1:-1);hap('sel',null,{norip:1})}else j9NxGo();x0=null});
    N.addEventListener('click',e=>e.stopPropagation())}
  j9NxDraw(0)}
function j9NxDraw(dir){const N=$('j9nx');if(!N)return;const L=j9Sugg();if(!L.length){N.hidden=true;return}N.hidden=false;const i=((J9.next%L.length)+L.length)%L.length,s=L[i];
  N.className='j9nx'+(s.hot?' hot':'');N.dataset.a=s.a;
  N.innerHTML=`<span class="ic">${s.ic}</span><span class="tx"><small>NEXT${L.length>1?` ・ ${i+1}/${L.length}`:''}</small><b>${s.t}</b><em>${s.s}</em></span><span class="ar">${J9I.go}</span>${L.length>1?`<span class="dt">${L.map((_,j)=>`<i class="${j===i?'on':''}"></i>`).join('')}</span>`:''}`;
  if(dir&&!J9RM())N.querySelector('.tx').animate([{opacity:0,transform:`translateX(${dir*18}px)`},{opacity:1,transform:'none'}],{duration:300,easing:'cubic-bezier(.3,1.2,.5,1)'})}
function j9NxGo(){const N=$('j9nx');if(!N)return;const a=N.dataset.a;j9Bump(N);hap('pop','ぷにっ(NEXT)');
  if(a==='shoot'){try{ORB.A.shoot.run()}catch(e){try{goShoot()}catch(_){}}}else if(a==='find'||a==='req')j9Find();else if(a==='poke'){const i=FR.findIndex(f=>f.k===0);try{fPoke2(i,N)}catch(_){}}
  else if(a==='live')openLive($('hst'));else if(a==='dev'){try{openDvx(Math.max(0,shots-1))}catch(_){}}}
setInterval(()=>{const N=$('j9nx');if(!N||N.hidden||document.hidden)return;const H=$('home');if(!H||!H.classList.contains('on'))return;if(j9Sugg().length>1&&!J9RM()){J9.next++;j9NxDraw(1)}},5200);
{const _r=renderHome;renderHome=function(a){_r(a);try{j9Next()}catch(e){console.error(e)}}}
try{j9Next()}catch(e){}

/* ================= 8. Home 下:Friends カードを 上へ ・ 4つの ボタン ================= */
arcFriends=function(ni){const B=$('afc');if(!B)return;const A=$('arc');if(A&&A.firstElementChild!==B){A.insertBefore(B,A.firstElementChild)}
  const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';B.className='afc j9af';
  const RQ=REQ||[],V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  let h=`<div class="j9afh" data-j9="open"><b>Friends</b>${took?`<span class="j9live"><i></i>${took}人 撮った</span>`:`<small>${FR.length?'きょうは まだ':'つながると 毎朝 9:00 に 見せあえる'}</small>`}<button class="go" aria-label="Friends を ひらく">${J9I.go}</button></div>`;
  if(FR.length)h+=`<div class="j9fpr j9afr">${V.map(f=>{const i=FR.indexOf(f);return `<button class="j9fa${f.k?' k':''}" data-fi="${i}"><span class="j9fav">${j9Ring(f.k)}<i style="background-image:url(${fPic(f)})"></i>${f.k===0?`<s>${J9I.hand}</s>`:''}</span><b>${f.n}</b><small>${f.k?f.k+' / 3':'まだ'}</small></button>`}).join('')}</div>`;
  if(RQ.length)h+=`<button class="j9rq" data-j9="req"><span class="k9mav">${RQ.slice(0,3).map(r=>`<i style="background:${avBg(r.f)}">${r.f.n[0]}</i>`).join('')}</span><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small><em>確認 ›</em></button>`;
  h+=`<div class="j9bt"><button class="b1" data-j9="link"><i>${J9I.share}</i><b>リンクを 送る</b><small>LINE ・ AirDrop</small></button>
      <button class="b2" data-j9="qr"><span class="j9bq">${tQR('@'+K9.id,40)}</span><b>QR を 見せる</b></button>
      <button class="b3" data-j9="scan"><i>${X8I.scan}</i><b>QR を 読む</b></button>
      <button class="b4" data-j9="id">${K9I.mag}<span>名前 か @ID で さがす</span></button></div>`;
  B.innerHTML=h;j9Acts(B);B.querySelectorAll('[data-j9="open"]').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(Friends)');openFriend()});
  if(!J9RM()&&!B._j9){B._j9=1;B.querySelectorAll('.j9bt>button').forEach((c,j)=>c.animate([{opacity:0,transform:'translateY(14px) scale(.96)'},{opacity:1,transform:'none'}],{duration:480,delay:120+j*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}};
try{arcFriends()}catch(e){}

/* ================= 9. Mondo:Explore ・ ない 日 ・ Friends タブ ================= */
{const _oa=orbActs;orbActs=function(){const R=_oa();if(R.A.mondo)R.A.mondo.run=()=>{hap('pop','ぷにっ(Mondo)');try{openY()}catch(e){}setTimeout(()=>{Y72.tab='m';Y72.anim=1;y72Render();const s=document.querySelector('#yst .y72 .zsc');s&&(s.scrollTop=0)},420);return true};return R}}
{const _hr=hpRender;hpRender=function(only){_hr(only);try{if(only&&only!==3)return;const C=$('hpc3');const b=C&&C.querySelector('[data-a="go"]');if(b)b.onclick=()=>{try{ORB.A.mondo.run()}catch(e){}}}catch(e){}};window.hpRender=hpRender}
const J9CT=[['TOKYO',9],['SEOUL',9],['SYDNEY',10],['BANGKOK',7],['DUBAI',4],['PARIS',1],['LONDON',0],['NEW YORK',-5],['LA',-8]];
function j9Relay(){const u=new Date(),uh=u.getUTCHours()+u.getUTCMinutes()/60;return J9CT.map(([n,o])=>{let l=(uh+o+24)%24,d=(9-l+24)%24;return{n,d}}).sort((a,b)=>a.d-b.d).slice(0,6)}
x8NoMondo=function(){const d=new Date(Date.now()-864e5),R=j9Relay();
  return `<section class="j9nm"><div class="j9gl"><svg viewBox="0 0 580 580">${Y72D}<g data-sp="night"></g><circle cx="290" cy="290" r="271" fill="url(#y72sh)"/></svg><i class="j9term"></i>
      ${[[38,30],[62,40],[30,58],[70,62],[50,74]].map(([x,y],j)=>`<i class="j9pin" style="left:${x}%;top:${y}%;--d:${j*.6}s"></i>`).join('')}<span class="j9glt"><small>${d.getMonth()+1}/${d.getDate()} ・ きのう</small><b>No Mondo</b><em>きのうは お題が 出ませんでした</em></span></div>
    <div class="j9cdw"><small>NEXT MONDO</small><b id="j9cd">--:--:--</b><i><u id="j9cb"></u></i><em>9:00 に 世界の きのうが ひらく</em></div>
    <div class="j9bn">
      <div class="j9b1"><small>今日の お題</small><b>#<span>？？？</span></b><em>${K9I.lock}9:00 に 発表</em></div>
      <div class="j9b2"><b>2,431</b><small>きのうの 枚数</small></div><div class="j9b3"><b>128</b><small>都市</small></div>
      <div class="j9b4"><small>9:00 リレー ・ 次に ひらく 街</small><div class="j9rl"><div>${R.concat(R).map(c=>`<span><i></i>${c.n}<em>${c.d<.02?'NOW':`${Math.floor(c.d)}h ${String(Math.round(c.d%1*60)).padStart(2,'0')}m`}</em></span>`).join('')}</div></div></div></div>
    <div class="j9how"><span><i>1</i>撮る</span><u></u><span><i>2</i>お題の タグを つける</span><u></u><span><i>3</i>世界と ならぶ</span></div>
    <div class="x8nb j9nmb"><button data-a="shoot">${X8I.cam}撮って 参加</button><button class="nf" data-a="nf" aria-label="9:00 に 知らせる">${X8I.bell}<span hidden></span></button></div></section>`};
setInterval(()=>{const e=$('j9cd');if(!e)return;const[h,m,s]=j9Cd(9);e.innerHTML=`${h}:${String(m).padStart(2,'0')}<span>:${String(s).padStart(2,'0')}</span>`;const b=$('j9cb');if(b)b.style.transform=`scaleX(${(1-(h*3600+m*60+s)/86400).toFixed(4)})`},1000);
/* Friends タブ(はじめて):上に「ストーリーの 列」+ 見本を 2つ */
{const _o=k9Own;k9Own=function(){const sg=k9Sugs().slice(0,4),av=(()=>{try{return avUrl()}catch(e){return 'none'}})();
  return `<div class="j9st"><button class="j9s me" data-a="shoot"><span style="background-image:${av}"><u>${X8I.cam}</u></span><b>あなた</b></button>${sg.map(o=>`<button class="j9s" data-u9="find"><span class="em" style="--g:${avBg(o.f)}"><i>${o.f.n[0]}</i></span><b>${o.f.n}</b></button>`).join('')}<button class="j9s ad" data-u9="find"><span class="em"><i>+</i></span><b>よぶ</b></button></div>`+_o()}}

window.__kit=Object.assign(window.__kit||{},{j9Inv:()=>j9InvOpen(),j9Tour:i=>j9Tour(i||0),j9Kb:st=>{OB.name=OB.name||'ゆい';obStep(st||'name');setTimeout(()=>{const i=document.querySelector('#ob input');i&&i.focus()},600)},j9Inv2:k=>{j9InvOpen();setTimeout(()=>{const b=document.querySelector(`.j9oph[data-t="${k}"]`);b&&b.click();setTimeout(()=>{if(k==='trip'){const c=$('j9code');c.value='K7Q2MP';c.oninput()}if(k==='link')document.querySelector('[data-a="paste"]').click();if(k==='id'){const q=$('j9idq');q.value=FID(FPOOL[3]).slice(1);q.oninput()}},380)},400)}});
