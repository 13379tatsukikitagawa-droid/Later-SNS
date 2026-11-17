
/* ================= v79(PROMPT v86)・ ME = Recap が 主役 ・ 過去の 写真を 見やすく ================= */
const RC={kb:0,pl:null,dv:null};
const RMO=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'],RWD=['SUN','MON','TUE','WED','THU','FRI','SAT'],RWJ=['日','月','火','水','木','金','土'];
function rcWeeks(D){/* 月曜 はじまりの 週に 分ける(さいごの 週 = 今週 = 作成中)*/
  const W=[];D.forEach(x=>{const d=x.d,m=new Date(d);m.setDate(d.getDate()-((d.getDay()+6)%7));m.setHours(0,0,0,0);const k=+m;let w=W.find(w=>w.k===k);if(!w){w={k,mon:m,days:[]};W.push(w)}w.days.push(x)});
  W.forEach(w=>{w.sh=w.days.reduce((a,x)=>a+x.k,0);w.dn=w.days.filter(x=>x.k).length;w.st=w.days.reduce((a,x)=>a+x.sh.filter(s=>s.st).length,0);w.end=new Date(+w.mon+6*864e5);
    const ph=w.days.flatMap(x=>x.sh.map(s=>s.p));w.cover=ph[ph.length-1]||'a';w.ph=ph;const hs=w.days.flatMap(x=>x.sh.map(s=>s.h));w.hr=hs.length?Math.round(hs.reduce((a,b)=>a+b,0)/hs.length):0});
  const today=new Date();today.setHours(0,0,0,0);const cur=new Date(today);cur.setDate(today.getDate()-((today.getDay()+6)%7));
  return {done:W.filter(w=>+w.mon<+cur&&w.days.length===7&&w.sh>=3).reverse(),cur,curDays:(today.getDay()+6)%7}}
const rcLbl=w=>`${RMO[w.mon.getMonth()]} ${w.mon.getDate()}–${w.end.getMonth()!==w.mon.getMonth()?RMO[w.end.getMonth()]+' ':''}${w.end.getDate()}`;
const RCTAG=['#夕焼け','#帰り道','#放課後','#自販機','#おやつ','#教室'];
meRender=function(){const W=$('mew');if(!W)return;const D=m73Days();M73.D=D;const R=rcWeeks(D);RC.R=R;const L=R.done[0];
  const tot=D.reduce((a,x)=>a+x.k,0),days=D.filter(x=>x.k).length,kept=D.reduce((a,x)=>a+x.sh.filter(s=>s.st).length,0);
  const mo=new Date();mo.setDate(1);const pm=new Date(mo);pm.setMonth(mo.getMonth()-1);
  W.innerHTML=`<div class="m73 m79"><div class="zs">
   <div class="zh"><button class="zbk" data-a="bk" aria-label="もどる"><svg viewBox="0 0 24 24"><path d="M15 5l-7 7 7 7"/></svg></button><div class="zt">ME</div><div class="zy">${tot} SHOTS<b>${new Date().getFullYear()}</b></div></div>
   <button class="rch" data-a="play" data-w="0" aria-label="Recap を 再生"><i class="r9kb r9a" style="background-image:url(${PH[L.ph[0]||'a']})"></i><i class="r9kb r9b"></i><i class="r9sh"></i>
    <div class="r9tp"><span class="r9nw">NEW</span><span>RECAP ・ ${rcLbl(L)}</span></div>
    <div class="r9bt"><b>Your<br><em>week.</em></b><div class="r9ch"><span>${L.sh} SHOTS</span><span>${L.dn} DAYS</span><span>${RCTAG[L.k%6]}</span></div></div>
    <span class="r9pl"><svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z"/></svg></span>
    <div class="r9sg">${L.days.map(x=>`<i class="${x.k?'on':''}"></i>`).join('')}</div></button>
   <div class="rcn"><div class="r9rg"><svg viewBox="0 0 44 44"><circle cx="22" cy="22" r="18" class="r9t"/><circle cx="22" cy="22" r="18" class="r9p" style="stroke-dasharray:${(R.curDays+1)/7*113} 113"/></svg><b>${R.curDays+1}<small>/7</small></b></div>
    <div class="r9tx"><b>次の Recap を つくって います</b><small>${7-R.curDays>1?`あと ${7-R.curDays}日 ・ 月曜 9:00 に できる`:'あした 9:00 に できる'}</small></div>
    <div class="r9ft">${Array.from({length:7},(_,i)=>{const x=i<R.curDays?D[D.length-R.curDays+i]:null;return `<i class="${x?(x.k?'on':'r9em'):i===R.curDays?'r9td':''}">${x&&x.sh[0]?`<u style="background-image:url(${PH[x.sh[0].p]})"></u>`:''}</i>`}).join('')}</div></div>
   <div class="rcs"><div class="r9hh"><b>Recaps</b><small>${R.done.length+1} RECAPS</small></div><div class="r9row">
    <button class="rcm" data-a="play" data-w="m"><i style="background-image:url(${PH.d})"></i><span><small>MONTH</small><b>${RMO[pm.getMonth()]}</b><em>${pm.getFullYear()}</em></span></button>
    ${R.done.map((w,i)=>`<button class="rcw" data-a="play" data-w="${i}"><i style="background-image:url(${PH[w.cover]})"></i><span><small>WEEK</small><b>${rcLbl(w)}</b><em>${w.sh} shots</em></span><u></u></button>`).join('')}</div></div>
   <div class="zbc"><div class="lb"><b>●</b> ${M73.n} DAYS</div><div class="rd"></div>${m73Bars(D)}<i class="cur"></i><div class="ax"><span>${M73.n} DAYS AGO</span><span>30</span><span>YESTERDAY</span></div></div>
   <div class="zdy"></div>
   <div class="alb"><div class="r9hh"><b>Album</b><div class="r9mt"><button data-a="pm" aria-label="前の 月">‹</button><span id="m79mo"></span><button data-a="nm" aria-label="次の 月">›</button></div></div><div class="r9wd">${RWJ.map(w=>`<span>${w}</span>`).join('')}</div><div class="r9gd" id="m79gd"></div></div>
   <div class="zst"><div><b>${tot}</b><small>SHOTS</small></div><div><b>${days}</b><small>DAYS</small></div><div><b>${kept}</b><small>KEPT ★</small></div></div>
  </div></div>`;
  W.querySelector('[data-a="bk"]').onclick=()=>closeMe();
  W.querySelectorAll('[data-a="play"]').forEach(b=>b.onclick=()=>rcPlay(b.dataset.w));
  const Bc=W.querySelector('.zbc'),pick=e=>{const r=Bc.getBoundingClientRect(),x=Math.max(0,Math.min(1,(e.clientX-r.left-16)/(r.width-32)));const i=Math.min(D.length-1,Math.floor(x*D.length));if(i!==M73.sel){m73Sel(i);hap('tick',null,{norip:1,gap:40})}};
  Bc.onpointerdown=e=>{Bc.setPointerCapture(e.pointerId);pick(e);Bc.onpointermove=pick};Bc.onpointerup=Bc.onpointercancel=()=>{Bc.onpointermove=null};
  m73Sel(M73.sel,true);RC.mo=RC.mo||new Date(new Date().getFullYear(),new Date().getMonth(),1);rcAlbum();
  W.querySelector('[data-a="pm"]').onclick=()=>{RC.mo=new Date(RC.mo.getFullYear(),RC.mo.getMonth()-1,1);rcAlbum(-1);hap('sel')};
  W.querySelector('[data-a="nm"]').onclick=()=>{RC.mo=new Date(RC.mo.getFullYear(),RC.mo.getMonth()+1,1);rcAlbum(1);hap('sel')};
  if(!RC.seen&&!RC.dev&&!matchMedia('(prefers-reduced-motion:reduce)').matches){RC.dev=1;const K=W.querySelector('.rch .r9kb.r9a');K.animate([{filter:'blur(16px) grayscale(1) brightness(.35) sepia(.6)'},{filter:'blur(6px) grayscale(.6) brightness(.7) sepia(.3)',offset:.5},{filter:'none'}],{duration:1800,delay:300,easing:'cubic-bezier(.3,.6,.3,1)',fill:'backwards'});setTimeout(()=>hap('land','トン(Recap が できた)'),1900)}
  if(RC.seen){const n=W.querySelector('.rch .r9nw');n&&(n.textContent='▶ 見た',n.classList.add('r9sn'))}
  rcKB();if(!matchMedia('(prefers-reduced-motion:reduce)').matches)W.querySelectorAll('.rch,.rcn,.rcs,.zbc,.alb').forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(22px)'},{opacity:1,transform:'none'}],{duration:560,delay:80+i*70,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}))}
/* 選んだ 日 の パネル:押すと 全画面 */
{const _s=m73Sel;m73Sel=function(i,q){_s(i,q);const Z=document.querySelector('#mew .zdy');if(Z){Z.querySelectorAll('.zdp i').forEach((e,j)=>{e.style.cursor='pointer';e.onclick=()=>rcDay(M73.D[M73.sel],j)})}}}
/* ヒーローの Ken Burns(2.6秒 ごとに 写真が 入れかわる)*/
function rcKB(){clearInterval(RC.kbt);const W=$('mew'),H=W&&W.querySelector('.rch');if(!H||matchMedia('(prefers-reduced-motion:reduce)').matches)return;const L=RC.R.done[0],ph=L.ph.length?L.ph:['a'];let i=0,front='r9a';
  const step=()=>{if(!document.contains(H)){clearInterval(RC.kbt);return}i=(i+1)%ph.length;const a=H.querySelector('.r9kb.'+front),b=H.querySelector('.r9kb.'+(front==='r9a'?'r9b':'r9a'));b.style.backgroundImage=`url(${PH[ph[i]]})`;
    b.animate([{opacity:0,transform:'scale(1.12) translate(2%,1%)'},{opacity:1,transform:'scale(1.02) translate(0,0)'}],{duration:2600,easing:'cubic-bezier(.3,.6,.3,1)',fill:'forwards'});a.animate([{opacity:1},{opacity:0}],{duration:900,fill:'forwards'});front=front==='r9a'?'r9b':'r9a'};
  H.querySelector('.r9kb.r9a').animate([{transform:'scale(1.12)'},{transform:'scale(1.02)'}],{duration:2600,fill:'forwards'});RC.kbt=setInterval(step,2600)}
/* アルバム:月の カレンダーに 1日 1枚 */
function rcAlbum(dir){const G=$('m79gd'),T=$('m79mo');if(!G)return;const m=RC.mo,D=M73.D;T.textContent=`${m.getFullYear()} ・ ${RMO[m.getMonth()]}`;
  const n=new Date(m.getFullYear(),m.getMonth()+1,0).getDate(),pad=m.getDay(),today=new Date();
  G.innerHTML=Array.from({length:pad},()=>'<i class="r9pd"></i>').join('')+Array.from({length:n},(_,k)=>{const d=new Date(m.getFullYear(),m.getMonth(),k+1);const x=D.find(x=>x.d.toDateString()===d.toDateString());
    const fut=d>today;return x&&x.k?`<button data-d="${D.indexOf(x)}" style="background-image:url(${PH[x.sh[x.sh.length-1].p]})"><b>${k+1}</b>${x.sh.some(s=>s.st)?'<u>★</u>':''}${x.k>1?`<em>${x.k}</em>`:''}</button>`:`<i class="${fut?'r9fu':'r9no'}"><b>${k+1}</b></i>`}).join('');
  G.querySelectorAll('button[data-d]').forEach(b=>b.onclick=()=>{hap('pop');rcDay(D[+b.dataset.d],0)});
  if(dir&&!matchMedia('(prefers-reduced-motion:reduce)').matches)G.animate([{opacity:0,transform:`translateX(${dir*30}px)`},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.1,.4,1)'})}
/* 1日の 全画面(3枚を 横に スワイプ)*/
function rcDay(x,j){if(!x||!x.k)return;let V=$('dv79');if(!V){$('phone').insertAdjacentHTML('beforeend','<section class="dv79" id="dv79" aria-label="1日の 写真"></section>');V=$('dv79')}
  V.innerHTML=`<div class="r9h"><button data-a="x" aria-label="とじる">×</button><div><b>${RWJ[x.d.getDay()]} ${x.d.getMonth()+1}/${x.d.getDate()}</b><small>${RWD[x.d.getDay()]} ・ ${x.k} SHOTS</small></div><button data-a="st" aria-label="★ で のこす">★</button></div>
   <div class="r9sc">${x.sh.map((s,i)=>`<div class="r9pg"><i style="background-image:url(${PH[s.p]})"></i><div class="r9cp"><span>${s.h}:${String((i*17)%60).padStart(2,'0')}</span><em>${RCTAG[(s.h+i)%6]}</em>${s.st?'<u>★ KEPT</u>':''}</div></div>`).join('')}</div>
   <div class="r9dt">${x.sh.map((_,i)=>`<i class="${i===j?'on':''}"></i>`).join('')}</div>`;
  V.classList.add('on');hap('pop','ぷにっ(ひらく)');const S=V.querySelector('.r9sc');requestAnimationFrame(()=>{S.scrollLeft=j*S.clientWidth});
  S.onscroll=()=>{const k=Math.round(S.scrollLeft/S.clientWidth);V.querySelectorAll('.r9dt i').forEach((e,i)=>e.classList.toggle('on',i===k));if(k!==RC.dk){RC.dk=k;hap('tick',null,{norip:1})}};
  V.querySelector('[data-a="x"]').onclick=()=>{V.classList.remove('on');hap('soft',null,{norip:1})};
  V.querySelector('[data-a="st"]').onclick=e=>{e.currentTarget.classList.toggle('on');hap('success','トトン(のこす)')}}
/* ---------- Recap の 再生(ストーリー の 形)---------- */
function rcPlay(w){if(RC.pl)clearTimeout(RC.pl.t);const me={};const R=RC.R;let sel;const pm=new Date();pm.setDate(1);pm.setMonth(pm.getMonth()-1);
  if(w==='m'){const days=M73.D.filter(x=>x.d.getMonth()===pm.getMonth());sel={lbl:`${RMO[pm.getMonth()]} ${pm.getFullYear()}`,ttl:'Your<br><em>month.</em>',days:days.filter((_,i)=>i%3===0).slice(0,10)}}
  else{const W=R.done[+w]||R.done[0];sel={lbl:rcLbl(W),ttl:'Your<br><em>week.</em>',days:W.days}}
  const fr=[];sel.days.forEach((x,di)=>x.sh.forEach((s,si)=>fr.push({x,s,di,si})));if(!fr.length)return;
  const sh=sel.days.reduce((a,x)=>a+x.k,0),dn=sel.days.filter(x=>x.k).length,kp=sel.days.reduce((a,x)=>a+x.sh.filter(s=>s.st).length,0),hs=fr.map(f=>f.s.h),hr=Math.round(hs.reduce((a,b)=>a+b,0)/hs.length);
  let P=$('rc79');if(!P){$('phone').insertAdjacentHTML('beforeend','<section class="rc79" id="rc79" aria-label="Recap"></section>');P=$('rc79')}
  P.innerHTML=`<div class="r9st"><i class="r9a"></i><i class="r9b"></i><i class="r9sh"></i></div>
   <div class="r9sg">${sel.days.map(()=>'<i><u></u></i>').join('')}<i class="r9end"><u></u></i></div>
   <div class="r9h"><span>RECAP ・ ${sel.lbl}</span><button data-a="x" aria-label="とじる">×</button></div>
   <div class="r9lb"><b></b><small></small><em></em></div>
   <div class="r9in"><small>LATTAG RECAP</small><b>${sel.ttl}</b><span>${sel.lbl} ・ ${sh} SHOTS</span></div>
   <div class="r9fin"><small>RECAP ・ ${sel.lbl}</small><b>${sel.ttl}</b><div class="r9gd"><div><b>${sh}</b><small>SHOTS</small></div><div><b>${dn}</b><small>DAYS</small></div><div><b>${kp}</b><small>KEPT ★</small></div><div><b>${hr}時台</b><small>よく 撮る 時間</small></div></div>
    <div class="r9tg"><small>いちばん 多い タグ</small><b>${RCTAG[sh%6]}</b></div><div class="r9bt"><button data-a="save"><svg viewBox="0 0 24 24"><path d="M12 4v11M7 10l5 5 5-5M5 19h14"/></svg>保存</button><button data-a="share" class="r9pr"><svg viewBox="0 0 24 24"><path d="M12 15V4M7 9l5-5 5 5M5 14v5h14v-5"/></svg>シェア</button><button data-a="again"><svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1 0 2.4-5.7M4 4v4h4"/></svg></button></div></div>
   <button class="r9tz r9l" data-a="prev" aria-label="前"></button><button class="r9tz r9r" data-a="next" aria-label="次"></button>`;
  P.classList.add('on');hap('projector','カタカタ(Recap)');RC.pl={fr,i:-1,sel,front:'r9a',me};
  const go=k=>{const S=RC.pl;if(!S||S.me!==me)return;clearTimeout(S.t);if(k<0)k=0;S.i=k;const rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
    const segs=P.querySelectorAll('.r9sg i');
    if(k>=fr.length){P.classList.add('done');segs.forEach(s=>s.querySelector('u').style.width='100%');hap('success','トトトン(Recap おわり)');RC.seen=true;{const n=document.querySelector('#mew .rch .r9nw');n&&(n.textContent='▶ 見た',n.classList.add('r9sn'))}
      !rm&&P.querySelectorAll('.r9fin>*').forEach((e,n)=>e.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:520,delay:n*90,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}));return}
    P.classList.remove('done');const f=fr[k];segs.forEach((s,n)=>{const u=s.querySelector('u');u.getAnimations().forEach(a=>a.cancel());u.style.width=n<f.di?'100%':n>f.di?'0%':''});
    const cur=segs[f.di].querySelector('u'),per=sel.days[f.di].sh.length,base=f.si/per*100;cur.style.width=base+'%';!rm&&cur.animate([{width:base+'%'},{width:(f.si+1)/per*100+'%'}],{duration:1300,fill:'forwards',easing:'linear'});
    const nb=S.front==='r9a'?'r9b':'r9a',A=P.querySelector('.r9st .'+S.front),B=P.querySelector('.r9st .'+nb);B.style.backgroundImage=`url(${PH[f.s.p]})`;
    if(!rm){B.animate([{opacity:0,transform:`scale(1.14) translate(${(k%2?-2:2)}%,1%)`},{opacity:1,transform:'scale(1.02) translate(0,0)'}],{duration:1500,easing:'cubic-bezier(.3,.6,.3,1)',fill:'forwards'});A.animate([{opacity:1},{opacity:0}],{duration:500,fill:'forwards'})}else{B.style.opacity=1;A.style.opacity=0}
    S.front=nb;const lb=P.querySelector('.r9lb');lb.querySelector('b').textContent=`${RWD[f.x.d.getDay()]} ${f.x.d.getDate()}`;lb.querySelector('small').textContent=`${f.s.h}:${String((k*13)%60).padStart(2,'0')}`;lb.querySelector('em').textContent=RCTAG[(f.s.h+k)%6];
    if(f.si===0){hap('soft',null,{norip:1});!rm&&lb.animate([{opacity:0,transform:'translateY(10px)'},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.2,.4,1)'})}
    S.t=setTimeout(()=>go(k+1),1300)};
  P.querySelector('[data-a="x"]').onclick=()=>{clearTimeout(RC.pl&&RC.pl.t);RC.pl=null;P.classList.remove('on','done');hap('soft',null,{norip:1})};
  P.querySelector('[data-a="next"]').onclick=()=>go(RC.pl.i+1);P.querySelector('[data-a="prev"]').onclick=()=>go(RC.pl.i-1);
  P.querySelector('[data-a="again"]').onclick=()=>{hap('pop');go(0)};
  P.querySelector('[data-a="save"]').onclick=()=>{hap('success');try{_toast('Recap を 動画で 保存しました(モック)')}catch(e){}};
  P.querySelector('[data-a="share"]').onclick=()=>{hap('pop');try{openShare({t:'Lattag の Recap ・ '+sel.lbl,h:'Recap'})}catch(e){}};
  ['pointerdown'].forEach(t=>P.querySelector('.r9st').addEventListener(t,()=>{}));
  /* 長押しで 止める ・ はなすと 再開 */
  P.querySelectorAll('.r9tz').forEach(z=>{let t0=0,held=false;z.addEventListener('pointerdown',()=>{t0=performance.now();held=false;z._ht=setTimeout(()=>{held=true;const S=RC.pl;if(!S)return;clearTimeout(S.t);P.classList.add('r9ps');P.getAnimations({subtree:true}).forEach(a=>a.pause());hap('soft',null,{norip:1})},240)});
    z.addEventListener('pointerup',e=>{clearTimeout(z._ht);if(held){e.preventDefault();z._skip=true;const S=RC.pl;P.classList.remove('r9ps');P.getAnimations({subtree:true}).forEach(a=>a.play());if(S)S.t=setTimeout(()=>go(S.i+1),700)}});
    z.addEventListener('click',e=>{if(z._skip){z._skip=false;e.stopImmediatePropagation()}},true)});
  const IN=P.querySelector('.r9in');if(matchMedia('(prefers-reduced-motion:reduce)').matches){IN.style.display='none';go(0);return}
  IN.style.opacity=1;IN.querySelectorAll('*').forEach((e,n)=>e.animate([{opacity:0,transform:'translateY(16px)',filter:'blur(6px)'},{opacity:1,transform:'none',filter:'blur(0)'}],{duration:620,delay:120+n*140,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}));
  RC.pl.t=setTimeout(()=>{IN.animate([{opacity:1},{opacity:0,transform:'scale(1.06)'}],{duration:420,fill:'forwards'});go(0)},1700)}
Object.assign(window.__kit||(window.__kit={}),{rcPlay:(w,k)=>{rcPlay(w==null?'0':String(w));if(k!=null){const S=RC.pl;if(S){clearTimeout(S.t);const I=document.querySelector('#rc79 .r9in');I&&(I.style.opacity=0);RC.pl.i=k-1;document.querySelector('#rc79 [data-a="next"]').click()}}},rcDay:i=>{const D=M73.D;rcDay(D[i!=null?i:D.length-2],0)},rcStop:()=>{if(RC.pl){clearTimeout(RC.pl.t);document.querySelectorAll('#rc79 *').forEach(e=>e.getAnimations().forEach(a=>a.finish()))}},rcSeen:v=>{RC.seen=!!v;RC.dev=0}});
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-rc79]'))return;C.insertAdjacentHTML('beforeend','<button data-rc79="me">ME:Recap</button><button data-rc79="new">Recap:できた(新)</button><button data-rc79="play">Recap 再生</button>');
  C.querySelector('[data-rc79="me"]').onclick=()=>{try{__kit.openMe()}catch(e){}};
  C.querySelector('[data-rc79="new"]').onclick=()=>{RC.seen=false;RC.dev=0;try{__kit.openMe();meRender()}catch(e){}};
  C.querySelector('[data-rc79="play"]').onclick=()=>{try{__kit.openMe()}catch(e){};setTimeout(()=>rcPlay('0'),500)}})();
