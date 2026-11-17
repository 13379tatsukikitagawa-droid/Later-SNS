(()=>{
const $=id=>document.getElementById(id);
const phone=$('phone');const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
/* ---------- 大きさ(画面に合わせる) ---------- */
let SC=1;function fit(){SC=Math.min(1,(innerHeight-150)/844,(innerWidth-24)/390);const w=$('wrap');w.style.transform=`scale(${SC})`;w.style.width='390px';w.style.height=(844*SC)+'px'}
addEventListener('resize',fit);fit();
/* ---------- フィルムの粒 ---------- */
(function(){const c=document.createElement('canvas');c.width=c.height=180;const x=c.getContext('2d'),d=x.createImageData(180,180);for(let i=0;i<d.data.length;i+=4){const v=Math.random()*255;d.data[i]=d.data[i+1]=d.data[i+2]=v;d.data[i+3]=26}x.putImageData(d,0,0);$('grain').style.backgroundImage=`url(${c.toDataURL()})`})();
/* ---------- 時刻 ---------- */
const now=new Date();const p2=n=>String(n).padStart(2,'0');
const HM=()=>{const d=new Date();return p2(d.getHours())+':'+p2(d.getMinutes())};
const DT=`'${String(now.getFullYear()).slice(2)} ${p2(now.getMonth()+1)} ${p2(now.getDate())}`;
function tickClock(){$('clock').textContent=HM();$('stamp').textContent=DT+(window.__m==='movie'?'':'  '+HM())}tickClock();setInterval(tickClock,10000);
{const m=Math.max(0,(24*60)-(now.getHours()*60+now.getMinutes()));document.getElementById('hlo').textContent=Math.floor(m/60)+'h '+p2(m%60)+'m';document.getElementById('hkd').textContent=`TODAY'S FILM ・ ${p2(now.getMonth()+1)}.${p2(now.getDate())}`}
$('rtx').textContent=('LATTAG — TODAY — YESTERDAY — 3 SHOTS A DAY — '+p2(now.getMonth()+1)+'.'+p2(now.getDate())+' — ').repeat(2);
$('tdt').textContent=p2(now.getMonth()+1)+'.'+p2(now.getDate());$('tpvd').textContent=DT;

/* =================== 触覚 =================== */
const HP={tick:{v:[7],a:.35,l:'ごく軽く1回'},sel:{v:[11],a:.5,l:'コツッ'},pop:{v:[20],a:.7,l:'ぷにっ'},click:{v:[16],a:.65,l:'カチッ'},soft:{v:[10],a:.3,l:'やわらかく1回'},
  thud:{v:[42],a:1,l:'ドン'},warn:{v:[26,60,26],a:.8,l:'やわらかく2回(できない)',seq:[90]},success:{v:[18,60,18,60,46],a:.9,l:'トトトン(そろった)',seq:[80,160]},
  shutter:{v:[52,28,24],a:1,l:'カシャッ(強く2回)',seq:[70]},land:{v:[30],a:.85,l:'トン(フィルムに入る)'},
  heart:{v:[30,70,18],a:.9,l:'ドクン',seq:[100]},projector:{v:[8,38,8,38,8,38,8],a:.45,l:'カタカタ(映写機)',seq:[46,92,138]},
  buzz:{v:[120],a:.75,l:'ブルブル',seq:[40,80]},rumble:{v:[200],a:1,l:'ブルブルブル(つよく)',seq:[35,70,105,140,175]},vui:{v:[40,20,320],a:1,l:'ブイッ',seq:[60,120,180,240,300]}};
const sw=document.createElement('label');sw.innerHTML='<input type="checkbox" switch>';sw.style.cssText='position:fixed;left:-9999px;top:0;opacity:0;pointer-events:none';document.body.appendChild(sw);
const act=()=>!navigator.userActivation||navigator.userActivation.hasBeenActive;
let env=0,cont=0,contL='',lastT={};
function ios(){const ae=document.activeElement;if(ae&&ae.tagName==='INPUT'&&ae.type!=='checkbox')return;try{sw.click()}catch(e){}}
function hap(n,why,o={}){const h=HP[n];if(!h)return;const t=performance.now();if(o.gap&&lastT[n]&&t-lastT[n]<o.gap)return;lastT[n]=t;
  try{if(act()&&navigator.vibrate)navigator.vibrate(h.v)}catch(e){}ios();(h.seq||[]).forEach(d=>setTimeout(()=>{ios();env=Math.max(env,h.a*.8)},d));
  env=Math.max(env,h.a);$('hn').textContent=why||h.l;
  if(!o.norip&&pos&&['pop','click','thud','success','shutter','land','heart'].includes(n))ripple(h.a>=.9)
  if(h.a>=1&&!o.noq){phone.classList.remove('qk');void phone.offsetWidth;phone.classList.add('qk')}}
let contIv=0;function setCont(v,l){cont=v;if(l)contL=l;if(v<=0){contL='';clearInterval(contIv);contIv=0;return}
  if(!contIv)contIv=setInterval(()=>{try{if(act()&&navigator.vibrate&&cont>0)navigator.vibrate(Math.round(8+cont*32))}catch(e){}},80)}
const hw=$('hw'),hx=hw.getContext('2d'),HIS=new Array(80).fill(0);
(function draw(){env=Math.max(env*.86,cont);HIS.push(env);HIS.shift();hx.fillStyle='#111';hx.fillRect(0,0,hw.width,hw.height);const bw=hw.width/HIS.length;
  HIS.forEach((v,i)=>{const h=v*50;hx.fillStyle=v>.9?'#27AF42':v>.55?'#24A73E':'#9ED6A5';hx.fillRect(i*bw,hw.height-3-h,bw-1,h)});if(contL)$('hn').textContent=contL;requestAnimationFrame(draw)})();
let pos=null;phone.addEventListener('pointerdown',e=>{const r=phone.getBoundingClientRect();pos={x:(e.clientX-r.left)/SC,y:(e.clientY-r.top)/SC}},true);
function ripple(big){const R=$('rip');const mk=(c,s,d)=>{const i=document.createElement('i');i.className=c;i.style.left=pos.x+'px';i.style.top=pos.y+'px';i.style.setProperty('--s',s);i.style.animationDelay=d+'s';R.appendChild(i);setTimeout(()=>i.remove(),900)};mk(big?'o':'',big?6:3.5,0);if(big)mk('o',9,.08)}
function toast(m){const t=$('toast');t.textContent=m;t.classList.add('on');clearTimeout(t._t);t._t=setTimeout(()=>t.classList.remove('on'),1800)}

/* =================== 7セグ =================== */
const MAP={0:'abcdef',1:'bc',2:'abdeg',3:'abcdg',4:'bcfg',5:'acdfg',6:'acdefg',7:'abc',8:'abcdefg',9:'abcdfg'};
const SG={a:[0,0,'h'],g:[0,.5,'h'],d:[0,1,'h'],f:[0,0,'v'],b:[1,0,'v'],e:[0,.5,'v'],c:[1,.5,'v']};
function segs(ch,ox,w,h,t){const g=t*.62;let o='';for(const k of MAP[ch]||''){const[sx,sy,v]=SG[k];let p;
  if(v==='h'){const x=ox+g,y=sy*h,l=w-2*g;p=[[x,y],[x+t/2,y-t/2],[x+l-t/2,y-t/2],[x+l,y],[x+l-t/2,y+t/2],[x+t/2,y+t/2]]}
  else{const x=ox+sx*w,y=sy*h+g*.45,l=h/2-g*.9;p=[[x,y],[x+t/2,y+t/2],[x+t/2,y+l-t/2],[x,y+l],[x-t/2,y+l-t/2],[x-t/2,y+t/2]]}
  o+=`<polygon points="${p.map(q=>q.map(n=>n.toFixed(1)).join(',')).join(' ')}" stroke-width="3" stroke-linejoin="round"/>`}return o}
function seg1(d){return `<g transform="skewX(-6)"><g class="ghost">${segs('8',0,40,80,10)}</g><g class="lit">${segs(String(d),0,40,80,10)}</g></g>`}
function seg900(){let x=0,o='',gh='';const w=40,h=80,t=10;for(const c of '9:00'){if(c===':'){o+=`<circle cx="${x+6}" cy="${h*.3}" r="5.5"/><circle cx="${x+6}" cy="${h*.7}" r="5.5"/>`;x+=22;continue}gh+=segs('8',x,w,h,t);o+=segs(c,x,w,h,t);x+=58}
  return `<svg viewBox="-8 -8 ${x+4} ${h+16}"><g transform="skewX(-6)"><g class="ghost">${gh}</g><g class="lit" style="filter:drop-shadow(0 0 8px rgba(36,167,62,.8))">${o.replace(/<circle/g,'<circle fill="#24A73E"')}</g></g></svg>`}

/* =================== 状態 =================== */
let tags=[],shots=0,flash=true,cur='tag',busy=false;
const POP=[['#エモい','3.2k'],['#空','2.1k'],['#ぴえん','2.0k'],['#優勝','1.9k'],['#散歩','1.8k'],['#雨の日','1.6k'],['#きもかわ','1.5k'],['#夕焼け','1.4k'],['#やばい','1.3k'],['#放課後','1.2k'],['#ごはん','1.1k'],['#ねむい','980'],['#部活','940'],['#帰り道','860'],['#コーヒー','820'],['#テスト前','760'],['#いい匂い','610']];
const POP2=[['#チル','2.4k'],['#尊い','2.2k'],['#ガチ','2.0k'],['#推ししか勝たん','1.9k'],['#しんどい','1.7k'],['#映え','1.6k'],['#あざとい','1.5k'],['#草','1.4k'],['#まじむり','1.3k'],['#ちょうどいい','1.2k'],['#神','1.1k'],['#わかる','1.0k'],['#ウケる','950'],['#沼','900'],['#いとおかし','820'],['#ハピ','760'],['#ばえ','700']];


/* =================== タグ画面(黒・2つまで) =================== */
const TMAX=3;
const PIN='<svg viewBox="0 0 24 24" fill="#111"><path d="M12 2a7 7 0 00-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 00-7-7zm0 9.5A2.5 2.5 0 1112 6a2.5 2.5 0 010 5z"/></svg>';
const MOOD={'ごきげん':['#E9B63A','#FFE27A',-2,1],'ぼんやり':['#6F86E6','#AFC0FF',1.5],'わくわく':['#368345','#6FD483',-1],'#散歩':['#3A9558','#71CC8E',1],'ねむい':['#2C54D6','#6C8EFF',-1.5],'おだやか':['#0BB52D','#47F76A',1],
  'もやもや':['#85858C','#C4C4C9',1],'きんちょう':['#C26862','#92D59F',-1],'ふわふわ':['#D8619C','#F7A7CB',1.5],'さみしい':['#2443C4','#5B7AFF',-1],'うれしい':['#2A8E3E','#7CE290',1],'つかれた':['#6B57A6','#A792E2',-1.5]};
const R1=['ごきげん','ぼんやり','わくわく','#散歩','ねむい','おだやか'],R2=['もやもや','きんちょう','ふわふわ','さみしい','うれしい','つかれた'];
const EX=['雨の日','放課後','いい匂い','部活','帰り道','テスト前'];
const chipCls=(t,i)=>i%2?'b':'w';
function renderTags(newT){const c=$('chips');
  c.innerHTML=`<span class="tch loc">${PIN}Musashino</span>`+tags.map((t,i)=>`<span class="tch ${chipCls(t,i)}${t===newT?' in':''}" data-t="${t}">${t}</span>`).join('')+(tags.length<TMAX?'<span class="tadd" id="tadd">+ タグ</span>':'');
  c.querySelectorAll('.tch[data-t]').forEach(ch=>ch.onclick=()=>{ch.classList.add('out');hap('soft','やわらかく1回(はずす)');setTimeout(()=>{tags=tags.filter(x=>x!==ch.dataset.t);renderTags();syncTag()},260)});
  const ad=$('tadd');if(ad)ad.onclick=()=>{hap('tick','ごく軽く1回(書く)');tin.focus()};syncTag()}
function syncTag(){const n=tags.length,full=n>=TMAX;
  $('card').classList.toggle('full',full);$('tin').disabled=full;
  $('gon').textContent='';$('tcnt').textContent=n+' / '+TMAX;$('go').querySelector('b').textContent=n?'撮る':'つけずに撮る';$('go').classList.toggle('has',n>0);$('chips').classList.toggle('has',n>0);
  document.querySelectorAll('.mc').forEach(m=>m.classList.toggle('used',tags.includes(m.dataset.t)));
  $('add').classList.toggle('on',!!$('tin').value.trim()&&!full);$('tin').placeholder=full?TMAX+'つ えらびました':($('tin')===document.activeElement?'':$('tin').placeholder)}
function renderLeft(){const k=3-shots;$('tleft').innerHTML=Array.from({length:3},(_,i)=>`<i class="${i<k?'':'o'}"></i>`).join('')+`<span>のこり</span><b>${k}</b>`;$('go').classList.toggle('dead',k<=0)}
function commit(raw){let t=String(raw||'').replace(/^[#＃]+/,'').replace(/[\s　]+/g,'').slice(0,12);if(!t)return false;if(!MOOD[t]&&!MOOD['#'+t])t='#'+t;else if(MOOD['#'+t])t='#'+t;
  if(tags.includes(t)){hap('warn','やわらかく2回(もう入ってる)');shake($('card'));return false}
  if(tags.length>=TMAX){hap('warn','やわらかく2回(3つめは えらべない)');shake($('card'));toast('タグは '+TMAX+'つまで');return false}
  tags.push(t);renderTags(t);
  if(tags.length===TMAX){hideKb();hap('success');const s=$('sheen');s.classList.remove('go');void s.offsetWidth;s.classList.add('go');$('tin').blur()}else hap('pop','ぷにっ(タグが入った)');
  return true}
function shake(el){el.classList.remove('shake');void el.offsetWidth;el.classList.add('shake')}
const tin=$('tin');
tin.addEventListener('input',e=>{syncTag();if(e.isComposing)return;if(/[\s　]$/.test(tin.value)){if(commit(tin.value))tin.value='';syncTag()}});
tin.addEventListener('keydown',e=>{if(e.isComposing||e.keyCode===229)return;if(e.key==='Enter'){e.preventDefault();if(commit(tin.value))tin.value='';syncTag()}else if(e.key==='Backspace'&&!tin.value&&tags.length){const last=[...$('chips').querySelectorAll('.tch[data-t]')].pop();if(last)last.click()}});
tin.addEventListener('focus',()=>{stopPh();tin.placeholder='';showKb();hap('tick','ごく軽く1回(書く)')});
$('inrow').addEventListener('click',()=>{showKb()});
tin.addEventListener('blur',()=>{if(!tin.value)startPh()});
$('add').addEventListener('pointerdown',e=>e.preventDefault());
$('add').onclick=e=>{e.preventDefault();if(commit(tin.value))tin.value='';syncTag()};
// プレースホルダー:「じぶんの言葉で、かく」→ 例が タイプされる
let phT=0;function startPh(){stopPh();if(tags.length>=TMAX){tin.placeholder=TMAX+'つ えらびました';return}let i=0,j=0,dir=1,first=true;
  const step=()=>{if(first){tin.placeholder='雨の日';first=false;phT=setTimeout(step,2200);return}const w=EX[i%EX.length];if(dir>0){j++;if(j>w.length){dir=-1;phT=setTimeout(step,1400);return}}else{j--;if(j<0){dir=1;i++;j=0;if(i%3===0){first=true}phT=setTimeout(step,250);return}}
  tin.placeholder=w.slice(0,Math.max(0,j));phT=setTimeout(step,dir>0?95:40)};step()}
function stopPh(){clearTimeout(phT)}
startPh();
// 流れる ことば(2列・反対向き)
function fillMq(){const mk=L=>{const r=L.map(([t])=>`<button class="mc" data-t="${t}">${t}</button>`).join('');return r+r+r};
  document.querySelector('#mq1 .mqt').innerHTML=mk(POP);document.querySelector('#mq2 .mqt').innerHTML=mk(POP2);
  document.querySelectorAll('.mc').forEach(m=>m.addEventListener('click',()=>flyIn(m)));
  ['mq1','mq2'].forEach(id=>{const q=$(id);q.addEventListener('pointerdown',()=>{q.classList.add('hold');hap('tick','ごく軽く1回(とめる)',{norip:1})});['pointerup','pointerleave','pointercancel'].forEach(ev=>q.addEventListener(ev,()=>q.classList.remove('hold')))})}
/* ふうの キーボード(モック用・実機では 本物が 出る) */
const KB=[['→','あ','か','さ','⌫'],['↺','た','な','は','空白'],['ABC','ま','や','ら','✓'],['😊','^_^','わ_','、。?!','']];
(function(){const K=$('kbd');K.innerHTML=KB.map((r,ri)=>r.map((k,ci)=>k===''?'':`<button class="k${ci===0?' fn':''}${k==='⌫'||k==='空白'?' fn':''}${k==='✓'?' ok':''}" data-k="${k}">${k==='空白'?'空白':k}</button>`).join('')).join('')+'<i class="kg">🌐</i><i class="km">🎙</i>';
  K.querySelectorAll('button').forEach(b=>{b.addEventListener('pointerdown',e=>e.preventDefault());b.onclick=()=>{const k=b.dataset.k;
    if(k==='⌫'){tin.value=tin.value.slice(0,-1);hap('tick',null,{norip:1})}
    else if(k==='空白'||k==='✓'){if(tin.value.trim()){if(commit(tin.value))tin.value=''}else hap('tick',null,{norip:1});if(k==='✓')hideKb()}
    else if(['→','↺','ABC','😊','^_^','、。?!'].includes(k)){hap('tick',null,{norip:1})}
    else{if(tin.value.length<12)tin.value+=k;hap('tick',null,{norip:1});stopPh()}
    syncTag()}})})();
function showKb(){if(tags.length>=TMAX)return;$('tag').classList.add('kb')}
function hideKb(){$('tag').classList.remove('kb');tin.blur();if(!tin.value)startPh()}
fillMq();
/* 音楽(モック:実機では MusicKit / Spotify) */
const MUS={am:[['放課後ライト','ミナト'],['ひるさがり','ことり'],['雨のち、すき','NAGI'],['ゆうやけ通り','ハル'],['いつメンのうた','4(フォー)'],['ねむれない夜に','ソラ']],sp:[['Afterschool Blue','minato'],['Hiru no Sora','kotori'],['Amenochi Suki','NAGI'],['Yuyake Dori','haru'],['Itsumen','Four'],['Midnight Soft','sora']]};
const MCO=['linear-gradient(135deg,#61D278,#EE5E9C)','linear-gradient(135deg,#9ED8FF,#9B8CFF)','linear-gradient(135deg,#C8F25A,#18FA45)','linear-gradient(135deg,#63DC7B,#FFD25A)','linear-gradient(135deg,#B28CFF,#F27CC0)','linear-gradient(135deg,#5AC8FF,#2A3A8A)'];
var MS='am',MCON={am:false,sp:false},MPICK=-1,MSEL=null;
function renderMus(){const q=($('min').value||'').trim().toLowerCase();const L=MUS[MS].map((s,i)=>[s,i]).filter(([s])=>!q||s.join(' ').toLowerCase().includes(q));
  $('mlist').innerHTML=L.length?L.map(([s,i])=>`<button class="mrow${MPICK===i?' on':''}" data-i="${i}"><i style="background:${MCO[i]}"></i><span><b>${s[0]}</b><small>${s[1]}</small></span><u><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></u></button>`).join(''):'<p class="mnone">みつかりませんでした</p>';
  $('mlist').querySelectorAll('.mrow').forEach(r=>r.onclick=()=>{MPICK=+r.dataset.i;hap('sel','コツッ(えらぶ)');renderMus();syncMus()})}
function syncMus(){const ok=MPICK>=0;$('mgo').classList.toggle('on',ok);$('mgo').textContent=ok?'この曲にする':'曲を えらんでください';$('mrm').hidden=!MSEL}
function viewMus(){const c=MCON[MS];$('mcon').hidden=c;$('mbody').hidden=!c;$('mconp').innerHTML=MS==='am'?'Apple Music の 曲を えらべます。<br>ライブラリの 中身は 見ません。':'Spotify の 曲を えらべます。<br>つなぐと ブラウザが ひらきます。';$('mconb').textContent=(MS==='am'?'Apple Music':'Spotify')+' と つなぐ';$('mseg').dataset.s=MS;$('mseg').querySelectorAll('button').forEach(b=>b.classList.toggle('on',b.dataset.s===MS));if(c)renderMus()}
$('msc').onclick=()=>{hap('pop','ぷにっ(音楽)');MPICK=MSEL?MSEL.i:-1;MS=MSEL?MSEL.s:MS;viewMus();syncMus();openSheet('shm')};
$('mseg').querySelectorAll('button').forEach(b=>b.onclick=()=>{if(b.dataset.s===MS)return;MS=b.dataset.s;MPICK=-1;hap('sel','コツッ(きりかえ)',{norip:1});viewMus();syncMus()});
$('mconb').onclick=()=>{const b=$('mconb');b.textContent='つないでいます…';b.classList.remove('on');hap('tick',null,{norip:1});setTimeout(()=>{MCON[MS]=true;hap('success','やさしく2回(つながった)');viewMus();syncMus()},800)};
$('min').addEventListener('input',()=>{renderMus()});
$('mgo').onclick=()=>{if(MPICK<0){hap('warn','やわらかく2回(まだ)');return}MSEL={s:MS,i:MPICK};const s=MUS[MS][MPICK];hap('success','やさしく2回(きまった)');closeSheet('shm');setMus()};
$('mrm').onclick=()=>{MSEL=null;MPICK=-1;hap('soft','ふわっ(はずす)');closeSheet('shm');setMus()};
function setMus(){const b=$('msc'),s=MSEL&&MUS[MSEL.s][MSEL.i];b.classList.toggle('has',!!s);if(s){b.querySelector('#mscl b').textContent=s[0];b.querySelector('#mscl small').textContent=s[1];$('mdisc').style.background=MCO[MSEL.i];b.animate([{scale:'.86'},{scale:'1.05',offset:.6},{scale:'1'}],{duration:460,easing:'cubic-bezier(.3,1.5,.4,1)'})}}
function rel(el){const r=el.getBoundingClientRect(),p=phone.getBoundingClientRect();return{x:(r.left-p.left)/SC,y:(r.top-p.top)/SC,w:r.width/SC,h:r.height/SC}}
function flyIn(m){const t=m.dataset.t;if(tags.includes(t)){hap('warn','やわらかく2回(もう入ってる)');return}if(tags.length>=TMAX){hap('warn','やわらかく2回(3つめは えらべない)');shake($('card'));toast('タグは '+TMAX+'つまで');return}
  hap('sel','コツッ(つまむ)');const a=rel(m);const tgt=$('tadd')||$('chips');const b=rel(tgt);
  const f=m.cloneNode(true);f.classList.add('fly');f.style.cssText+=`;position:absolute;left:${a.x}px;top:${a.y}px;width:${a.w}px;height:${a.h}px;margin:0;z-index:40`;phone.appendChild(f);
  const dx=b.x-a.x,dy=b.y-a.y;
  f.animate([{transform:'translate(0,0) scale(1)'},{transform:`translate(${dx*.5}px,${dy*.5-70}px) scale(1.14) rotate(-6deg)`,offset:.5},{transform:`translate(${dx}px,${dy}px) scale(.9)`,opacity:.2}],{duration:460,easing:'cubic-bezier(.4,0,.2,1)'}).onfinish=()=>{f.remove();commit(t)}}
$('go').onclick=()=>{if(shots>=3){hap('warn','やわらかく2回(今日は、ここまで)');shake($('go'));toast('今日は、ここまで ・ 9:00 に ひらきます');return}
  const s=$('go').querySelector('.ts1');s.animate([{transform:'scale(1)'},{transform:'scale(.9)',offset:.35},{transform:'scale(1)'}],{duration:260});hap('click','カチッ(撮影へ)');hideKb();setTimeout(toCam,120)};
$('tx').onclick=()=>{hap('tick','ごく軽く1回(もどる)');toHome()};
function entTag(){const s=$('tag');showKb();s.classList.add('ent');[...s.querySelectorAll('.rv')].forEach((r,i)=>r.style.transitionDelay=(.05+i*.06)+'s');requestAnimationFrame(()=>requestAnimationFrame(()=>s.classList.remove('ent')));setTimeout(()=>[...s.querySelectorAll('.rv')].forEach(r=>r.style.transitionDelay=''),1200)}

/* =================== 画面の切りかえ =================== */
function syncCtl(){document.querySelectorAll('#ctl button[data-c="home"],#ctl button[data-c="tag"],#ctl button[data-c="cam"]').forEach(b=>b.classList.toggle('on',b.dataset.c===cur))}
function show(id){['home','tag','cam','dev'].forEach(s=>{$(s).classList.toggle('on',s===id);$(s).getAnimations().forEach(a=>a.cancel())});cur=id;phone.classList.toggle('lt',id==='home');syncCtl()}
function fadeTo(id,ms,after){const from=$(cur),to=$(id);if(from===to){after&&after();return}
  to.classList.add('on');to.animate([{opacity:0,transform:'scale(1.03)'},{opacity:1,transform:'none'}],{duration:ms,easing:'cubic-bezier(.2,.8,.2,1)'});
  from.animate([{opacity:1,transform:'none'},{opacity:0,transform:'scale(.96)'}],{duration:ms*.8,fill:'forwards'}).onfinish=()=>{from.classList.remove('on');from.getAnimations().forEach(a=>a.cancel())};
  cur=id;phone.classList.toggle('lt',id==='home');syncCtl();setTimeout(()=>after&&after(),ms)}
const BR=[...document.querySelectorAll('.br')];const BD=[[1,1],[-1,1],[1,-1],[-1,-1]];
function setBr(k){BR.forEach((b,i)=>b.style.transform=`translate(${BD[i][0]*k}px,${BD[i][1]*k}px)`)}
const WK_IN=[{left:'0px',right:'0px',top:'0px',height:'844px',borderRadius:'54px'},{left:'27px',right:'27px',top:'126px',height:'472px',borderRadius:'24px',offset:.58},{left:'13px',right:'13px',top:'108px',height:'507px',borderRadius:'32px',offset:.8},{left:'16px',right:'16px',top:'112px',height:'500px',borderRadius:'30px'}];
const WK_OUT=[{left:'16px',right:'16px',top:'112px',height:'500px',borderRadius:'30px'},{left:'0px',right:'0px',top:'0px',height:'844px',borderRadius:'54px'}];
// タグ → 撮影:はじが キュッと しまる
var bT=0;function lock(){busy=true;clearTimeout(bT);bT=setTimeout(()=>{busy=false},1300)}
function toCam(){if(busy||cur==='cam')return;lock();stopPh();tin.blur();renderCam();
  const from=$(cur),cam=$('cam');cam.classList.add('on','enter');
  const an=from.animate([{opacity:1,transform:'none',filter:'blur(0px)'},{opacity:0,transform:'scale(.93)',filter:'blur(8px)'}],{duration:320,easing:'cubic-bezier(.5,0,.6,1)',fill:'forwards'});toCam._an=an;toCam._from=from;an.onfinish=()=>{from.classList.remove('on');from.getAnimations().forEach(a=>a.cancel());toCam._an=null};
  cur='cam';phone.classList.remove('lt');syncCtl();
  $('win').animate(WK_IN,{duration:720,easing:'cubic-bezier(.6,0,.25,1)'});
  $('live').animate([{transform:'scale(1.1)'},{transform:'scale(.985)',offset:.6},{transform:'scale(1)'}],{duration:720,easing:'cubic-bezier(.6,0,.25,1)'});
  const S=[[-16,-112],[16,-112],[-16,232],[16,232]];
  BR.forEach((b,i)=>b.animate([{transform:`translate(${S[i][0]}px,${S[i][1]}px)`,opacity:0},{transform:`translate(${BD[i][0]*11}px,${BD[i][1]*11}px)`,opacity:1,offset:.58},{transform:`translate(${-BD[i][0]*3}px,${-BD[i][1]*3}px)`,offset:.8},{transform:'translate(0,0)'}],{duration:720,easing:'cubic-bezier(.6,0,.25,1)'}));
  const t0=performance.now();const rp=()=>{const k=(performance.now()-t0)/420;if(k<1){setCont(.15+k*.7,'ぎゅーっ(はじが しまる)');requestAnimationFrame(rp)}};requestAnimationFrame(rp);
  setTimeout(()=>{setCont(0);hap('click','キュッ(はじが しまった)',{norip:1})},420);
  setTimeout(()=>hap('tick','ごく軽く1回(もどる)',{norip:1}),580);
  setTimeout(()=>{cam.classList.remove('enter');busy=false},720)}
function leaveCam(to,after){const cam=$('cam');if(toCam._an){toCam._an.onfinish=null;try{toCam._an.cancel()}catch(e){}toCam._an=null}
  if(toCam._from&&toCam._from!==$(to)){toCam._from.classList.remove('on');toCam._from.getAnimations().forEach(a=>a.cancel())}$('win').animate(WK_OUT,{duration:420,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'});
  const nx=$(to);nx.classList.add('on');nx.animate([{opacity:0,transform:'scale(1.04)'},{opacity:1,transform:'none'}],{duration:420,delay:100,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'});
  cam.animate([{opacity:1},{opacity:0}],{duration:380,delay:120,fill:'forwards'}).onfinish=()=>{cam.classList.remove('on');cam.getAnimations().forEach(a=>a.cancel());$('win').getAnimations().forEach(a=>a.cancel())};
  cur=to;phone.classList.toggle('lt',to==='home');syncCtl();setTimeout(()=>after&&after(),520)}
function toTag(){if(busy||cur==='tag')return;lock();hap('soft','やわらかく1回(もどる)');
  const done=()=>{busy=false;entTag();if(!tin.value)startPh()};if(cur==='cam')leaveCam('tag',done);else fadeTo('tag',380,done)}
function toHome(){if(busy||cur==='home')return;lock();renderHome();homeFocus();const done=()=>{busy=false};if(cur==='cam')leaveCam('home',done);else fadeTo('home',380,done)}

/* =================== 撮影画面 =================== */
const lv=$('live'),lx=lv.getContext('2d');let BK=[];
(function(){for(let i=0;i<70;i++)BK.push({x:Math.random()*390,y:120+Math.random()*560,r:5+Math.random()*34,c:['255,170,90','255,120,150','255,220,140','120,190,255','200,150,255'][i%5],a:.12+Math.random()*.4,s:.2+Math.random()*.6})})();
const BLD=Array.from({length:14},(_,i)=>({x:i*30-10+Math.random()*10,w:26+Math.random()*24,h:120+Math.random()*240}));
function drawLive(t){lx.setTransform(2,0,0,2,0,0);const sx=Math.sin(t*.0007)*3,sy=Math.cos(t*.0009)*2;
  const g=lx.createLinearGradient(0,0,0,844);g.addColorStop(0,'#0c1022');g.addColorStop(.45,'#251a33');g.addColorStop(.75,'#3a2430');g.addColorStop(1,'#120c10');lx.fillStyle=g;lx.fillRect(0,0,390,844);
  lx.save();lx.translate(sx,sy);
  BLD.forEach(b=>{lx.fillStyle='#0a0a12';lx.fillRect(b.x,600-b.h,b.w,b.h+260);lx.fillStyle='rgba(128,227,148,.35)';for(let yy=600-b.h+10;yy<590;yy+=16)for(let xx=b.x+5;xx<b.x+b.w-5;xx+=9)if(((xx*7+yy*3)|0)%5===0)lx.fillRect(xx,yy,4,6)});
  const rg=lx.createLinearGradient(0,600,0,844);rg.addColorStop(0,'rgba(89,219,115,.35)');rg.addColorStop(1,'rgba(20,10,10,0)');lx.fillStyle=rg;lx.fillRect(0,600,390,244);
  lx.globalCompositeOperation='lighter';BK.forEach(b=>{const x=(b.x+Math.sin(t*.0003*b.s+b.r)*12),y=b.y+Math.cos(t*.0002*b.s+b.x)*8;const gg=lx.createRadialGradient(x,y,0,x,y,b.r);gg.addColorStop(0,`rgba(${b.c},${b.a})`);gg.addColorStop(.7,`rgba(${b.c},${b.a*.6})`);gg.addColorStop(1,`rgba(${b.c},0)`);lx.fillStyle=gg;lx.beginPath();lx.arc(x,y,b.r,0,7);lx.fill()});
  lx.globalCompositeOperation='source-over';lx.restore();
  const v=lx.createRadialGradient(195,380,120,195,380,520);v.addColorStop(0,'rgba(0,0,0,0)');v.addColorStop(1,'rgba(0,0,0,.55)');lx.fillStyle=v;lx.fillRect(0,0,390,844)}
/* 動画の撮影中も ふつうの画面(加工なし・ぐらぐらなし)。レトロ加工は「現像された動画」だけ。 */
let mode='photo';
(function loop(t){if(cur==='cam'||$('cam').classList.contains('on'))drawLive(t);requestAnimationFrame(loop)})(0);
// シャッターの目もり(24)
const TK=24;(function(){let o='';for(let i=0;i<TK;i++){const a=(-90+i*360/TK)*Math.PI/180,big=i%8===0,r1=big?55:56,r2=big?62:59.5;o+=`<line class="tk${big?' big':''}" x1="${(52+r1*Math.cos(a)).toFixed(2)}" y1="${(52+r1*Math.sin(a)).toFixed(2)}" x2="${(52+r2*Math.cos(a)).toFixed(2)}" y2="${(52+r2*Math.sin(a)).toFixed(2)}"/>`}$('tks').innerHTML=o})();
const TKS=[...document.querySelectorAll('#tks .tk')];
function renderCam(){$('seg').innerHTML=seg1(3-shots);renderLeft&&renderLeft();
  const mu=MSEL&&MUS[MSEL.s][MSEL.i];const tg0=mu?`<span class="tg glass">♪ ${mu[0]}</span>`:'';const tg=[`<span class="tg pl glass"><svg viewBox="0 0 24 24" fill="#A3EBB1"><path d="M12 2a7 7 0 00-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 00-7-7zm0 9.5A2.5 2.5 0 1112 6a2.5 2.5 0 010 5z"/></svg>渋谷区</span>`].concat((tags.length?tags:['#タグなし']).slice(0,2).map(t=>`<span class="tg glass">${t}</span>`));
  if(tags.length>2)tg.push(`<span class="tg glass">+${tags.length-2}</span>`);
  $('ctags').innerHTML=tg.join('')+tg0;document.querySelectorAll('#ctags .tg').forEach(x=>x.onclick=()=>{hap('tick','ごく軽く1回(タグを なおす)');toTag()});
  let n='';for(let i=0;i<3;i++){const a=(-90+(i-1)*14)*Math.PI/180;n+=`<circle cx="${(52+49*Math.cos(a)).toFixed(1)}" cy="${(52+49*Math.sin(a)).toFixed(1)}" r="${i<3-shots?3.4:2.4}" fill="${i<3-shots?'#24A73E':'#4a4a52'}"/>`}$('notch').innerHTML=n;
  $('stack').innerHTML=shots?Array.from({length:shots},(_,i)=>`<div class="ck" style="transform:rotate(${[-8,4,-2][i]}deg) translate(${i*2}px,${-i*2}px)"><i></i></div>`).join(''):'<i class="em"></i>';
  $('stt').textContent=shots+' / 3';$('sh').classList.toggle('dead',shots>=3);
  $('hint').innerHTML=shots>=3?'今日は、ここまで':mode==='movie'?'ながおしで まわす ・ はなすと とまる ・ 音量ボタンも':'ながおしで撮る ・ 音量ボタンも ながおし'}
$('fl').onclick=()=>{flash=!flash;$('fl').classList.toggle('on',flash);$('flt').textContent=flash?'AUTO':'OFF';hap('click',flash?'カチッ(フラッシュ AUTO)':'カチッ(フラッシュ OFF)')};
$('st')&&($('st').onclick=()=>{hap('soft');toast(shots?'あしたの朝、仕上がります':'まだ 撮っていません')});
$('cback').onclick=()=>{hap('tick','ごく軽く1回(もどる)');if(cur==='cam'&&busy&&!$('cam').classList.contains('shooting'))busy=false;toTag()};

/* ---------- 長押し(1.5秒) ---------- */
const HOLD=1500;let hT0=0,hRaf=0,lit=0;const sh=$('sh'),disc=$('disc'),prog=$('prog'),sgl=$('sglow');
const DOTS=n=>['○ ○ ○','● ○ ○','● ● ○','● ● ●'][n];
let src='screen';const volK=k=>{const v=$('vol');v.style.setProperty('--k',k)};
sh.addEventListener('pointerdown',e=>holdStart(e.pointerId,'screen'));
function holdStart(pid,s){if(busy||hT0||mvRec)return;if(shots>=3){hap('warn','やわらかく2回(今日は、ここまで)');shake(sh);return}
  src=s;if(s==='vol')$('vol').classList.add('hold');
  if(mode==='movie'){mvStart(pid);return}
  if(pid!=null)try{sh.setPointerCapture(pid)}catch(_){}sh.classList.add('hold');hT0=performance.now();lit=0;hap('pop','ぷにっ(押しこむ)',{norip:1});$('win').classList.add('focus');
  $('hint').innerHTML=`<b>${DOTS(0)}</b>  そのまま`;
  const st=now=>{if(!hT0)return;const k=clamp((now-hT0)/HOLD,0,1),e=k*k*(3-2*k);
    const want=Math.min(TK,Math.floor(TK*Math.pow(k,1.25)));
    while(lit<want){TKS[lit].classList.add('on');lit++;if(lit%8===0&&lit<TK){const st3=lit/8;hap('click',`カチッ(${st3} / 3)`,{norip:1});$('hint').innerHTML=`<b>${DOTS(st3)}</b>  ${st3===1?'もうすこし':'いま'}`}else hap('tick',null,{norip:1})}
    const tr=k>.55?(k-.55)*3.4:0;const jx=(Math.random()-.5)*tr,jy=(Math.random()-.5)*tr;
    prog.style.strokeDashoffset=(307.9*(1-k)).toFixed(1);disc.style.transform=`translate(${jx.toFixed(2)}px,${jy.toFixed(2)}px) scale(${(1-.64*e).toFixed(3)})`;
    sh.style.transform=`scale(${(.95+.09*e).toFixed(3)})`;sgl.style.opacity=(e*.95).toFixed(2);sgl.style.transform=`scale(${(.5+.8*e).toFixed(3)})`;volK(k.toFixed(3));
    setBr(-8*e);$('live').style.transform=`scale(${1+.045*e})`;setCont(.12+.78*k,'じわっと強くなる(ためる)');
    if(k>=1){hT0=0;snap()}else hRaf=requestAnimationFrame(st)};hRaf=requestAnimationFrame(st)}
function rewind(){const n0=lit;let i=0;const iv=setInterval(()=>{if(lit<=0){clearInterval(iv);return}lit--;TKS[lit].classList.remove('on');if(i++%3===0)hap('tick',null,{norip:1,gap:30})},14)}
const hUp=()=>{$('vol').classList.remove('hold');volK(0);if(mvRec){mvEnd();return}if(!hT0)return;cancelAnimationFrame(hRaf);hT0=0;setCont(0);sh.classList.remove('hold');disc.style.transform='';sh.style.transform='';sgl.style.opacity=0;sgl.style.transform='scale(.5)';
  prog.style.transition='stroke-dashoffset .35s';prog.style.strokeDashoffset=307.9;setTimeout(()=>prog.style.transition='',360);rewind();
  setBr(0);$('live').style.transform='';$('win').classList.remove('focus');hap('soft','やわらかく1回(はなした)');const h=$('hint');h.innerHTML='もうすこし、長く';h.classList.remove('p');void h.offsetWidth;h.classList.add('p');setTimeout(()=>{if(!hT0)renderCam()},1300)};
sh.addEventListener('pointerup',hUp);sh.addEventListener('pointercancel',hUp);
function snap(){setCont(0);sh.classList.remove('hold');
  disc.animate([{transform:'scale(.36)'},{transform:'scale(.1)',offset:.3},{transform:'scale(1.1)',offset:.75},{transform:'scale(1)'}],{duration:320,easing:'cubic-bezier(.3,1.3,.5,1)'});
  const r=document.createElement('i');r.className='sring';$('cam').appendChild(r);r.animate([{transform:'scale(.6)',opacity:1},{transform:'scale(2.4)',opacity:0}],{duration:520,easing:'cubic-bezier(.2,.8,.2,1)'}).onfinish=()=>r.remove();
  shoot(src==='vol')}
function resetShutter(){disc.style.transform='';sh.style.transform='';sgl.style.opacity=0;sgl.style.transform='scale(.5)';prog.style.transition='stroke-dashoffset .5s';prog.style.strokeDashoffset=307.9;setTimeout(()=>prog.style.transition='',520);
  TKS.forEach(t=>t.classList.remove('on'));lit=0;volK(0);setBr(0);$('live').style.transform='';$('win').classList.remove('focus')}


/* ---------- 動画:押して まわす → はなして とめる ---------- */
const MV_MAX=10,MV_CHG=620;let mvRec=null;
function setMode(m){if(mode===m||busy||mvRec)return;mode=m;window.__m=m;tickClock();$('cam').classList.toggle('mv',m==='movie');$('mode').classList.toggle('mv',m==='movie');
  document.querySelectorAll('#mode button').forEach(b=>b.classList.toggle('on',b.dataset.m===m));$('wtxt').textContent=m==='movie'?'LIVE ・ 30fps':'LIVE ・ ISO 400';
  hap('sel','コツッ('+(m==='movie'?'動画':'写真')+'に きりかえ)');setTimeout(()=>hap('tick','ごく軽く1回(おさまる)',{norip:1}),90);
  $('live').animate([{filter:'brightness(1.25)'},{filter:'none'}],{duration:240,easing:'ease-out'});
  const h=$('hint');renderCam();h.classList.remove('p');void h.offsetWidth;h.classList.add('p');
  }
document.querySelectorAll('#mode button').forEach(b=>b.addEventListener('click',()=>setMode(b.dataset.m)));
// ファインダーを よこになぞって きりかえ
(function(){let sx=0,sy=0,on=false;lv.addEventListener('pointerdown',e=>{sx=e.clientX;sy=e.clientY;on=true});
  lv.addEventListener('pointerup',e=>{if(!on)return;on=false;const dx=(e.clientX-sx)/SC,dy=(e.clientY-sy)/SC;if(Math.abs(dx)>46&&Math.abs(dy)<40)setMode(dx<0?'movie':'photo')})})();
function mvStart(pid){if(pid!=null)try{sh.setPointerCapture(pid)}catch(_){}sh.classList.add('hold');mvRec={t0:performance.now(),ph:0,st:0,lit:0,raf:0,tk:0};
  hap('pop','ぷにっ(押しこむ)',{norip:1});$('hint').innerHTML='<b>● ● ●</b>  ためる';
  const step=now=>{const r=mvRec;if(!r)return;
    if(r.ph===0){const k=clamp((now-r.t0)/MV_CHG,0,1),e2=k*k*(3-2*k);
      disc.style.transform=`scale(${(1-.30*e2).toFixed(3)})`;sh.style.transform=`scale(${(.95+.07*e2).toFixed(3)})`;sgl.style.opacity=(e2*.85).toFixed(2);sgl.style.transform=`scale(${(.5+.7*e2).toFixed(3)})`;
      prog.style.strokeDashoffset=(307.9*(1-.06*k)).toFixed(1);volK(k.toFixed(3));const want=Math.floor(k*4);while(r.tk<want){r.tk++;hap('tick',null,{norip:1})}
      setCont(.12+.5*k,'じわっと(ためる)');if(k>=1){r.ph=1;r.st=now;mvGo()}
    }else{const k=clamp((now-r.st)/(MV_MAX*1000),0,1),f=.06+.94*k;
      prog.style.strokeDashoffset=(307.9*(1-f)).toFixed(1);const want=Math.min(TK,Math.floor(TK*f));while(r.lit<want){TKS[r.lit].classList.add('on');r.lit++;hap('tick',null,{norip:1,gap:60})}
      const sec=k*MV_MAX;$('rect').textContent='00:'+p2(Math.floor(sec));
      if(k>.7){if(!sh.classList.contains('late')){sh.classList.add('late');$('hint').innerHTML='<b>● REC</b>  もうすぐ 10びょう'}setCont(.16+(k-.7)/.3*.6,'ぎゅーっ(のこり わずか)')}
      if(k>=1){mvEnd(true);return}}
    r.raf=requestAnimationFrame(step)};mvRec.raf=requestAnimationFrame(step)}
function mvGo(){hap('thud','ドン(まわりはじめた)',{norip:1});setTimeout(()=>hap('click','カチッ(フィルムが かかった)',{norip:1}),90);
  sh.classList.add('rec');$('cam').classList.add('recording');volK(1);$('mode').classList.add('hide');$('recp').classList.add('on');$('rect').textContent='00:00';
  disc.style.transform='';sh.style.transform='';setCont(.14,'カラカラ(フィルムが まわる)');$('hint').innerHTML='<b>● REC</b>  そのまま';
  const r=document.createElement('i');r.className='sring';$('cam').appendChild(r);r.animate([{transform:'scale(.6)',opacity:1},{transform:'scale(2.2)',opacity:0}],{duration:480,easing:'cubic-bezier(.2,.8,.2,1)'}).onfinish=()=>r.remove()}
function mvReset(){sh.classList.remove('hold','rec','late');$('cam').classList.remove('recording');$('mode').classList.remove('hide');$('recp').classList.remove('on');
  disc.style.transform='';sh.style.transform='';sgl.style.opacity=0;sgl.style.transform='scale(.5)';prog.style.transition='stroke-dashoffset .4s';prog.style.strokeDashoffset=307.9;setTimeout(()=>prog.style.transition='',420);
  TKS.forEach(t=>t.classList.remove('on'));volK(0);$('vol').classList.remove('hold');setCont(0)}
function mvEnd(auto){const r=mvRec;if(!r)return;mvRec=null;cancelAnimationFrame(r.raf);setCont(0);
  const dur=r.ph?(performance.now()-r.st)/1000:0;
  if(!r.ph){mvReset();hap('soft','やわらかく1回(はなした)');renderCam();return}
  if(dur<1&&!auto){mvReset();hap('warn','やわらかく2回(1秒より みじかい)');toast('1秒より みじかいと 撮れません');setTimeout(renderCam,200);return}
  hap(auto?'thud':'click',auto?'ドン(10びょう ぴったり)':'カチッ(とまった)',{norip:1});setTimeout(()=>hap('soft','やわらかく1回(テープが とまる)',{norip:1}),110);
  mvReset();shoot(false,Math.min(10,Math.round(dur*10)/10))}

/* ---------- 撮る → 毎回ホームへ ---------- */
function shoot(vol,mvd){if(busy||shots>=3)return;busy=true;setCont(0);
  if(vol){const v=$('vol');v.classList.remove('go');void v.offsetWidth;v.classList.add('go')}
  const snapImg=lv.toDataURL('image/jpeg',.7);if(!mvd)hap('shutter',null,{norip:1});
  const bl=$('blink'),wf=$('wfl');bl.animate(mvd?[{opacity:0},{opacity:.7,offset:.3},{opacity:0}]:[{opacity:0},{opacity:1,offset:.25},{opacity:1,offset:.55},{opacity:0}],{duration:mvd?220:150});
  if(!mvd)setTimeout(()=>{wf.animate([{opacity:flash?1:.55},{opacity:0}],{duration:flash?420:260,easing:'ease-out'});if(flash){const f=document.createElement('div');f.style.cssText='position:absolute;inset:0;background:#fff;z-index:45;pointer-events:none';phone.appendChild(f);f.animate([{opacity:.85},{opacity:0}],{duration:360}).onfinish=()=>f.remove()}},120);
  setTimeout(resetShutter,220);
  const ck=document.createElement('div');ck.className='cheki';ck.style.cssText='left:16px;top:112px;width:358px;height:500px;border-radius:30px';
  ck.innerHTML=`<div class="im" style="left:0;top:0;right:0;bottom:0"><img src="${snapImg}"><b></b>${mvd?'<u class="sp l"></u><u class="sp r"></u>':''}</div><span class="d">${DT}</span>${mvd?`<span class="mvt">▶ ${fmtD(mvd)}</span>`:''}`;if(mvd)ck.classList.add('mv');phone.appendChild(ck);
  const im=ck.querySelector('.im'),milk=ck.querySelector('b'),dd=ck.querySelector('.d');
  const E='cubic-bezier(.3,1.3,.45,1)';
  setTimeout(()=>{milk.animate([{opacity:0},{opacity:.96}],{duration:420,fill:'forwards'});
    ck.animate([{left:'16px',top:'112px',width:'358px',height:'500px',borderRadius:'30px',transform:'rotate(0deg)'},{left:'95px',top:'250px',width:'200px',height:'250px',borderRadius:'5px',transform:'rotate(-5deg)'}],{duration:480,easing:E,fill:'forwards'});
    im.animate([{left:'0px',top:'0px',right:'0px',bottom:'0px'},{left:'10px',top:'10px',right:'10px',bottom:'42px'}],{duration:480,easing:E,fill:'forwards'});
    dd.animate([{opacity:0},{opacity:1}],{duration:250,delay:300,fill:'forwards'});const mt=ck.querySelector('.mvt');if(mt)mt.animate([{opacity:0},{opacity:1}],{duration:250,delay:300,fill:'forwards'});setTimeout(()=>hap('pop',mvd?'ぷにっ(動くチェキになった)':'ぷにっ(チェキになった)',{norip:1}),300)},230);
  // カメラが ひらいて、ホームへ
  setTimeout(()=>{renderHome();homeFocus(1);hap('soft','ふわっ(ホームへ)',{norip:1});leaveCam('home')},780);
  // 物干しへ とんでいく
  setTimeout(()=>{const T=rel($('tck'));const tx=T.x,ty=T.y,tw=64,th=76;
    setCont(.45,'ジーッ(フィルムが 送られる)');
    ck.animate([{left:'95px',top:'250px',width:'200px',height:'250px',transform:'rotate(-5deg)'},{left:'150px',top:'330px',width:'130px',height:'160px',transform:'rotate(8deg)',offset:.5},{left:tx+'px',top:ty+'px',width:tw+'px',height:th+'px',transform:'rotate(-4deg)'}],{duration:600,easing:'cubic-bezier(.5,0,.25,1)',fill:'forwards'});
    im.animate([{left:'10px',top:'10px',right:'10px',bottom:'42px'},{left:'5px',top:'5px',right:'5px',bottom:'17px'}],{duration:600,fill:'forwards'});dd.animate([{opacity:1},{opacity:0}],{duration:240,fill:'forwards'});const mt2=ck.querySelector('.mvt');if(mt2)mt2.animate([{opacity:1},{opacity:0}],{duration:240,fill:'forwards'})},1080);
  setTimeout(()=>{setCont(0);ck.remove();KIND[shots]=mvd?{m:1,d:mvd}:null;shots++;renderHome(shots-1);$('tcard').animate([{transform:'scale(1)'},{transform:'scale(1.03)',offset:.3},{transform:'scale(1)'}],{duration:420,easing:'cubic-bezier(.3,1.5,.5,1)'});hap('land','トン(今日のカードに とまった)',{norip:1});renderCam();busy=false;if(shots>=3)setTimeout(dayDone,520)},1700)}
/* 音量ボタン(サイドボタン)= ながおし。写真も動画も、画面のシャッターと まったく同じ動き。
   モックでは キーボードの V を押しつづける / 上の「音量ボタン」を押しつづける、で ためせます。 */
let vDown=false;
function volDown(){if(vDown)return;if(cur!=='cam'){toast('撮影画面で ためしてね');return}vDown=true;hap('click','カチッ(音量ボタンを おした)',{norip:1});holdStart(null,'vol')}
function volUp(){if(!vDown)return;vDown=false;hUp()}
addEventListener('keydown',e=>{if(e.target===tin||e.repeat)return;if(e.key==='v'||e.key==='V')volDown()});
addEventListener('keyup',e=>{if(e.key==='v'||e.key==='V')volUp()});
/* =================== ホーム(v17 の形 ・ 撮ったあとは 毎回ここへ) =================== */
const HX=[66,195,324],HR=[-6,2.5,6];const sag=x=>{const t=x/390;return (1-t)*(1-t)*8+2*t*(1-t)*48+t*t*8};
const TM=['09:12','13:40','20:43'];const KIND=[];const fmtD=d=>'0:'+p2(Math.max(1,Math.round(d)));
let prevLeft=3;
function untilNine(){const d=new Date(),t=new Date(d);t.setDate(d.getDate()+(d.getHours()>=9?1:0));t.setHours(9,0,0,0);const m=Math.round((t-d)/60000);return Math.floor(m/60)+':'+p2(m%60)}
function renderHome(swing){const H=$('hline');let h=`<svg class="str" viewBox="0 0 390 60" preserveAspectRatio="none"><path d="M0 8 Q195 48 390 8" fill="none" stroke="#111" stroke-width="1.3"/></svg>`;
  for(let i=0;i<3;i++){const kind=i<shots?'ksh':i===shots?'knx':'kno';const y=sag(HX[i])+2;const K=KIND[i];
    let inner=kind==='ksh'?(K&&K.m?`<div class="im"><i></i><b></b><u class="sp l"></u><u class="sp r"></u></div><span class="mvb">▶ ${fmtD(K.d)}</span><span class="d">${i===shots-1?HM():TM[i]}</span>`:`<div class="im"><i></i><b></b></div><span class="t">today</span><span class="d">${i===shots-1?HM():TM[i]}</span>`):kind==='knx'?`<div class="im"><svg viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg><span>撮る</span></div><span class="t">next</span>`:`<div class="im">あとで</div>`;
    h+=`<div class="hck ${kind}${K&&K.m&&kind==='ksh'?' kmv':''}${i===swing?' sw':''}" data-i="${i}" style="left:${HX[i]-54}px;top:${y}px;--r:${HR[i]}deg;transform:rotate(${HR[i]}deg)"><span class="pin"></span>${inner}</div>`}
  H.innerHTML=h;$('hnum').textContent=shots+' / 3';
  H.querySelectorAll('.hck').forEach(c=>c.onclick=()=>{c.classList.remove('sw');void c.offsetWidth;c.classList.add('sw');const k=c.classList;
    if(k.contains('ksh')){hap('pop','ゆらっ(チェキ)');toast(k.contains('kmv')?'動画は あしたの 9:00 に、ひらきます':'9:00 に、仕上がります')}else if(k.contains('knx')){hap('click','カチッ(撮る)');setTimeout(goShoot,200)}else{hap('warn','やわらかく2回(順番)')}});
  const lock=shots>=3,left=3-shots;
  // 日の出
  $('hmoon').classList.toggle('lock',lock);
  $('hmt').textContent=lock?'9:00に、ひらきます':shots?'もう1枚 撮る':'今日を撮る';
  $('hms').innerHTML=lock?'今日は、ここまで':`<i>${'●'.repeat(left)}</i>${'○'.repeat(shots)}  のこり ${left}こま`;
  // ヘッダー(のこりは ここが 正)
  $('hfilm').innerHTML=Array.from({length:3},(_,i)=>`<i class="${i<left?'':'o'}${i===left&&left<prevLeft?' gone':''}"></i>`).join('')+`<b>${left}</b>`;prevLeft=left;
  // 今日のカード
  $('tim').className='tim'+(shots?' milk':'');
  $('tct').textContent=lock?'3こま、預けました':shots?'今日の1枚を、預けました':DAY2?'今日の 1こま目':'最初の1枚に、なります';
  $('tcs').textContent=lock?'あしたの 9:00 に、まとめて ひらきます':shots?'9:00 まで ひみつ':'0 / 3 ・ まだ からっぽ';
  $('tsl').innerHTML=Array.from({length:3},(_,i)=>`<i class="${i<shots?'s':i===shots?'n':''}"></i>`).join('');$('tsn').textContent=shots+' / 3';
  $('tcd').textContent=lock?'あと '+untilNine():'';
  // 地球の まんなか
  if(window.renderOrb)renderOrb();
  $('hcap').textContent=lock?'3こま、撮りました ・ 9:00 に ひらく':shots?'撮った写真は、9:00 まで ミルク色':'0 / 3 ・ まだ からっぽ';
  headline();renderLeft();if(window.renderDay2)renderDay2()}
/* 見出し(状態で かわる)── v17 と同じ 2行・同じ大きさ */
const HT=[['はじめまして。','今日を撮ってみよう。',3,5,'あしたの朝に、今日の1枚がひらきます。'],
['1こま、撮りました。','今日は、あと2こま。',6,6,'あしたの朝 9:00 に、まとめてひらきます。'],
['2こま、撮りました。','今日は、あと1こま。',6,6,'あしたの朝 9:00 に、まとめてひらきます。'],
['3こま、撮りました。','今日は、ここまで。',-1,-1,'あしたの 9:00 に、ひらきます。']];
const CIRC='<svg class="cir" viewBox="0 0 160 64" preserveAspectRatio="none"><path d="M84 6C128 2 157 15 154 34 151 54 112 62 76 60 32 58 4 49 6 29 8 12 44 4 104 8"/></svg>';
function headline(){const t=(!DAY2||shots)?HT[Math.min(3,shots)]:['おはよう。','今日も、撮ってみよう。',4,6,'あしたの朝に、今日の1枚がひらきます。'];const a=$('hl0'),h=$('hl1');a.innerHTML=[...t[0]].map(c=>`<i>${c}</i>`).join('');h.innerHTML=[...t[1]].map(c=>`<i>${c}</i>`).join('');$('hsub').textContent=t[4];
  if(t[2]>=0){const ch=h.children,x=ch[t[2]],y=ch[t[3]];if(x&&y){const fs=30,left=x.offsetLeft,w=y.offsetLeft+y.offsetWidth-left,pad=t[2]===t[3]?12:8;h.insertAdjacentHTML('beforeend',CIRC);const s=h.lastChild;s.style.cssText=`left:${left-pad}px;top:${(fs*.02).toFixed(1)}px;width:${w+pad*2}px;height:${(fs*1.3).toFixed(1)}px`}}}
/* ---------- 世界の光(ガラスの球の中) ---------- */
const gl=$('globe'),gx=gl.getContext('2d');const GR=[];let GRM=86,gReveal=1;
(function(){for(let r=14;r<=GRM;r+=7.2){const n=Math.round(6.2832*r/7.6),dir=(Math.round((r-14)/7.2)%2?1:-1);for(let i=0;i<n;i++)GR.push({r,a:i/n*6.2832,w:dir*(.00005+(GRM-r)*.0000016),s:.5+Math.random()*.9+(r/GRM)*.5,tw:Math.random()*6.3,c:Math.random()})}})();
const PAL=['255,138,42','255,196,60','255,120,160','110,150,255','170,130,255'];
function drawGlobe(t){gx.setTransform(2,0,0,2,0,0);gx.clearRect(0,0,184,184);const cx=92,cy=92,wv=((t/1000)%5.2)/5.2*(GRM+30),col=shots>0;
  for(const d of GR){if(d.r>gReveal*(GRM+2))continue;const an=d.a+t*d.w,x=cx+Math.cos(an)*d.r,y=cy+Math.sin(an)*d.r*.96,b=Math.exp(-Math.pow((d.r-wv)/9,2)),tw=.5+.5*Math.sin(t*.0016+d.tw);
    const edge=Math.min(1,(gReveal*(GRM+2)-d.r)/14),fall=1-Math.pow(d.r/GRM,3)*.45;let a=(.14+.22*(d.r/GRM)+.14*tw)*edge*fall,s=d.s*(1+.55*b);
    if(col&&d.c>.8){const p=PAL[(d.c*50|0)%5];gx.fillStyle=`rgba(${p},${Math.min(1,.45+.4*tw+b)*edge})`;s*=1.2}
    else if(d.c>.95){gx.fillStyle=`rgba(17,17,20,${(.4+.2*tw)*edge})`;s*=1.1}
    else gx.fillStyle=b>.3?`rgba(89,219,115,${Math.min(.75,a+b*.35)})`:`rgba(140,136,152,${a})`;
    gx.beginPath();gx.arc(x,y,s,0,6.2832);gx.fill()}
  // あなたの光(撮った数だけ ともる ・ まだのぶんは 点線)
  const R=58,rot=t*.00018;gx.save();gx.setLineDash([2,4]);gx.strokeStyle=`rgba(35,158,60,${.35*gReveal})`;gx.lineWidth=1;gx.beginPath();gx.arc(cx,cy,R,0,6.2832);gx.stroke();gx.restore();
  for(let i=0;i<3;i++){const an=rot-Math.PI/2+i*2.0944,x=cx+Math.cos(an)*R,y=cy+Math.sin(an)*R;
    if(i<shots){const g=gx.createRadialGradient(x,y,0,x,y,12);g.addColorStop(0,'rgba(39,176,66,.95)');g.addColorStop(.35,'rgba(36,166,62,.5)');g.addColorStop(1,'rgba(36,166,62,0)');gx.fillStyle=g;gx.beginPath();gx.arc(x,y,12,0,6.2832);gx.fill();gx.fillStyle='#fff';gx.beginPath();gx.arc(x,y,2.2,0,6.2832);gx.fill()}
    else{gx.strokeStyle=`rgba(35,158,60,${(i===shots?.75+.25*Math.sin(t*.004):.4)*gReveal})`;gx.lineWidth=1.3;gx.beginPath();gx.arc(x,y,i===shots?4.2:3.2,0,6.2832);gx.stroke()}}}
(function loop2(t){if($('home').classList.contains('on'))drawGlobe(t);requestAnimationFrame(loop2)})(0);
/* ---------- さわれる所 ---------- */
const openMondo=()=>{if(shots){hap('pop','ぷにっ(Mondo へ)');toast('Mondo(世界の 昨日)へ ひらく')}else{hap('warn','やわらかく2回(まだ ひらけない)');shake($('omo'));toast('1枚 撮ると、Mondo が ひらきます')}};
/* orb の 操作は 下の「万能ボタン」で */
$('gjn').onclick=()=>{hap('click','カチッ(参加する)');$('jin').value='';jParse();openSheet('shj')};
const toFilm=()=>{hap('sel','コツッ(今日の film へ)');$('hs').scrollTo({top:$('hfs').offsetTop-150,behavior:'smooth'})};
$('tcard').onclick=()=>{hap('pop','ぷにっ(現像を のぞく)');openDvx(Math.max(0,shots-1))};$('hst').onclick=toFilm;
$('dsw').onclick=()=>{openY()};
$('gclose').onclick=()=>{hap('soft','やわらかく1回(とじる)');const g=$('guide');g.animate([{opacity:1,transform:'none'},{opacity:0,transform:'scale(.96)'}],{duration:260}).onfinish=()=>{g.classList.add('hide')};toast('設定の「使いかた」から また見られます')};
{const d=new Date(),k=(d.getHours()*60+d.getMinutes())/1440;$('dbn').style.left=(k*100).toFixed(1)+'%';$('dbnow').textContent='いま '+HM()}
$('hs').addEventListener('scroll',()=>{const y=$('hs').scrollTop;const o=$('orb');o.style.transform=`translateY(${(y*.25).toFixed(1)}px) scale(${Math.max(.9,1-y/2400).toFixed(3)})`;o.style.opacity=Math.max(.15,1-y/420).toFixed(2);$('hfade').classList.toggle('on',y>8)},{passive:true});
function homeFocus(){$('hs').scrollTop=0;$('home').classList.remove('arcm');$('hfade').classList.remove('on');$('orb').style.transform='';$('orb').style.opacity=''}
/* ---------- Home の登場 ---------- */
function homeIn(sun){const A=(el,k,o)=>el&&el.animate(k,Object.assign({fill:'backwards',easing:'cubic-bezier(.2,.9,.25,1)'},o));
  A($('hhd'),[{opacity:0,transform:'translateY(-14px)'},{opacity:1,transform:'none'}],{duration:520});
  const t0=performance.now();gReveal=0;const rp=()=>{const k=Math.min(1,(performance.now()-t0)/1300);gReveal=1-Math.pow(1-k,3);if(k<1)requestAnimationFrame(rp)};requestAnimationFrame(rp);
  A($('og'),[{opacity:0,transform:'scale(.7)'},{opacity:1,transform:'none'}],{duration:800,delay:80,easing:'cubic-bezier(.3,1.3,.5,1)'});
  A($('ring'),[{opacity:0,transform:'scale(.86)'},{opacity:1,transform:'none'}],{duration:900,delay:200});
  A($('oc'),[{opacity:0},{opacity:1}],{duration:500,delay:700});A($('omo'),[{opacity:0,transform:'translate(-50%,8px)'},{opacity:1,transform:'translateX(-50%)'}],{duration:500,delay:820});
  document.querySelectorAll('.orb .stk').forEach((s,i)=>A(s,[{opacity:0,transform:'scale(.2) rotate(-30deg)'},{opacity:1,transform:'none'}],{duration:560,delay:600+i*110,easing:'cubic-bezier(.3,1.6,.4,1)'}));
  [...$('hl0').querySelectorAll('i')].forEach((c,i)=>A(c,[{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:460,delay:700+i*30}));
  [...$('hl1').querySelectorAll('i')].forEach((c,i)=>{A(c,[{opacity:0,transform:'translateY(22px) scale(.7)'},{opacity:1,transform:'none'}],{duration:540,delay:860+i*45,easing:'cubic-bezier(.3,1.5,.45,1)'});if(i%2===0)setTimeout(()=>hap('tick',null,{norip:1}),860+i*45)});
  const pa=$('hl1').querySelector('path');if(pa)A(pa,[{strokeDashoffset:420},{strokeDashoffset:0}],{duration:760,delay:1380,easing:'cubic-bezier(.5,0,.3,1)'});
  A($('hsub'),[{opacity:0},{opacity:1}],{duration:500,delay:1300});
  A($('tcard'),[{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:620,delay:1350});
  A($('tck'),[{transform:'translateY(-40px) rotate(-20deg)',opacity:0},{transform:'rotate(-4deg)',opacity:1}],{duration:700,delay:1500,easing:'cubic-bezier(.3,1.4,.4,1)'});setTimeout(()=>hap('land',null,{norip:1}),1900);
  A($('hg'),[{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:620,delay:1480});
  if(sun!==false)A($('hmoon'),[{transform:'translateY(260px)'},{transform:'none'}],{duration:1000,delay:600});
  setTimeout(()=>hap('pop','ぷにっ(日の出)',{norip:1}),sun===false?500:1100)}
/* =================== ともだち(12人まで ・ ふって つながる ・ つつく)=================== */
const FMAX=999;let FR=[],GRP=[],INV=null;
const FPOOL=[{n:'れな',g:['#d9f2ff','#7fb0ff','#9C86FF'],k:2},{n:'あや',g:['#BFF1C9','#61DD7A','#FF5A7A'],k:3},{n:'そら',g:['#e6fff4','#6FCB8C','#0BB52D'],k:0},{n:'ひなた',g:['#fff7c2','#FFD60A','#2A8E3E'],k:1},{n:'みお',g:['#ffe0ef','#F7A7CB','#D8619C'],k:1},{n:'かい',g:['#e8e6ff','#A792E2','#6B57A6'],k:2}];
const avBg=f=>`radial-gradient(circle at 35% 30%,${f.g[0]},${f.g[1]} 45%,${f.g[2]} 90%)`;
const PHS='<svg class="phs" id="phs" viewBox="0 0 110 86"><g stroke="#111" stroke-width="2.4" stroke-linejoin="round"><rect x="10" y="18" width="40" height="64" rx="9" fill="#98E8A8" transform="rotate(-14 30 50)"/><rect x="17" y="27" width="26" height="40" rx="4" fill="#fff" transform="rotate(-14 30 50)"/><rect x="54" y="14" width="40" height="64" rx="9" fill="#B9A4FF" transform="rotate(10 74 46)"/><rect x="61" y="23" width="26" height="40" rx="4" fill="#fff" transform="rotate(10 74 46)"/></g><g stroke="#111" stroke-width="2.2" stroke-linecap="round"><path d="M46 8l3 7M56 4v8M66 7l-3 7"/></g></svg>';
const SHK='<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round"><rect x="7" y="3" width="10" height="18" rx="2.5"/><path d="M3 9v6M21 9v6"/></svg>';
function ringSvg(k){let o='<svg viewBox="0 0 64 64"><circle cx="32" cy="32" r="30" fill="none" stroke="#ECEBF0" stroke-width="2"/>';
  for(let i=0;i<3;i++){const a=(-90+(i-1)*28)*Math.PI/180;o+=`<circle cx="${(32+30*Math.cos(a)).toFixed(1)}" cy="${(32+30*Math.sin(a)).toFixed(1)}" r="${i<k?4.2:3}" fill="${i<k?'#239E3C':'#fff'}" stroke="${i<k?'#fff':'#D0CFD6'}" stroke-width="1.6"/>`}return o+'</svg>'}
const EMPTY_ART=`<div class="fempty"><svg class="fe-art" viewBox="0 0 240 120" aria-hidden="true"><g fill="none" stroke="#C7C7CC" stroke-width="1.6" stroke-dasharray="3 5" stroke-linecap="round"><circle cx="24" cy="34" r="14"/><circle cx="68" cy="34" r="14"/><circle cx="112" cy="34" r="14"/><circle cx="156" cy="34" r="14"/><circle cx="200" cy="34" r="14"/><circle cx="24" cy="82" r="14"/><circle cx="68" cy="82" r="14"/><circle cx="112" cy="82" r="14"/><circle cx="156" cy="82" r="14"/><circle cx="200" cy="82" r="14"/></g><circle cx="24" cy="82" r="10" fill="#111"/><g fill="none" stroke="#239E3C" stroke-width="1.6" stroke-linecap="round"><path d="M42 72a12 12 0 0 1 0 16"/></g></svg><b class="fe-t">席は 12こ。</b><small class="fe-s">つながった人から、ひとつずつ うまります</small></div>`;
function renderFriends(ni){setTimeout(()=>window.renderFriendEntry&&renderFriendEntry(),0);$('frn').textContent=FR.length+' / '+FMAX;$('shfn').textContent='ともだち '+FR.length+' / '+FMAX;const B=$('frbody');
  if(!FR.length){B.innerHTML=`<div class="fr0" id="fr0"><b class="t">まだ、だれも。</b><p>となりの人と、スマホを ふるだけ。12人まで つながれます。</p>${PHS}<button class="bump" id="bump"><i class="gz" id="gz"></i>${SHK}<span id="bumpt">ふって つながる</span></button><div class="flinks"><button id="fl1">合言葉で 呼ぶ</button><button id="fl2">QR を 見せる</button></div></div>${EMPTY_ART}`;
    bindBump($('bump'));$('fl1').onclick=$('fl2').onclick=()=>openSheet('shf');return}
  const more=FR.length<FMAX?`<div class="fr0" id="fr0"><b class="t">もっと つながる</b><p>となりの人と、スマホを ふるだけ。</p>${PHS}<button class="bump" id="bump"><i class="gz" id="gz"></i>${SHK}<span id="bumpt">ふって つながる</span></button></div>`:'';B.innerHTML=`<div class="frow">${FR.map((f,i)=>`<div class="fp${i===ni?' new':''}" data-i="${i}"><div class="fav">${ringSvg(f.k)}<div class="fc" style="background:${avBg(f)}">${f.n[0]}</div></div><b>${f.n}</b><small>${f.k} / 3</small><button class="knock"><i></i><span>つつく</span></button></div>`).join('')}<div class="fp add" id="fadd"><div class="fav"><div class="fc">+</div></div><b>呼ぶ</b><small>${FR.length} / ${FMAX}</small></div></div><div class="frhint">まわりの 橙の点 = 今日 撮った こま ・ つつくは 長押しで つよく</div>${more}`;if($('bump'))bindBump($('bump'));
  B.querySelectorAll('.fp[data-i]').forEach(bindKnock);
  $('fadd').onclick=()=>{if(FR.length>=FMAX){hap('warn','やわらかく2回(12人まで)');toast('デモの 友だちは ここまで');return}hap('tick','ごく軽く1回');openSheet('shf')}}
/* ふって つながる(本物は スマホを ふる。ボタンは ふれない人の 代わり)*/
const BUMP_MS=1500;
function bindBump(btn){let t0=0,raf=0,tk=0;
  const end=()=>{if(!t0)return;cancelAnimationFrame(raf);t0=0;setCont(0);btn.classList.remove('hold');$('gz').style.transition='width .3s';$('gz').style.width='0';setTimeout(()=>$('gz')&&($('gz').style.transition=''),320);$('phs')&&$('phs').classList.remove('sh');$('bumpt').textContent='もっと ふって';hap('soft','やわらかく1回(とまった)')};
  btn.addEventListener('pointerdown',e=>{if(FR.length>=FMAX){hap('warn');toast('デモの 友だちは ここまで');return}try{btn.setPointerCapture(e.pointerId)}catch(_){}t0=performance.now();tk=0;btn.classList.add('hold');$('phs').classList.add('sh');$('bumpt').textContent='ふっています…';hap('pop','ぷにっ(ふりはじめ)',{norip:1});
    const st=now=>{if(!t0)return;const k=Math.min(1,(now-t0)/BUMP_MS);$('gz').style.width=(k*100).toFixed(1)+'%';setCont(.12+.7*k*k,'だんだん強く(ふる)');
      const want=Math.floor(Math.pow(k,1.6)*14);while(tk<want){tk++;hap(k>.7?'thud':'tick',null,{norip:1,noq:1})}
      if(k>=1){t0=0;setCont(0);btn.classList.remove('hold');$('phs').classList.remove('sh');bumpBurst($('fr0'),()=>askBump());return}raf=requestAnimationFrame(st)};raf=requestAnimationFrame(st)});
  ['pointerup','pointercancel'].forEach(ev=>btn.addEventListener(ev,end))}
function bumpBurst(el,after){hap('success','トトトン(BUMP!)',{norip:1});phone.classList.remove('qk');void phone.offsetWidth;phone.classList.add('qk');
  for(let i=0;i<3;i++){const r=document.createElement('i');r.className='bburst';r.style.borderColor=['#24A73E','#FF5A7A','#9C86FF'][i];el.appendChild(r);r.animate([{transform:'scale(.4)',opacity:1},{transform:'scale(5.5)',opacity:0}],{duration:900,delay:i*120,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'}).onfinish=()=>r.remove()}
  const w=document.createElement('div');w.className='bword';w.textContent='BUMP!';el.appendChild(w);w.animate([{transform:'scale(.3) rotate(-10deg)',opacity:0},{transform:'scale(1.15) rotate(3deg)',opacity:1,offset:.45},{transform:'scale(1) rotate(-2deg)',opacity:1,offset:.8},{transform:'scale(1.05)',opacity:0}],{duration:1100,easing:'cubic-bezier(.3,1.4,.5,1)'}).onfinish=()=>{w.remove();after&&after()};
  setTimeout(()=>hap('pop','ぷにっ',{norip:1}),260)}
let candidate=null;
function askBump(){candidate=FPOOL.find(f=>!FR.includes(f));if(!candidate){toast('デモの 友だちは ここまで');return}
  $('bq').textContent=candidate.n+' と つながる?';$('bav').textContent=candidate.n[0];$('bav').style.background=avBg(candidate);openSheet('shb')}
$('byes').onclick=()=>{if(!candidate)return;FR.push(candidate);closeSheet('shb');hap('success','トトトン(つながった)',{norip:1});setTimeout(()=>{renderFriends(FR.length-1);renderPick();toast(candidate.n+' と つながりました')},280)};
$('bno').onclick=()=>{hap('soft');closeSheet('shb')};
$('pbump').onclick=()=>{closeSheet('shf');setTimeout(()=>{if(!$('fscr').classList.contains('on'))openFriend();setTimeout(()=>{const el=$('fr0');if(!el){toast('デモの 友だちは ここまで');return}$('fbody').scrollTo({top:el.offsetTop-150,behavior:'smooth'});setTimeout(()=>bumpBurst(el,()=>askBump()),350)},450)},250)};
$('psend').onclick=()=>{hap('tick');toast('共有シートを ひらく(LINE・AirDrop など)')};
$('pcopy').onclick=()=>{hap('click','カチッ(コピー)');toast('リンクを コピーしました')};
$('pscan').onclick=()=>{hap('tick');toast('カメラで 相手の QR を よみとる')};
/* つつく:長押しで ためる(0.9秒で つよく)*/
function bindKnock(p){const btn=p.querySelector('.knock'),f=FR[+p.dataset.i];let t0=0,iv=0,raf=0,strong=false;
  btn.addEventListener('pointerdown',e=>{e.stopPropagation();try{btn.setPointerCapture(e.pointerId)}catch(_){}t0=performance.now();strong=false;hap('soft','やわらかく1回(押した)',{norip:1});
    iv=setInterval(()=>hap('tick',null,{norip:1,noq:1}),240);
    const st=now=>{if(!t0)return;const k=Math.min(1,(now-t0)/900);btn.querySelector('i').style.width=(k*100)+'%';setCont(.1+.5*k,'ためる(つつく)');
      if(k>=1&&!strong){strong=true;btn.classList.add('st');btn.querySelector('span').textContent='つよく';hap('thud','ドン(つよく)',{norip:1});setCont(0)}
      if(!strong)raf=requestAnimationFrame(st)};raf=requestAnimationFrame(st)});
  const up=()=>{if(!t0)return;t0=0;clearInterval(iv);cancelAnimationFrame(raf);setCont(0);btn.querySelector('i').style.width='0';
    p.classList.remove('wob','wob2');void p.offsetWidth;p.classList.add(strong?'wob2':'wob');
    hap(strong?'thud':'heart',strong?'ドドン(つよく つついた)':'どくん(つついた)',{norip:1});toast(strong?`${f.n} を つよく つついた`:`${f.n} を つついた`);
    setTimeout(()=>{btn.classList.remove('st');btn.querySelector('span').textContent='つつく'},700)};
  btn.addEventListener('pointerup',up);btn.addEventListener('pointercancel',up)}
/* QR(見本の模様)*/
(function(){let o='';const fd=(x,y)=>{for(const[a,b]of[[0,0],[14,0],[0,14]]){const dx=x-a,dy=y-b;if(dx>=0&&dx<7&&dy>=0&&dy<7)return(dx===0||dx===6||dy===0||dy===6||(dx>=2&&dx<=4&&dy>=2&&dy<=4))?1:0}return -1};
  for(let y=0;y<21;y++)for(let x=0;x<21;x++){const f=fd(x,y);const on=f>=0?f:((x*7+y*13+x*y)%5<2);o+=on?'<i></i>':'<u></u>'}$('qr').innerHTML=o})();
/* シート */
function openSheet(id){$(id).classList.add('on');hap('soft','ふわっ(シート)',{norip:1})}
function closeSheet(id){$(id).classList.remove('on')}
document.querySelectorAll('.sheet .scrim').forEach(s=>s.onclick=()=>{hap('tick');closeSheet(s.dataset.x)});
/* グループ:ともだちを えらんで 招待カード(本人が「入る」まで 入らない)*/
let PICK=new Set();
function renderPick(){const P=$('pick');if(!FR.length){P.innerHTML='<div style="font:500 12px var(--sans);color:#AEAEB2;padding:10px 0">まだ ともだちが いません。下の リンクで 呼べます。</div>';syncPick();return}
  P.innerHTML=FR.map((f,i)=>`<button class="pk${PICK.has(i)?' on':''}" data-i="${i}"><span class="fc" style="background:${avBg(f)}">${f.n[0]}<i class="ck"><svg viewBox="0 0 10 10" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 5.2l2 2 4-4.4"/></svg></i></span>${f.n}</button>`).join('');
  P.querySelectorAll('.pk').forEach(b=>b.onclick=()=>{const i=+b.dataset.i;if(PICK.has(i)){PICK.delete(i);hap('tick','ごく軽く1回(はずす)')}else{if(PICK.size>=7){hap('warn','やわらかく2回(8人まで)');toast('グループは 8人まで(自分を 入れて)');return}PICK.add(i);hap('pop','ぷにっ(えらぶ)')}b.classList.toggle('on',PICK.has(i));syncPick()});syncPick()}
function syncPick(){const n=PICK.size,s=$('gsend');s.classList.toggle('on',n>0);s.textContent=n?`${n}人に 招待カードを おくる`:'ともだちを えらんでください'}
$('gsend').onclick=()=>{const n=PICK.size;if(!n){hap('warn');return}const m=[...PICK].map(i=>FR[i]);const name=$('gnin').value.trim()||'あたらしい グループ';
  GRP.unshift({n:name,m,sub:`招待中 ${n}人 ・ 本人が「入る」と 入ります`,pill:'招待中'});PICK.clear();closeSheet('shc');hap('success','トトトン(おくった)',{norip:1});setTimeout(()=>{renderGroups(true);toast('招待カードを おくりました')},300)};
/* 招待リンク:いままでと 同じ 形(「なまえ」に招待されました…\nlattag://join?shareUrl=…) */
function inviteText(name,url){return `「${name}」に招待されました。Lattag で、昨日をひらきあいましょう。\nlattag://join?shareUrl=${url}`}
let LK=null;
$('glink').onclick=()=>{const b=$('glink');if(b._busy)return;b._busy=1;const name=$('gnin').value.trim()||'あたらしい グループ';hap('click','カチッ(リンクを つくる)');
  b.textContent='リンクを つくっています…';b.classList.add('busy');let n=0;const iv=setInterval(()=>{hap('tick',null,{norip:1});if(++n>=3)clearInterval(iv)},260);
  setTimeout(()=>{const tok=Array.from({length:22},()=>'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789'[Math.random()*58|0]).join('');
    LK=inviteText(name,'https://www.icloud.com/share/'+tok);$('lktext').textContent=LK;const c=$('lkcard');c.hidden=false;
    c.animate([{opacity:0,transform:'translateY(18px) scale(.96)'},{opacity:1,transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'});
    b.textContent='リンクを つくりなおす';b.classList.remove('busy');b._busy=0;hap('success','トトトン(リンクが できた)',{norip:1});$('shc').querySelector('.pn').scrollTo({top:9999,behavior:'smooth'})},900)};
$('lkcopy').onclick=()=>{hap('click','カチッ(コピー)');let ok=false;try{navigator.clipboard.writeText(LK).then(()=>toast('招待リンクを コピーしました'),()=>toast('コピー できませんでした ・ 長押しで えらんでください'));ok=true}catch(e){}if(!ok)toast('コピー できませんでした ・ 長押しで えらんでください');
  const b=$('lkcopy');b.textContent='コピーした';setTimeout(()=>b.textContent='コピー',1400)};
$('lksend').onclick=()=>{hap('pop','ぷにっ(共有シート)');toast('共有シートを ひらく(メッセージ・LINE など)')};
/* 参加する:リンクを はる / 合言葉 */
var JN=null;
function jParse(){const v=$('jin').value.trim();const g=$('jgo'),c=$('jcard');JN=null;
  const m=v.match(/lattag:\/\/join\?shareUrl=(https?:\/\/\S+)/);const nm=(v.match(/「(.+?)」に招待/)||[])[1];
  if(m){JN={n:nm||'グループ',url:m[1]}}else if(/^[A-Za-z0-9ぁ-んァ-ヶ一-龠]{4,8}$/.test(v)){JN={n:'合言葉の グループ',code:v}}
  if(JN){c.hidden=false;$('jname').textContent='「'+JN.n+'」';$('jsub').textContent=JN.url?'招待リンクが みつかりました ・ 本人が「入る」と 入ります':'合言葉が みつかりました';
    $('jav').innerHTML=[0,1,2].map(i=>`<i style="left:${i*12}px;background:${['#61DD7A','#9C86FF','#6FA8FF'][i]};z-index:${3-i}"></i>`).join('');g.classList.add('on');g.textContent='「'+JN.n+'」に 入る'}
  else{c.hidden=true;g.classList.remove('on');g.textContent='リンクか 合言葉を いれてください'}}
$('jin').addEventListener('input',jParse);
$('jpaste').onclick=()=>{hap('pop','ぷにっ(はる)');$('jin').value='「たつかあ」に招待されました。Lattag で、昨日をひらきあいましょう。\nlattag://join?shareUrl=https://www.icloud.com/share/048QUuOQglIyxDdrKDRVre3wg';const was=$('jcard').hidden;jParse();if(was&&JN)$('jcard').animate([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.4,.5,1)'})};
$('jqr').onclick=()=>{hap('tick','ごく軽く1回');toast('QR を よむ(カメラ)')};
$('jgo').onclick=()=>{if(!JN){hap('warn','やわらかく2回(まだ)');shake($('jin').parentNode);return}
  hap('success','トトトン(入った)',{norip:1});GRP.unshift({n:JN.n,m:FR.length?FR.slice(0,3):[{n:'た',g:['#BFF1C9','#61DD7A','#FF5A7A'],k:0},{n:'か',g:['#e6fff4','#6FCB8C','#0BB52D'],k:0}],sub:'いま 入りました ・ 明日の朝 ひらきます',pill:'NEW'});closeSheet('shj');$('jin').value='';jParse();setTimeout(()=>{renderGroups(true);toast('グループに 入りました')},300)};
$('gmk').onclick=()=>{hap('tick','ごく軽く1回');PICK.clear();renderPick();openSheet('shc')};
const stack=m=>m.slice(0,3).map((f,i)=>`<i style="left:${i*12}px;background:${avBg(f)};z-index:${3-i}"></i>`).join('');
function renderGroups(fresh){$('gcount').innerHTML=GRP.length+' / 10';
  $('ginv').innerHTML=INV?`<div class="ginv in"><div class="gi1">${INV.m.slice(0,3).map((f,i)=>`<i style="left:${i*8}px;top:${i%2*12}px;background:${avBg(f)}"></i>`).join('')}</div><div class="gx"><b>${INV.from} から 招待</b><small>「${INV.n}」・${INV.size}人</small></div><button class="later" id="ilater">あとで</button><button class="ok" id="iok">入る</button></div>`:'';
  if(INV){$('iok').onclick=()=>{hap('success','トトトン(入った)',{norip:1});GRP.unshift({n:INV.n,m:INV.m,sub:`${INV.size}人`,pill:'あと 3人',un:1,last:INV.from+': よろしく〜'});INV=null;renderGroups(true);toast('グループに 入りました')};
    $('ilater').onclick=()=>{hap('soft');const c=$('ginv').firstChild;c.classList.add('gone2');setTimeout(()=>{INV.later=true;$('ginv').innerHTML='';$('gcount').innerHTML=`<span style="color:#239E3C;cursor:pointer" id="gre">● とどいた 1</span>  ${GRP.length} / 10`;$('gre').onclick=()=>{INV.later=false;renderGroups()};toast('「とどいた」から あとで 入れます')},300)}}
  $('gt').style.display=GRP.length?'none':'';
  $('glist').innerHTML=GRP.length?GRP.slice(0,1).map(g=>`<button class="grow"><div class="gst">${stack(g.m)}</div><div class="gtx"><b>${g.n}</b><small>${g.last||g.sub}</small></div>${g.un?'<u class="gun"></u>':''}<span class="gpill${g.all?' all':''}">${g.pill}</span><em>›</em></button>`).join('')+(GRP.length>1?`<button class="gall" id="gall">ほかの グループ ${GRP.length-1} ・ ぜんぶ見る ›</button>`:'')+`<div class="gmini"><button class="m1" id="gm1">+ つくる</button><button class="m2" id="gm2">参加する</button></div>`:'';
  if(GRP.length){$('gm1').onclick=()=>$('gmk').onclick();$('gm2').onclick=()=>$('gjn').onclick();$('gall')&&($('gall').onclick=()=>{hap('pop');toast('グループの 大きな画面へ')});$('glist').querySelectorAll('.grow').forEach(r=>r.onclick=()=>openRoom(GRP[0]));if(fresh){const r=$('glist').firstChild;r.animate([{transform:'scale(.9)',opacity:0},{transform:'scale(1.03)',opacity:1,offset:.6},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})}};if(window.renderArc&&DAY2)renderArc();if(window.renderOrb)renderOrb()}
renderFriends();renderGroups();renderPick();

/* =================== v22.1:初回だけの説明 / 2日目からの スクロール =================== */
const PH=window.PH;let DAY2=true;
function setDay(d2){DAY2=d2;$('home').classList.toggle('d2',d2);renderHome();renderDay2();revealReset()}
/* --- 見えたら ふわっと(1回だけ ごく軽く)--- */
const RV=[...document.querySelectorAll('.rv2')];
function revealReset(){RV.forEach(e=>{e.classList.add('pre');e._seen=false});revealCheck()}
function revealCheck(){const hs=$('hs'),top=hs.scrollTop,h=844;RV.forEach(e=>{if(e._seen||e.offsetParent===null)return;const y=e.offsetTop-top;if(y<h-120){e._seen=true;e.classList.remove('pre');if(e.id==='wks')weekIn();if(top>20)hap('tick',null,{norip:1,gap:120})}})}
$('hs').addEventListener('scroll',revealCheck,{passive:true});
/* --- 現像中(今日の film)--- */
const MZ=[['#86E499','#F7A8D8','#9C86FF','#86E499','#6FA8FF','#60CA75'],['#3A4A6A','#73E088','#C5D6D4','#7A8A9A','#61DD7A','#2A3040'],['#C8D8E8','#8AA0B8','#BDE0C4','#5A6A80','#96E8A7','#A0B8D0']];
function dvProgress(i){const now=new Date();const st=new Date(now);const [h,m]=TM[i].split(':').map(Number);st.setHours(h,m,0,0);const end=new Date(now);end.setDate(now.getDate()+(now.getHours()>=9?1:0));end.setHours(9,0,0,0);
  const k=Math.max(.04,Math.min(.96,(now-st)/(end-st)));return isNaN(k)?.3:k}
function renderDev(){if(!$('dvrow'))return;const R=$('dvrow');let h='';
  for(let i=0;i<3;i++){const r=[-3,2,-1.5][i];
    if(i<shots){const k=dvProgress(i),cols=MZ[i%3];const mz=Array.from({length:7},(_,j)=>`<i style="position:absolute;left:${(j*37+i*23)%100}%;top:${(j*53+i*31)%100}%;width:70px;height:70px;margin:-35px;border-radius:50%;background:${cols[(j+i)%6]}"></i>`).join('');
      const bub=Array.from({length:5},(_,j)=>`<i style="left:${12+j*28}px;animation-delay:${-j*.8}s"></i>`).join('');
      h+=`<div class="dvc" data-i="${i}" style="--r:${r}deg"><div class="w"><div class="mz">${mz}</div><div class="fog" style="opacity:${(.97-k*.22).toFixed(2)}"></div><div class="bub">${bub}</div><span class="eye">DEVELOPING</span></div><span class="pc">現像 ${Math.round(k*100)}%</span><span class="tm">${i===shots-1?HM():TM[i]}</span></div>`}
    else if(i===shots)h+=`<div class="dvc nx" style="--r:${r}deg"><div class="w"><svg viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>撮る</div><span class="pc">next</span></div>`;
    else h+=`<div class="dvc no" style="--r:${r}deg"><div class="w">あとで</div></div>`}
  R.innerHTML=h;$('dvleft').textContent='9:00 まで '+untilNine();
  const k=shots?dvProgress(0):0;$('dvfill').style.width=(k*100)+'%';$('dvnow').style.left=(k*100)+'%';
  R.querySelectorAll('.dvc[data-i]').forEach(bindPeek);const nx=R.querySelector('.dvc.nx');if(nx)nx.onclick=()=>{hap('click','カチッ(撮る)');setTimeout(goShoot,150)};
  R.querySelectorAll('.dvc.no').forEach(n=>n.onclick=()=>hap('warn','やわらかく2回(順番)'))}
/* 長押しで のぞく:霧が すこし うすくなる(色だけ)・どくん…が だんだん はやく */
function bindPeek(c){const fog=c.querySelector('.fog'),base=+fog.style.opacity;let t0=0,raf=0,tm=0,beat=520;
  const beatF=()=>{if(!t0)return;hap('heart',null,{norip:1,noq:1});beat=Math.max(190,beat*.8);tm=setTimeout(beatF,beat)};
  c.addEventListener('pointerdown',e=>{try{c.setPointerCapture(e.pointerId)}catch(_){}t0=performance.now();beat=520;c.classList.add('peek');hap('soft','そっと(のぞく)',{norip:1});tm=setTimeout(beatF,300);
    const st=now=>{if(!t0)return;const k=Math.min(1,(now-t0)/1400),e2=k*k*(3-2*k);fog.style.opacity=(base-(base-.42)*e2).toFixed(3);c.style.transform=`rotate(var(--r)) scale(${1+.05*e2})`;setCont(.08+.3*k,'どくん…(のぞいている)');raf=requestAnimationFrame(st)};raf=requestAnimationFrame(st)});
  const up=()=>{if(!t0)return;t0=0;clearTimeout(tm);cancelAnimationFrame(raf);setCont(0);c.classList.remove('peek');fog.style.transition='opacity .5s';fog.style.opacity=base;c.style.transform='';setTimeout(()=>fog.style.transition='',520);hap('soft','やわらかく1回(もどる)',{norip:1})};
  ['pointerup','pointercancel'].forEach(ev=>c.addEventListener(ev,up))}

/* =================== 現像ビュー(カードを おすと:濃くなっていく ところを 見る)=================== */
var DXI=0,DXD=[0,0,0],DXtok=0,DXseen={},DXopen=false,DXst=0;
const dxK=i=>i<shots?dvProgress(i):0;
const GRN="url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='120' height='120'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.9' numOctaves='2' stitchTiles='stitch'/><feColorMatrix values='0 0 0 0 .2  0 0 0 0 .2  0 0 0 0 .22  0 0 0 .9 0'/></filter><rect width='120' height='120' filter='url(%23n)'/></svg>\")";
const DXP=['c','a','e'];
function renderDvx(){let h='';
  for(let i=0;i<3;i++){const r=[-2.5,2,-1.5][i];
    if(i<shots){const cols=MZ[i%3];const mz=Array.from({length:7},(_,j)=>`<i style="position:absolute;left:${(j*37+i*23)%100}%;top:${(j*53+i*31)%100}%;width:110px;height:110px;margin:-55px;border-radius:50%;background:${cols[(j+i)%6]}"></i>`).join('');
      const bub=Array.from({length:7},(_,j)=>`<i style="left:${8+j*14}%;animation-delay:${-j*.7}s;animation-duration:${3.4+j%3*.8}s"></i>`).join('');
      h+=`<div class="dxp" data-i="${i}"><div class="dxc" data-dv="1" style="--r:${r}deg"><div class="dxw"><img class="dxim" src="${PH[DXP[i]]}" alt=""><i class="dxtn"></i><div class="fog"></div><div class="gr" style="background-image:${GRN}"></div><i class="dxsh"></i><span class="dxpt"></span></div><span class="dxtm">${i===shots-1?HM():TM[i]}</span><span class="dxkd mono">${KIND[i]&&KIND[i].m?'MOVIE':'PHOTO'}</span></div></div>`}
    else if(i===shots)h+=`<div class="dxp" data-i="${i}"><div class="dxc nx" style="--r:${r}deg"><div class="dxw"><svg viewBox="0 0 24 24" fill="none" stroke="#111" stroke-width="2.2" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg><b>shoot</b><small>${['1st','2nd','3rd'][i]} shot</small></div></div></div>`;
    else h+=`<div class="dxp" data-i="${i}"><div class="dxc no" style="--r:${r}deg"><div class="dxw"><b>Lattag</b><small>one by one</small></div></div></div>`}
  $('dxs').innerHTML=h;$('dxdots').innerHTML=[0,1,2].map(i=>`<i class="${i===DXI?'on':''}"></i>`).join('');
  $('dxs').querySelectorAll('.dxc.nx').forEach(n=>n.onclick=()=>{hap('click','カチッ(撮る)');closeDvx();setTimeout(goShoot,420)});
  $('dxs').querySelectorAll('.dxc.no').forEach(n=>n.onclick=()=>hap('warn','やわらかく2回(順番)'))}
function dxApply(i,d){const c=document.querySelector(`.dxp[data-i="${i}"] .dxc[data-dv]`);if(!c)return;
  const v=Math.pow(d,.6);c.style.setProperty('--mk',(.97-v*.5).toFixed(3));c.style.setProperty('--ib',(16-v*11).toFixed(1)+'px');c.style.setProperty('--is',(.08+v*.85).toFixed(2));c.style.setProperty('--ibr',(1.55-v*.45).toFixed(2));c.style.setProperty('--tn',(Math.sin(Math.PI*Math.min(1,v*1.15))*.6).toFixed(2));const pt=c.querySelector('.dxpt');if(pt)pt.textContent=Math.round(d*100)+'%';c.style.setProperty('--fg',(.97-v*.76).toFixed(3));c.style.setProperty('--bl',(30-v*21).toFixed(1)+'px');c.style.setProperty('--sa',(.3+v*1.8).toFixed(2));c.style.setProperty('--ct',(.9+v*.45).toFixed(2));c.style.setProperty('--gr',(.55-v*.38).toFixed(2));c.style.setProperty('--d',d.toFixed(3))}
function dxUI(){const i=DXI,taken=i<shots,k=dxK(i),d=DXD[i],C=$('dxctl');C.classList.toggle('na',!taken);$('dxcnt').textContent=(i+1)+' / 3';
  [...$('dxdots').children].forEach((x,j)=>x.classList.toggle('on',j===i));
  if(!taken){$('dxnote').textContent=i===shots?'shoot to start developing':'one by one';return}
  $('dxpc').textContent=Math.round(d*100);$('dxlab').textContent=d>=k-.004?'now':(DXplay?'developing…':'replay');
  $('dxfill').style.width=(d*100)+'%';$('dxth').style.left=(d*100)+'%';$('dxnow').style.left=(k*100)+'%';$('dxlock').style.left=(k*100)+'%';
  $('dxt0').textContent=(i===shots-1?HM():TM[i])+' SHOT';$('dxnote').textContent='opens in '+untilTxt()}
var DXplay=0;
function dxPlay(auto){const i=DXI;if(i>=shots)return;const k=dxK(i),tok=++DXtok;DXplay=1;$('dxplt').textContent='developing…';const dur=2600+k*2400;let lastTen=-1;const t0=performance.now();
  DXD[i]=0;dxApply(i,0);dxUI();
  const card=document.querySelector(`.dxp[data-i="${i}"] .dxc[data-dv]`);
  (function f(n){if(tok!==DXtok)return;const p=Math.min(1,(n-t0)/dur),e=p*p*(3-2*p),d=k*e;DXD[i]=d;dxApply(i,d);dxUI();setCont(.05+.5*p,'じわ…(濃く なっていく)');
    const ten=Math.floor(d*10);if(ten!==lastTen&&ten>0){lastTen=ten;hap('sel',null,{norip:1,gap:60})}
    if(p<1)requestAnimationFrame(f);else{DXplay=0;setCont(0);hap('heart','ドクン(いまの 濃さ)',{norip:1});$('dxplt').textContent='watch again';dxUI();
      card&&card.animate([{transform:`rotate(var(--r)) scale(1)`},{transform:'rotate(var(--r)) scale(1.04)',offset:.3},{transform:'rotate(var(--r)) scale(1)'}],{duration:460,easing:'cubic-bezier(.3,1.5,.5,1)'})}})(t0)}
function dxStop(){DXtok++;DXplay=0;setCont(0)}
function openDvx(i){if(DXopen)return;DXopen=true;DXI=Math.max(0,Math.min(2,i));DXseen={};DXD=[0,0,0];for(let j=0;j<3;j++)DXD[j]=dxK(j);renderDvx();
  for(let j=0;j<shots;j++)dxApply(j,DXD[j]);dxUI();$('dxplt').textContent='watch it develop';
  const V=$('dvx');V.classList.remove('off');V.classList.add('on');hap('land','トン(現像の 中へ)');
  requestAnimationFrame(()=>{const S=$('dxs');S.scrollLeft=DXI*S.clientWidth;dxScroll(true);
    S.querySelectorAll('.dxp').forEach((p,j)=>p.animate([{opacity:0,transform:'translateY(46px) scale(.9)'},{opacity:1,transform:'none'}],{duration:620,delay:160+j*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
    DXst=setTimeout(()=>{if(DXopen&&DXI<shots){DXseen[DXI]=1;dxPlay(true)}},760)})}
function closeDvx(){if(!DXopen)return;DXopen=false;clearTimeout(DXst);dxStop();const V=$('dvx');V.classList.add('off');V.classList.remove('on');hap('soft','やわらかく1回(もどる)');renderDev()}
function dxScroll(init){const S=$('dxs'),w=S.clientWidth||1,x=S.scrollLeft/w;
  S.querySelectorAll('.dxp').forEach((p,j)=>{const dist=Math.min(1.2,Math.abs(x-j)),c=p.firstElementChild;c.style.setProperty('--sc',(1-dist*.12).toFixed(3));c.style.opacity=(1-dist*.45).toFixed(2);c.style.setProperty('--tx',((j-x)*-14).toFixed(1)+'px')});
  const idx=Math.max(0,Math.min(2,Math.round(x)));
  if(!init&&idx!==DXI){DXI=idx;clearTimeout(DXst);dxStop();hap('sel','コツッ(となりの こま)',{norip:1});dxUI();$('dxplt').textContent=DXseen[idx]?'watch again':'watch it develop'}
  clearTimeout(DXst);if(!init)DXst=setTimeout(()=>{if(DXopen&&DXI<shots&&!DXseen[DXI]&&!DXplay){DXseen[DXI]=1;dxPlay(true)}},420)}
$('dxs').addEventListener('scroll',()=>dxScroll(false),{passive:true});
$('dxback').onclick=closeDvx;
$('dxplay').onclick=()=>{if(DXI>=shots){hap('click','カチッ(撮る)');closeDvx();setTimeout(goShoot,420);return}if(DXplay){hap('warn','やわらかく2回(いま 見ている)');return}hap('click','カチッ(もう一度)');DXseen[DXI]=1;dxPlay()};
(function(){const T=$('dxtr');let on=0,over=0,last=-1;
  const pos=e=>{const r=T.getBoundingClientRect();return Math.max(0,Math.min(1,(e.clientX-r.left)/r.width))};
  const mv=e=>{if(!on)return;const k=dxK(DXI);let d=pos(e);if(d>k){d=k;if(!over){over=1;hap('warn','やわらかく2回(さきは ひみつ)');shake(T.parentNode)}}else over=0;
    DXD[DXI]=d;dxApply(DXI,d);dxUI();const st=Math.floor(d*20);if(st!==last){last=st;hap('tick',null,{norip:1,gap:25})}};
  T.addEventListener('pointerdown',e=>{if(DXI>=shots)return;dxStop();$('dxplt').textContent='watch again';on=1;over=0;last=-1;try{T.setPointerCapture(e.pointerId)}catch(_){}T.classList.add('drag');hap('soft','そっと(つまむ)',{norip:1});mv(e)});
  T.addEventListener('pointermove',mv);['pointerup','pointercancel'].forEach(ev=>T.addEventListener(ev,()=>{if(!on)return;on=0;T.classList.remove('drag');hap(DXD[DXI]>=dxK(DXI)-.004?'pop':'soft',DXD[DXI]>=dxK(DXI)-.004?'ぷにっ(いま に ぴったり)':'やわらかく1回',{norip:1})}))})();

/* =================== Lattag yesterday(昨日の ホーム:Mondo / グループ / カレンダー)=================== */
var YOPEN=false,YTAB='ytg';
const yH=()=>{const h=new Date().getHours();return h>=21||h<9};
function untilTxt(){const [h,m]=untilNine().split(':').map(Number);return h>0?`${h}h ${m}m`:`${m}m`}
function renderYMeta(){if(!$('ypt'))return;$('ypt').textContent='ひらくまで  '+untilTxt();$('ybars').innerHTML=[0,1,2].map(i=>`<i class="${i<3-shots?'':'o'}"></i>`).join('');$('ypn').textContent=3-shots;$('ylock').classList.toggle('hide',shots>0)}
function renderYFriends(){if(!$('yfr'))return;$('ycnt').textContent=FR.length+' / '+FMAX;
  $('yfr').innerHTML=`<button class="yf call" id="ycall"><span class="yav2"><u></u><svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg></span><b>呼ぶ</b><small>つながる</small></button>`+FR.map((f,i)=>`<button class="yf" data-i="${i}"><span class="yav2 fr">${ringSvg(f.k)}<span class="fc" style="background:${avBg(f)}">${f.n[0]}</span></span><b>${f.n}</b><small>${f.k} / 3</small></button>`).join('');
  $('ycall').onclick=()=>{hap('pop','ぷにっ(呼ぶ)');openSheet('shf')};
  $('yfr').querySelectorAll('.yf[data-i]').forEach(b=>b.onclick=()=>{const f=FR[+b.dataset.i];hap('tick','ごく軽く1回');toast(`${f.n} ・ 今日 ${f.k}こま 撮った`)})}
function renderYGroups(fresh){if(!$('yglist'))return;
  $('yginv').innerHTML=INV&&!INV.later?`<div class="ginv in"><div class="gi1">${INV.m.slice(0,3).map((f,i)=>`<i style="left:${i*8}px;top:${i%2*12}px;background:${avBg(f)}"></i>`).join('')}</div><div class="gx"><b>${INV.from} から 招待</b><small>「${INV.n}」・${INV.size}人</small></div><button class="later" id="yilater">あとで</button><button class="ok" id="yiok">入る</button></div>`:'';
  if($('yiok')){$('yiok').onclick=()=>$('iok').click();$('yilater').onclick=()=>$('ilater').click()}
  $('ysamp').style.display=GRP.length?'none':'';renderYHero();
  $('yglist').innerHTML=GRP.length?GRP.slice(0,1).map(g=>`<button class="grow"><div class="gst">${stack(g.m)}</div><div class="gtx"><b>${g.n}</b><small>${g.last||g.sub}</small></div>${g.un?'<u class="gun"></u>':''}<span class="gpill${g.all?' all':''}">${g.pill}</span><em>›</em></button>`).join('')+(GRP.length>1?`<button class="gall" id="yall">ほかの グループ ${GRP.length-1} ・ ぜんぶ見る ›</button>`:'')
  :'';
  if(GRP.length){$('yall')&&($('yall').onclick=()=>{hap('pop');toast('グループの 大きな画面へ')});$('yglist').querySelectorAll('.grow').forEach(r=>r.onclick=()=>openRoom(GRP[0]));
    if(fresh){const r=$('yglist').firstChild;r.animate([{transform:'scale(.9)',opacity:0},{transform:'scale(1.03)',opacity:1,offset:.6},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})}}}
function renderYM(){if(!$('ymr'))return;$('ymr').innerHTML=TOP.map(([t,w,p1,p2],i)=>`<button class="ymrow" data-t="${t}"><span class="n">0${i+1}</span><span class="t"><b>${t}</b><i style="--w:${(w*100).toFixed(0)}%"></i></span><span class="ph"><i style="background-image:url(${PH[p1]})"></i><i style="background-image:url(${PH[p2]})"></i></span></button>`).join('');
  $('ymr').querySelectorAll('.ymrow').forEach(r=>r.onclick=()=>{if(!shots){hap('warn','やわらかく2回(まだ ひらけない)');shake(r);toast('今日 1枚 撮ると、ひらきます');return}hap('pop','ぷにっ(ことばへ)');toast(r.dataset.t+' の 昨日へ')})}
function renderYC(){if(!$('ycal'))return;const d=new Date(),y=d.getFullYear(),m=d.getMonth(),first=new Date(y,m,1).getDay(),n=new Date(y,m+1,0).getDate(),today=d.getDate();$('ycm').textContent=`${y}.${p2(m+1)}`;
  let h='日月火水木金土'.split('').map(x=>`<span class="w">${x}</span>`).join('')+Array.from({length:first},()=>'<span></span>').join('');
  for(let i=1;i<=n;i++){const past=i<today,star=past&&(i%4===1);h+=`<button class="d${i===today?' td':''}${past?' mk':''}${star?' st':''}" data-d="${i}">${i}${star?'<em>★</em>':''}</button>`}
  $('ycal').innerHTML=h;$('ycal').querySelectorAll('.d.mk').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(その日の 1枚)');toast(`${m+1}/${b.dataset.d} の 1枚(グループ ＋ せかい)`)})}
function renderYAll(){renderYMeta();renderYGroups();renderYM();renderYC();if(window.yOnce)yOnce()}
function ytab(id,quiet){YTAB=id;document.querySelectorAll('.ytab').forEach(t=>t.classList.toggle('on',t.id===id));document.querySelectorAll('#ynav button').forEach(b=>b.classList.toggle('on',b.dataset.t===id));
  const t=$(id);t.animate([{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'none'}],{duration:360,easing:'cubic-bezier(.2,.9,.25,1)'});$('ybody').scrollTo({top:0});if(!quiet)hap('sel','コツッ(タブ)')}
document.querySelectorAll('#ynav button').forEach(b=>b.onclick=()=>{if(b.dataset.t!==YTAB)ytab(b.dataset.t);else hap('tick',null,{norip:1})});
function yOrigin(el){const r=rel(el);return {x:r.x+r.w/2,y:r.y+r.h/2}}
function ringBurst(o){for(let i=0;i<2;i++){const r=document.createElement('i');r.className='dbr';r.style.left=o.x+'px';r.style.top=o.y+'px';phone.appendChild(r);
  r.animate([{transform:'translate(-50%,-50%) scale(.5)',opacity:.9},{transform:'translate(-50%,-50%) scale(3.6)',opacity:0}],{duration:640,delay:i*110,easing:'cubic-bezier(.2,.8,.3,1)',fill:'backwards'}).onfinish=()=>r.remove()}}
function yIntro(Y){yHeroIn();[...Y.querySelectorAll('#ytg .yhl,#ytg .yhs,#ytg .ypl,#ytg .yme,#ytg .ysamp,#ytg .grow,#ynav')].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(26px) scale(.97)'},{opacity:1,transform:'none'}],{duration:560,delay:1000+i*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));if(!$('ylock').classList.contains('hide'))$('ylock').animate([{opacity:0},{opacity:1}],{duration:500,delay:1500,fill:'backwards'})}
function openY(from){if(YOPEN)return;YOPEN=true;const Y=$('yst');Y.classList.toggle('dk',yH());renderYAll();ytab('ytg',true);Y.classList.remove('off');
  if(from){const o=yOrigin(from);Y.classList.add('rv','on');Y.getAnimations().forEach(a=>a.cancel());
    Y.animate([{clipPath:`circle(0px at ${o.x}px ${o.y}px)`},{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`}],{duration:700,easing:'cubic-bezier(.3,.85,.25,1)'}).onfinish=()=>Y.classList.remove('rv');
    ringBurst(o);hap('pop','ぷにっ(ダブルタップ)');setTimeout(()=>hap('sel','コツッ(昨日へ)',{norip:1}),260);setTimeout(()=>hap('soft',null,{norip:1}),560);yIntro(Y)}
  else{Y.classList.add('on');hap('sel','コツッ(昨日へ)');setTimeout(()=>hap('tick',null,{norip:1}),240);yIntro(Y)}}
function closeY(from){if(!YOPEN)return;YOPEN=false;const Y=$('yst');
  if(from){const o=yOrigin(from);Y.classList.add('rv');ringBurst(o);hap('pop','ぷにっ(ダブルタップ)');setTimeout(()=>hap('sel','コツッ(今日へ)',{norip:1}),260);
    Y.animate([{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`},{clipPath:`circle(0px at ${o.x}px ${o.y}px)`}],{duration:520,easing:'cubic-bezier(.5,0,.7,.3)',fill:'forwards'}).onfinish=()=>{Y.classList.remove('on','rv');Y.getAnimations().forEach(a=>a.cancel())}}
  else{Y.classList.remove('on');hap('sel','コツッ(今日へ)')}}
/* ダブルタップ:アイコン(アバター)を 2回 とんとん */
function dbl(el,single,dbl2){let t=0,tm=0;el.style.touchAction='manipulation';el.addEventListener('pointerup',e=>{e.preventDefault();const n=performance.now();
  if(n-t<340){clearTimeout(tm);t=0;el.animate([{transform:'scale(1)'},{transform:'scale(.84)',offset:.25},{transform:'scale(1.14)',offset:.6},{transform:'scale(1)'}],{duration:440,easing:'cubic-bezier(.3,1.5,.5,1)'});dbl2(el)}
  else{t=n;hap('tick',null,{norip:1});el.animate([{transform:'scale(1)'},{transform:'scale(.9)',offset:.4},{transform:'scale(1)'}],{duration:200});tm=setTimeout(()=>{t=0;single&&single(el)},340)}})}
const HAV=document.querySelector('#hhd .av');
dbl(HAV,()=>toast('ダブルタップで 昨日へ'),el=>openY(el));
dbl(document.querySelector('#yst .yav'),()=>toast('ダブルタップで 今日へ'),el=>closeY(el));
var HINTED=false;function hintDbl(){if(HINTED||cur!=='home'||YOPEN)return;HINTED=true;const o=yOrigin(HAV);[0,230].forEach(d=>setTimeout(()=>{hap('tick',null,{norip:1});HAV.animate([{transform:'scale(1)'},{transform:'scale(1.16)',offset:.4},{transform:'scale(1)'}],{duration:320,easing:'cubic-bezier(.3,1.5,.5,1)'})},d));
  const r=document.createElement('i');r.className='dbr';r.style.left=o.x+'px';r.style.top=o.y+'px';phone.appendChild(r);r.animate([{transform:'translate(-50%,-50%) scale(.6)',opacity:.8},{transform:'translate(-50%,-50%) scale(2.6)',opacity:0}],{duration:800}).onfinish=()=>r.remove()}
setTimeout(hintDbl,7000);
$('ydsw').onclick=()=>closeY();
$('ymk').onclick=()=>$('gmk').onclick();$('yjn').onclick=()=>$('gjn').onclick();
$('yme').onclick=()=>{hap('pop','ぷにっ(ME)');toast('ME(昨日の まい・7日で きえる)へ')};
$('ypill').onclick=()=>{hap('soft');toast(shots?'あしたの朝 9:00 に ひらきます':'今日を 撮ると、ひらきます')};
{const yb=document.querySelector('#yst .ybody');if(yb)yb.addEventListener('scroll',()=>$('ylock').classList.toggle('sc',yb.scrollTop>140),{passive:true})}
$('ylock').onclick=()=>{hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます')};
setInterval(()=>{if(YOPEN)renderYMeta()},30000);
{const _rg=renderGroups;renderGroups=function(f){_rg(f);renderYGroups(f)};const _rf=renderFriends;renderFriends=function(n){_rf(n);renderYFriends()};const _rh=renderHome;renderHome=function(a){_rh(a);renderYMeta()}}
(function(){const c=$('ctl'),mk=(t,fn)=>{const b=document.createElement('button');b.textContent=t;b.onclick=fn;c.appendChild(b)};mk('昨日 (Lattag yesterday)',()=>{YOPEN?closeY():openY()});mk('昼夜 きりかえ',()=>{const Y=$('yst');Y.classList.toggle('dk')})})();

/* ---- グループの ヒーロー(あなた + 席 + ハッシュタグの シール)---- */
const YS=[[0,-82,'#EE6F9C'],[-95,-52,'#3EFF65'],[96,-50,'#66C4F5'],[-118,14,'#62D279'],[119,18,'#B5E85A'],[-54,70,'#6AD67F'],[54,72,'#9A82F2']];
const YK=[['#放課後',-112,-104,-8,'#EE5E9C','#fff'],['#いつメン',104,-98,8,'#C8F25A','#111'],['#部活',-118,102,7,'#9ED8FF','#111'],['#帰り道',112,106,-6,'#61D278','#111']];
function renderYHero(){if(!$('yseats'))return;const g=GRP[0];const mem=g?g.m:[];
  $('yseats').innerHTML=YS.map(([x,y,c],i)=>{const f=mem[i];return `<button class="yseat${f?' on':''}" style="--x:${x}px;--y:${y}px;--c:${c};--d:${i}" data-i="${i}">${f?`<span class="fc" style="background:${avBg(f)}">${f.n[0]}</span>`:'<i>+</i>'}</button>`}).join('');
  $('ylns').innerHTML=YS.map(([x,y])=>`<line x1="175" y1="150" x2="${175+x}" y2="${150+y}"/>`).join('');
  $('ystks').innerHTML=YK.map(([t,x,y,r,bg,fg],i)=>`<button class="ystk" style="--x:${x}px;--y:${y}px;--r:${r}deg;--bg:${bg};--fg:${fg};--d:${i}" data-t="${t}">${t}</button>`).join('');
  $('yhl').innerHTML=g?`<span class="hi">${g.n}</span>`:'なかまと、<br><span class="hi">昨日</span>を見せあおう。';
  $('yhs').innerHTML=g?g.sub:'4〜8人 ・ 撮った人だけ 見られる';
  $('yseats').querySelectorAll('.yseat').forEach(b=>b.onclick=()=>{hap('pop','ぷにっ(席)');b.animate([{scale:1},{scale:.82,offset:.3},{scale:1.18,offset:.65},{scale:1}],{duration:480,easing:'cubic-bezier(.3,1.5,.5,1)'});if(!b.classList.contains('on'))setTimeout(()=>$('gmk').onclick(),180)});
  $('ystks').querySelectorAll('.ystk').forEach(b=>b.onclick=()=>{hap('sel','コツッ(シール)',{norip:1});b.animate([{rotate:'var(--r)'},{rotate:'calc(var(--r) + 14deg)',offset:.3},{rotate:'calc(var(--r) - 10deg)',offset:.62},{rotate:'var(--r)'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'});toast(b.dataset.t+' は いま よく えらばれています')})}
function yHeroIn(){const A=(el,k,o)=>el&&el.animate(k,Object.assign({fill:'backwards',easing:'cubic-bezier(.3,1.4,.5,1)'},o));
  A($('ycore'),[{scale:0,opacity:0},{scale:1.12,opacity:1,offset:.6},{scale:1,opacity:1}],{duration:700,delay:300});setTimeout(()=>hap('pop','ぷにっ(あなた)',{norip:1}),360);
  document.querySelectorAll('#yseats .yseat').forEach((e,i)=>A(e,[{scale:0,opacity:0},{scale:1.15,opacity:1,offset:.65},{scale:1,opacity:1}],{duration:520,delay:520+i*70}));
  [560,700,840].forEach(d=>setTimeout(()=>hap('tick',null,{norip:1}),d));
  document.querySelectorAll('#ystks .ystk').forEach((e,i)=>A(e,[{scale:.3,opacity:0,translate:'0 -30px'},{scale:1.1,opacity:1,translate:'0 4px',offset:.7},{scale:1,opacity:1,translate:'0 0'}],{duration:560,delay:900+i*90}));
  setTimeout(()=>hap('soft',null,{norip:1}),1240);
  document.querySelectorAll('#ylns line').forEach((l,i)=>A(l,[{opacity:0},{opacity:1}],{duration:500,delay:560+i*70}));
  const hi=document.querySelector('#yhl .hi');if(hi){hi.classList.remove('draw');void hi.offsetWidth;hi.classList.add('draw')}}
(function(){const H=$('yhero');H.addEventListener('pointermove',e=>{const r=H.getBoundingClientRect();H.style.setProperty('--px',(((e.clientX-r.left)/r.width)*2-1).toFixed(3));H.style.setProperty('--py',(((e.clientY-r.top)/r.height)*2-1).toFixed(3))});
  ['pointerleave','pointerup','pointercancel'].forEach(ev=>H.addEventListener(ev,()=>{H.style.setProperty('--px',0);H.style.setProperty('--py',0)}));
  $('ycore').onclick=()=>{hap('heart','ドクン(あなた)',{norip:1});const r=$('ycore').querySelector('.rg');r.animate([{rotate:'0deg'},{rotate:'540deg'}],{duration:900,easing:'cubic-bezier(.2,.8,.2,1)'});$('ycore').animate([{scale:1},{scale:.9,offset:.2},{scale:1.1,offset:.5},{scale:1}],{duration:560,easing:'cubic-bezier(.3,1.5,.5,1)'});ringBurst(yOrigin($('ycore')))};
  $('ysamp').onclick=()=>{hap('soft','やわらかく1回');toast('サンプルです。つくると ここに できます')};
  ['ymk','yjn'].forEach(id=>{const b=$(id);b.addEventListener('pointerdown',()=>hap('tick',null,{norip:1}))})})();
/* --- 昨日の世界で 多かったことば --- */
const TOP=[['#散歩',1,'a','d'],['#放課後',.84,'f','b'],['#夕焼け',.71,'a','c'],['#雨の日',.55,'c','e'],['#ねむい',.42,'b','f']];
function renderTop(){$('tgl').innerHTML=TOP.map(([t,w,p1,p2],i)=>`<button class="tgr" data-t="${t}"><span class="n">0${i+1}</span><span class="t"><b>${t}</b><i class="lb" style="--w:${(w*100).toFixed(0)}%"></i></span><span class="ph"><i style="background-image:url(${PH[p1]})"></i><i style="background-image:url(${PH[p2]})"></i><i style="background-image:url(${PH[i%2?'e':'b']})"></i></span></button>`).join('');
  $('tgl').querySelectorAll('.tgr').forEach(r=>r.onclick=()=>{if(!shots){hap('warn','やわらかく2回(まだ ひらけない)');shake($('tglock'));return}hap('pop','ぷにっ(ことばへ)');toast(r.dataset.t+' の 昨日へ(Mondo)')})}
$('tglock').onclick=()=>{hap('soft');toast('今日 1枚 撮ると、ひらきます')};
/* --- きのうの3こま:タップで めくる / 長押し 0.7秒で 1年 のこす --- */
let YD=[{p:'a',t:'#夕焼け',tm:'18:42'},{p:'b',t:'#放課後',tm:'16:05'},{p:'c',t:'#帰り道',tm:'21:13'}],ydTop=0,kept=-1;
const STAR='<svg class="star" viewBox="0 0 40 40"><path d="M20 1c1.6 10 8 16.4 19 19-11 2.6-17.4 9-19 19-1.6-10-8-16.4-19-19C12 17.4 18.4 11 20 1z" fill="#FFD60A" stroke="#111" stroke-width="2.2" stroke-linejoin="round"/></svg>';
function renderYday(){const S=$('ydst');S.innerHTML=YD.map((y,i)=>`<div class="ydc${i===kept?' kept':''}" data-i="${i}"><img src="${PH[y.p]}" alt=""><span class="tg">${y.t}</span><span class="d">${y.tm}</span><svg class="ring" viewBox="0 0 70 70"><circle cx="35" cy="35" r="32" transform="rotate(-90 35 35)"/></svg>${STAR}<span class="keep">1年 のこる</span></div>`).join('');layoutYd();S.querySelectorAll('.ydc').forEach(bindYd)}
function layoutYd(){$('ydst').querySelectorAll('.ydc').forEach(c=>{const i=+c.dataset.i,o=(i-ydTop+3)%3;c.style.zIndex=3-o;c.style.transform=`translate(${o*16}px,${o*8}px) rotate(${[-3,4,9][o]}deg) scale(${1-o*.05})`});$('ydn').textContent=(ydTop+1)+' / 3';
  $('ydh').textContent=kept>=0?`えらんだ1枚は、1年 のこります ・ 長押しで えらびなおす`:'タップで めくる ・ 長押しで「1年 のこす」'}
function bindYd(c){let t0=0,raf=0,done=false;const ring=c.querySelector('.ring circle');
  c.addEventListener('pointerdown',e=>{if(+c.dataset.i!==ydTop)return;try{c.setPointerCapture(e.pointerId)}catch(_){}t0=performance.now();done=false;
    const st=now=>{if(!t0)return;const k=Math.min(1,(now-t0)/700);if(k>.12)c.classList.add('hold');ring.style.strokeDashoffset=(201*(1-k)).toFixed(1);setCont(.1+.6*k,'ためる(1年 のこす)');
      if(k>=1){t0=0;done=true;setCont(0);c.classList.remove('hold');kept=+c.dataset.i;$('ydst').querySelectorAll('.ydc').forEach(x=>x.classList.toggle('kept',+x.dataset.i===kept));hap('success','トトトン(1年 のこす)',{norip:1});setTimeout(()=>hap('land',null,{norip:1}),260);layoutYd();return}
      raf=requestAnimationFrame(st)};raf=requestAnimationFrame(st)});
  const up=()=>{if(!t0&&!done){return}const was=t0;t0=0;cancelAnimationFrame(raf);setCont(0);c.classList.remove('hold');ring.style.strokeDashoffset=201;
    if(done){done=false;return}if(was&&performance.now()-was<260){// タップ = めくる
      hap('sel','コツッ(めくる)');c.animate([{transform:c.style.transform},{transform:'translate(-150px,-30px) rotate(-18deg)',offset:.45},{transform:'translate(30px,16px) rotate(9deg) scale(.9)'}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)'});ydTop=(ydTop+1)%3;setTimeout(layoutYd,200);setTimeout(()=>hap('tick',null,{norip:1}),380)}};
  ['pointerup','pointercancel'].forEach(ev=>c.addEventListener(ev,up))}
/* --- 7日の film --- */
var wkSel=0,wkStar={},wkIdx=-1,wkDone=false;
function wkLab(k){const dd=new Date();dd.setDate(dd.getDate()-k);return p2(dd.getMonth()+1)+'.'+p2(dd.getDate())}
function wkN(k){return k===0?shots:([3,2,3,1,3,2][k-1]||0)}
function wkCap(k){const C=$('wkcap');if(!C)return;const n=wkN(k),left=7-k;
  const seg=Array.from({length:7},(_,s)=>`<i class="${s<left?'on':''}" style="--s:${s}"></i>`).join('');
  const st=wkStar[k];const msg=k===0?'今日の film ・ 9:00 に ひらく':k===6?(st<0?'あした きえます。のこす 1枚を ★ で えらんで':'あした きえます ・ ★ の 1枚は 1年 のこる'):`あと ${left}日で きえる ・ ${n}こま`;
  const hint=k>0&&n>0?'こまを 長押しで ★ 1年 のこす(1日 1枚)':'';
  C.innerHTML=`<div class="wcd"><b>${wkLab(k)}</b><span>${n}こま</span><em>${k===0?'今日':'あと '+left+'日'}</em></div><div class="wsg${left<=2?' hot':''}">${seg}</div><p class="wcm">${msg}</p>${hint?`<p class="wch">${hint}</p>`:''}`;
  C.classList.remove('sw');void C.offsetWidth;C.classList.add('sw')}
function wkPick(k,quiet){const W=$('wkst');wkSel=k;W.querySelectorAll('.wkd').forEach(x=>x.classList.toggle('on',+x.dataset.k===k));wkCap(k);
  const c=W.querySelector(`.wkd[data-k="${k}"]`);if(c)W.scrollTo({left:c.offsetLeft-(W.clientWidth-c.offsetWidth)/2,behavior:'smooth'});
  if(!quiet){if(k===6&&wkStar[6]<0)hap('warn','やわらかく2回(もうすぐ きえる)');else hap('pop','ぷにっ(日を えらぶ)',{norip:1})}}
function wkKeep(c,f){const k=+c.dataset.k;const j=+f.dataset.j;
  if(wkStar[k]===j){hap('soft','やわらかく1回(もう ★ です)');toast('この こまに ★ は ついています');return}
  c.querySelectorAll('.fs i.k').forEach(x=>x.classList.remove('k'));f.classList.add('k');wkStar[k]=j;
  if(k===6){c.classList.remove('em');const ash=c.querySelector('.ash');if(ash)ash.remove()}
  hap('heart','ドクン(★ 1年 のこす)',{norip:1});
  for(let i=0;i<7;i++){const b=document.createElement('b');b.className='sb';b.textContent='★';f.appendChild(b);const a=i/7*Math.PI*2,r=26+Math.random()*14;
    b.animate([{transform:'translate(-50%,-50%) scale(.4)',opacity:1},{transform:`translate(calc(-50% + ${Math.cos(a)*r}px),calc(-50% + ${Math.sin(a)*r}px)) scale(1.1) rotate(${Math.random()*80-40}deg)`,opacity:0}],{duration:620,easing:'cubic-bezier(.2,.8,.3,1)'}).onfinish=()=>b.remove()}
  toast(k===6?'★ のこしました ・ この1枚は 1年 のこります':'★ を この こまに うつしました');wkPick(k,true)}
function weekIn(){const t=+$('wkn').dataset.t||0,el=$('wkn'),t0=performance.now();
  (function f(n){const p=Math.min(1,(n-t0)/900);el.textContent=Math.round(t*(1-Math.pow(1-p,3)));if(p<1)requestAnimationFrame(f);else{el.classList.remove('pop');void el.offsetWidth;el.classList.add('pop');hap('pop','ぷにっ(こまが そろう)',{norip:1})}})(t0);
  for(let s=0;s<7;s++)setTimeout(()=>hap(s===0?'click':'tick',s===0?'カチッ(フィルムが すすむ)':null,{norip:1}),140+s*80)}
function renderWeek(){const W=$('wkst');let h='';const pp=['a','b','c','d','e','f'];let total=0;
  for(let k=6;k>=0;k--){const lab=wkLab(k);const left=7-k;const n=wkN(k);total+=n;const i=6-k;
    if(!(k in wkStar))wkStar[k]=k===6?-1:(k===0?-1:[0,1,2].find(j=>j<n&&(k+j)%4===0)??-1);
    const star=wkStar[k];
    const fr=Array.from({length:3},(_,j)=>k===0?(j<shots?'<i class="m"></i>':'<i></i>'):(j<n?`<i data-j="${j}" class="${star===j?'k':''}" style="--j:${j};background-image:url(${PH[pp[(k*2+j)%6]]})"></i>`:'<i></i>')).join('');
    const em=k===6&&star<0;
    h+=`<div class="wkd${k===0?' td':' old'}${em?' em':''}${left<=2?' hot':''}${wkSel===k?' on':''}" style="--o:${(1-(k/7)*.55).toFixed(2)};--s:${(1-(k/7)*.6).toFixed(2)};--i:${i}" data-l="${lab}" data-n="${n}" data-k="${k}"><div class="fs">${fr}</div><div class="fuse"><i style="--w:${(left/7*100).toFixed(0)}%"></i></div><div class="dl"><span>${lab}</span><b>${k===0?'今日':k===6?'あした きえる':'あと '+left+'日'}</b></div>${em?'<u class="ash"><i></i><i></i><i></i><i></i></u>':''}</div>`}
  W.innerHTML=h;const wn=$('wkn');wn.dataset.t=total;if(!wn.closest('.pre'))wn.textContent=total;
  W._init=1;setTimeout(()=>{W.scrollLeft=W.scrollWidth;setTimeout(()=>{wkIdx=wkMid(W);wkMark(W);W._init=0},60)},50);
  W.querySelectorAll('.wkd').forEach(c=>c.onclick=()=>{if(W._lp)return;wkPick(+c.dataset.k)});
  wkCap(wkSel);
  if(!W._b){W._b=1;let lt=0,lp=null,sx=0,sy=0;
    W.addEventListener('pointerdown',e=>{const f=e.target.closest('.fs i');if(!f||!f.dataset.j)return;const c=f.closest('.wkd');if(+c.dataset.k===0)return;lp=f;sx=e.clientX;sy=e.clientY;f.classList.add('hold');hap('tick',null,{norip:1});
      lt=setTimeout(()=>{if(!lp)return;W._lp=1;const ff=lp;ff.classList.remove('hold');lp=null;wkKeep(c,ff);setTimeout(()=>W._lp=0,450)},520)});
    const cancel=()=>{clearTimeout(lt);if(lp){lp.classList.remove('hold');lp=null}};
    ['pointerup','pointercancel','pointerleave'].forEach(ev=>W.addEventListener(ev,cancel));
    W.addEventListener('pointermove',e=>{if(lp&&(Math.abs(e.clientX-sx)>8||Math.abs(e.clientY-sy)>8))cancel()});
    W.addEventListener('scroll',()=>{const th=$('wkthumb');const sw=W.scrollWidth,cw=W.clientWidth;th.style.width=(cw/sw*100)+'%';th.style.left=(W.scrollLeft/sw*100)+'%';
      if(W._init)return;const ix=wkMid(W);if(ix!==wkIdx){wkIdx=ix;wkMark(W);hap('sel','コツッ(フィルムが 1こま すすむ)',{norip:1,gap:70})}},{passive:true})}}
function wkMid(W){const c=W.scrollLeft+W.clientWidth/2;return Math.max(0,Math.min(6,Math.floor((c-22)/132)))}
function wkMark(W){W.querySelectorAll('.wkd').forEach(x=>x.classList.toggle('mid',+x.dataset.i===wkIdx||(6-(+x.dataset.k))===wkIdx));const th=$('wkthumb');if(th){th.style.width=(W.clientWidth/W.scrollWidth*100)+'%';th.style.left=(W.scrollLeft/W.scrollWidth*100)+'%'}}
/* --- 世界の 9:00(なぞると 時間が うごく)--- */
const CITY=[['ホノルル','Honolulu',-10],['ロサンゼルス','LA',-8],['ニューヨーク','NY',-5],['サンパウロ','São Paulo',-3],['ロンドン','London',0],['パリ','Paris',1],['ドバイ','Dubai',4],['デリー','Delhi',5.5],['バンコク','Bangkok',7],['東京','Tokyo',9],['シドニー','Sydney',11]];
let w9off=0;const zx=z=>((z+11)/24)*390*.9+18;
function renderW9(){const nowU=new Date().getUTCHours()+new Date().getUTCMinutes()/60+w9off;let z=9-nowU;z=((z+12)%24+24)%24-12;if(z<-11)z+=24;
  const x=zx(z);$('w9line').style.left=x+'px';
  $('w9band').style.background=`linear-gradient(90deg,#0E0E18 0%,#0E0E18 ${Math.max(0,x/3.9-24)}%,#3A2A50 ${Math.max(0,x/3.9-12)}%,#FF9A62 ${x/3.9}%,#FFE7C8 ${Math.min(100,x/3.9+7)}%,#FFF6E8 ${Math.min(100,x/3.9+30)}%,#C9D6F0 100%)`;
  let best=CITY[0],bd=99;CITY.forEach(c=>{const d=Math.abs(c[2]-z);if(d<bd){bd=d;best=c}});
  const bx=zx(best[2]);let lx=-99;$('w9cities').innerHTML=CITY.map(c=>{const x=zx(c[2]);const show=c===best||(x-lx>46&&Math.abs(x-bx)>46);if(show)lx=x;return `<i style="left:${x}px"></i>`+(show?`<span class="${c===best?'on':''}" style="left:${x}px">${c[1]}</span>`:'')}).join('');
  $('w9c').textContent=best[1];$('w9now').textContent=`${best[0]} の あたりが いま 9:00`;
  const west=CITY.filter(c=>c[2]<best[2]).sort((a,b)=>b[2]-a[2])[0]||CITY[CITY.length-1];let hrs=((z-west[2])%24+24)%24;$('w9next').textContent=`つぎ:${west[0]} まで ${Math.floor(hrs)}h ${p2(Math.round((hrs%1)*60))}m`;return best}
(function(){const el=$('w9');let sx=0,o0=0,on=false,lastH=0,lastC=null;el.addEventListener('pointerdown',e=>{on=true;sx=e.clientX;o0=w9off;lastH=Math.round(w9off);try{el.setPointerCapture(e.pointerId)}catch(_){}hap('soft','そっと(つかむ)',{norip:1})});
  el.addEventListener('pointermove',e=>{if(!on)return;w9off=o0-(e.clientX-sx)/SC/16;const hh=Math.round(w9off);if(hh!==lastH){lastH=hh;hap('tick',null,{norip:1,noq:1})}const c=renderW9();if(c!==lastC){if(lastC)hap('sel','コツッ(朝が 次の街へ)',{norip:1});lastC=c}});
  const up=()=>{if(!on)return;on=false;const f=w9off;const t0=performance.now();const back=()=>{const k=Math.min(1,(performance.now()-t0)/600);w9off=f*(1-(1-Math.pow(1-k,3)));renderW9();if(k<1)requestAnimationFrame(back);else{w9off=0;renderW9();hap('soft','やわらかく1回(いまに もどる)',{norip:1})}};requestAnimationFrame(back)};
  el.addEventListener('pointerup',up);el.addEventListener('pointercancel',up)})();
setInterval(()=>{if($('home').classList.contains('on'))renderW9()},30000);
/* --- friend 入口と 画面 --- */
function renderFriendEntry(){$('frn').textContent=FR.length+' / '+FMAX;$('fcnt').textContent=FR.length+' / '+FMAX;const E=$('fent');
  if(!FR.length){E.innerHTML=`<span class="fst">${PHS.replace('class="phs" id="phs"','class="phs2"')}</span><span class="ftx"><b>まだ、だれも。</b><small>ふって つながる ・ 12人まで</small></span><em>›</em>`;return}
  const took=FR.filter(f=>f.k>0).length;E.innerHTML=`<span class="fst">${FR.slice(0,4).map((f,i)=>`<i style="left:${i*17}px;background:${avBg(f)};z-index:${5-i}">${f.n[0]}</i>`).join('')}</span><span class="ftx"><b>${FR.slice(0,3).map(f=>f.n).join('・')}${FR.length>3?' ほか':''}</b><small>今日 ${took}人が 撮った ・ つつく</small></span><em>›</em>`}
function openFriend(){const F=$('fscr');F.classList.remove('off');F.classList.add('on');hap('sel','コツッ(friend へ)');setTimeout(()=>hap('tick',null,{norip:1}),300);
  F.querySelectorAll('.fp,.fr0').forEach((x,i)=>x.animate([{opacity:0,transform:'translateY(18px) scale(.9)'},{opacity:1,transform:'none'}],{duration:480,delay:180+i*50,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
function closeFriend(){const F=$('fscr');F.classList.add('off');F.classList.remove('on');hap('soft','やわらかく1回(もどる)');renderFriendEntry()}
$('fent').onclick=openFriend;$('fback').onclick=closeFriend;$('fcall').onclick=()=>{if(FR.length>=FMAX){hap('warn');toast('デモの 友だちは ここまで');return}openSheet('shf')};
$('fday').textContent=p2(now.getMonth()+1)+'.'+p2(now.getDate());$('dvd').textContent=p2(now.getMonth()+1)+'.'+p2(now.getDate());
{const y=new Date();y.setDate(y.getDate()-1);$('ydd').textContent=p2(y.getMonth()+1)+'.'+p2(y.getDate())}
function renderDay2(){renderDev();$('tgs').classList.toggle('lock',!shots);renderWeek();renderW9();renderFriendEntry();if(window.renderArc)renderArc()}
renderTop();renderYday();

window.renderFriendEntry=renderFriendEntry;window.renderDay2=renderDay2;window.renderArc=renderArc;
/* =================== オープニング(アプリを ひらいたとき ・ 約3.4秒) =================== */
const OP=$('open');let OA=[],OT=[],opening=false;
$('odt').textContent=p2(now.getMonth()+1)+'.'+p2(now.getDate());$('ost').textContent=DT;
function openAnims(){const E=(sel,k,o,fill)=>{const el=typeof sel==='string'?OP.querySelector(sel):sel;OA.push(el.animate(k,Object.assign({fill:fill||'both',easing:'cubic-bezier(.2,.8,.2,1)'},o)))};
  E('.odot',[{opacity:0,transform:'scale(0)'},{opacity:1,transform:'scale(1)',offset:.22},{opacity:1,transform:'scale(1)',offset:.9},{opacity:0,transform:'scale(1.6)'}],{duration:1000,delay:90,easing:'ease-out'});
  [['ktl',-1,-1],['ktr',1,-1],['kbl',-1,1],['kbr',1,1]].forEach(([c,x,y])=>E('.obr .'+c,[{transform:`translate(${x*150}px,${y*200}px)`,opacity:0},{opacity:1,offset:.3},{transform:`translate(${-x*9}px,${-y*9}px)`,opacity:1,offset:.78},{transform:'translate(0,0)',opacity:1}],{duration:560,delay:240,easing:'cubic-bezier(.5,0,.3,1)'}));
  E('.olab',[{opacity:0},{opacity:1}],{duration:320,delay:700});
  E('.opg',[{opacity:0},{opacity:1,offset:.01},{opacity:1,offset:.8},{opacity:0}],{duration:2500,delay:1040,easing:'linear'});
  E('.obk',[{opacity:1},{opacity:0}],{duration:1,delay:1040,easing:'linear'});
  E('.obr',[{opacity:1},{opacity:0}],{duration:1,delay:1040,easing:'linear'});
  E('.ofl',[{opacity:0},{opacity:1,offset:.12},{opacity:1,offset:.4},{opacity:0}],{duration:430,delay:985,easing:'linear'});
  E('.och',[{transform:'translateY(780px)'},{transform:'translateY(-16px)',offset:.74},{transform:'translateY(0)'}],{duration:780,delay:1200,easing:'cubic-bezier(.3,.9,.3,1)'});
  E('.ofr',[{transform:'rotate(-9deg)'},{transform:'rotate(-2deg)',offset:.74},{transform:'rotate(-3deg)'}],{duration:780,delay:1200,easing:'cubic-bezier(.3,.9,.3,1)'});
  E('.ofr',[{transform:'rotate(-3deg)'},{transform:'rotate(0deg)'}],{duration:320,delay:2330,easing:'ease-in-out'},'forwards');
  E('.otp',[{opacity:0,transform:'translateY(-14px) rotate(-3deg)'},{opacity:.94,transform:'rotate(-3deg)'}],{duration:260,delay:1800});
  E('.osk',[{transform:'translateY(100%)',filter:'blur(10px)'},{transform:'translateY(0)',filter:'blur(0)'}],{duration:1050,delay:1850,easing:'cubic-bezier(.3,.6,.2,1)'});
  E('.omk',[{opacity:1},{opacity:.0}],{duration:1150,delay:1900,easing:'ease-in-out'});
  [...$('owm').querySelectorAll('span')].forEach((s,i)=>E(s,[{opacity:0,transform:'translateY(12px)',filter:'blur(7px)'},{opacity:1,transform:'none',filter:'blur(0)'}],{duration:420,delay:2250+i*70}));
  E('#ost',[{opacity:0},{opacity:1}],{duration:300,delay:2700});
  E('.omorph',[{opacity:0},{opacity:1}],{duration:1,delay:2670,easing:'linear'});
  E('.omorph',[{left:'80px',top:'207px',width:'230px',height:'270px',borderRadius:'5px'},{left:'-105px',top:'742px',width:'600px',height:'600px',borderRadius:'300px'}],{duration:780,delay:2670,easing:'cubic-bezier(.65,0,.25,1)'},'forwards');
  E('.omorph .mB',[{opacity:0},{opacity:1}],{duration:700,delay:2750,easing:'ease-in'},'forwards');
  E('.och',[{opacity:1},{opacity:0}],{duration:300,delay:2670,easing:'ease-out'},'forwards');
  E(OP,[{opacity:1},{opacity:0}],{duration:200,delay:3480,easing:'ease-out'},'forwards')}
function openClean(){OA.forEach(a=>{try{a.cancel()}catch(_){}});OA=[];OT.forEach(clearTimeout);OT=[];setCont(0);OP.classList.remove('on');OP.style.opacity='';opening=false;$('hmoon').classList.remove('pre')}
function openEnd(sunDone){openClean();busy=false;phone.classList.add('lt');homeFocus();if(!sunDone)homeIn(true)}
function playOpen(){if(opening)return;opening=true;busy=true;cur='home';show('home');phone.classList.remove('lt');$('hmoon').classList.add('pre');OP.classList.add('on');OP.style.opacity='';openAnims();
  const T=(f,ms)=>OT.push(setTimeout(f,ms));
  T(()=>hap('pop','ぷっ(光が ひとつ)',{norip:1}),180);
  T(()=>hap('click','キュッ(ファインダーが しまる)',{norip:1}),760);
  T(()=>{hap('shutter','パシャ(まっ白)',{norip:1});phone.classList.add('lt')},1000);
  T(()=>hap('soft','すーっ(チェキが でてくる)',{norip:1}),1230);
  T(()=>hap('land','トン(とまる)',{norip:1}),1900);
  T(()=>{const t0=performance.now();const rp=()=>{if(!opening)return;const k=Math.min(1,(performance.now()-t0)/1000);setCont(.12+.7*k*k,'じわっと強くなる(現像)');if(k<1)requestAnimationFrame(rp);else setCont(0)};requestAnimationFrame(rp)},1850);
  [0,1,2,3,4].forEach(i=>T(()=>hap('tick',null,{norip:1}),2280+i*70));
  T(()=>{setCont(0);hap('heart','ドクン(日の出に なる)',{norip:1});homeIn(false)},2670);
  T(()=>{$('hmoon').classList.remove('pre')},3440);
  T(()=>hap('land','トン(おちつく)',{norip:1}),3460);
  T(()=>openEnd(true),3700)}
function skipOpen(){if(!opening)return;OT.forEach(clearTimeout);OT=[];OA.forEach(a=>a.pause());openEnd(false);hap('tick',null,{norip:1})}
function openFreeze(){OT.forEach(clearTimeout);OT=[];setCont(0)}
function openSeek(ms){OA.forEach(a=>{a.pause();a.currentTime=ms})}
OP.addEventListener('click',()=>skipOpen());

function goShoot(){if(busy)return;if(shots>=3){hap('warn','やわらかく2回(今日は、ここまで)');shake($('hmoon'));toast('9:00に、ひらきます');return}
  const m=$('hmoon');window.mglSpin&&mglSpin();m.animate([{transform:'scale(1)'},{transform:'scale(.95,.92)',offset:.3},{transform:'scale(1.04)'}],{duration:260});hap('pop','ぷにっ(月)');
  setTimeout(()=>{busy=true;tags=[];tin.value='';renderTags();fadeTo('tag',420,()=>{busy=false;entTag();startPh()})},180)}
$('hmoon').onclick=goShoot;
function dayDone(){hap('success','トトトン(今日は、ここまで)',{norip:1});$('hline').querySelectorAll('.hck').forEach((c,i)=>setTimeout(()=>{c.classList.remove('sw');void c.offsetWidth;c.classList.add('sw');hap('tick',null,{norip:1})},i*140));
  setTimeout(()=>{const n=$('h9');n.innerHTML=seg900();n.classList.add('on');hap('thud','ドン(9:00 に ひらく)',{norip:1})},620)}


/* =================== 翌朝 9:00:現像 → 上映 =================== */
const SEGC=s=>{let x=0,o='',gh='';const w=40,h=80,t=10;for(const ch of s){if(ch===':'){o+=`<circle cx="${x+6}" cy="${h*.3}" r="5.5"/><circle cx="${x+6}" cy="${h*.7}" r="5.5"/>`;x+=22;continue}gh+=segs('8',x,w,h,t);o+=segs(ch,x,w,h,t);x+=58}
  return `<svg viewBox="-8 -8 ${x+4} ${h+16}"><g transform="skewX(-6)"><g class="ghost">${gh}</g><g class="lit">${o.replace(/<circle/g,'<circle fill="#24A73E"')}</g></g></svg>`};
const vid=$('vid'),dch=$('dcheki');vid.src=window.VID.src;$('vpo').src=window.VID.poster;
let devT=[],devOn=false,playing=false,tickIv=0,fbIv=0;const FB=!(vid.canPlayType&&vid.canPlayType('video/mp4; codecs="avc1.42E01E"'));
function dT(f,ms){devT.push(setTimeout(f,ms))}
function devClear(){devT.forEach(clearTimeout);devT=[];clearInterval(tickIv);clearInterval(fbIv);dch.classList.remove('fb');setCont(0);vid.pause();dch.classList.remove('playing','big','lit','flick');$('dev').classList.remove('big');playing=false}
function goDev(){if(busy)return;busy=true;devClear();$('dclock').className='dclock dim';$('dclock').innerHTML=SEGC('8:59');$('fog').style.opacity=.97;$('dvt').style.opacity=1;$('dplay').classList.remove('on');$('dcap').textContent='9:00 に、仕上がります';$('bar').style.width='0';
  dch.style.transform='';const go=()=>{busy=false;devSeq()};if(cur==='cam')leaveCam('dev',go);else fadeTo('dev',420,go)}
function devSeq(){devOn=true;
  dT(()=>{$('dclock').innerHTML=SEGC('9:00');$('dclock').className='dclock on';hap('click','カチッ(9:00)')},900);
  dT(()=>{$('dcap').textContent='現像中 ・ ミルク色が とけて、レトロな 色に';const t0=performance.now();const rp=()=>{const k=(performance.now()-t0)/1700;if(k<1&&devOn){setCont(.15+k*.7,'じわっと強くなる(現像)');requestAnimationFrame(rp)}};requestAnimationFrame(rp);
    $('fog').animate([{opacity:.97,filter:'blur(0px)'},{opacity:.5,filter:'blur(6px)',offset:.6},{opacity:0,filter:'blur(10px)'}],{duration:1700,easing:'cubic-bezier(.4,0,.3,1)',fill:'forwards'});$('dvt').animate([{opacity:1},{opacity:0}],{duration:900,fill:'forwards'});
    dch.animate([{transform:'rotate(-3deg)'},{transform:'rotate(-1.5deg) scale(1.01)',offset:.5},{transform:'rotate(-3deg)'}],{duration:1700,easing:'ease-in-out'})},1500);
  dT(()=>{setCont(0);hap('heart','ドクン(ひらいた)');dch.classList.add('lit','flick');$('dim').classList.remove('trk');void $('dim').offsetWidth;$('dim').classList.add('trk');$('dcap').textContent='ひらきました ・ RETRO-8 に 仕上がりました';[0,110,230,360].forEach(d=>dT(()=>hap('tick',null,{norip:1}),d))},3300);
  dT(()=>{$('dplay').classList.add('on');hap('pop','ぷにっ(上映する)',{norip:1});$('dpt').textContent='上映する'},4000)}
function playIn(){if(playing)return;playing=true;hap('pop','ぷにっ(ひろがる)');$('dplay').classList.remove('on');dch.classList.add('big','playing');$('dev').classList.add('big');$('dcap').textContent='タップで とじる ・ 7日で消えます';
  if(FB){dch.classList.add('fb');const t0=performance.now();clearInterval(fbIv);fbIv=setInterval(()=>{const s=((performance.now()-t0)/1000)%6;$('bar').style.width=(s/6*100).toFixed(1)+'%';$('tc').textContent='▶ 0:0'+Math.floor(s)+' / 0:06'},100)}else{vid.currentTime=0;const pr=vid.play();if(pr&&pr.catch)pr.catch(()=>{})}
  setTimeout(()=>hap('projector','カタカタ(映写機が まわる)',{norip:1}),260);let n=0;clearInterval(tickIv);tickIv=setInterval(()=>{if(++n<=6)hap('tick',null,{norip:1,gap:60});else clearInterval(tickIv)},120)}
function playOut(){if(!playing)return;playing=false;clearInterval(tickIv);clearInterval(fbIv);hap('soft','やわらかく1回(とじる)');vid.pause();dch.classList.remove('big','playing','fb');$('dev').classList.remove('big');$('dpt').textContent='もういちど';$('dplay').classList.add('on');$('dcap').textContent='ひらきました'}
vid.addEventListener('timeupdate',()=>{if(!vid.duration)return;$('bar').style.width=(vid.currentTime/vid.duration*100).toFixed(1)+'%';$('tc').textContent='▶ 0:'+p2(Math.floor(vid.currentTime))+' / 0:'+p2(Math.round(vid.duration))});
vid.addEventListener('seeked',()=>{if(playing&&vid.currentTime<.2)hap('tick','ごく軽く1回(もういちど)',{norip:1})});
$('dplay').onclick=playIn;dch.addEventListener('click',()=>{if(playing)playOut()});
$('dx').onclick=()=>{hap('tick','ごく軽く1回(とじる)');devClear();devOn=false;toHome()};

/* =================== パネル =================== */
function reset(){closeOb();closeRoom();cmHide();CMS.clear();if($('fscr').classList.contains('on'))closeFriend();FR=[];GRP=[];INV=null;renderFriends();renderGroups();renderPick();devClear();devOn=false;KIND.length=0;if(mode==='movie')setMode('photo');shots=0;tags=[];tin.value='';renderTags();renderCam();renderHome();$('h9').classList.remove('on');show('home');homeFocus()}
document.querySelectorAll('#ctl button').forEach(b=>b.onclick=()=>{const c=b.dataset.c;
  if(c==='open')playOpen();else if(c==='ob'){if(OB.on)closeOb();else openOb()}else if(c==='home'){if(cur==='home'){homeFocus();$('hs').scrollTo({top:0});homeIn()}else toHome()}else if(c==='tag'){if(cur==='home'){busy=true;fadeTo('tag',380,()=>{busy=false;entTag();startPh()})}else toTag()}
  else if(c==='cam'){if(!tags.length){tags=['#雨の日','#放課後'];renderTags()}toCam()}
  else if(c==='last'){shots=2;renderCam();renderHome();toast('のこり 1こま')}
  else if(c==='cam-m'){if(!tags.length){tags=['#雨の日','#放課後'];renderTags()}const go=()=>setTimeout(()=>setMode('movie'),mode==='movie'?0:900);if(cur==='cam')setMode('movie');else{toCam();go()}}
  else if(c==='next')goDev();
  else if(c==='fr3'){if(cur!=='home')toHome();FR=FPOOL.slice(0,3);renderFriends();renderPick();renderFriendEntry();setTimeout(openFriend,400)}
  else if(c==='day'){if(cur!=='home')toHome();if($('fscr').classList.contains('on'))closeFriend();cmHide();setDay(!DAY2);homeFocus();toast(DAY2?'2日目からの Home':'初回の Home(はじめての 合図つき)')}
  else if(c==='inv'){if(cur!=='home')toHome();INV={from:'あや',n:'2-B のなかま',size:5,m:[FPOOL[1],FPOOL[0],FPOOL[4]]};renderGroups();homeFocus();hap('pop','ぷにっ(招待が とどいた)',{norip:1})}
  else if(c==='room'){let g=GRP.find(g=>!g.pend&&g.m.length);if(!g){g={n:'いつメン',m:FPOOL.slice(0,4).map(f=>({...f})),sub:'5人',pill:'あと 2人',un:1,last:'れな: あと そらだけ。はよ 撮って'};GRP.unshift(g);renderGroups();renderYGroups()}if(RM.on)closeRoom();else openRoom(g)}
  else if(c==='allin'){if(!RM.on){toast('さきに「グループの 部屋」を ひらく');return}rmAll()}
  else if(c==='rare'){openRvl(2,true)}
  else if(c==='reset')reset()});
const vb=document.querySelector('#ctl button[data-c="vol"]');vb.onclick=null;vb.addEventListener('pointerdown',e=>{e.preventDefault();volDown();vb.classList.add('on')});['pointerup','pointerleave','pointercancel'].forEach(ev=>vb.addEventListener(ev,()=>{volUp();vb.classList.remove('on')}));
renderTags();renderCam();setDay(true);show('home');homeFocus();

/* ===== 現像の画面(撮影のあと:前日の1枚が チェキのように ひらく → 投稿を えらぶ → ホーム) ===== */
var RVL=false;
var RV2={};
function openRvl(n,rare){if(RVL)return;RVL=true;n=n||1;const R=$('rvl'),P=['d','b','a'][(n-1)%3],tm=TM[n-1]||'18:42',rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
  document.documentElement.style.setProperty('--grn',GRN);R.classList.toggle('rare',!!rare);R.classList.remove('dn');
  const y=new Date(Date.now()-864e5);$('dkd').textContent=`'${String(y.getFullYear()).slice(2)} ${p2(y.getMonth()+1)} ${p2(y.getDate())}`;
  $('dki').src=PH[P];$('dkk').textContent='YESTERDAY · '+n+' / 3';$('dkt').textContent='Developing';$('dkseg').innerHTML=SEGC(tm);$('dkseg').className='dkseg off';
  const tg=YD[(n-1)%3]?YD[(n-1)%3].t:'#夕焼け',c=tgc(tg);$('dktg').textContent=tg;$('dktg').style.background=c[0];$('dktg').style.color=c[1];
  $('rvq').classList.remove('on');$('dkhint').textContent='SHAKE TO DEVELOP';
  const C=$('dkc'),S=$('dkst');[C,S,$('dkslit'),$('dkgl'),$('dktg'),$('rrs'),$('dkg')].forEach(e=>e.getAnimations().forEach(x=>x.cancel()));
  C.style.transform='';S.style.transform='translateY(-104%)';
  RV2={p:0,boost:0,done:false,t0:0,last:0,tick:0,rare:!!rare,shk:0,lx:null,dir:0};rvApply(0);
  R.classList.add('on');R.setAttribute('aria-hidden','false');hap('soft','ふわっ(暗室)');
  const T=(f,ms)=>setTimeout(()=>{if(RVL)f()},ms);
  if(rm){S.style.transform='none';RV2.t0=performance.now();requestAnimationFrame(rvLoop);return}
  $('dkg').animate([{opacity:0},{opacity:1}],{duration:900,fill:'forwards'});
  $('dkslit').animate([{transform:'scaleX(0)'},{transform:'scaleX(1)'}],{duration:420,delay:250,easing:'cubic-bezier(.3,1,.4,1)',fill:'forwards'});
  // チェキが スロットから 出てくる
  S.animate([{transform:'translateY(-104%)'},{transform:'translateY(-70%)',offset:.3},{transform:'translateY(-64%)',offset:.42},{transform:'translateY(-18%)',offset:.8},{transform:'translateY(0)'}],{duration:1400,delay:600,easing:'linear',fill:'forwards'}).onfinish=()=>{S.style.transform='none';hap('land','トン(手の ひらに)');RV2.t0=performance.now();RV2.last=RV2.t0;requestAnimationFrame(rvLoop);
    $('dkhint').animate([{opacity:0},{opacity:1}],{duration:500})};
  [640,860,1080,1300,1520,1740].forEach((t,k)=>T(()=>hap(k%2?'tick':'projector',k%2?null:'カタカタ(出てくる)',{norip:1}),t))}
function rvApply(p){const e=1-Math.pow(1-p,1.6),C=$('dkc');
  $('dkm').style.opacity=(1-e).toFixed(3);
  $('dkn').style.opacity=(Math.sin(Math.PI*Math.min(1,p*1.25))*.55).toFixed(3);
  $('dki').style.filter=`url(#chk) blur(${(7*(1-e)).toFixed(2)}px) saturate(${(e*1.02).toFixed(2)}) brightness(${(1.6-e*.6).toFixed(2)}) contrast(${(.7+e*.34).toFixed(2)})`;
  $('dkpb').style.width=(p*100)+'%';$('dkpc').textContent=Math.round(p*100)+'%';
  $('rvl').style.setProperty('--sl',(1-e).toFixed(3));
  if(RV2.rare)$('dkl').style.opacity=Math.max(0,(p-.45)/.55).toFixed(3);else $('dkl').style.opacity=0}
function rvLoop(t){if(!RVL||RV2.done)return;const dt=Math.min(50,t-(RV2.last||t));RV2.last=t;
  RV2.p=Math.min(1,RV2.p+dt/6400+RV2.boost);RV2.boost*=.85;rvApply(RV2.p);
  const tk=Math.floor(RV2.p*10);if(tk>RV2.tick){RV2.tick=tk;hap('tick','ごく軽く(濃くなる)',{norip:1})}
  if(RV2.p>=1){rvDone();return}requestAnimationFrame(rvLoop)}
function rvDone(){RV2.done=true;const R=$('rvl'),C=$('dkc'),rm=matchMedia('(prefers-reduced-motion:reduce)').matches;R.classList.add('dn');C.style.transform='';
  hap('heart','ドクン(ひらいた)');setTimeout(()=>hap('success','トトトン',{norip:1}),260);
  $('dkt').textContent=RV2.rare?'Rare film':'Opened';$('dkhint').textContent=RV2.rare?'LIGHT LEAK · 1 IN 7':'YESTERDAY';
  setTimeout(()=>{if(!RVL)return;$('dkseg').className='dkseg on';hap('click','カチッ(日付)')},350);
  if(!rm){$('dkgl').animate([{transform:'translateX(-120%) skewX(-18deg)',opacity:0},{opacity:1,offset:.2},{transform:'translateX(220%) skewX(-18deg)',opacity:0}],{duration:900,delay:120,easing:'cubic-bezier(.4,0,.2,1)'});
    C.animate([{transform:'scale(1) rotate(0deg)'},{transform:'scale(1.05) rotate(-2.5deg)',offset:.35},{transform:'scale(1) rotate(-1.5deg)'}],{duration:620,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'forwards'});
    $('dktg').animate([{transform:'scale(2.6) rotate(-30deg)',opacity:0},{transform:'scale(.9) rotate(9deg)',opacity:1,offset:.6},{transform:'scale(1) rotate(7deg)',opacity:1}],{duration:460,delay:520,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'both'});
    setTimeout(()=>RVL&&hap('pop','ぷにっ(タグを はる)'),620);
    if(RV2.rare){$('rrs').animate([{transform:'scale(3) rotate(-30deg)',opacity:0},{transform:'scale(.9) rotate(-9deg)',opacity:.95,offset:.6},{transform:'scale(1) rotate(-9deg)',opacity:.95}],{duration:520,delay:820,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'both'});setTimeout(()=>RVL&&hap('thud','ドン(RARE)'),900)}}
  else{$('dktg').style.opacity=1}
  setTimeout(()=>{if(RVL)$('rvq').classList.add('on')},1000)}
// ふる / こする で 早く 現像(チェキを ふる しぐさ)
(function(){const C=$('dkc');let on=false,px=0,py=0;
  C.addEventListener('pointerdown',e=>{if(!RVL||RV2.done||!RV2.t0)return;on=true;px=e.clientX;py=e.clientY;RV2.lx=e.clientX;try{C.setPointerCapture(e.pointerId)}catch(_){}hap('tick',null,{norip:1})});
  C.addEventListener('pointermove',e=>{if(!on||RV2.done)return;const dx=e.clientX-px,dy=e.clientY-py;C.style.transform=`translate(${(dx*.35).toFixed(1)}px,${(dy*.25).toFixed(1)}px) rotate(${(dx*.06).toFixed(2)}deg) rotateY(${(dx*.12).toFixed(1)}deg) rotateX(${(-dy*.1).toFixed(1)}deg)`;
    const d=Math.sign(e.clientX-RV2.lx);if(d&&d!==RV2.dir&&Math.abs(e.clientX-RV2.lx)>6){RV2.dir=d;RV2.boost+=.02;hap('sel','シャッ(ふる)',{norip:1,gap:70});$('dkhint').textContent='KEEP SHAKING'}RV2.lx=e.clientX});
  const up=()=>{if(!on)return;on=false;if(!RV2.done)C.animate([{transform:C.style.transform},{transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'});C.style.transform=''};
  C.addEventListener('pointerup',up);C.addEventListener('pointercancel',up)})();
function closeRvl(){RVL=false;const R=$('rvl');R.classList.remove('on');R.setAttribute('aria-hidden','true');hap('soft','ふわっ(ホームへ)',{norip:1})}
$('rvy').onclick=()=>{hap('click','カチッ(投稿する)');toast('投稿しました ・ みんなに 共有されます');closeRvl()};
$('rvn').onclick=()=>{hap('soft','ふわっ(投稿しない)');toast('投稿しません ・ 自分だけに のこります');closeRvl()};
(function(){const c=$('ctl');const b=document.createElement('button');b.textContent='現像(チェキ)';b.onclick=()=>openRvl(2);c.appendChild(b)})();


/* ===== グループを つくる(1から:なまえ → つくる → リンク) ===== */
const GNC=['#EE5E9C','#24FD4F','#61DC79','#5AC8FF','#9BE23B','#9B8CFF','#61D278'];
const GNP=[['#61D278','#EE5E9C'],['#9ED8FF','#9B8CFF'],['#C8F25A','#18FA45'],['#63DC7B','#FFD25A'],['#B28CFF','#F27CC0'],['#5AC8FF','#2A3A8A'],['#FF7AA8','#6EE085'],['#4CFF6F','#5A7CFF']];
const GNS=['いつメン','放課後クラブ','部活','2-B','帰り道','ひみつ基地','推し活','テスト前'];
var GP=[];var GN={on:false,st:'name',lk:null,name:'',pc:0};
const gnHash=s=>{let h=0;for(const c of s)h=(h*31+c.codePointAt(0))>>>0;return h};
function gnSeatXY(i){const ang=(-90+i*360/7)*Math.PI/180,r=108+[0,10,-6,8,-4,12,2][i];return[Math.cos(ang)*r,Math.sin(ang)*r]}
function gnBuild(){const S=$('gseats');S.style.animation='none';void S.offsetWidth;S.style.animation='';S.innerHTML=GNC.map((k,i)=>{const[x,y]=gnSeatXY(i);return `<div class="gnseat" data-i="${i}" style="--x:${x.toFixed(1)}px;--y:${y.toFixed(1)}px"><div class="gnsi" style="--k:${k};--i:${i}">+</div></div>`}).join('')}
function gnTheme(name){const p=GNP[name?gnHash(name)%GNP.length:0];const G=$('gnw');G.style.setProperty('--c1',p[0]);G.style.setProperty('--c2',p[1]);GN.pc=name?gnHash(name)%GNP.length:0}
function gnSync(){const v=$('gname').value.trim(),n=[...$('gname').value].length;$('gcnt').textContent=n+' / 14';$('gcta').disabled=!v;
  const ch=v?[...v][0]:'?';const s=$('gch');if(s.textContent!==ch){s.textContent=ch;if(!matchMedia('(prefers-reduced-motion:reduce)').matches)$('gav').animate([{scale:'1'},{scale:'1.16',offset:.4},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'})}
  gnTheme(v)}
function gnPulse(){const s=document.querySelector(`#gseats .gnseat[data-i="${[...$('gname').value].length%7}"]`);if(!s)return;s.classList.remove('gpl');void s.offsetWidth;s.classList.add('gpl')}
function gnConf(n){const st=$('gst'),cols=[...GNC,'#fff'];for(let i=0;i<n;i++){const e=document.createElement('i');e.className='gcf';const sz=6+Math.random()*7;e.style.cssText=`width:${sz}px;height:${sz}px;margin:${-sz/2}px;background:${cols[i%cols.length]}`;st.appendChild(e);const ang=Math.random()*Math.PI*2,d=110+Math.random()*80;
    e.animate([{translate:'0 0',opacity:1,scale:1},{translate:`${Math.cos(ang)*d}px ${Math.sin(ang)*d}px`,opacity:0,scale:.4}],{duration:900+Math.random()*500,easing:'cubic-bezier(.2,.8,.3,1)',delay:Math.random()*120}).onfinish=()=>e.remove()}}

function gnFr(){const R=$('gfr');R.innerHTML=FR.length?FR.map((f,i)=>`<button data-i="${i}" class="${GP.includes(i)?'on':''}"><span class="fc2" style="background:${avBg(f)}">${f.n[0]}<i><svg viewBox="0 0 10 10" fill="none" stroke="#fff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 5.2l2 2 4-4.4"/></svg></i></span>${f.n}</button>`).join(''):'<p style="font:500 12px var(--sans);color:var(--gs);padding:8px 4px">まだ ともだちが いません。あとで リンクで よべます</p>';
  R.querySelectorAll('button').forEach(bt=>bt.onclick=()=>{const i=+bt.dataset.i,k=GP.indexOf(i);
    if(k>=0){GP.splice(k,1);hap('tick','ごく軽く1回(はずす)')}else{if(GP.length>=7){hap('warn','やわらかく2回(8人まで)');toast('グループは 8人まで(自分を 入れて)');return}GP.push(i);hap('pop','ぷにっ(えらぶ)')}
    bt.classList.toggle('on',GP.includes(i));gnSeats(i)})}
function gnSeats(pop){document.querySelectorAll('#gseats .gnseat').forEach((s,k)=>{const f=FR[GP[k]],sy=s.querySelector('.gnsi');s.classList.toggle('frd',!!f);
    if(f){s.style.setProperty('--fb',f.g[1]);if(sy.textContent!==f.n[0]){sy.textContent=f.n[0];if(!matchMedia('(prefers-reduced-motion:reduce)').matches)s.classList.remove('gpl'),void s.offsetWidth,s.classList.add('gpl')}}else sy.textContent='+'});
  const n=GP.length;$('gfn').textContent=n?n+'人 えらびました':'あとでも OK';$('gctat').textContent=n?`つくって ${n}人に おくる`:'つくる'}
function openGnw(){if(GN.on)return;GN.on=true;$('gnw').classList.remove('done2');$('gwp').hidden=true;GN.code='';GN.st='name';const G=$('gnw');G.classList.toggle('dk',yH());GP=[];gnBuild();gnFr();$('gname').value='';$('gp1').hidden=false;$('gp2').hidden=true;$('gcta').classList.remove('hide','busy');$('gctat').textContent='つくる';$('gtt').textContent='あたらしい グループ';$('gerr').hidden=true;$('glk').hidden=false;$('gfs').hidden=true;
  gnSync();gnTheme('');G.classList.add('on');G.setAttribute('aria-hidden','false');hap('soft','ふわっ(はじまる)');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches){$('gav').animate([{scale:'.3',opacity:0},{scale:'1.12',opacity:1,offset:.65},{scale:'1'}],{duration:600,delay:120,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'});
    document.querySelectorAll('#gseats .gnseat').forEach((s,i)=>{const[x,y]=gnSeatXY(i);s.animate([{translate:'0px 0px',scale:.2,opacity:0},{translate:`${x}px ${y}px`,scale:1,opacity:1}],{duration:620,delay:360+i*70,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'}).onfinish=()=>{if(i===1||i===3||i===5)hap('tick',null,{norip:1})}});
    [$('gp1'),$('gcta')].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:520,delay:700+i*80,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
  $('gsug').innerHTML=GNS.map(t=>`<button data-t="${t}">${t}</button>`).join('');
  $('gsug').querySelectorAll('button').forEach(bt=>bt.onclick=()=>{$('gname').value=bt.dataset.t;hap('sel','コツッ(なまえ)');gnSync();gnPulse()});
  setTimeout(()=>{if(GN.on&&GN.st==='name')$('gname').focus({preventScroll:true})},760)}
function closeGnw(){if(!GN.on)return;$('gnw').scrollTop=0;GN.on=false;$('gname').blur();const G=$('gnw');G.classList.remove('on');G.setAttribute('aria-hidden','true')}
$('gname').addEventListener('input',e=>{if(e.isComposing)return;gnSync();gnPulse();hap('tick','ごく軽く1回(書く)',{norip:1})});
$('gname').addEventListener('compositionend',()=>{gnSync();gnPulse()});
$('gname').addEventListener('focus',()=>{const G=$('gnw');setTimeout(()=>{G.scrollTop=0;G.scrollLeft=0},50)});
$('gname').addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();if(!$('gcta').disabled)$('gcta').click()}});
$('gnx').onclick=()=>{hap('tick','ごく軽く1回(とじる)');if(GN.st==='creating')return;if(GN.st==='done')gnFinish();else closeGnw()};
function gnFinish(){const nm=GN.name;closeGnw();setTimeout(()=>{renderGroups(true);toast('「'+nm+'」を つくりました')},350)}
$('gcta').onclick=()=>{if(GN.st==='creating'||$('gcta').disabled)return;GN.st='creating';GN.name=$('gname').value.trim();const fail=GN.name==='エラー';
  const T=matchMedia('(prefers-reduced-motion:reduce)').matches;$('gcta').classList.add('busy');$('gctat').textContent='つくっています…';$('gname').blur();const FM=GP.map(i=>FR[i]);hap('click','カチッ(つくる)');
  $('gtt').textContent='つくっています…';
  $('gp1').animate([{opacity:1,transform:'none'},{opacity:0,transform:'translateY(-14px)'}],{duration:260,fill:'forwards',easing:'ease-in'});
  let n=0;const iv=setInterval(()=>{hap('tick',null,{norip:1});if(++n>=3)clearInterval(iv)},260);
  const seats=[...document.querySelectorAll('#gseats .gnseat')];
  if(!T)seats.forEach((s,i)=>{const[x,y]=gnSeatXY(i);s.animate([{translate:`${x}px ${y}px`,scale:1},{translate:`${x*.55}px ${y*.55}px`,scale:.85,offset:.45},{translate:'0px 0px',scale:.3,opacity:.0}],{duration:820,delay:i*30,easing:'cubic-bezier(.5,0,.7,.4)',fill:'forwards'})});
  if(!T)$('gav').animate([{scale:'1'},{scale:'.9',offset:.7},{scale:'1.24',offset:.9},{scale:'1'}],{duration:980,easing:'ease-in-out'});
  setTimeout(()=>{if(!T)$('gfl').animate([{opacity:0},{opacity:.85,offset:.3},{opacity:0}],{duration:520})},820);
  setTimeout(()=>{ // ここで 保存と リンクの発行が 終わる(実機では 本物の処理)
    seats.forEach(s=>s.getAnimations().forEach(an=>an.cancel()));
    $('gp1').hidden=true;$('gp2').hidden=false;$('gnw').scrollTop=0;
    if(fail){GN.st='error';$('gwp').hidden=true;$('gk2').textContent='ERROR';$('gh2').textContent='うまく いきませんでした';$('gsb').textContent='もういちど ためしてください';$('glk').hidden=true;$('gerr').hidden=false;$('gerrd').textContent='CKError 9 (notAuthenticated) ・ iCloud に サインインしているか 確かめてください';$('glsend').textContent='もういちど';$('glcopy').hidden=true;$('gcta').classList.add('hide');hap('warn','やわらかく2回(しっぱい)');$('gtt').textContent='エラー';
      if(!T)seats.forEach((s,i)=>{const[x,y]=gnSeatXY(i);s.animate([{translate:'0px 0px',scale:.3,opacity:0},{translate:`${x}px ${y}px`,scale:1,opacity:1}],{duration:520,delay:i*40,easing:'cubic-bezier(.3,1.35,.5,1)'})});return}
    GN.st='done';const tok=Array.from({length:22},()=>'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz0123456789'[Math.random()*58|0]).join('');
    GN.lk=inviteText(GN.name,'https://www.icloud.com/share/'+tok);GN.code=gnCode();gnShowCode();$('gnw').classList.add('done2');$('gk2').textContent='CREATED';$('glkt').textContent='icloud.com/share/'+tok.slice(0,5)+'…';$('gh2').textContent=GN.name;$('gsb').textContent='';$('glk').hidden=false;$('gerr').hidden=true;$('glsend').textContent='リンクを おくる';$('glcopy').hidden=false;$('gcta').classList.add('hide');$('gtt').textContent=GN.name;
    if(FM.length){seats.forEach((s,k)=>{if(s.classList.contains('frd'))s.classList.add('wt')});
      $('gk2').textContent='SENT';$('gh2').textContent='おくりました';$('gsb').textContent='「入る」で なかまに なります';
      $('gfs').hidden=false;$('gfs').innerHTML=FM.map(f=>`<span><i style="background:${f.g[1]}">${f.n[0]}</i>${f.n}<em>承認まち</em></span>`).join('');$('glk').hidden=true;$('glsend').textContent='リンクでも よぶ';
      GRP.unshift({n:GN.name,m:FM,pend:1,sub:`招待中 ${FM.length}人`,pill:'招待中'})}
    else{$('gfs').hidden=true;seats[0].classList.add('me');seats[0].querySelector('.gnsi').textContent='you';
    GRP.unshift({n:GN.name,m:[],pend:1,sub:'リンクで 招待中',pill:'招待中'})}
    hap('success','トトトン(できた)',{norip:1});gnConf(22);
    if(!T){seats.forEach((s,i)=>{const[x,y]=gnSeatXY(i);s.animate([{translate:'0px 0px',scale:.3,opacity:0},{translate:`${x}px ${y}px`,scale:1.08,opacity:1,offset:.7},{translate:`${x}px ${y}px`,scale:1}],{duration:720,delay:60+i*50,easing:'cubic-bezier(.2,.9,.3,1)'})});
      $('gp2').animate([{opacity:0,transform:'translateY(26px)'},{opacity:1,transform:'none'}],{duration:560,delay:260,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})}
  },1560)};

const GNW=['くじら','さくら','いちご','こあら','めろん','らっこ','ぱんだ','きつね','うさぎ','ひかり','みかん','すずめ','あられ','もなか','ことり'];
function gnCode(){const a=GNW[Math.random()*GNW.length|0];let b;do{b=GNW[Math.random()*GNW.length|0]}while(b===a);return a+b}
function gnShowCode(){const W=$('gwp'),T=$('gwt'),C=['#B1EEBD','#FFC9DF','#E3D4FF','#CDE4FF','#ADFEBD','#FFF0B8'];W.hidden=false;W.classList.remove('cp');$('gwh').textContent='TAP TO COPY';
  T.innerHTML='<i class="ghs" style="--c:#fff;--r:0deg;--i:0">#</i>'+[...GN.code].map((c,i)=>`<i style="--c:${C[i%6]};--r:${[-4,3,-2,4,-3,2][i%6]}deg;--i:${i}">${c}</i>`).join('');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches)T.querySelectorAll('i').forEach((t,i)=>{t.animate([{opacity:0,filter:'blur(10px)',transform:'translateY(8px)'},{opacity:1,filter:'blur(0)',transform:'none'}],{duration:700,delay:600+i*110,easing:'cubic-bezier(.2,.7,.3,1)',fill:'backwards'});setTimeout(()=>hap('tick',null,{norip:1}),520+i*90)})}
$('gwp').onclick=()=>{if(!GN.code)return;const kc=$('gkcopy');kc.classList.add('ok');kc.querySelector('b').textContent='Copied';setTimeout(()=>{kc.classList.remove('ok');kc.querySelector('b').textContent='Copy'},1600);try{navigator.clipboard.writeText('#'+GN.code).catch(()=>{})}catch(e){}hap('pop','ぷにっ(合言葉を コピー)');$('gwp').classList.add('cp');$('gwh').textContent='COPIED';toast('KEY を コピーしました');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches)$('gwt').querySelectorAll('i').forEach((t,i)=>t.animate([{color:'#fff'},{color:'#9ED6A5',textShadow:'0 0 18px rgba(36,160,60,.9)'},{color:'#fff'}],{duration:700,delay:i*50}));
  setTimeout(()=>{$('gwp').classList.remove('cp');$('gwh').textContent='TAP TO COPY'},1600)};
$('glk').onclick=()=>$('glcopy').click();
/* v43 できた画面:KEY + Add / Link / Copy */
$('gklink').onclick=()=>{if(!GN.lk)return;hap('pop','ぷにっ(共有シート)');toast('共有シートを ひらく(招待文 + リンク)')};
$('gkcopy').onclick=()=>$('gwp').click();
$('gkadd').onclick=()=>{hap('pop','ぷにっ(ともだちを 追加)');if(!FR.length){toast('まだ ともだちが いません ・ Link で よべます');return}toast('ともだちを えらぶ(招待カードが とどく)')};

$('glcopy').onclick=()=>{hap('click','カチッ(コピー)');let ok=false;try{navigator.clipboard.writeText(GN.lk).then(()=>toast('招待リンクを コピーしました'),()=>toast('コピー できませんでした'));ok=true}catch(e){}if(!ok)toast('コピー できませんでした');const b=$('glcopy');b.textContent='コピーした';setTimeout(()=>b.textContent='コピー',1400)};
$('glsend').onclick=()=>{if(GN.st==='error'){GN.st='name';$('gp2').hidden=true;$('gp1').hidden=false;$('gp1').getAnimations().forEach(an=>an.cancel());$('gcta').classList.remove('hide','busy');$('gctat').textContent='つくる';$('gtt').textContent='あたらしい グループ';$('gname').value='';gnSync();hap('pop','ぷにっ(もういちど)');setTimeout(()=>$('gname').focus(),200);return}hap('pop','ぷにっ(共有シート)');toast('共有シートを ひらく(メッセージ・LINE など)')};
$('gldone').onclick=()=>{hap('soft','ふわっ(あとで)');if(GN.st==='done')gnFinish();else closeGnw()};
$('gmk').onclick=()=>{hap('tick','ごく軽く1回');openGnw()};


/* ===== はじめての 合図(説明しない。1回に 1つ・さわったら 消える・二度と 出ない) ===== */
var CMS=new Set(),CMC=null,CMQ={s:null,t:0},CMON=true;
const CMD=[
 {k:'first', s:'home',t:'hmoon',x:'ここから、1枚目',p:'up',c:()=>!DAY2&&shots===0,spot:1},
 {k:'unlock',s:'home',t:'hmoon',x:'撮ると、きのうが 1枚 ひらく',p:'up',c:()=>DAY2&&shots===0,spot:1},
 {k:'tag',   s:'tag', t:'inrow',x:'ひとこと タグ。なくても OK',p:'up'},
 {k:'shoot', s:'cam', t:'sh',   x:'ながおしで 撮る',p:'up',halo:1,press:1},
 {k:'orb',   s:'home',t:'omo',  x:'まんなかは、いま いちばんの こと',p:'down',halo:1,c:()=>true},
 {k:'keep',  s:'home',t:'ayk', x:'長押しで、1年 のこす',p:'up',c:()=>DAY2&&shots>0},
 {k:'grp',   s:'home',t:()=>DAY2?'acnew':'gmk',  x:'ともだちと、見せあう',p:'up',halo:1,c:()=>shots>0},
];
function cmRect(el){const P=$('phone').getBoundingClientRect(),r=el.getBoundingClientRect();return{x:(r.left-P.left)/SC,y:(r.top-P.top)/SC,w:r.width/SC,h:r.height/SC}}
function cmVis(el){if(el&&el.id==='hmoon')return true;if(!el||!el.offsetParent&&el.id!=='hmoon')return false;const r=cmRect(el);return r.w>0&&r.y>90&&r.y+Math.min(r.h,60)<800}
function cmPlace(){if(!CMC)return;const d=CMC.d,el=$(typeof d.t==='function'?d.t():d.t),r=cmRect(el),B=CMC.b;
  if(d.t==='hmoon'){r.x=0;r.w=390;r.y=748}
  const bw=B.offsetWidth,cx=Math.max(16+bw/2,Math.min(390-16-bw/2,r.x+r.w/2));
  B.style.left=(cx-bw/2)+'px';B.style.top=(d.p==='up'?r.y-B.offsetHeight-12:r.y+r.h+12)+'px';B.style.setProperty('--tx',(r.x+r.w/2-(cx-bw/2))+'px');
  if(CMC.h){const H=CMC.h,br=getComputedStyle(el).borderRadius;H.style.cssText=`left:${r.x-6}px;top:${r.y-6}px;width:${r.w+12}px;height:${r.h+12}px;border-radius:${br==='0px'?'18px':'calc('+br+' + 6px)'}`}
  if(!cmVis(el)&&d.t!=='hmoon')cmHide()}
function cmHide(){if(!CMC)return;const c=CMC;CMC=null;$('home').classList.remove('cm-spot');$('cam').classList.remove('cm-cam');c.el.removeEventListener('pointerdown',c.off,true);
  c.b.animate([{opacity:1,scale:'1'},{opacity:0,scale:'.85'}],{duration:180,easing:'ease-in'}).onfinish=()=>c.b.remove();if(c.h)c.h.animate([{opacity:1},{opacity:0}],{duration:180}).onfinish=()=>c.h.remove()}
function cmShow(d){const el=$(typeof d.t==='function'?d.t():d.t);CMS.add(d.k);const P=$('phone');
  const b=document.createElement('div');b.className='cmb '+(d.p==='up'?'up':'dn');b.innerHTML=`<i></i><span>${d.x}</span>`;P.appendChild(b);
  let h=null;if(d.halo){h=document.createElement('div');h.className='cmh'+(d.press?' press':'');P.appendChild(h)}
  CMC={d,el,b,h,off:()=>cmHide()};el.addEventListener('pointerdown',CMC.off,true);
  if(d.spot)$('home').classList.add('cm-spot');if(d.k==='shoot')$('cam').classList.add('cm-cam');
  cmPlace();hap('soft','ふわっ(はじめての 合図)',{norip:1});
  b.animate([{opacity:0,transform:`translateY(${d.p==='up'?10:-10}px) scale(.8)`},{opacity:1,transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.5,.5,1)'});
  if(h)h.animate([{opacity:0,scale:'1.25'},{opacity:1,scale:'1'}],{duration:520,easing:'cubic-bezier(.3,1.3,.5,1)'})}
function cmTick(){if(!CMON)return;
  if(CMC&&(CMC.d.s!==cur||YOPEN||GN.on||RM.on||OB.on||(AV!==null)||DXopen||document.querySelector('.sheet.on')||RVL)){cmHide();return}
  if(CMC){cmPlace();return}
  if(CMQ.s!==cur){CMQ={s:cur,t:performance.now()};return}
  if(performance.now()-CMQ.t<(cur==='cam'?1300:800)||busy||YOPEN||GN.on||RM.on||OB.on||AV!==null||DXopen||RVL||document.querySelector('.sheet.on')||$('fscr').classList.contains('on'))return;
  const d=CMD.find(d=>d.s===cur&&!CMS.has(d.k)&&(!d.c||d.c())&&cmVis($(typeof d.t==='function'?d.t():d.t)));if(d)cmShow(d)}
setInterval(cmTick,200);$('hs').addEventListener('scroll',()=>{if(!CMC)return;if(CMC.d.spot&&$('hs').scrollTop>60)cmHide();else cmPlace()},{passive:true});

/* ===== グループの 部屋(チャット):写真のまわりで 話す。タグが スタンプ。7日で 消える ===== */
const STK=[['#それな','#EE5E9C','#fff'],['#エモい','#9B8CFF','#fff'],['#草','#C8F25A','#111'],['#天才','#FFD60A','#111'],['#かわいい','#FF8FB3','#111'],['#うける','#9ED8FF','#111'],['#わかる','#24FD4F','#111'],['#えぐい','#61DC79','#fff'],['#優勝','#61D278','#111'],['#おつかれ','#DCD6FF','#111'],['#ねむい','#B8C7FF','#111'],['#すき','#FF5A7A','#fff']];
const RMY=[['d',1,'18:42'],['b',0,'16:05'],['a',-1,'12:30'],['e',3,'08:51']];
const RMR=['それな','わかる〜','きのうの 夕焼け えぐかった','あした なに撮る?','まって、それ どこ?','天才かも','はやく 9時 ならんかな','#1','#0','#6'];
var RM={on:false,g:null,msgs:[],rep:null,poked:new Set(),blk:new Set(),tm:[],id:0,menu:null};
const rmRM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
const stkH=(i,r,cls)=>`<span class="${cls||'stk'}" style="--c:${STK[i][1]};--t:${STK[i][2]};--r:${r==null?(i%2?5:-5):r}deg">${STK[i][0]}</span>`;
const rmEsc=s=>s.replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function rmCount(){const g=RM.g;const d=g.m.filter(f=>f.k>0).length+(shots>0?1:0);return[d,g.m.length+1]}
function rmSeed(g){if(g.chat)return g.chat;const M=g.m,has=i=>i<M.length;const c=[{w:'sys',x:'9:00 ・ きのうが ひらいた'}];
  if(has(0))c.push({w:0,t:'text',x:'きのうの 夕焼け、だれ?'});
  if(has(1)){c.push({w:1,t:'ph',p:'d',x:'わたし! 帰り道'});}
  if(has(2))c.push({w:2,t:'stk',s:1});
  if(has(0)){const lz=M.findIndex(f=>!f.k);c.push({w:0,t:'text',x:lz>=0?`あと ${M[lz].n}だけ。はよ 撮って`:'きょうも そろいそう'})}
  c.forEach(m=>{m.id=++RM.id;m.at=[]});if(c[1])c[1].at=[2];g.chat=c;return c}
function rmHead(){const g=RM.g,[d,n]=rmCount(),all=d===n&&n>1;$('rmn').textContent=g.n;
  $('rms').textContent=g.pend||n<2?'承認まち':all?'そろった':`あと ${n-d}人で そろう`;
  $('rmav').innerHTML=`<button class="rma me${shots>0?' ok':''}" data-i="me" aria-label="あなた"><i></i></button>`+g.m.map((f,i)=>`<button class="rma${f.k>0?' ok':''}${RM.blk.has(i)?' blk':''}" data-i="${i}" aria-label="${f.n}"><i style="background:${avBg(f)}">${f.n[0]}</i></button>`).join('');
  $('rmav').querySelectorAll('.rma').forEach(b=>b.onclick=()=>{const i=b.dataset.i;
    if(i==='me'){if(shots>0){hap('sel','コツッ');return}hap('pop','ぷにっ(撮りに いく)');toast('下の「今日を撮る」から 撮れます');return}
    const f=g.m[+i];if(f.k>0){hap('sel','コツッ(もう 撮った)');b.animate([{scale:'1'},{scale:'1.15'},{scale:'1'}],{duration:300});return}
    if(RM.poked.has(+i)){hap('warn','やわらかく2回(きょうは もう つついた)');toast('つつくのは 1日 1回')
;return}
    RM.poked.add(+i);b.classList.add('pk');hap('heart','ドクン(つつく)');toast(f.n+' を つついた')});
  const wd=(new Date().getDay()+6)%7,pat=[1,0,1,1,1,0,1];
  $('rmwk').innerHTML=[0,1,2,3,4,5,6].map(i=>`<i class="${i<wd&&pat[i]?'f':''}${i===wd?' t'+(all?' f':''):''}"></i>`).join('');
  g.pill=all?'そろった':`あと ${n-d}人`;g.all=all}
function rmMsgH(m,i,A){const g=RM.g;if(m.w==='sys')return `<div class="msys${m.all?' all':''}" data-id="${m.id}">${m.x}</div>`;
  const me=m.w==='me',f=me?null:g.m[m.w],pv=A[i-1],nx=A[i+1],same=o=>o&&o.w===m.w&&o.w!=='sys';
  const first=!same(pv),last=!same(nx);
  if(!me&&RM.blk.has(m.w))return '';
  let body;if(m.hid)body=`<div class="mb">通報した メッセージ</div>`;
  else if(m.t==='stk')body=`<span class="stk" style="--c:${STK[m.s][1]};--t:${STK[m.s][2]};--r:${m.id%2?-6:5}deg;position:relative">${STK[m.s][0]}${rmAt(m)}</span>`;
  else{const big=/^(\p{Extended_Pictographic}|️|‍){1,6}$/u.test(m.x);body=(m.t==='ph'?`<div class="pr"><div class="chk"><img src="${PH[m.p]}" alt=""></div></div>`:'')+`<div class="mb${big?' big':''}">${rmEsc(m.x)}${rmAt(m)}</div>`}
  return `<div class="m ${me?'me':'o'}${first?' f1':' nx'}${last?'':' nl'}${m.hid?' hid':''}${m.at&&m.at.length?' has':''}" data-id="${m.id}">${me?'':`<i class="ma" style="background:${avBg(f)}">${f.n[0]}</i>`}<div class="mw" style="--mc:${me?'#888':f.g[1]}">${!me&&first?`<span class="nm">${f.n}</span>`:''}${body}</div></div>`}
function rmAt(m){return (m.at||[]).slice(-1).map(s=>`<span class="at" style="--c:${STK[s][1]};--t:${STK[s][2]};--r:${m.id%2?7:-6}deg">${STK[s][0]}</span>`).join('')}
function rmYH(){const lk=shots===0;return `<div class="rmday">${fmtYd()}</div><div class="rmy${lk?' lk':''}" id="rmy"><div class="ks">${RMY.map(([p,w,t],i)=>`<div class="k" data-i="${i}" style="--i:${i};--r:${[-5,3,-2,6][i]}deg"><div class="chk"><img src="${PH[p]}" alt=""></div><u>${t}</u></div>`).join('')}</div><div class="rt"><b>yesterday</b><small>${RMY.length} こま</small></div><span class="lkp"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>撮ると、ひらく</span></div>`}
const fmtYd=()=>{const d=new Date(Date.now()-864e5);return p2(d.getMonth()+1)+'.'+p2(d.getDate())};
function rmRender(pop){const L=$('rml'),g=RM.g;
  if(g.pend||g.m.length<1){L.innerHTML=`<div class="rmemp"><div class="sd"><i class="me"></i><i></i><i></i><i></i></div><b>なかまが 入ると、<br>ここで 話せます</b><button id="rmeinv">リンクで よぶ</button></div>`;$('rmeinv').onclick=()=>{hap('pop','ぷにっ(共有シート)');toast('共有シートを ひらく(メッセージ・LINE など)')};$('rmc').style.display='none';return}
  $('rmc').style.display='';
  const st=L.scrollTop,bot=L.scrollHeight-L.clientHeight-st<60;
  L.innerHTML=rmYH()+RM.msgs.map(rmMsgH).join('')+(RM.typ!=null?`<div class="m o f1" id="rmtyp"><i class="ma" style="background:${avBg(g.m[RM.typ])}">${g.m[RM.typ].n[0]}</i><div class="mw" style="--mc:${g.m[RM.typ].g[1]}"><div class="mb mty"><i></i><i></i><i></i></div></div></div>`:'');
  rmBind();if(pop||bot)L.scrollTop=L.scrollHeight;else L.scrollTop=st;
  if(pop&&!rmRM()){const e=pop===true?L.querySelector('.m:last-of-type,.msys:last-of-type'):L.querySelector(`[data-id="${pop}"]`);const el=e||L.lastElementChild;
    if(el){const me=el.classList.contains('me'),t=el.querySelector('.stk');
      if(t)t.animate([{scale:'2.2',rotate:'-30deg',opacity:0},{scale:'.9',opacity:1,offset:.6},{scale:'1'}],{duration:460,easing:'cubic-bezier(.3,1.5,.4,1)'});
      else el.animate([{opacity:0,transform:`translate(${me?30:-20}px,26px) scale(.7)`},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.4,1)'})}}}
function rmBind(){const L=$('rml');
  const y=$('rmy');if(y){y.querySelectorAll('.k').forEach(k=>k.onclick=e=>{e.stopPropagation();if(shots===0){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます');return}rmView(+k.dataset.i)});y.onclick=()=>{if(shots===0){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます')}}}
  L.querySelectorAll('.m[data-id]').forEach(el=>{const t=el.querySelector('.mb,.stk');if(!t||el.classList.contains('hid'))return;const id=+el.dataset.id;let tm=0,sx=0,sy=0,lp=false;
    t.addEventListener('pointerdown',e=>{sx=e.clientX;sy=e.clientY;lp=false;tm=setTimeout(()=>{lp=true;rmMenu(id,el)},420)});
    const cl=()=>clearTimeout(tm);t.addEventListener('pointerup',cl);t.addEventListener('pointerleave',cl);t.addEventListener('pointercancel',cl);
    t.addEventListener('pointermove',e=>{if(Math.hypot(e.clientX-sx,e.clientY-sy)>10)cl()});
    t.addEventListener('contextmenu',e=>e.preventDefault());
    t.addEventListener('dblclick',()=>{if(lp)return;rmStick(id,0)})})}
function rmStick(id,s){const m=RM.msgs.find(m=>m.id===id);if(!m||m.w==='sys')return;m.at=m.at||[];const had=m.at.slice(-1)[0]===s;m.at=had?[]:[s];hap(had?'tick':'pop',had?'ごく軽く(はがす)':'ぷにっ(タグを はる)');rmRender();
  if(!had&&!rmRM()){const a=$('rml').querySelector(`[data-id="${id}"] .at`);a&&a.animate([{scale:'2.6',opacity:0},{scale:'.85',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}}
function rmPush(m,quiet){m.id=++RM.id;m.at=[];RM.msgs.push(m);rmRender(m.id);const g=RM.g;const who=m.w==='me'?'':m.w==='sys'?'':g.m[m.w].n+': ';g.last=who+(m.t==='stk'?STK[m.s][0]:m.x);return m}
function rmLater(f,ms){const t=setTimeout(()=>{if(RM.on)f()},ms);RM.tm.push(t)}
function rmReply(){const g=RM.g,c=g.m.map((f,i)=>i).filter(i=>!RM.blk.has(i));if(!c.length)return;const w=c[Math.random()*c.length|0];
    rmLater(()=>{RM.typ=null;const r=RMR[Math.random()*RMR.length|0];if(r[0]==='#'&&r.length===2)rmPush({w,t:'stk',s:+r[1]});else rmPush({w,t:'text',x:r});hap('soft','ふわっ(とどいた)',{norip:1})},700+900+Math.random()*900)}
function rmSendText(){const v=$('rmin').value.trim();if(!v)return;$('rmin').value='';$('rmgo').disabled=true;
  const m={w:'me',t:RM.rep!=null?'ph':'text',x:v};if(RM.rep!=null){m.p=RMY[RM.rep][0];rmRep(null)}rmPush(m);hap('click','カチッ(おくる)');rmReply()}
function rmSendStk(s){rmPush({w:'me',t:'stk',s});hap('pop','ぷにっ(タグ スタンプ)');rmTray(false);rmReply()}
function rmTray(on){const T=$('rmtray');on=on==null?!T.classList.contains('on'):on;T.classList.toggle('on',on);$('rmst').classList.toggle('on',on)}
function rmRep(i){RM.rep=i;const R=$('rmrep');if(i==null){R.hidden=true;return}R.hidden=false;$('rmrpi').style.backgroundImage=`url(${PH[RMY[i][0]]})`;const w=RMY[i][1];$('rmrpt').textContent=(w<0?'じぶん':RM.g.m[w]?RM.g.m[w].n:'なかま')+'の 写真へ';$('rmin').focus({preventScroll:true})}
function rmView(i){RM.vi=i;$('rmvi').src=PH[RMY[i][0]];$('rmvd').textContent=RMY[i][2];$('rmv').classList.add('on');hap('pop','ぷにっ(写真を ひらく)')}
function rmViewX(){$('rmv').classList.remove('on')}
function rmMenu(id,el){const m=RM.msgs.find(m=>m.id===id);if(!m)return;RM.menu={id,el};const me=m.w==='me',X=$('rmx'),Q=$('rmxq'),Lm=$('rmxl');hap('thud','ドン(もちあげる)');
  el.classList.add('lift');$('rmtray').classList.remove('on');$('rmst').classList.remove('on');
  Q.innerHTML=[0,1,2,3,6].map(i=>`<span class="stk" data-s="${i}" style="--c:${STK[i][1]};--t:${STK[i][2]};--r:${i%2?4:-4}deg">${STK[i][0]}</span>`).join('');
  Q.querySelectorAll('.stk').forEach(s=>s.onclick=()=>{rmMenuX();rmStick(id,+s.dataset.s)});
  const list=h=>{Lm.innerHTML=h;Lm.querySelectorAll('button').forEach(b=>b.onclick=()=>act(b.dataset.a))};
  const act=a=>{const f=me?null:RM.g.m[m.w];
    if(a==='copy'){try{navigator.clipboard.writeText(m.x||STK[m.s][0]).catch(()=>{})}catch(e){}hap('click','カチッ(コピー)');toast('コピーしました');rmMenuX()}
    else if(a==='del'){RM.msgs=RM.msgs.filter(x=>x.id!==id);RM.g.chat=RM.msgs;hap('soft','ふわっ(とりけす)');rmMenuX();rmRender()}
    else if(a==='rep'){hap('sel','コツッ');list(`<div class="hd">どんな 内容?</div>`+['いやがらせ','性的な 内容','個人情報','そのほか'].map(r=>`<button data-a="r">${r}</button>`).join(''));rmPos()}
    else if(a==='r'){m.hid=true;hap('success','やさしく2回(通報した)',{norip:1});rmMenuX();rmRender();toast('通報しました。24時間以内に 確認します')}
    else if(a==='blk'){list(`<div class="hd">${f.n} を ブロックする?</div><button data-a="blk2" class="rd">ブロックする</button><button data-a="x">やめる</button>`);hap('warn','やわらかく2回(たしかめる)');rmPos()}
    else if(a==='blk2'){RM.blk.add(m.w);hap('thud','ドン(ブロック)');rmMenuX();rmHead();rmRender();toast(f.n+' を ブロックしました')}
    else rmMenuX()};
  list(me?`<button data-a="copy">コピー</button><button data-a="del" class="rd">とりけす</button>`:`<button data-a="copy">コピー</button><button data-a="rep" class="rd">通報する</button><button data-a="blk" class="rd">ブロック</button>`);
  X.classList.add('on');rmPos()}
function rmPos(){if(!RM.menu)return;const el=RM.menu.el,t=el.querySelector('.mb,.stk'),r=cmRect(t),me=el.classList.contains('me'),Q=$('rmxq'),Lm=$('rmxl');
  const qh=50,lh=Lm.offsetHeight,qa=r.y-qh-10>168;let qy=qa?r.y-qh-10:r.y+r.h+10,ly=(qa?r.y+r.h:qy+qh)+10;
  if(ly+lh>806){ly=(qa?qy:r.y)-lh-10;if(ly<110)ly=806-lh}
  Q.style.top=qy+'px';Lm.style.top=ly+'px';[Q,Lm].forEach(e=>{e.style.left=me?'auto':'52px';e.style.right=me?'14px':'auto';e.style.transformOrigin=me?'100% 50%':'0 50%'})}
function rmMenuX(){if(!RM.menu)return;RM.menu.el.classList.remove('lift');RM.menu=null;$('rmx').classList.remove('on')}
function rmConf(n){const R=$('room'),cols=['#239E3C','#EE5E9C','#C8F25A','#9ED8FF','#FFD60A','#9B8CFF'];for(let i=0;i<n;i++){const e=document.createElement('i');const sz=6+Math.random()*8;e.style.cssText=`position:absolute;left:${40+Math.random()*310}px;top:120px;width:${sz}px;height:${sz*(Math.random()<.5?1:.45)}px;border-radius:${Math.random()<.5?'50%':'2px'};background:${cols[i%6]};z-index:7;pointer-events:none`;R.appendChild(e);
    e.animate([{transform:'translateY(-30px) rotate(0)',opacity:1},{transform:`translate(${(Math.random()-.5)*120}px,${420+Math.random()*260}px) rotate(${(Math.random()-.5)*900}deg)`,opacity:0}],{duration:1500+Math.random()*900,easing:'cubic-bezier(.2,.6,.4,1)',delay:Math.random()*250}).onfinish=()=>e.remove()}}
function rmAll(){if(!RM.on||RM.g.pend)return;const g=RM.g;if(shots===0){shots=1;renderCam();renderHome()}g.m.forEach(f=>{if(!f.k)f.k=1});rmHead();
  $('rmav').querySelectorAll('.rma').forEach((b,i)=>b.animate([{scale:'1'},{scale:'1.25'},{scale:'1'}],{duration:420,delay:i*70,easing:'cubic-bezier(.3,1.6,.4,1)'}));
  hap('success','トトトン(ぜんいん そろった)');if(!rmRM())rmConf(34);const m=rmPush({w:'sys',x:'ぜんいん そろった',all:1});renderGroups();renderYGroups()}
function openRoom(g){if(RM.on||!g)return;RM.on=true;RM.g=g;RM.msgs=g.pend?[]:rmSeed(g);RM.typ=null;RM.rep=null;g.un=0;const R=$('room');R.classList.toggle('dk',yH());
  $('rmtray').innerHTML=STK.map((s,i)=>`<span class="stk" data-s="${i}" style="--c:${s[1]};--t:${s[2]};--r:${[-5,4,-3,6,-6,3][i%6]}deg">${s[0]}</span>`).join('');
  $('rmtray').querySelectorAll('.stk').forEach(s=>s.onclick=()=>rmSendStk(+s.dataset.s));rmTray(false);rmRep(null);$('rmin').value='';$('rmgo').disabled=true;
  rmHead();rmRender(true);R.classList.add('on');R.setAttribute('aria-hidden','false');hap('pop','ぷにっ(部屋に 入る)');
  if(!rmRM()){$('rmav').querySelectorAll('.rma').forEach((b,i)=>b.animate([{scale:'0',opacity:0},{scale:'1',opacity:1}],{duration:420,delay:160+i*55,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'}));
    [...$('rml').children].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:420,delay:200+i*45,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
  renderGroups();renderYGroups()}
function closeRoom(){if(!RM.on)return;RM.on=false;RM.tm.forEach(clearTimeout);RM.tm=[];RM.typ=null;rmMenuX();rmViewX();$('rmin').blur();const R=$('room');R.classList.remove('on');R.setAttribute('aria-hidden','true');if(RM.g&&!RM.g.pend)RM.g.chat=RM.msgs;renderGroups();renderYGroups()}
$('rmback').onclick=()=>{hap('tick','ごく軽く1回(もどる)');closeRoom()};
$('rmmore').onclick=()=>{hap('sel','コツッ');toast('メンバー ・ 通知 ・ リンクで よぶ ・ ぬける')};
$('rmst').onclick=()=>{hap('sel','コツッ(タグ スタンプ)');rmTray()};
$('rmin').addEventListener('input',()=>{$('rmgo').disabled=!$('rmin').value.trim()});
$('rmin').addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();rmSendText()}});
$('rmin').addEventListener('focus',()=>{rmTray(false);setTimeout(()=>{$('room').scrollTop=0},50)});
$('rmgo').onclick=rmSendText;$('rmrpx').onclick=()=>{hap('tick');rmRep(null)};
$('rmxs').onclick=rmMenuX;$('rmvs').onclick=rmViewX;$('rmvc').onclick=rmViewX;
$('rmvr').onclick=()=>{hap('sel','コツッ(返信)');rmViewX();rmRep(RM.vi)};
$('rml').addEventListener('scroll',()=>{if($('rmtray').classList.contains('on'))rmTray(false)},{passive:true});

/* ===== はじめての 設定:サインイン → なまえ → タグ/アイコン → ともだち → 通知 → ながおしで はじめる ===== */
const OBP=[['#61D278','#EE5E9C'],['#9ED8FF','#9B8CFF'],['#C8F25A','#18FA45'],['#63DC7B','#FFD25A'],['#B28CFF','#F27CC0'],['#5AC8FF','#3A4ACF']];
const OBT=['#ねむい','#推し活','#カフェ','#部活','#音楽','#さんぽ','#甘党','#夜型','#ゲーム','#映画','#ダンス'];
const OBTC=[['#EE5E9C','#fff',-8],['#C8F25A','#111',7],['#9ED8FF','#111',5]];
const OBMK={in:1,mail:1,sent:1,name:.8,tag:.5,fr:.26,nt:.1,go:0};
const OBPG={name:1,tag:2,fr:3,nt:4,go:4};
const OBDOT=[[-148,50],[148,34],[-150,138],[150,128],[-140,222],[142,218]];
var OB={on:false,st:'in',name:'',col:0,tags:[],req:[],mail:'',con:false,img:false,busy:false};
const obRM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
function obSync(){const O=$('ob'),p=OBP[OB.col];O.style.setProperty('--c1',p[0]);O.style.setProperty('--c2',p[1]);
  const ch=OB.name?[...OB.name][0]:'';const s=$('obini');if(s.textContent!==ch){s.textContent=ch;if(ch&&!obRM())$('obph').animate([{scale:'1'},{scale:'1.06',offset:.4},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'})}
  $('obnm').textContent=OB.name;$('obmk').style.opacity=OB.name||OB.st!=='name'?OBMK[OB.st]:.94;
  $('obph').classList.toggle('im',OB.img);$('obph').style.backgroundImage=OB.img?`url(${PH.c})`:'';
  $('obtg').innerHTML=OB.tags.map((t,i)=>`<span style="--c:${OBTC[i][0]};--t:${OBTC[i][1]};--r:${OBTC[i][2]}deg">${rmEsc(t)}</span>`).join('');
  $('obfr').innerHTML=OB.req.map((fi,i)=>{const f=FPOOL[fi],d=OBDOT[i%6];return `<i style="left:${d[0]}px;top:${d[1]}px;background:${avBg(f)};--i:${i}">${f.n[0]}</i>`}).join('');
  const pn=OBPG[OB.st];if(pn){$('obpn').textContent='0'+pn;$('obpl').textContent=['','YOU','TAG','FRIENDS','NOTICE'][pn]}}
function obTpl(st){
  if(st==='in')return[`<span class="obk2">FILM FOR TOMORROW</span><h2 class="obh">撮る。<br>あした、<em>ひらく。</em></h2>`,`<button class="ob1" data-a="apple">Apple で つづける</button><button class="ob2" data-a="google">Google で つづける</button><button class="ob2" data-a="mail">メールで つづける</button><p class="obtm">つづけると <u>利用規約</u>・<u>プライバシー</u> に 同意(13歳以上)</p>`];
  if(st==='mail')return[`<h2 class="obh">メールアドレス</h2><label class="obin sm"><input id="obmail" type="email" inputmode="email" placeholder="you@example.com" autocomplete="email" enterkeyhint="send" aria-label="メールアドレス"></label><p class="obsb">パスワードは いりません</p>`,`<button class="ob1" id="obmgo" disabled>リンクを おくる</button><button class="ob3" data-a="toin">ほかの 方法</button>`];
  if(st==='sent')return[`<h2 class="obh">メールを<br>おくりました</h2><p class="obsb">${rmEsc(OB.mail)}<br>リンクを タップすると、もどってきます</p>`,`<button class="ob1" data-a="openmail">メールを ひらく</button><button class="ob3" data-a="resend">もういちど おくる</button>`];
  if(st==='name')return[`<h2 class="obh obnmh">Name<small>Lattag で よばれる なまえ</small></h2><label class="obin"><input id="obname" maxlength="12" placeholder="なまえ" autocomplete="off" enterkeyhint="next" aria-label="なまえ" value="${rmEsc(OB.name)}"></label><div class="obct" id="obcnt">${[...OB.name].length} / 12</div>`,`<button class="ob1" id="obnx" ${OB.name?'':'disabled'}>つぎへ</button>`];
  if(st==='tag')return[`<h2 class="obh">じぶんを、<em>タグ</em>で。</h2><div class="obsw" id="obsw">${OBP.map((p,i)=>`<button data-c="${i}" class="${!OB.img&&OB.col===i?'on':''}" style="--a:${p[0]};--b:${p[1]}" aria-label="色 ${i+1}"></button>`).join('')}<button class="cam${OB.img?' on':''}" data-c="cam" aria-label="写真を えらぶ"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg></button></div><div class="obch" id="obch"></div>`,`<button class="ob1" id="obnx">つぎへ</button>`];
  if(st==='fr')return[`<h2 class="obh">ともだちを さがす</h2><div class="obli" id="obli" style="max-height:206px"></div><div class="obm"><button data-a="shake">ふって つながる</button><button data-a="link">リンクを おくる</button></div>`,`<button class="ob1" id="obnx">${OB.req.length?'つぎへ':'あとで'}</button>`];
  if(st==='nt')return[`<h2 class="obh"><i>9:00</i> に、しらせる。</h2><p class="obsb">朝の 1回と、なかまの ことだけ</p>`,`<button class="ob1" data-a="nton">通知を うけとる</button><button class="ob3" data-a="ntoff">あとで</button>`];
  return[`<h2 class="obh obfin">ようこそ、<br>${rmEsc(OB.name||'あなた')}。</h2>`,`<div class="obhd" id="obhd" role="button" aria-label="ながおしで はじめる"></div><p class="obhl">HOLD<small>ながおしで はじめる</small></p>`]}
function obChips(){const C=$('obch');if(!C)return;const cus=OB.tags.filter(t=>!OBT.includes(t));
  C.innerHTML=[...OBT,...cus].map(t=>`<button data-t="${rmEsc(t)}" class="${OB.tags.includes(t)?'on':''}">${rmEsc(t)}</button>`).join('')+(OB.cus?`<input id="obcus" maxlength="10" placeholder="#じぶんで" aria-label="じぶんで タグを 書く">`:`<button data-t="+">+ じぶんで</button>`);
  C.querySelectorAll('button').forEach(b=>b.onclick=()=>{const t=b.dataset.t;if(t==='+'){OB.cus=true;hap('sel','コツッ');obChips();$('obcus').focus({preventScroll:true});return}obTag(t)});
  const ci=$('obcus');if(ci){const add=()=>{let v=ci.value.trim().replace(/^#+/,'');OB.cus=false;if(v)obTag('#'+v,true);else obChips()};ci.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();add()}});ci.addEventListener('blur',()=>setTimeout(()=>{if(OB.cus)add()},60))}}
function obTag(t,force){const i=OB.tags.indexOf(t);if(i>=0&&!force){OB.tags.splice(i,1);hap('tick','ごく軽く(はずす)')}else if(i<0){if(OB.tags.length>=3){hap('warn','やわらかく2回(3つまで)');toast('タグは 3つまで');obChips();return}OB.tags.push(t);hap('pop','ぷにっ(タグを はる)')}
  obChips();obSync();if(i<0&&!obRM()){const s=$('obtg').lastElementChild;s&&s.animate([{scale:'2.4',opacity:0},{scale:'.9',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}}
function obList(pop){const L=$('obli');if(!L)return;const row=(fi,sub,inv)=>{const f=FPOOL[fi],on=OB.req.includes(fi);return `<div class="obrw${inv?' inv':''}"><i style="background:${avBg(f)}">${f.n[0]}</i><span><b>${f.n}</b><small>${sub}</small></span><button data-f="${fi}" class="${on?'on':''}">${on?'申請した':'申請'}</button></div>`};
  L.innerHTML=row(1,'招待してくれた',true)+(OB.con?[0,2,3,4].map(i=>row(i,'連絡先に います')).join(''):`<button class="obw" data-a="con"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="9" cy="8.5" r="3.5"/><path d="M2.5 19.5c.6-3.4 3.2-5.2 6.5-5.2s5.9 1.800 6.5 5.200M17 8v6M14 11h6"/></svg>連絡先から さがす</button>`);
  L.querySelectorAll('.obrw button').forEach(b=>b.onclick=()=>{const fi=+b.dataset.f,i=OB.req.indexOf(fi);if(i>=0){OB.req.splice(i,1);hap('tick','ごく軽く(とりけす)')}else{OB.req.push(fi);hap('pop','ぷにっ(申請)')}
    const st=L.scrollTop;obList();L.scrollTop=st;obSync();$('obnx').textContent=OB.req.length?'つぎへ':'あとで';
    if(i<0&&!obRM()){const d=$('obfr').lastElementChild;d&&d.animate([{scale:'0',opacity:0},{scale:'1.2',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}});
  const c=L.querySelector('[data-a="con"]');if(c)c.onclick=()=>{hap('click','カチッ(連絡先)');OB.con=true;obList(true);toast('(モック)連絡先を 許可した ことに します')};
  if(pop&&!obRM())[...L.querySelectorAll('.obrw:not(.inv)')].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(16px) scale(.96)'},{opacity:1,transform:'none'}],{duration:400,delay:i*70,easing:'cubic-bezier(.3,1.4,.4,1)',fill:'backwards'}))}
function obBind(){const st=OB.st,X=$('obx'),F=$('obf');
  [...X.querySelectorAll('[data-a]'),...F.querySelectorAll('[data-a]')].forEach(b=>b.onclick=()=>obAct(b.dataset.a,b));
  const nx=$('obnx');if(nx)nx.onclick=()=>{if(nx.disabled)return;hap('click','カチッ(つぎへ)');obStep({name:'tag',tag:'fr',fr:'nt'}[st])};
  if(st==='name'){const i=$('obname');i.addEventListener('input',e=>{OB.name=i.value.trim();$('obcnt').textContent=[...i.value].length+' / 12';$('obnx').disabled=!OB.name;if(!e.isComposing)hap('tick','ごく軽く(書く)',{norip:1});OB.col=OB.name?gnHash(OB.name)%OBP.length:0;obSync()});
    i.addEventListener('compositionend',()=>{OB.name=i.value.trim();obSync()});i.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.isComposing){e.preventDefault();$('obnx').click()}});i.addEventListener('focus',()=>setTimeout(()=>{$('ob').scrollTop=0},50));setTimeout(()=>{if(OB.on&&OB.st==='name')i.focus({preventScroll:true})},420)}
  if(st==='mail'){const i=$('obmail');i.value=OB.mail;const ok=()=>/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(i.value.trim());$('obmgo').disabled=!ok();i.addEventListener('input',()=>{$('obmgo').disabled=!ok()});
    const go=()=>{if(!ok())return;OB.mail=i.value.trim();i.blur();hap('click','カチッ(おくる)');obStep('sent')};$('obmgo').onclick=go;i.addEventListener('keydown',e=>{if(e.key==='Enter'){e.preventDefault();go()}});i.addEventListener('focus',()=>setTimeout(()=>{$('ob').scrollTop=0},50));setTimeout(()=>{if(OB.on&&OB.st==='mail')i.focus({preventScroll:true})},420)}
  if(st==='tag'){obChips();$('obsw').querySelectorAll('button').forEach(b=>b.onclick=()=>{if(b.dataset.c==='cam'){OB.img=!OB.img;hap('pop','ぷにっ(写真)');if(OB.img)toast('(モック)カメラ / 写真から えらぶ')}else{OB.img=false;OB.col=+b.dataset.c;hap('sel','コツッ(色)')}
      $('obsw').querySelectorAll('button').forEach(x=>x.classList.toggle('on',x.dataset.c==='cam'?OB.img:!OB.img&&+x.dataset.c===OB.col));obSync()})}
  if(st==='fr')obList();
  if(st==='go')obHold()}
function obAct(a,b){if(OB.busy)return;
  if(a==='apple'||a==='google'){OB.busy=true;const t=b.textContent;b.textContent='…';hap('click','カチッ(サインイン)');setTimeout(()=>{OB.busy=false;b.textContent=t;if(!OB.on)return;hap('success','トトトン(サインイン できた)',{norip:1});obStep('name')},800)}
  else if(a==='mail'){hap('sel','コツッ');obStep('mail')}
  else if(a==='toin'){hap('tick');obStep('in',-1)}
  else if(a==='openmail'){hap('success','トトトン(もどってきた)',{norip:1});toast('(モック)リンクを タップした ことに します');obStep('name')}
  else if(a==='resend'){hap('sel','コツッ');toast('もういちど おくりました')}
  else if(a==='shake'){hap('heart','ドクン');toast('となりの人と、スマホを ふる')}
  else if(a==='link'){hap('pop','ぷにっ(共有シート)');toast('共有シートを ひらく(LINE など)')}
  else if(a==='nton'){hap('success','トトトン(通知 オン)',{norip:1});if(!obRM())$('obn').animate([{scale:'1'},{scale:'1.05'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(()=>OB.on&&obStep('go'),380)}
  else if(a==='ntoff'){hap('soft','ふわっ(あとで)');obStep('go')}}
function obStep(st,dir){if(!OB.on)return;const O=$('ob'),X=$('obx'),F=$('obf'),d=dir||1,rm=obRM();
  const sw=()=>{OB.st=st;O.className='ob on s-'+st;const[x,f]=obTpl(st);X.innerHTML=x;F.innerHTML=f;obSync();obBind();
    if(st==='nt')hap('soft','ふわっ(通知の 見本)',{norip:1});if(st==='go')hap('success','トトトン(できた)',{norip:1});
    if(!rm){[X,F].forEach((e,i)=>e.animate([{opacity:0,transform:`translateY(${22*d}px)`},{opacity:1,transform:'none'}],{duration:440,delay:i*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}};
  if(rm||!X.innerHTML){sw();return}
  F.animate([{opacity:1},{opacity:0}],{duration:160,fill:'forwards'});X.animate([{opacity:1,transform:'none'},{opacity:0,transform:`translateY(${-14*d}px)`}],{duration:170,easing:'ease-in',fill:'forwards'}).onfinish=()=>{[X,F].forEach(e=>e.getAnimations().forEach(a=>a.cancel()));sw()}}
function obHold(){const b=$('obhd'),O=$('ob'),C=$('obc');let raf=0,t0=0,done=false,lt=0,lb=0,on=false,lsp=0;const D=1700;
  const stop=()=>{if(!on||done)return;on=false;cancelAnimationFrame(raf);b.style.setProperty('--pg','0deg');b.style.setProperty('--ps','1');O.style.setProperty('--hp',0);C.style.translate='';C.style.scale='';$('obfr').style.translate='';hap('soft','ふわっ(はなした)',{norip:1});O.querySelectorAll('.obsp').forEach(s=>s.remove())};
  const spark=p=>{if(obRM())return;const s=document.createElement('i');s.className='obsp';const ang=Math.random()*6.283,r=170+Math.random()*90,cx=195,cy=560;s.style.left=(cx+Math.cos(ang)*r)+'px';s.style.top=(cy+Math.sin(ang)*r)+'px';O.appendChild(s);
    s.animate([{transform:'none',opacity:0},{opacity:1,offset:.2},{transform:`translate(${-Math.cos(ang)*r}px,${-Math.sin(ang)*r}px) scale(.4)`,opacity:0}],{duration:520-p*200,easing:'cubic-bezier(.5,0,.9,.6)'}).onfinish=()=>s.remove()};
  const step=t=>{const p=Math.min(1,(t-t0)/D),e=p*p;b.style.setProperty('--pg',(p*360)+'deg');b.style.setProperty('--ps',(1-p*.28).toFixed(3));O.style.setProperty('--hp',e.toFixed(3));
    if(!obRM()){const sh=e*5;C.style.translate=`${((Math.random()-.5)*sh).toFixed(1)}px ${((Math.random()-.5)*sh).toFixed(1)}px`;C.style.scale=(1.22+e*.16).toFixed(3);$('obfr').style.translate=C.style.translate;
      if(t-lsp>Math.max(18,90-p*80)){lsp=t;spark(p)}}
    // バイブ:はじめは 間をあけて コツコツ → だんだん 速く → 最後は ずっと ブルブル
    if(p<.45){if(t-lt>200-p*260){lt=t;hap('tick','コツ(たまる)',{norip:1})}}
    else if(p<.8){if(t-lt>90-(p-.45)*150){lt=t;hap('buzz','ブルブル(もうすこし)',{norip:1})}}
    else if(t-lb>70){lb=t;hap('rumble','ブルブルブル(いっぱい)',{norip:1})}
    if(p>=1){done=true;obFinish();return}raf=requestAnimationFrame(step)};
  b.addEventListener('pointerdown',e=>{e.preventDefault();if(done||on)return;on=true;t0=performance.now();lt=t0;lb=t0;lsp=t0;hap('click','カチッ(おさえた)');raf=requestAnimationFrame(step)});
  ['pointerup','pointerleave','pointercancel'].forEach(ev=>b.addEventListener(ev,stop));b.addEventListener('contextmenu',e=>e.preventDefault())}
function obFinish(){const O=$('ob'),W=$('obwc'),rm=obRM();O.querySelectorAll('.obsp').forEach(s=>s.remove());hap('shutter','カシャッ(はじまる)');
  const T=(f,ms)=>OBT2.push(setTimeout(()=>{if(OB.on)f()},ms));
  W.classList.add('on');const fl=$('wcfl'),lg=$('wclogo'),ir=$('wciris');[fl,lg,ir].forEach(e=>e.getAnimations().forEach(x=>x.cancel()));
  if(rm){fl.style.opacity=0;lg.style.opacity=1;T(obDone,1400);return}
  fl.animate([{opacity:1},{opacity:1,offset:.25},{opacity:0}],{duration:620,fill:'forwards'});
  lg.animate([{opacity:0,transform:'scale(3.2)',filter:'blur(16px)'},{opacity:1,transform:'scale(.92)',filter:'blur(0)',offset:.6},{transform:'scale(1.03)',offset:.8},{opacity:1,transform:'none'}],{duration:640,delay:160,easing:'cubic-bezier(.2,.8,.3,1)',fill:'both'});
  T(()=>{hap('vui','ブイッ(ようこそ)');W.animate([{transform:'translate(0,0)'},{transform:'translate(-6px,3px)'},{transform:'translate(5px,-4px)'},{transform:'translate(-3px,2px)'},{transform:'none'}],{duration:320})},520);
  T(()=>{hap('soft','ふわっ(ひらく)');ir.animate([{transform:'scale(0)'},{transform:'scale(3.4)'}],{duration:760,easing:'cubic-bezier(.6,0,.2,1)',fill:'forwards'})},1700);
  T(obDone,2400)}
function obDone(){closeOb();const W=$('obwc');setTimeout(()=>{if(OB.on)return;W.classList.remove('on');[...W.querySelectorAll('*')].forEach(e=>e.getAnimations().forEach(x=>x.cancel()))},1100);if(cur!=='home')show('home');shots=0;setDay(false);renderCam();homeFocus();CMS.clear();try{homeIn()}catch(e){}}
var OBT2=[];
function obWall(){const P=['a','b','c','d','e','f'];let h='';for(let c=0;c<4;c++){let col='';for(let k=0;k<7;k++){const p=P[(c*3+k*5)%6],m=(c+k)%3===0;col+=`<div class="w${m?' m':''}" style="--r:${((c*7+k*11)%9-4)*.8}deg"><i style="background-image:url(${PH[p]})"></i></div>`}h+=`<div class="col">${col}${col}</div>`}$('obwall').innerHTML=h}
function obIntro(){const O=$('obop'),S=$('obst'),G=$('obseg'),rm=obRM();OBT2.forEach(clearTimeout);OBT2=[];
  O.classList.remove('gone');{const dt=new Date();$('opdt').textContent=`'${String(dt.getFullYear()).slice(2)} ${p2(dt.getMonth()+1)} ${p2(dt.getDate())}`}
  G.innerHTML=SEGC('9:00');G.className='obseg off';$('opimg').src=PH.d;
  const T=(f,ms)=>OBT2.push(setTimeout(()=>{if(OB.on)f()},ms));const A=(e,k,o)=>e.animate(k,Object.assign({fill:'forwards'},o));
  const ck=$('opck'),mk=$('opmk'),lg=$('oplogo');[ck,mk,lg,$('opslit'),$('oplk')].forEach(e=>e.getAnimations().forEach(x=>x.cancel()));
  if(rm){ck.style.transform='none';mk.style.opacity=0;lg.style.opacity=1;G.className='obseg on';T(obIntroEnd,1600);return}
  ck.style.transform='';mk.style.opacity='';lg.style.opacity='';
  A($('opslit'),[{transform:'scaleX(0)'},{transform:'scaleX(1)'}],{duration:420,delay:150,easing:'cubic-bezier(.3,1,.4,1)'});
  T(()=>hap('tick','ごく軽く(スロット)',{norip:1}),180);
  // チェキが スロットから 出てくる(モーター音の かわりに カタカタ)
  A(ck,[{transform:'translateY(-102%)'},{transform:'translateY(-70%)',offset:.3},{transform:'translateY(-66%)',offset:.42},{transform:'translateY(-20%)',offset:.78},{transform:'translateY(0)'}],{duration:1300,delay:520,easing:'linear'});
  [560,760,980,1200,1420,1640].forEach((t,k)=>T(()=>hap(k%2?'tick':'projector',k%2?null:'カタカタ(チェキが 出てくる)',{norip:1}),t));
  T(()=>{G.className='obseg on';hap('click','カチッ(日付が ともる)')},1880);
  A(mk,[{opacity:1},{opacity:.85,offset:.3},{opacity:0}],{duration:2600,delay:1900,easing:'cubic-bezier(.3,.1,.3,1)'});
  A($('opimg'),[{filter:'url(#chk) brightness(1.6) saturate(.1)'},{filter:'url(#chk) brightness(1) saturate(1)'}],{duration:2600,delay:1900});
  A($('oplk'),[{opacity:0},{opacity:1,offset:.4},{opacity:.55}],{duration:2400,delay:1700});
  // 大きな Lattag が 印刷ズレ ごと 落ちてくる
  A(lg,[{opacity:0,transform:'scale(1.5)',filter:'blur(10px)'},{opacity:1,transform:'scale(.97)',filter:'blur(0)',offset:.55},{opacity:1,transform:'none',filter:'blur(0)'}],{duration:620,delay:2250,easing:'cubic-bezier(.2,.8,.3,1)'});
  T(()=>hap('thud','ドン(Lattag)'),2560);
  T(obIntroEnd,4300)}
function obIntroEnd(){OBT2.forEach(clearTimeout);OBT2=[];const O=$('obop');if(O.classList.contains('gone'))return;O.classList.add('gone');
  if(obRM())return;$('obc').animate([{transform:'translateY(-300px) rotate(-14deg)',opacity:0},{transform:'translateY(14px) rotate(2deg)',opacity:1,offset:.7},{transform:'none'}],{duration:900,delay:120,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'}).onfinish=()=>hap('land','トン(チェキが おちる)',{norip:1});
  [$('obl'),$('obwall')].forEach(e=>e.animate([{opacity:0}],{duration:900,fill:'backwards',composite:'replace'}));
  [...$('obx').children,...$('obf').children].forEach((e,i)=>e.animate([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:520,delay:700+i*80,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
function openOb(){if(OB.on)return;if(RM.on)closeRoom();if(GN.on)closeGnw();cmHide();OB={on:true,st:'in',name:'',col:0,tags:[],req:[],mail:'',con:false,img:false,busy:false,cus:false};const O=$('ob');
  document.documentElement.style.setProperty('--grn',GRN);
  const d=new Date();$('obdt').textContent=`'${String(d.getFullYear()).slice(2)} ${p2(d.getMonth()+1)} ${p2(d.getDate())}`;$('obc').style.scale='';$('obx').innerHTML='';obWall();
  O.classList.add('on');O.setAttribute('aria-hidden','false');obStep('in');hap('soft','ふわっ(はじまる)');obIntro()}
$('obop').onclick=()=>{hap('tick',null,{norip:1});obIntroEnd()};
function closeOb(){if(!OB.on)return;OB.on=false;OBT2.forEach(clearTimeout);OBT2=[];$('ob').style.setProperty('--hp',0);const a=document.activeElement;a&&a.blur&&a.blur();const O=$('ob');O.classList.remove('on');O.setAttribute('aria-hidden','true')}
$('obk').onclick=()=>{const b={tag:'name',fr:'tag',nt:'fr',mail:'in',sent:'mail'}[OB.st];if(!b)return;hap('tick','ごく軽く1回(もどる)');obStep(b,-1)};
$('obph').onclick=()=>{if(OB.st!=='tag')return;OB.img=!OB.img;hap('pop','ぷにっ(写真)');if(OB.img)toast('(モック)カメラ / 写真から えらぶ');const sw=$('obsw');sw&&sw.querySelectorAll('button').forEach(x=>x.classList.toggle('on',x.dataset.c==='cam'?OB.img:!OB.img&&+x.dataset.c===OB.col));obSync()};

/* ===== v28 暗室(Home の 下):ACTIVE / YESTERDAY / MONDO / ALBUMS / FRIENDS ===== */
const MON=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'],WD=['SUN','MON','TUE','WED','THU','FRI','SAT'];
const ICO={clk:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/></svg>',
 cam:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>',
 chat:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linejoin="round"><path d="M4 12a8 7 0 1 1 3.6 5.8L4 19.5l1.3-3.6A6.8 6.8 0 0 1 4 12z"/></svg>',
 globe:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/></svg>',
 plus:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>',
 lock:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><rect x="5" y="11" width="14" height="10" rx="2.5"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>',
 star:'<svg class="kp" viewBox="0 0 40 40"><path d="M20 3c1.4 9 7 14.6 17 17-10 2.4-15.6 8-17 17-1.4-9-7-14.6-17-17 10-2.4 15.6-8 17-17z"/></svg>'};
const YF=[{n:'あや',p:'d',tm:'07:58',t:'#朝',f:1},{n:'れな',p:'e',tm:'12:20',t:'#カフェ',f:0},{n:'そら',p:'f',tm:'17:31',t:'#部活',f:2}];
const TGC=[['#EE5E9C','#fff'],['#C8F25A','#111'],['#9ED8FF','#111'],['#FFD60A','#111'],['#9B8CFF','#fff']];
const tgc=s=>TGC[gnHash(s)%TGC.length];
const enD=k=>{const d=new Date();d.setDate(d.getDate()-k);return[MON[d.getMonth()]+' '+d.getDate(),WD[d.getDay()]]};
function ydOrder(){return YD.map((y,i)=>({...y,i})).sort((a,b)=>a.tm<b.tm?-1:1)}
function arcActive(){const A=$('aact');let h='';
  if(INV&&!INV.later)h+=`<button class="acd inv" data-a="inv"><i class="bg" style="background-image:url(${PH.e})"></i><b>${rmEsc(INV.n)}</b><small>${ICO.clk}from ${rmEsc(INV.from)}</small><span class="st">join</span></button>`;
  GRP.forEach((g,gi)=>{const ph=PH['abcdef'[gnHash(g.n)%6]];const sub=g.pend?'pending':g.all?'all in':(g.pill||'');
    const av=[{n:'me',g:['#B1EFBE','#67DE7F','#EE5E9C']},...g.m].slice(0,3).map(f=>f.n==='me'?'<i class="me"></i>':`<i style="background:${avBg(f)}">${f.n[0]}</i>`).join('');
    h+=`<button class="acd" data-a="g" data-i="${gi}">${g.pend?'':`<i class="bg" style="background-image:url(${ph})"></i>`}<b>${rmEsc(g.n)}</b><small>${ICO.clk}${rmEsc(sub)}</small><span class="st${g.all?' all':''}">${ICO.chat}${g.un?'<u style="width:7px;height:7px;border-radius:50%;background:#239E3C"></u>':''}</span><span class="av3">${av}</span>${g.pend?'':(()=>{const t=['#放課後','#いつメン','#部活','#帰り道'][gnHash(g.n)%4],c=tgc(t);return `<span class="tgk" style="background:${c[0]};color:${c[1]}">${t}</span>`})()}</button>`});
  h+=`<button class="acd nw" id="acnew" data-a="new"><i>${ICO.plus}</i><span>New trip</span></button>`;
  A.innerHTML=h;
  A.querySelectorAll('.acd').forEach(c=>c.onclick=()=>{const a=c.dataset.a;
    if(a==='today'){if(!shots){hap('pop','ぷにっ(撮りに いく)');goShoot();return}hap('pop','ぷにっ(現像中を みる)');openDvx()}
    else if(a==='inv'){hap('success','トトトン(入った)',{norip:1});GRP.unshift({n:INV.n,m:INV.m,sub:`${INV.size}人`,pill:'あと 3人',un:1,last:INV.from+': よろしく〜'});INV=null;renderGroups(true);toast('グループに 入りました')}
    else if(a==='g')openRoom(GRP[+c.dataset.i]);
    else if(a==='new'){hap('tick','ごく軽く1回');openGnw()}})}
function arcYesterday(){const H=$('ayh'),G=$('ayg'),lk=shots===0,ord=ydOrder(),open=new Set(ord.slice(0,shots).map(o=>o.i));
  const [dl,wd]=enD(1);$('aydd').textContent=wd;
  const heroP=kept>=0&&open.has(kept)?YD[kept]:(!lk?YF[0]:YD[0]);const tg=heroP.t,c=tgc(tg);
  H.className='ayh'+(lk?' lk':'');
  H.innerHTML=`<i class="bg" style="background-image:url(${PH[heroP.p]})"></i><span class="lkp">${ICO.lock}shoot today to open</span>
    <span class="stk2" style="right:18px;top:22px;background:${c[0]};color:${c[1]};--r:8deg">${rmEsc(tg)}</span>
    <div class="tt">Yesterday<small>${dl.toUpperCase()}</small></div>
    <div class="sts"><div><b>${3+YF.length}</b><span>Moments</span></div><div class="cir"><b>6d</b><span>Left</span><svg viewBox="0 0 74 50"><path d="M40 4C18 2 3 12 5 26c2 14 26 21 46 17 17-3 22-15 17-25C63 8 48 3 30 6"/></svg></div><div><b>${YF.length+1}</b><span>People ›</span></div></div>
    <div class="bt"><button class="w" data-a="mondo">${ICO.globe}Mondo</button><button class="s" data-a="chat" aria-label="グループ">${ICO.chat}</button></div>`;
  H.querySelector('[data-a="mondo"]').onclick=()=>{if(lk){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます');return}hap('pop','ぷにっ(Mondo)');openY()};
  H.querySelector('[data-a="chat"]').onclick=()=>{const g=GRP.find(g=>!g.pend);if(g)openRoom(g);else{hap('tick');openGnw()}};
  H.querySelector('.stk2').style.display=lk?'none':'';
  // グリッド:ともだち と じぶん を かわりばんこに
  const items=[];YF.forEach((f,k)=>{items.push({t:'f',d:f});if(ord[k])items.push({t:'o',d:ord[k]})});
  let firstOwn=true;
  G.innerHTML=items.map(it=>{if(it.t==='f'){const f=it.d,ml=lk;return `<div class="ayc${ml?' ml':''}" data-t="f" data-n="${f.n}"><img src="${PH[f.p]}" alt=""><span class="nm">${f.n}.</span>${ml?`<span class="lk">${ICO.lock}</span>`:`<span class="tm">${f.tm}</span>`}</div>`}
    const o=it.d,op=open.has(o.i),id=op&&firstOwn?' id="ayk"':'';if(op)firstOwn=false;
    return `<div class="ayc own${op?'':' ml'}${o.i===kept?' kept':''}"${id} data-t="o" data-i="${o.i}"><img src="${PH[o.p]}" alt=""><span class="nm">you.</span>${op?`<span class="tm">${o.tm}</span>`:`<span class="lk">${ICO.lock}</span>`}${ICO.star}<svg class="rg" viewBox="0 0 70 70" preserveAspectRatio="none"><circle cx="35" cy="35" r="32" transform="rotate(-90 35 35)"/></svg></div>`}).join('');
  G.querySelectorAll('.ayc').forEach(c=>arcBindTile(c,()=>{const ml=c.classList.contains('ml');
      if(ml){hap('warn','やわらかく2回(まだ)');toast(c.dataset.t==='o'?'もう1枚 撮ると、ひらきます':'今日 1枚 撮ると、ひらきます');return}
      if(c.dataset.t==='f'){const f=YF.find(x=>x.n===c.dataset.n);openAv({p:f.p,n:f.n,s:'yesterday · '+f.tm,t:f.t})}
      else{const y=YD[+c.dataset.i];openAv({p:y.p,n:'you',s:'yesterday · '+y.tm,t:y.t,own:'y',i:+c.dataset.i})}},
    c.dataset.t==='o'&&!c.classList.contains('ml')?()=>{kept=+c.dataset.i;hap('heart','ドクン(1年 のこす)',{norip:1});setTimeout(()=>hap('success','トトトン',{norip:1}),240);toast('この 1枚は、1年 のこります');arcYesterday();try{renderYday()}catch(e){}}:null))}
function arcBindTile(c,tap,hold){let t0=0,tm=0,sx=0,sy=0,fired=false,an=null;const rg=c.querySelector('.rg circle');
  c.addEventListener('pointerdown',e=>{sx=e.clientX;sy=e.clientY;t0=performance.now();fired=false;if(!hold)return;
    tm=setTimeout(()=>{c.classList.add('hold');hap('tick',null,{norip:1});if(rg)an=rg.animate([{strokeDashoffset:201},{strokeDashoffset:0}],{duration:520,fill:'forwards'});tm=setTimeout(()=>{fired=true;c.classList.remove('hold');hold()},520)},160)});
  const end=()=>{clearTimeout(tm);c.classList.remove('hold');if(an){an.cancel();an=null}};
  c.addEventListener('pointermove',e=>{if(Math.hypot(e.clientX-sx,e.clientY-sy)>9){end();t0=0}});
  c.addEventListener('pointerup',()=>{const was=t0;end();if(fired||!was)return;if(performance.now()-was<400)tap()});
  c.addEventListener('pointercancel',end);c.addEventListener('contextmenu',e=>e.preventDefault())}
function arcMondo(){const M=$('amd');M.classList.toggle('lk',!shots);
  M.innerHTML=TOP.map(([t,w,p1],i)=>`<button class="amc" data-t="${t}" style="background-image:url(${PH[p1]})"><span class="n">0${i+1}</span><b>${t}</b></button>`).join('');
  M.querySelectorAll('.amc').forEach(b=>b.onclick=()=>{if(!shots){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます');return}hap('pop','ぷにっ(ことばへ)');openY();setTimeout(()=>{try{ytab('ymr')}catch(e){}},500)})}
function arcAlbums(){const L=$('aal'),pp=['a','b','c','d','e','f'];let h='';
  for(let k=1;k<=6;k++){const [dl,wd]=enD(k),n=wkN(k),left=7-k,st=wkStar[k],more=[8,5,12,3,9,6][k-1];
    const tiles=Array.from({length:3},(_,j)=>j<n?`<div class="alt${st===j?' kept':''}" data-k="${k}" data-j="${j}" style="background-image:url(${PH[pp[(k*2+j)%6]]})">${ICO.star}</div>`:'<div class="alt em"></div>').join('')+`<div class="alt mr" style="background-image:url(${PH[pp[(k*3+1)%6]]})"><span>+${more}</span></div>`;
    h+=`<div class="alr${k===6?' go':''}" style="--o:${(1-(k-1)*.07).toFixed(2)}"><div class="alh"><b>${dl}</b><span class="${left<=2?'hot':''}">${k===6?'GOES TOMORROW':left+'D LEFT · '+wd}</span></div><div class="als">${tiles}</div></div>`}
  L.innerHTML=h;
  L.querySelectorAll('.alt[data-j]').forEach(t=>arcBindTile(t,()=>{const k=+t.dataset.k,j=+t.dataset.j;openAv({p:pp[(k*2+j)%6],n:'you',s:enD(k)[0].toLowerCase(),own:'w',k,j})},
    ()=>{const k=+t.dataset.k,j=+t.dataset.j;wkStar[k]=j;hap('heart','ドクン(★ 1年 のこす)',{norip:1});toast('この 1枚は、1年 のこります');arcAlbums();try{renderWeek()}catch(e){}}));
  L.querySelectorAll('.alt.mr').forEach(t=>t.onclick=()=>{hap('pop','ぷにっ');openY()})}
function arcFriends(){const B=$('afr');if(!FR.length){B.innerHTML=`<span class="fs"><i style="border:2px dashed #3A3A3F;background:none"></i><i style="border:2px dashed #3A3A3F;background:none"></i></span><span class="tx"><b>No one yet</b><small>shake to connect</small></span><em>0<s>/12</s></em>`;return}
  const took=FR.filter(f=>f.k>0).length;B.innerHTML=`<span class="fs">${FR.slice(0,4).map(f=>`<i class="${f.k>0?'k':''}" style="background:${avBg(f)}">${f.n[0]}</i>`).join('')}</span><span class="tx"><b>${FR.slice(0,3).map(f=>f.n).join(', ')}</b><small>${took} shot today</small></span><em>${FR.length}<s>/12</s></em>`}
$('afr').onclick=()=>openFriend();

function arcToday(){const T=$('tdv');if(!T)return;const d=new Date();const dl=MON[d.getMonth()].toUpperCase()+' '+d.getDate();const P=['c','a','e'];
  const fr=[0,1,2].map(i=>{if(i<shots){const p=dvProgress(i);return `<div class="tf dv" data-i="${i}" style="--i:${i};--mk:${(0.92-p*.62).toFixed(2)};--bl:${(10-p*8).toFixed(1)}px;--sa:${(.15+p*.6).toFixed(2)};--br:${(1.45-p*.4).toFixed(2)}"><img src="${PH[P[i]]}" alt=""><span class="tp">${Math.round(p*100)}%</span><span class="tt">${TM[i]}</span></div>`}
    if(i===shots)return `<div class="tf nx" data-a="shoot">${ICO.plus}<span>SHOOT</span></div>`;return '<div class="tf no"></div>'}).join('');
  const p=shots?dvProgress(0):0;
  T.innerHTML=`<div class="tdh"><b>Today</b><span>${shots}<s>/3</s></span></div><div class="tdl"><i></i>${shots?'DEVELOPING':'EMPTY FILM'} · ${dl}</div><div class="tdf">${fr}</div><div class="tdp" style="--p:${(p*100).toFixed(1)}%"><i></i></div><div class="tdq"><span>${shots?'<b>'+TM[0]+'</b> shot':'<b>9:00</b> start'}</span><em>${shots?'opens 9:00 · '+untilTxt():'lights out · '+(($('hlo')||{}).textContent||'24:00')}</em></div>`;
  T.onclick=e=>{if(e.target.closest('[data-a="shoot"]')){hap('pop','ぷにっ(撮りに いく)');goShoot();return}if(!shots){hap('pop','ぷにっ(撮りに いく)');goShoot();return}const f=e.target.closest('.tf.dv');hap('pop','ぷにっ(現像を のぞく)');openDvx(f?+f.dataset.i:Math.max(0,shots-1))}}
var ARC_OK;function renderArc(){if(!ARC_OK||!$('arc'))return;arcToday();arcActive();arcYesterday();arcMondo();arcAlbums();arcFriends()}
/* ビューア */
var AV=null;
function openAv(o){AV=o;$('avi').src=PH[o.p];$('avn').textContent=o.n;$('avs').textContent=o.s||'';const t=$('avtg');if(o.t){const c=tgc(o.t);t.textContent=o.t;t.style.background=c[0];t.style.color=c[1]}else t.textContent='';
  const own=!!o.own;$('avk').hidden=!own;avKeep();$('avr').textContent=own?'keep for a year':'reply';
  $('avw').classList.add('on');$('avw').setAttribute('aria-hidden','false');hap('pop','ぷにっ(ひらく)');
  if(!matchMedia('(prefers-reduced-motion:reduce)').matches)$('avp').animate([{transform:'scale(.9)',opacity:0,borderRadius:'60px'},{transform:'none',opacity:1,borderRadius:'30px'}],{duration:420,easing:'cubic-bezier(.3,1.3,.4,1)'})}
function avIsKept(){if(!AV||!AV.own)return false;return AV.own==='y'?kept===AV.i:wkStar[AV.k]===AV.j}
function avKeep(){$('avk').classList.toggle('on',avIsKept());if(AV&&AV.own)$('avr').textContent=avIsKept()?'kept · 1 year':'keep for a year'}
function avDoKeep(){if(!AV||!AV.own)return;if(avIsKept()){hap('soft','やわらかく1回(もう のこす)');return}if(AV.own==='y')kept=AV.i;else wkStar[AV.k]=AV.j;hap('heart','ドクン(1年 のこす)',{norip:1});setTimeout(()=>hap('success','トトトン',{norip:1}),240);avKeep();renderArc();try{renderYday();renderWeek()}catch(e){}
  $('avk').animate([{scale:'1'},{scale:'1.4',rotate:'-20deg'},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})}
function closeAv(){$('avw').classList.remove('on');$('avw').setAttribute('aria-hidden','true');AV=null}
$('avback').onclick=()=>{hap('tick','ごく軽く1回(もどる)');closeAv()};$('avk').onclick=avDoKeep;
$('avr').onclick=()=>{if(AV&&AV.own){avDoKeep();return}const g=GRP.find(g=>!g.pend);closeAv();if(g){openRoom(g)}else toast('グループを つくると、返信できます')};
/* 暗室に 入ったら ヘッダーも 黒に */
(function(){let on=false;$('hs').addEventListener('scroll',()=>{const a=$('arc');if(!a||!DAY2)return;const dq=$('dusk'),pt=$('phone').getBoundingClientRect().top;const t=dq?(dq.getBoundingClientRect().top-pt)/SC+dq.offsetHeight*.62:(a.getBoundingClientRect().top-pt)/SC;const v=t<120;
  const dk=$('dusk');if(dk){const dt=(dk.getBoundingClientRect().top-$('phone').getBoundingClientRect().top)/SC;$('home').classList.toggle('arcb',dt+dk.offsetHeight*.55<844)}
  if(v!==on){on=v;$('home').classList.toggle('arcm',v);if(cur==='home')phone.classList.toggle('lt',!v);if(v)hap('tick','コツ(暗室へ)',{norip:1})}},{passive:true})})();
ARC_OK=true;renderArc();

/* ===== v32 まんなかの 万能ボタン:いま いちばんの ことを 真ん中に、ほかは まわりに ===== */
const OI={shoot:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg>',
 yday:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="6" width="13" height="15" rx="2"/><path d="M8 3h11a2 2 0 0 1 2 2v12"/><circle cx="10.5" cy="12" r="2.4"/></svg>',
 chat:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"><path d="M4 12a8 7 0 1 1 3.6 5.8L4 19.5l1.3-3.6A6.8 6.8 0 0 1 4 12z"/></svg>',
 group:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><circle cx="9" cy="9" r="3.4"/><path d="M3 19c.6-3.4 3-5 6-5s5.4 1.6 6 5M18 8v6M15 11h6"/></svg>',
 mondo:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"/></svg>',
 friends:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><circle cx="8" cy="9" r="3"/><circle cx="16.5" cy="9" r="3"/><path d="M2.5 19c.5-3 2.6-4.6 5.5-4.6S13 16 13.5 19M13 15.2c.9-.5 2-.8 3.5-.8 2.9 0 5 1.6 5.5 4.6"/></svg>',
 dev:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.2 2"/></svg>',
 join:'<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 12h14M13 6l6 6-6 6"/></svg>'};
const OCOL={shoot:'#B1EEBD',yday:'#CDE4FF',chat:'#FFC9DF',group:'#ADFEBD',mondo:'#E3D4FF',friends:'#FFF0B8',dev:'#B1EFBE',join:'#9ED6A5'};
function orbActs(){const unG=GRP.find(g=>g.un&&!g.pend),anyG=GRP.find(g=>!g.pend),A={};
  A.join=INV&&!INV.later?{l:'JOIN',s:INV.n,run:()=>{hap('success','トトトン(入った)',{norip:1});GRP.unshift({n:INV.n,m:INV.m,sub:`${INV.size}人`,pill:'あと 3人',un:1,last:INV.from+': よろしく〜'});INV=null;renderGroups(true);toast('グループに 入りました')}}:null;
  A.shoot=shots<3?{l:'SHOOT',s:(3-shots)+' LEFT',run:()=>goShoot()}:null;
  A.yday={l:'YESTERDAY',s:shots?Math.min(shots,3)+' OPENED':'LOCKED',lock:!shots,run:()=>{if(!shots){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます');return false}openY()}};
  A.chat=unG||anyG?{l:'CHAT',s:(unG||anyG).n,dot:!!unG,run:()=>openRoom(unG||anyG)}:null;
  A.group={l:'TRIP',s:GRP.find(g=>g.trip)?(GRP.find(g=>g.trip).cnt||0)+' / 23':'NEW',dot:false,run:()=>openGnw()};
  A.mondo={l:'MONDO',s:'TOP 5',lock:!shots,run:()=>{if(!shots){hap('warn','やわらかく2回(まだ)');toast('今日 1枚 撮ると、ひらきます');return false}openY();setTimeout(()=>{try{ytab('ymr')}catch(e){}},500)}};
  A.friends={l:'FRIENDS',s:FR.filter(f=>f.k>0).length?'● '+FR.filter(f=>f.k>0).length+' TODAY':'ADD',dot:!!(window.REQ&&window.REQ.length),run:()=>openFriend()};
  A.dev=shots?{l:'DEVELOP',s:'OPENS 9:00',run:()=>openDvx(Math.max(0,shots-1))}:null;
  // まんなか = いま いちばん
  const main=A.join?'join':shots===0?'shoot':(A.chat&&A.chat.dot)?'chat':'yday';
  const order=['shoot','dev','yday','chat','group','mondo','friends'].filter(k=>k!==main&&A[k]);
  return{A,main,sat:order.slice(0,4)}}
var ORB=null;
function renderOrb(){if(!$('osat'))return;const R=orbActs();ORB=R;const m=R.A[R.main],O=$('orb');
  O.dataset.m=R.main;$('oci').innerHTML=OI[R.main==='yday'?'yday':R.main];
  $('oc1').textContent=m.l.charAt(0)+m.l.slice(1).toLowerCase();$('oc2').textContent=m.s;
  $('omot').textContent=R.main==='shoot'?'TAP':R.main==='yday'?'OPEN':R.main==='join'?'JOIN':'OPEN';
  $('oph').style.backgroundImage=R.main==='yday'?`url(${PH[(kept>=0?YD[kept]:YD[0]).p]})`:'';
  document.querySelectorAll('#ofl path').forEach(p=>p.classList.toggle('on',+p.dataset.i>=shots));
  const POS=[[-104,-102],[104,-102],[-104,102],[104,102]];
  $('osat').innerHTML=R.sat.map((k,i)=>{const a=R.A[k],[x,y]=POS[i];return `<button class="osb${a.lock?' lk':''}" data-k="${k}" style="--x:${x}px;--y:${y}px;--c:${OCOL[k]};--i:${i}" aria-label="${a.l}"><i>${OI[k]}${a.dot?'<u></u>':''}</i><span>${a.l}</span></button>`}).join('');
  $('osat').querySelectorAll('.osb').forEach(bt=>bt.onclick=e=>{e.stopPropagation();const k=bt.dataset.k,a=ORB.A[k];hap('pop','ぷにっ('+a.l+')');
    if(!matchMedia('(prefers-reduced-motion:reduce)').matches)bt.animate([{scale:'1'},{scale:'.82'},{scale:'1.08'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(()=>a.run(),120)})}
(function(){const O=$('orb'),S=$('osh');let dn=false;
  S.addEventListener('pointerdown',e=>{dn=true;O.classList.add('prs');hap('click','カチッ(おさえた)')});
  const up=()=>{if(!dn)return;dn=false;O.classList.remove('prs')};['pointerleave','pointercancel'].forEach(ev=>S.addEventListener(ev,up));
  S.addEventListener('pointerup',()=>{if(!dn)return;up();const R=ORB||orbActs(),m=R.A[R.main];const rm=matchMedia('(prefers-reduced-motion:reduce)').matches;
    if(R.main==='shoot'){hap('shutter','カシャッ(撮影へ)');if(!rm){$('ofl2').animate([{opacity:0,transform:'scale(.6)'},{opacity:.95,offset:.3},{opacity:0,transform:'scale(1.6)'}],{duration:420,easing:'ease-out'});$('oir').animate([{transform:'rotate(0deg) scale(1)'},{transform:'rotate(90deg) scale(.6)',offset:.45},{transform:'rotate(120deg) scale(1)'}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)'})}setTimeout(()=>m.run(),260)}
    else{hap('pop','ぷにっ('+m.l+')');if(!rm)S.animate([{scale:'1'},{scale:'1.08'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'});setTimeout(()=>m.run(),140)}})})();
window.renderOrb=renderOrb;renderOrb();

/* ===== v36 Lattag yesterday(グループ)を Once ふうに ===== */
function yOnce(){const H=$('yon');if(!H)return;const lk=!shots,d=new Date(Date.now()-864e5),dl=MON[d.getMonth()].toUpperCase()+' '+d.getDate();
  const ph=['a','d','b','f'].map(p=>`<i style="background-image:url(${PH[p]})"></i>`).join('');
  const g=GRP.find(g=>!g.pend);const tt=g?rmEsc(g.n):'Yesterday,<br>together.';
  H.innerHTML=`<div class="yoh${lk?' lk':''}"><div class="yoc">${ph}</div><span class="yok">GROUPS · ${dl}</span><h2>${tt}</h2>
    ${lk?`<span class="yolk">${ICO.lock}shoot today to open</span>`:''}
    <div class="yos"><div><b>${GRP.length}</b><span>Groups</span></div><div><b>${lk?untilTxt().replace(/\s.*$/,''):'6d'}</b><span>${lk?'To open':'Left'}</span></div><div><b>${FR.length}</b><span>Friends ›</span></div></div>
    <div class="yob"><button class="w" data-a="mk">${ICO.plus}Create</button><button class="s" data-a="jn" aria-label="参加する"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><rect x="3.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="13.5" y="3.5" width="7" height="7" rx="1.5"/><rect x="3.5" y="13.5" width="7" height="7" rx="1.5"/><path d="M14 14h2v2h-2zM18 18h2.5M14 19h2"/></svg></button></div></div>
    ${GRP.length?`<div class="axh yax"><span>ACTIVE</span></div><div class="aact yact" id="yact"></div>`:''}`;
  H.querySelector('[data-a="mk"]').onclick=()=>{hap('pop','ぷにっ(つくる)');openGnw()};H.querySelector('[data-a="jn"]').onclick=()=>{hap('pop','ぷにっ(参加)');$('gjn').onclick()};
  H.querySelector('.yos div:last-child').onclick=()=>{closeY();setTimeout(openFriend,350)};
  if(GRP.length){const A=$('yact');A.innerHTML=GRP.map((g,gi)=>{const ph=PH['abcdef'[gnHash(g.n)%6]];const sub=g.pend?'pending':g.all?'all in':(g.pill||'');
      return `<button class="acd" data-i="${gi}">${g.pend?'':`<i class="bg" style="background-image:url(${ph})"></i>`}<b>${rmEsc(g.n)}</b><small>${ICO.clk}${rmEsc(sub)}</small><span class="st${g.all?' all':''}">${ICO.chat}</span></button>`}).join('');
    A.querySelectorAll('.acd').forEach(c=>c.onclick=()=>{const g=GRP[+c.dataset.i];closeY();setTimeout(()=>openRoom(g),380)})}
  const F=$('yfx');F.innerHTML=`<div class="axh yax"><span>FRIENDS · TODAY</span><em>${FR.length} / 12</em></div><div class="yfr"><button class="yfa ad" data-a="add"><i>${ICO.plus}</i><span>invite</span></button>${FR.map(f=>`<button class="yfa${f.k>0?' k':''}" data-a="f"><i style="background:${avBg(f)}">${f.n[0]}</i><span>${f.n}</span>${f.k>0?`<em>${f.k}</em>`:''}</button>`).join('')}</div>`;
  F.querySelectorAll('.yfa').forEach(x=>x.onclick=()=>{hap('pop','ぷにっ');if(x.dataset.a==='add'){openSheet('shf')}else{closeY();setTimeout(openFriend,350)}})}

window.yOnce=yOnce;
/* ===== v37 Mondo(世界の きのう):スクロールで 見る ===== */
const MW=[{p:'a',l:'鎌倉市',t:'#夕焼け',tm:'17:42'},{p:'d',l:'渋谷区',t:'#放課後',tm:'16:20'},{p:'b',l:'Brooklyn',t:'#散歩',tm:'08:05'},{p:'f',l:'京都市左京区',t:'#放課後',tm:'15:31'},{p:'c',l:'Seoul · Mapo',t:'#散歩',tm:'11:12'},{p:'e',l:'札幌市中央区',t:'#雨の日',tm:'12:48'},{p:'a',l:'Paris 11e',t:'#散歩',tm:'19:03'},{p:'d',l:'那覇市',t:'#夕焼け',tm:'18:21'},{p:'f',l:'Bangkok',t:'#ねむい',tm:'23:40'},{p:'b',l:'福岡市中央区',t:'#雨の日',tm:'07:58'},{p:'c',l:'Lisbon',t:'#夕焼け',tm:'20:10'},{p:'e',l:'横浜市中区',t:'#ねむい',tm:'01:12'}];
const MPIN=[[18,38],[23,46],[47,30],[50,34],[53,28],[72,40],[80,36],[83,42],[86,52],[30,58],[62,62],[44,70]];
var MO={tag:null,pick:-1,lit:new Set()};
function moBest(){const u=new Date().getUTCHours()+new Date().getUTCMinutes()/60;let z=9-u;z=((z+12)%24+24)%24-12;let best=CITY[0],bd=99;CITY.forEach(c=>{const d=Math.abs(c[2]-z);if(d<bd){bd=d;best=c}});return best}
function yMondo(){const M=$('ymo');if(!M)return;const lk=!shots,d=new Date(Date.now()-864e5),dl=MON[d.getMonth()].toUpperCase()+' '+d.getDate();
  const items=MW.map((m,i)=>({...m,i})).filter(m=>!MO.tag||m.t===MO.tag);const pk=MO.pick>=0?MW[MO.pick]:null,best=moBest();
  M.innerHTML=`<div class="mohd"><span>MONDO · ${dl}</span><h2>The world,<br><i>yesterday.</i></h2></div>
  <div class="mobody${lk?' lk':''}">
   <div class="moone"><i class="bg" style="background-image:url(${PH.a})"></i><i class="aura"></i><span class="k">TODAY'S ONE · 9:00</span><b>鎌倉市</b><small>picked by the world · no numbers</small><span class="tg" style="background:${tgc('#夕焼け')[0]};color:${tgc('#夕焼け')[1]}">#夕焼け</span></div>
   <div class="axh moax"><span>WORDS</span><em>${MO.tag?'<u data-a="all">ALL ×</u>':'TOP 5'}</em></div>
   <div class="mowd">${TOP.map(([t,w,p1,p2],i)=>`<button class="mow${MO.tag===t?' on':''}" data-t="${t}"><i class="n">0${i+1}</i><b>${t}</b><span class="ph"><i style="background-image:url(${PH[p1]})"></i><i style="background-image:url(${PH[p2]})"></i></span><s style="--w:${(w*100)|0}%"></s></button>`).join('')}</div>
   <div class="axh moax"><span>MORNING NOW</span><em>9:00 →</em></div>
   <div class="mo9"><div class="band"><i style="left:${(((best[2]+11)/22)*100).toFixed(1)}%"></i></div><div class="cty"><b>${best[1]}</b><span>is opening yesterday</span></div></div>
   <div class="axh moax"><span>MAP</span><em>${MW.length} PLACES</em></div>
   <div class="momap">${MPIN.map(([x,y],i)=>`<button class="pin" data-i="${i}" style="left:${x}%;top:${y}%;--d:${i*.3}s"><i style="background-image:url(${PH[MW[i].p]})"></i></button>`).join('')}<span class="note">city-level only</span></div>
   <div class="axh moax"><span>${MO.tag?rmEsc(MO.tag):'EVERYONE'}</span><em>TAP×2 LIGHT · HOLD ONE</em></div>
   <div class="mofd">${items.map(m=>`<div class="mof${MO.lit.has(m.i)?' lit':''}${MO.pick===m.i?' pk':''}" data-i="${m.i}"><img src="${PH[m.p]}" alt=""><span class="l">${rmEsc(m.l)}</span><span class="tm">${m.tm}</span><span class="tg" style="background:${tgc(m.t)[0]};color:${tgc(m.t)[1]}">${m.t}</span>${ICO.star}</div>`).join('')}</div>
   <button class="mokp" data-a="kept"><span><b>Your one</b><small>${pk?rmEsc(pk.l)+' · results at 9:00':'hold a photo to choose · until 24:00'}</small></span><em>›</em></button>
  </div>${lk?`<span class="molk">${ICO.lock}shoot today to open</span>`:''}`;
  if(lk)return;
  M.querySelectorAll('.mow').forEach(b=>b.onclick=()=>{const t=b.dataset.t;MO.tag=MO.tag===t?null:t;hap('sel','コツッ(ことば)');yMondo();const f=M.querySelector('.mofd');f&&f.animate([{opacity:.3,transform:'translateY(10px)'},{opacity:1,transform:'none'}],{duration:320});});
  const all=M.querySelector('[data-a="all"]');if(all)all.onclick=()=>{MO.tag=null;hap('tick');yMondo()};
  M.querySelector('.moone').onclick=()=>openAv({p:'a',n:'鎌倉市',s:"today's one · picked by the world",t:'#夕焼け'});
  M.querySelectorAll('.pin').forEach(p=>p.onclick=()=>{const m=MW[+p.dataset.i];hap('pop','ぷにっ(まち)');openAv({p:m.p,n:m.l,s:'yesterday · '+m.tm,t:m.t})});
  M.querySelector('.mokp').onclick=()=>{hap('tick');toast(MO.pick>=0?'9:00 に、世界の 1枚が 決まります':'写真を 長押しで「あなたの 1枚」')};
  M.querySelectorAll('.mof').forEach(c=>{const i=+c.dataset.i;let lt=0;
    arcBindTile(c,()=>{const n=performance.now();if(n-lt<320){MO.lit.add(i);c.classList.add('lit');hap('soft','ふわっ(ひかり)',{norip:1});const s=document.createElement('i');s.className='lb';c.appendChild(s);s.animate([{transform:'scale(.2)',opacity:1},{transform:'scale(2.4)',opacity:0}],{duration:700,easing:'cubic-bezier(.2,.8,.3,1)'}).onfinish=()=>s.remove();lt=0;clearTimeout(c._t);return}
      lt=n;c._t=setTimeout(()=>{const m=MW[i];openAv({p:m.p,n:m.l,s:'yesterday · '+m.tm,t:m.t})},330)},
      ()=>{MO.pick=i;hap('heart','ドクン(あなたの 1枚)',{norip:1});setTimeout(()=>hap('success','トトトン',{norip:1}),240);toast('あなたの 1枚に えらびました ・ 24:00 まで かえられる');yMondo()})})}
renderYM=yMondo;window.yMondo=yMondo;

/* v39 レンズ */
function renderLens(){if(!$('lens'))return;const R=ORB||orbActs(),m=R.A[R.main];
  $('lnt').textContent=m.l.charAt(0)+m.l.slice(1).toLowerCase();
  $('lns').textContent=R.main==='shoot'?(3-shots)+' left today':R.main==='yday'?Math.min(shots,3)+' opened · tap to look':m.s;
  $('lfn').textContent=3-shots;$('lnic').innerHTML=OI[R.main==='yday'?'yday':R.main];$('lnt2').textContent=$('lnt').textContent;$('lns2').textContent=R.main==='shoot'?(3-shots)+' LEFT':R.main==='yday'?Math.min(shots,3)+' OPENED':m.s;$('lph').src=PH[(kept>=0?YD[kept]:YD[0]).p];
  $('lnc').innerHTML=R.sat.map(k=>{const a=R.A[k];return `<button data-k="${k}" class="${a.lock?'dis':''}">${OI[k]}${a.l.charAt(0)+a.l.slice(1).toLowerCase()}${a.dot?'<u></u>':''}</button>`}).join('');
  $('lnc').querySelectorAll('button').forEach(bt=>bt.onclick=()=>{const a=ORB.A[bt.dataset.k];hap('sel','コツッ('+a.l+')');a.run()})}
(function(){const L=$('lens');let dn=false;
  L.addEventListener('pointerdown',()=>{dn=true;L.classList.add('prs');hap('click','カチッ(絞りが しまる)')});
  const up=()=>{if(!dn)return;dn=false;L.classList.remove('prs')};['pointerleave','pointercancel'].forEach(e=>L.addEventListener(e,up));
  L.addEventListener('pointerup',()=>{if(!dn)return;up();const R=ORB||orbActs(),m=R.A[R.main];
    if(R.main==='shoot'){hap('shutter','カシャッ');const g=document.querySelector('.lnbl g');g&&g.animate([{transform:'rotate(0) scale(1)'},{transform:'rotate(40deg) scale(.55)',offset:.4},{transform:'rotate(0) scale(1)'}],{duration:380,easing:'cubic-bezier(.4,0,.2,1)'});setTimeout(()=>m.run(),280)}
    else{hap('pop','ぷにっ');setTimeout(()=>m.run(),140)}})})();
const _ro=renderOrb;renderOrb=function(){_ro();renderLens()};window.renderOrb=renderOrb;renderOrb();

/* ===== v40 今日を撮る = 地球 ===== */
(function(){const cv=$('mgl');if(!cv)return;const x=cv.getContext('2d'),N=5600,P=[];const G=Math.PI*(3-Math.sqrt(5));
  for(let i=0;i<N;i++){const y=1-(i/(N-1))*2,r=Math.sqrt(1-y*y),th=G*i;const lat=Math.asin(y),lon=Math.atan2(Math.sin(th)*r,Math.cos(th)*r);
    const land=Math.sin(lon*2.1+1.3)*Math.cos(lat*2.6)+Math.sin(lon*4.7+lat*3.1)*.55+Math.cos(lon*1.3-lat*5.2)*.35>.25;P.push({lat,lon,land,city:land&&Math.random()<.16,pin:land&&Math.random()<.012})}
  let rot=0,spd=.0016,boost=0;const R=290,cx=300,cy=300,tilt=.42;
  function draw(t){requestAnimationFrame(draw);if(!$('home').classList.contains('on'))return;rot+=spd+boost;boost*=.94;x.clearRect(0,0,600,600);
    const sun=-0.9;// 太陽の 方向(経度)
    for(const p of P){const lo=p.lon+rot;let X=Math.cos(p.lat)*Math.sin(lo),Y=Math.sin(p.lat),Z=Math.cos(p.lat)*Math.cos(lo);
      const Y2=Y*Math.cos(tilt)-Z*Math.sin(tilt),Z2=Y*Math.sin(tilt)+Z*Math.cos(tilt);if(Z2<0)continue;
      const sx=cx+X*R,sy=cy-Y2*R;if(sy>230)continue;const day=Math.cos(lo-sun)*Math.cos(p.lat);const e=.35+Z2*.65;
      if(p.pin){const pu=.6+.4*Math.sin(t/400+p.lon*9);x.fillStyle=`rgba(36,160,60,${.25*pu})`;x.beginPath();x.arc(sx,sy,7,0,6.283);x.fill();x.fillStyle='#24A03C';x.beginPath();x.arc(sx,sy,2.6,0,6.283);x.fill();continue}
      if(p.land){if(day>0){x.fillStyle=`rgba(245,240,232,${(.45+day*.55)*e})`;x.fillRect(sx-1.5,sy-1.5,3,3)}else if(p.city){x.fillStyle=`rgba(83,217,110,${.85*e})`;x.fillRect(sx-1,sy-1,2,2)}else{x.fillStyle=`rgba(245,240,232,${.16*e})`;x.fillRect(sx-1,sy-1,2,2)}}
      else{x.fillStyle=`rgba(245,240,232,${(day>0?.09:.04)*e})`;x.fillRect(sx-.6,sy-.6,1.2,1.2)}}}
  requestAnimationFrame(draw);window.mglSpin=()=>{boost=.05}})();

window.__api={renderOrb,renderArc,openAv,closeAv,openOb,closeOb,obStep,openRoom,closeRoom,rmAll,cmReset:()=>{cmHide();CMS.clear()},openGnw,closeGnw,openRvl,closeRvl,hintDbl,openY,closeY,ytab,openDvx,closeDvx,dxPlay,setDay,openFriend,closeFriend,openSheet,closeSheet,renderFriends,renderGroups,bumpBurst,askBump,FR:()=>FR,dayDone,openFreeze,playOpen,skipOpen,openSeek,homeIn,openClean,homeFocus,setShots:n=>{shots=n;renderCam();renderHome();homeFocus()},toCam,toTag,toHome,shoot,commit,reset,goShoot,setMode,goDev,playIn,playOut,state:()=>({tags,shots,cur,busy})};
if(!/noopen/.test(location.search))setTimeout(playOpen,250);else $('hmoon').classList.remove('pre');
})();