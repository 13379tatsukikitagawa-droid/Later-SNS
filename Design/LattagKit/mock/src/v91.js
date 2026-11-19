/* ===== v91(モック v91 ・ PROMPT v101):サインイン(Google ・ メールのリンク)の 状態 =====
   ・ メール:おくって いる 間 / 形の まちがい / おくれなかった(番号は DEBUG だけ)
   ・ おくった あと:もういちど おくる は 60秒 まつ ・ メールを まちがえた
   ・ リンクから もどって きた:はいって います → はじめて = Name へ / 前から いる 人 = おかえり → Home
   ・ ほかの 端末で ひらいた:メールアドレスを もう一度
   ・ リンクが 古い / もう 使った:あたらしい リンクを おくる
   ・ この メールは ほかの 方法で 登録 済み:その 方法で つづける
   ・ Google:えらぶ 画面を とじた = 何も 出さない(元に もどる だけ) */
const A9={left:0,iv:0,prov:'apple',err:''};
const A9I={warn:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M12 7.5v5.5M12 16.4v.1"/></svg>',
  mail:'<svg viewBox="0 0 24 24"><rect x="3.5" y="5.5" width="17" height="13" rx="2.5"/><path d="M4.5 7l7.5 6 7.5-6"/></svg>',
  clock:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/></svg>',
  dev:'<svg viewBox="0 0 24 24"><rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M11 18h2"/></svg>',
  key:'<svg viewBox="0 0 24 24"><circle cx="8" cy="12" r="3.5"/><path d="M11.5 12H20M17 12v3M20 12v2"/></svg>'};
OBMK.back=1;OBMK.ask=1;OBMK.old=1;OBMK.exists=1;OBMK.wb=0;
const a9Mail=()=>rmEsc(OB.mail||'you@example.com');
{const _t=obTpl;obTpl=function(st){
  if(st==='back')return[`<span class="obk2 a9k">SIGNING IN</span><div class="a9sp" aria-hidden="true"><i></i><b>#</b></div><h2 class="obh">はいって います</h2><p class="obsb">${a9Mail()}</p>`,``];
  if(st==='ask')return[`<span class="a9ic">${A9I.dev}</span><h2 class="obh">メールアドレスを<br>もう一度</h2><p class="obsb">ちがう 端末で リンクを ひらいた ため、<br>たしかめます</p><label class="obin sm"><input id="a9ask" type="email" inputmode="email" placeholder="you@example.com" autocomplete="email" enterkeyhint="go" aria-label="メールアドレス"></label>`,`<button class="ob1" id="a9askgo" disabled>はいる</button><button class="ob3" data-a="toin">ほかの 方法</button>`];
  if(st==='old')return[`<span class="a9ic">${A9I.clock}</span><h2 class="obh">リンクが<br>古く なりました</h2><p class="obsb">リンクは 1回 だけ、少しの 間 だけ 使えます</p>`,`<button class="ob1" data-a="a9new">あたらしい リンクを おくる</button><button class="ob3" data-a="toin">ほかの 方法</button>`];
  if(st==='exists'){const p=A9.prov==='google'?'Google':'Apple';return[`<span class="a9ic">${A9I.key}</span><h2 class="obh">${p} で<br>はいって いました</h2><p class="obsb">${a9Mail()} は ${p} で 登録 済み。<br>同じ 方法で つづけて ください</p>`,`<button class="ob1" data-a="${A9.prov}">${p} で つづける</button><button class="ob3" data-a="toin">ほかの 方法</button>`]}
  if(st==='wb')return[`<span class="obk2 a9k">WELCOME BACK</span><h2 class="obh">おかえり、<br><em>${rmEsc(OB.name||'ゆい')}</em>。</h2><p class="obsb">写真と なかまは、そのまま</p>`,``];
  const r=_t(st);
  if(st==='mail')r[0]+=`<p class="a9er" id="a9er" role="alert" hidden></p>`;
  if(st==='sent'){r[0]=r[0].replace('リンクを タップすると、もどってきます','リンクを タップすると、もどってきます<br><button class="a9fix" data-a="a9fix">アドレスを まちがえた</button>');r[1]=r[1].replace('<button class="ob3" data-a="resend">もういちど おくる</button>','<button class="ob3 a9rs" data-a="resend" id="a9rs">もういちど おくる</button>')}
  return r}}
{const _b=obBind;obBind=function(){_b();const st=OB.st;clearInterval(A9.iv);
  if(st==='mail'){const i0=$('obmail'),i=i0.cloneNode(true);i.value=i0.value;i0.replaceWith(i);const g=$('obmgo'),E=$('a9er');const ok=()=>/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(i.value.trim());
    const go=()=>{if(OB.busy)return;if(!ok()){a9Err('メールアドレスの 形を たしかめて ください');return}OB.mail=i.value.trim();i.blur();OB.busy=true;g.disabled=true;g.innerHTML='<i class="a9dot"></i>おくって います';hap('click','カチッ(おくる)');
      setTimeout(()=>{OB.busy=false;if(!OB.on)return;if(/@fail\./.test(OB.mail)){g.disabled=false;g.textContent='リンクを おくる';a9Err('おくれませんでした。少し まって、もう一度',A9.err||'auth/operation-not-allowed (17006)');hap('warn','やわらかく2回(おくれない)');return}obStep('sent')},900)};
    g.onclick=go;i.onkeydown=e=>{if(e.key==='Enter'){e.preventDefault();go()}};i.addEventListener('input',()=>{E.hidden=true;i.parentNode.classList.remove('a9bad');g.disabled=!ok()});i.addEventListener('focus',()=>setTimeout(()=>{$('ob').scrollTop=0},50));setTimeout(()=>{if(OB.on&&OB.st==='mail')i.focus({preventScroll:true})},420);
    i.addEventListener('blur',()=>{if(i.value.trim()&&!ok())a9Err('メールアドレスの 形を たしかめて ください')})}
  if(st==='sent'){a9Count(60)}
  if(st==='ask'){const i=$('a9ask'),g=$('a9askgo');const ok=()=>/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(i.value.trim());i.addEventListener('input',()=>g.disabled=!ok());
    g.onclick=()=>{if(!ok())return;OB.mail=i.value.trim();hap('click');obStep('back')};setTimeout(()=>{if(OB.on&&OB.st==='ask')i.focus({preventScroll:true})},420)}
  if(st==='back'){OB.busy=true;hap('projector','カタカタ(はいって いる)',{norip:1});setTimeout(()=>{OB.busy=false;if(!OB.on||OB.st!=='back')return;hap('success','トトトン(はいれた)',{norip:1});obStep(A9.ret?'wb':'name')},1500)}
  if(st==='wb'){hap('heart','ドクン(おかえり)',{norip:1});setTimeout(()=>{if(OB.on&&OB.st==='wb'&&!A9.hold){closeOb();try{toast('おかえりなさい')}catch(e){}}},1700)}}}
function a9Err(m,code){const E=$('a9er');if(!E)return;E.innerHTML=A9I.warn+'<span>'+m+(code?`<small>DEBUG ・ ${code}</small>`:'')+'</span>';E.hidden=false;const b=E.closest('#ob')&&E.closest('#ob').querySelector('.obin');b&&b.classList.add('a9bad');!obRM()&&E.animate([{transform:'translateX(-6px)'},{transform:'translateX(5px)'},{transform:'translateX(-3px)'},{transform:'none'}],{duration:320})}
function a9Count(n){A9.left=n;const B=$('a9rs');if(!B)return;const draw=()=>{B.disabled=A9.left>0;B.innerHTML=A9.left>0?`もういちど おくる <em>0:${String(A9.left).padStart(2,'0')}</em>`:'もういちど おくる'};draw();A9.iv=setInterval(()=>{A9.left--;draw();if(A9.left<=0)clearInterval(A9.iv)},1000)}
{const _a=obAct;obAct=function(a,b){
  if(a==='resend'){if(A9.left>0){hap('warn','やわらかく2回(まだ まつ)');return}hap('sel','コツッ(もういちど)');toast('もういちど おくりました');a9Count(60);return}
  if(a==='a9fix'){hap('tick');obStep('mail',-1);return}
  if(a==='a9new'){hap('click','カチッ(おくる)');obStep('sent');return}
  if(a==='google'&&A9.cancel){A9.cancel=0;OB.busy=true;const t=b.textContent;b.innerHTML='<i class="a9dot dk"></i>Google';setTimeout(()=>{OB.busy=false;b.textContent=t;hap('soft','ふわっ(とじた ・ 何も 出さない)',{norip:1})},900);return}
  return _a(a,b)}}
{const _k=$('obk').onclick;$('obk').onclick=()=>{const b={ask:'in',old:'in',exists:'in'}[OB.st];if(b){hap('tick');obStep(b,-1);return}if(OB.st==='back'||OB.st==='wb')return;_k&&_k()}}
/* デモ */
function a9Demo(st,o){A9.hold=!!(o&&o.hold);if(!OB.on){try{[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='ob').click()}catch(e){}}
  setTimeout(()=>{try{obIntroEnd()}catch(e){}OB.mail=OB.mail||'yui@example.com';A9.ret=st==='wb';if(st==='wb'){OB.name='ゆい';st='back'}
    if(st==='fail'){OB.mail='yui@fail.test';obStep('mail');const tryGo=(n)=>{const i=$('obmail');if(!i||OB.st!=='mail'){if(n<40)setTimeout(()=>tryGo(n+1),100);return}i.value=OB.mail;$('obmgo').disabled=false;$('obmgo').click()};setTimeout(()=>tryGo(0),400);return}
    if(st==='sending'){OB.mail='yui@example.com';obStep('mail');const t2=(n)=>{const i=$('obmail'),g=$('obmgo');if(!i||OB.st!=='mail'){if(n<40)setTimeout(()=>t2(n+1),100);return}i.value=OB.mail;g.disabled=true;g.innerHTML='<i class="a9dot"></i>おくって います'};setTimeout(()=>t2(0),400);return}
    if(st==='cancel'){A9.cancel=1;obStep('in');setTimeout(()=>document.querySelector('#ob [data-a="google"]').click(),500);return}
    if(st==='exists')A9.prov='apple';obStep(st)},OB.on?0:900)}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-a9]'))return;C.insertAdjacentHTML('beforeend',['sent:送った','fail:送れない','back:もどってきた','wb:おかえり','ask:別の端末','old:リンク期限切れ','exists:登録済み','cancel:Google とじた'].map(s=>{const[k,l]=s.split(':');return `<button data-a9="${k}">サインイン:${l}</button>`}).join(''));
  C.querySelectorAll('[data-a9]').forEach(b=>b.onclick=()=>a9Demo(b.dataset.a9))})();
window.__kit=Object.assign(window.__kit||{},{a9:(st,o)=>a9Demo(st,o)});
