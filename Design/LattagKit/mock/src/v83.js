
/* ================= v83(PROMPT v90)・ Trip を つくる:ブラッシュアップ ・「どこへ」は 流れる 候補 ================= */
const TW8P=['京都','沖縄','大阪','北海道','福岡','金沢','箱根','鎌倉','名古屋','広島','横浜','長野','ディズニー','USJ','ソウル','台湾','ハワイ'];
const TW8E=['修学旅行','卒業旅行','合宿','ライブ遠征','部活の 遠征','文化祭','体育祭','夏祭り','花火大会','誕生日','クリスマス','卒業式','テスト明け','いつメン旅'];
const TW8I={pin:'<svg viewBox="0 0 24 24"><path d="M12 21s-6.5-6.2-6.5-11a6.5 6.5 0 0113 0c0 4.8-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/></svg>',
  star:'<svg viewBox="0 0 24 24"><path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/></svg>',
  cal:'<svg viewBox="0 0 24 24"><rect x="4" y="5.5" width="16" height="14" rx="3"/><path d="M8 3.5v4M16 3.5v4M4 10h16"/></svg>',
  link:'<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>',
  ok:'<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>'};
const TW8Q=['どこへ 行く?','いつ 行く?','だれと 行く?','表紙を えらぶ'];
const TW8RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
function tw8Days(g){return Math.max(1,Math.round((g.to-g.from)/864e5)+1)}
function tw8Pass(g){const d=tw8Days(g),W=['SUN','MON','TUE','WED','THU','FRI','SAT'];
  return `<div class="tw8p"><div class="tw8s" style="background-image:url(${PH[g.cover]})"><i></i><span>LATTAG</span></div><i class="tw8pf" aria-hidden="true"></i>
   <div class="tw8b"><div class="tw8r1"><span>TRIP PASS</span><em>No.${String(1000+(g.n.length*37)%9000).padStart(4,'0')}</em></div>
    <b class="tw8tt${g.n?'':' tw8ph'}" id="tw8t">${tw8Chars(g.n||'どこへ?')}</b>
    <div class="tw8r2"><div><small>FROM</small><b>${t77d(g.from)}</b><em>${W[g.from.getDay()]}</em></div><i class="tw8ar">→</i><div><small>TO</small><b>${t77d(g.to)}</b><em>${W[g.to.getDay()]}</em></div><div class="tw8dy"><small>DAYS</small><b>${d}</b></div></div>
    <div class="tw8r3"><span class="tw8mm">${[{me:1},...g.m].slice(0,6).map(f=>t77av(f,22)).join('')}</span><em>${g.m.length+1}人 ・ 1日 23枚</em></div></div>
   <i class="tw8nt"></i></div>`}
function tw8Chars(s){return [...s].map(c=>`<span>${c===' '?'&nbsp;':c}</span>`).join('')}
/* 切りかわる 字(空港の 案内板 の ように 1字ずつ めくれる)*/
function tw8Flip(txt){const T=$('tw8t');if(!T)return;T.classList.toggle('tw8ph',!TW77.g.n);T.innerHTML=tw8Chars(txt||'どこへ?');if(TW8RM())return;
  T.querySelectorAll('span').forEach((s,i)=>s.animate([{transform:'perspective(200px) rotateX(-92deg)',opacity:0},{transform:'perspective(200px) rotateX(12deg)',opacity:1,offset:.7},{transform:'none',opacity:1}],{duration:300,delay:i*32,easing:'cubic-bezier(.3,1.2,.5,1)',fill:'backwards'}))}
function tw8Row(list,cls,ic){const one=list.map(c=>`<button class="tw8c ${cls}" data-c="${c}">${ic}<span>${c}</span></button>`).join('');return one+one}
function tw8StepHtml(){const g=TW77.g,s=TW77.s;
  if(s===0)return `<label class="tw8in"><i>${TW8I.pin}</i><input id="tw77n" maxlength="20" placeholder="行き先 ・ イベント" value="${g.n.replace(/"/g,'&quot;')}" autocomplete="off" enterkeyhint="next"><button data-a="clr" aria-label="けす" ${g.n?'':'hidden'}>×</button></label>
    <div class="tw8mq tw8r1" id="tw8m1"><div class="tw8mt">${tw8Row(TW8P,'pl',TW8I.pin)}</div></div>
    <div class="tw8mq tw8r2" id="tw8m2"><div class="tw8mt">${tw8Row(TW8E,'ev',TW8I.star)}</div></div>`;
  if(s===1){const days=Array.from({length:28},(_,i)=>new Date(+new Date(new Date().setHours(0,0,0,0))+i*864e5)),n=tw8Days(g),L=[['日帰り',1],['1泊2日',2],['2泊3日',3],['3泊4日',4]],k=L.findIndex(x=>x[1]===n);
    return `<div class="tw8sg" style="--k:${k}" data-k="${k}">${k>=0?'<i></i>':''}${L.map(([l,v])=>`<button data-len="${v}" class="${n===v?'on':''}">${l}</button>`).join('')}</div>
    <div class="tw8cal"><div class="tw8wd">${W77D.map(w=>`<span>${w}</span>`).join('')}</div><div class="tw8gd">${Array.from({length:days[0].getDay()},()=>'<i></i>').join('')}${days.map(d=>{const a=+d===+g.from,b=+d===+g.to,inr=d>g.from&&d<g.to,td=+d===+days[0];return `<button data-d="${+d}" class="${a?'a':''}${b?' b':''}${inr?' r':''}${a&&b?' ab':''}${td?' td':''}">${d.getDate()===1?`<small>${d.getMonth()+1}月</small>`:''}${d.getDate()}</button>`}).join('')}</div></div>
    <p class="tw8ht">${g.pick?'おわりの 日を タップ':'はじまり → おわり の 順に タップ'}</p>`}
  if(s===2){const pool=FR.concat((typeof FPOOL!=='undefined'?FPOOL:[]).slice(0,5)).filter((f,i,a)=>a.findIndex(x=>x.n===f.n)===i);
    return `<div class="tw8fr">${pool.map((f,i)=>{const on=g.m.some(x=>x.n===f.n);return `<button data-f="${i}" class="${on?'on':''}">${t77av(f,60)}<u>${TW8I.ok}</u><b>${f.n}</b></button>`}).join('')}
     <button class="tw8ln" data-a="link"><i>${TW8I.link}</i><b>リンク</b></button></div>
    <p class="tw8ht"><b>${g.m.length+1}人</b> ・ 1日 23枚を みんなで 撮る</p>`}
  return `<div class="tw8cv" id="tw8cv">${['a','b','c','d','e','f'].map(p=>`<button data-p="${p}" class="${g.cover===p?'on':''}" style="background-image:url(${PH[p]})"><u>${TW8I.ok}</u></button>`).join('')}</div>
    <div class="tw8sm"><button data-go="0"><i>${TW8I.pin}</i><b>${g.n}</b><em>変える</em></button><button data-go="1"><i>${TW8I.cal}</i><b>${t77d(g.from)} → ${t77d(g.to)} ・ ${tw8Days(g)}日</b><em>変える</em></button><button data-go="2"><i>${TW8I.star}</i><b>${g.m.length+1}人</b><em>変える</em></button></div>`}
tw77Draw=function(dir){const W=$('tw77');if(!W)return;W.classList.add('tw8');const g=TW77.g,s=TW77.s,ok=s!==0||g.n.trim();
  W.innerHTML=`<i class="tw8bg"></i><div class="tw8h"><button data-a="bk" aria-label="${s?'もどる':'とじる'}">${s?'<svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg>':'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>'}</button>
    <div class="tw8pg">${[0,1,2,3].map(i=>`<i class="${i<s?'d':i===s?'on':''}"></i>`).join('')}</div><span>${s+1}<small> / 4</small></span></div>
   ${tw8Pass(g)}<div class="tw8q" data-s="${s}"><h2>${TW8Q[s]}</h2>${tw8StepHtml()}</div>
   <div class="tw8f"><button class="nx${s===3?' go':''}" data-a="nx" ${ok?'':'disabled'}>${s===3?'Trip を つくる':'つぎへ'}</button></div>`;
  const q=W.querySelector('.tw8q');if(dir&&!TW8RM())q.animate([{opacity:0,transform:`translateX(${dir*32}px)`},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.1,.4,1)'});
  const A=(sel,f)=>W.querySelectorAll(sel).forEach(b=>b.onclick=f);
  A('[data-a="bk"]',()=>{if(TW77.s){TW77.s--;tw77Draw(-1);hap('sel')}else tw77Close()});
  A('[data-a="nx"]',()=>{if(TW77.s<3){TW77.s++;tw77Draw(1);hap('click','カチッ(つぎへ)')}else tw77Make()});
  const I=$('tw77n'),nxb=W.querySelector('[data-a="nx"]');
  if(I){I.oninput=()=>{g.n=I.value;const T=$('tw8t');T.innerHTML=tw8Chars(g.n||'どこへ?');T.classList.toggle('tw8ph',!g.n);nxb.disabled=!g.n.trim();W.querySelector('[data-a="clr"]').hidden=!g.n;hap('tick',null,{norip:1,gap:60})};
    A('[data-a="clr"]',()=>{g.n='';I.value='';tw8Flip('');nxb.disabled=true;W.querySelector('[data-a="clr"]').hidden=true;hap('soft');I.focus()})}
  /* 流れる 候補:長押しで 止まる ・ タップで パスの 名前へ 飛んで いく */
  ['tw8m1','tw8m2'].forEach(id=>{const q=$(id);if(!q)return;q.addEventListener('pointerdown',()=>{q.classList.add('hold');hap('tick',null,{norip:1})});['pointerup','pointerleave','pointercancel'].forEach(ev=>q.addEventListener(ev,()=>q.classList.remove('hold')))});
  A('.tw8c',e=>{const b=e.currentTarget,c=b.dataset.c;if(g.n===c){hap('warn');return}hap('sel','コツッ(つまむ)');const T=$('tw8t');
    const done=()=>{g.n=c;I&&(I.value=c);tw8Flip(c);nxb.disabled=false;const x=W.querySelector('[data-a="clr"]');x&&(x.hidden=false);hap('pop','ぷにっ(パスに はる)');W.querySelectorAll('.tw8c').forEach(z=>z.classList.toggle('on',z.dataset.c===c))};
    if(TW8RM()||!T){done();return}
    const P=$('phone').getBoundingClientRect(),a=b.getBoundingClientRect(),t=T.getBoundingClientRect(),f=b.cloneNode(true);f.classList.add('tw8fly');f.style.cssText=`position:absolute;left:${(a.left-P.left)/SC}px;top:${(a.top-P.top)/SC}px;width:${a.width/SC}px;height:${a.height/SC}px;margin:0;z-index:90`;$('phone').appendChild(f);
    const dx=(t.left-a.left)/SC,dy=(t.top-a.top)/SC;b.animate([{transform:'scale(.9)'},{transform:'none'}],{duration:260});
    f.animate([{transform:'none',opacity:1},{transform:`translate(${dx*.5}px,${dy*.5-40}px) scale(1.08) rotate(-4deg)`,opacity:1,offset:.5},{transform:`translate(${dx}px,${dy}px) scale(.6)`,opacity:0}],{duration:520,easing:'cubic-bezier(.4,0,.2,1)'}).onfinish=()=>{f.remove();done();const p=W.querySelector('.tw8p');p&&p.animate([{transform:'translateY(4px) scale(.985)'},{transform:'none'}],{duration:340,easing:'cubic-bezier(.3,1.5,.5,1)'})}});
  /* いつ */
  A('[data-len]',e=>{const k=+e.currentTarget.dataset.len;g.to=new Date(+g.from+(k-1)*864e5);g.pick=0;tw77Draw();hap('sel')});
  A('[data-d]',e=>{const d=new Date(+e.currentTarget.dataset.d);if(!g.pick||d<g.from){g.from=d;g.to=d;g.pick=1}else{g.to=d;g.pick=0}tw77Draw();hap('tick',null,{norip:1})});
  /* だれと */
  A('[data-f]',e=>{const pool=FR.concat((typeof FPOOL!=='undefined'?FPOOL:[]).slice(0,5)).filter((f,i,a)=>a.findIndex(x=>x.n===f.n)===i);const f=pool[+e.currentTarget.dataset.f];const i=g.m.findIndex(x=>x.n===f.n);i>=0?g.m.splice(i,1):g.m.push(f);tw77Draw();hap(i>=0?'soft':'pop');
    if(i<0&&!TW8RM()){const av=$('tw77').querySelectorAll('.tw8p .tw8mm .av77');const l=av[Math.min(av.length-1,g.m.length)];l&&l.animate([{transform:'scale(0) translateY(-10px)'},{transform:'scale(1.2)',offset:.6},{transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.5,.5,1)'})}});
  A('[data-a="link"]',()=>{hap('pop');try{openShare({t:'Lattag の Trip に 入ろう\nhttps://lattag.app/t/'+encodeURIComponent(g.n||'trip'),h:g.n||'Trip'})}catch(e){}});
  /* 表紙 */
  A('[data-p]',e=>{g.cover=e.currentTarget.dataset.p;const y=$('tw8cv').scrollLeft;tw77Draw();$('tw8cv').scrollLeft=y;hap('sel');const p=$('tw77').querySelector('.tw8p .tw8s');!TW8RM()&&p&&p.animate([{opacity:.2,transform:'scale(1.15)'},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.2,.9,.25,1)'})});
  A('[data-go]',e=>{TW77.s=+e.currentTarget.dataset.go;tw77Draw(-1);hap('sel')});
  if(I&&s===0)setTimeout(()=>{try{I.focus({preventScroll:true})}catch(e){}},350)};
/* できあがり:パスが 印刷される ように(新しい パスで)*/
tw77Make=function(){const g=TW77.g;const t={n:g.n.trim(),en:tEn(g.n.trim()),cover:g.cover,from:g.from,to:g.to,m:g.m.slice(),trip:true,cnt:0,by:[],key:tKey(),sub:(g.m.length+1)+'人',un:0,last:'Trip が はじまりました'};
  GRP.unshift(t);hap('projector','ジジジ(パスを 印刷)',{norip:1});const k=$('tw77')&&$('tw77').querySelector('.tw8p');
  if(k&&!TW8RM())k.animate([{transform:'none'},{transform:'translateY(6px) scale(.98)',offset:.2},{transform:'translateY(-12px) rotate(-1.5deg)',offset:.6},{transform:'none'}],{duration:800,easing:'cubic-bezier(.3,1.3,.5,1)'});
  setTimeout(()=>{hap('success','トトトン(できた)',{norip:1});tw77Close();try{renderGroups();renderOrb()}catch(e){}openPass(t,true)},850)};
