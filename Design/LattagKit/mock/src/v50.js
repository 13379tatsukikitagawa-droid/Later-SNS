/* ================= v50 ME:7日の フィルム と Recap ================= */
const MEK=['a','b','c','d','e','f'],METG=['#夕焼け','#放課後','#帰り道','#朝','#カフェ','#雨の日','#部活','#ねむい','#散歩'];
function meDays(){const out=[];for(let k=1;k<=7;k++){const d=new Date(Date.now()-k*864e5);const n=k===3?2:3;
  out.push({k,d,lab:MON[d.getMonth()].toUpperCase()+' '+d.getDate(),wd:WD[d.getDay()],left:7-k,
    fr:Array.from({length:n},(_,j)=>({p:MEK[(k*2+j)%6],tm:['08:'+p2(10+k*3),'13:'+p2(20+k*4),'19:'+p2(5+k*6)][j],t:METG[(k+j*2)%METG.length],star:j===(k%3)}))})}return out}
const stp=d=>`'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}`;
var ME={on:false,style:'film',days:null};
function openMe(){if(ME.on)return;ME.on=true;ME.days=meDays();const W=$('mew');meRender();W.classList.add('on');W.setAttribute('aria-hidden','false');
  hap('sel','コツッ(ME)');setTimeout(()=>hap('projector','カタカタ(フィルム)',{norip:1}),260);
  W.querySelectorAll('.mrc,.mstrip,.msty,.mday').forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(26px)'},{opacity:1,transform:'none'}],{duration:560,delay:120+i*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
  const s=W.querySelector('.mfilm');s&&s.animate([{transform:'translateX(220px)'},{transform:'none'}],{duration:900,easing:'cubic-bezier(.2,.9,.25,1)'})}
function closeMe(){if(!ME.on)return;ME.on=false;const W=$('mew');W.classList.remove('on');W.setAttribute('aria-hidden','true');hap('soft','やわらかく1回(もどる)')}
function meRender(){const W=$('mew'),D=ME.days,all=D.flatMap(x=>x.fr.map(f=>({...f,day:x}))),stars=all.filter(f=>f.star).length,cov=D.slice(0,4).map(x=>x.fr[0].p);
  const film=D.slice().reverse().map(x=>`<div class="mfd"><span class="mfl">${x.wd} <b>${x.d.getDate()}</b></span>${x.fr.map((f,j)=>`<button class="mfr" data-k="${x.k}" data-j="${j}"><i style="background-image:url(${PH[f.p]})"></i>${f.star?ICO.star:''}</button>`).join('')}</div>`).join('');
  W.innerHTML=`<div class="mbg" style="background-image:url(${PH[cov[0]]})"></div>
   <div class="mhd"><button class="fback" id="meb" aria-label="もどる"><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg></button><b class="mtt">ME</b><span class="mrg">${D[6].lab} — ${D[0].lab}</span></div>
   <div class="mbd" id="mbd">
    <button class="mrc" id="mrc" aria-label="Recap を 再生"><span class="cv">${cov.map((p,i)=>`<i style="background-image:url(${PH[p]});--i:${i}"></i>`).join('')}</span><i class="sh"></i>
      <span class="mrk">RECAP</span><b>Your<br><em>week.</em></b><span class="st"><i>${all.length}</i> shots <i>7</i> days <i>${stars}</i>kept</span><span class="pl"><svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z"/></svg></span></button>
    <div class="msty" id="msty">${[['film','Film'],['cheki','Cheki'],['beat','Beat']].map(([k,l])=>`<button data-s="${k}" class="${ME.style===k?'on':''}">${l}</button>`).join('')}</div>
    <div class="mstrip"><div class="mfilm">${film}</div></div>
    ${D.map(x=>`<div class="mday"><div class="mdh"><b>${x.wd.charAt(0)+x.wd.slice(1).toLowerCase()}</b><span>${x.lab}</span><em class="${x.left<=1?'r':''}">${x.left?x.left+'d left':'today'}</em></div>
      <div class="mdg">${x.fr.map((f,j)=>`<button class="mdc" data-k="${x.k}" data-j="${j}"><img src="${PH[f.p]}" alt=""><span class="tm">${f.tm}</span>${f.star?ICO.star:''}</button>`).join('')}</div></div>`).join('')}
   </div>`;
  $('meb').onclick=closeMe;$('mrc').onclick=()=>{hap('pop','ぷにっ(Recap)');meplay()};
  W.querySelectorAll('#msty button').forEach(b=>b.onclick=()=>{ME.style=b.dataset.s;W.querySelectorAll('#msty button').forEach(x=>x.classList.toggle('on',x===b));hap('sel','コツッ('+b.textContent+')');$('mrc').animate([{scale:'1'},{scale:'.97'},{scale:'1'}],{duration:300})});
  W.querySelectorAll('.mfr,.mdc').forEach(b=>b.onclick=()=>{const x=ME.days.find(d=>d.k===+b.dataset.k),f=x.fr[+b.dataset.j];hap('pop');openAv({p:f.p,n:x.lab,s:x.wd.toLowerCase()+' · '+f.tm,t:f.t})})}

/* --- Recap プレイヤー(動画みたいに 流れる) --- */
var MP={on:false,i:0,seq:[],t:0,pause:false};
function meSeq(){const s=[];ME.days.slice().reverse().forEach(x=>{s.push({ty:'day',x});x.fr.forEach(f=>s.push({ty:'ph',x,f}))});s.push({ty:'end'});return s}
function meplay(){const P=$('mrp');MP={on:true,i:-1,seq:meSeq(),t:0,pause:false};const fast=ME.style==='beat';
  P.className='mrp on st-'+ME.style;P.innerHTML=`<div class="mst" id="mst"></div><div class="mpr">${MP.seq.filter(s=>s.ty!=='end').map(()=>'<i><u></u></i>').join('')}</div>
    <div class="mtop"><span class="ap">L</span><span class="tx"><b>Your week</b><small>♪ 今日の 1曲 ・ Lattag</small></span><button class="x" id="mpx" aria-label="とじる">✕</button></div><i class="mgr"></i>`;
  $('mpx').onclick=e=>{e.stopPropagation();meStop()};
  let dn=0;P.onpointerdown=()=>{dn=performance.now();MP.pause=true;P.classList.add('ps')};
  P.onpointerup=e=>{P.classList.remove('ps');MP.pause=false;if(performance.now()-dn<220&&MP.seq[MP.i]&&MP.seq[MP.i].ty!=='end'){const r=P.getBoundingClientRect();meGo(e.clientX-r.left<r.width*.3?MP.i-1:MP.i+1)}};
  hap('projector','カタカタ(上映)',{norip:1});meGo(0)}
function meDur(s){const b=ME.style==='beat'?560:ME.style==='cheki'?1500:1150;return s.ty==='day'?b*.9:s.ty==='end'?0:b}
function meGo(i){if(!MP.on)return;i=Math.max(0,Math.min(MP.seq.length-1,i));MP.i=i;clearTimeout(MP.t);const s=MP.seq[i],S=$('mst'),P=$('mrp');
  const bars=P.querySelectorAll('.mpr i');bars.forEach((b,k)=>{const u=b.firstChild;u.getAnimations().forEach(a=>a.cancel());u.style.width=k<i?'100%':'0%'});
  if(s.ty!=='end'&&bars[i]){bars[i].firstChild.animate([{width:'0%'},{width:'100%'}],{duration:meDur(s),fill:'forwards'})}
  const el=document.createElement('div');el.className='msl m-'+s.ty;
  if(s.ty==='day'){el.innerHTML=`<span class="dk">${s.x.wd}</span><b>${s.x.d.getDate()}</b><span class="dm">${MON[s.x.d.getMonth()]}</span><span class="dc">${s.x.fr.length} shots</span>`;hap('thud','ドン(つぎの 日)',{norip:1})}
  else if(s.ty==='ph'){const ch=ME.style==='cheki';el.innerHTML=`<div class="fx${ch?' ck':''}" style="--r:${(i%2?1:-1)*(2+i%3)}deg"><i style="background-image:url(${PH[s.f.p]})"></i><span class="ds">${stp(s.x.d)} ${s.f.tm}</span>${ch?`<span class="cn">${rmEsc(s.f.t)}</span>`:`<span class="tg">${rmEsc(s.f.t)}</span>`}${s.f.star?'<em class="sr">★</em>':''}</div>`;hap(ME.style==='beat'?'pop':'tick',null,{norip:1})}
  else{const all=ME.days.flatMap(x=>x.fr);el.innerHTML=`<div class="en"><div class="mos">${all.slice(0,12).map((f,k)=>`<i style="background-image:url(${PH[f.p]});--k:${k}"></i>`).join('')}</div><span class="k">${ME.days[6].lab} — ${ME.days[0].lab}</span><b>That was<br><em>your week.</em></b>
    <span class="nm"><i>${all.length}</i>shots<i>7</i>days<i>${all.filter(f=>f.star).length}</i>kept</span>
    <div class="meb2"><button data-a="save"><svg viewBox="0 0 24 24"><path d="M12 4v11M7 10l5 5 5-5M5 20h14"/></svg>Save</button><button data-a="share" class="pr"><svg viewBox="0 0 24 24"><path d="M12 15V4M7 9l5-5 5 5M5 14v6h14v-6"/></svg>Share</button><button data-a="re" aria-label="もういちど"><svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 1 0 3-6.2M4 4v4h4"/></svg></button></div></div>`;
    hap('success','トトトン(おわり)',{norip:1});
    setTimeout(()=>{el.querySelector('[data-a="re"]').onclick=e=>{e.stopPropagation();meGo(0)};el.querySelector('[data-a="share"]').onclick=e=>{e.stopPropagation();openShare({t:'Your week on Lattag\nhttps://lattag.app/recap',h:'Recap'})};
      el.querySelector('[data-a="save"]').onclick=e=>{e.stopPropagation();const b=e.currentTarget;if(b.classList.contains('bz'))return;b.classList.add('bz');let k=0;const iv=setInterval(()=>{k+=7;b.style.setProperty('--k',k+'%');if(k%21===0)hap('tick',null,{norip:1});if(k>=100){clearInterval(iv);b.classList.remove('bz');b.classList.add('ok');b.innerHTML='Saved';hap('success','トトトン(保存)',{norip:1});_toast('写真に 保存しました(モック ・ 9:16 動画)')}},90)}},50)}
  [...S.children].forEach(c=>{c.classList.add('out');setTimeout(()=>c.remove(),600)});S.appendChild(el);
  if(s.ty!=='end'){const run=()=>{if(!MP.on)return;if(MP.pause){MP.t=setTimeout(run,120);return}meGo(i+1)};MP.t=setTimeout(run,meDur(s))}}
function meStop(){MP.on=false;clearTimeout(MP.t);const P=$('mrp');P.classList.remove('on');setTimeout(()=>{if(!MP.on)P.innerHTML=''},400);hap('soft')}

/* 入口 */
$('yme').onclick=()=>{hap('pop','ぷにっ(ME)');closeY();setTimeout(openMe,380)};
goMe=function(){hap('pop','ぷにっ(ME)');closeAll();setTimeout(openMe,380)};
{const a=document.querySelector('#aal');if(a&&a.previousElementSibling){const h=a.previousElementSibling;h.style.cursor='pointer';h.onclick=()=>{hap('pop');openMe()};const e=h.querySelector('em');if(e)e.innerHTML='7 DAYS · RECAP ›'}}
