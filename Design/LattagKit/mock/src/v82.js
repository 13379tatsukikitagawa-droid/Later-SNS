
/* ================= v82(PROMPT v89)・ タグ画面の お題 ・ 音楽 ・ 前日の 写真が ひらく ・ アイコンを 大きく ================= */
const Z8RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
/* ---------- A. 今日の お題(毎日 かわる ・ その日は みんな 同じ)---------- */
const Q8=['今日は、どんな日?','今日の いちばんは?','いま、なに してる?','今日の 空は、どんな色?','今日の 気分を ひとことで','今日、ちょっと うれしかったこと','いま、だれと いる?','今日の 帰り道は?','今日の ごはん、なに?','今日、なにを 見つけた?','今日の BGM は?','いまの 机の 上は?','今日、笑ったこと','今日の 推しポイント','いま いる場所の すきな所','今日の「エモい」','今日の「なんで?」','今日 がんばったこと','今日の おやつは?','いまの 手元','今日の くつ','窓の 外は、どんな景色?','今日の ちいさな 発見','今日、言いたいことは?','今日の 天気を ひとことで','今日の 色は?','今日の「はじめて」','いま ほしいもの','今日の あなたを 1枚で','明日の 自分へ','今日の「ちょうどいい」'];
function q8Today(d){d=d||new Date();const s=new Date(d.getFullYear(),0,0),n=Math.floor((d-s)/864e5);return Q8[(n+d.getFullYear()*7)%Q8.length]}
function q8Apply(){const h=document.querySelector('#tag .th');if(!h)return;const q=q8Today();if(h.textContent!==q)h.textContent=q;h.setAttribute('aria-label','今日の お題:'+q)}
{const _e=entTag;entTag=function(){q8Apply();_e()}}
try{q8Apply()}catch(e){}

/* ---------- B. 音楽:つないだ あと = おすすめ ・ 最近 ・ ライブラリ / えらぶと 流れる ---------- */
const MU8={rec:[['放課後ライト','ミナト',0],['雨のち、すき','NAGI',2],['ゆうやけ通り','ハル',3],['いつメンのうた','4(フォー)',4],['ねむれない夜に','ソラ',5],['ひるさがり','ことり',1]],
  rc:[['ゆうやけ通り','ハル',3],['Afterschool Blue','minato',1],['ねむれない夜に','ソラ',5],['ひるさがり','ことり',1]],
  lib:[['いつメンのうた','4(フォー)',4],['放課後ライト','ミナト',0],['Midnight Soft','sora',5],['雨のち、すき','NAGI',2],['Hiru no Sora','kotori',1],['Yuyake Dori','haru',3],['ゆうやけ通り','ハル',3]],
  tab:'rec',pick:null,play:null,t0:0,raf:0,vol:1};
const MU8C=['linear-gradient(135deg,#61D278,#EE5E9C)','linear-gradient(135deg,#9ED8FF,#9B8CFF)','linear-gradient(135deg,#C8F25A,#18FA45)','linear-gradient(135deg,#63DC7B,#FFD25A)','linear-gradient(135deg,#B28CFF,#F27CC0)','linear-gradient(135deg,#5AC8FF,#2A3A8A)'];
/* モック だけ:曲の かわりに 小さな 和音を 鳴らす(本番は 30秒の プレビュー)*/
const MU8A={ctx:null,iv:0,g:null};
function mu8Sound(k,on){try{if(MU8A.iv){clearInterval(MU8A.iv);MU8A.iv=0}if(MU8A.g){const g=MU8A.g;g.gain.setTargetAtTime(0,MU8A.ctx.currentTime,.15);MU8A.g=null}
  if(!on)return;const C=MU8A.ctx||(MU8A.ctx=new (window.AudioContext||window.webkitAudioContext)());C.resume&&C.resume();const G=C.createGain();G.gain.value=0;G.gain.setTargetAtTime(.07*MU8.vol,C.currentTime,.3);G.connect(C.destination);MU8A.g=G;
  const root=[57,60,62,55,64,59][k%6],prog=[[0,4,7],[-3,0,4],[5,9,12],[7,11,14]];let step=0;const f=m=>440*Math.pow(2,(m-69)/12);
  const beat=()=>{const ch=prog[Math.floor(step/4)%4],t=C.currentTime;const n=ch[step%3];const o=C.createOscillator(),e=C.createGain();o.type='triangle';o.frequency.value=f(root+n+12*(step%4===3?1:0));e.gain.setValueAtTime(0,t);e.gain.linearRampToValueAtTime(1,t+.02);e.gain.exponentialRampToValueAtTime(.001,t+.6);o.connect(e);e.connect(G);o.start(t);o.stop(t+.65);
    if(step%4===0){const b=C.createOscillator(),be=C.createGain();b.type='sine';b.frequency.value=f(root+ch[0]-12);be.gain.setValueAtTime(.8,t);be.gain.exponentialRampToValueAtTime(.001,t+1);b.connect(be);be.connect(G);b.start(t);b.stop(t+1.05)}step++};
  beat();MU8A.iv=setInterval(beat,260)}catch(e){}}
function mu8All(){return[].concat(MU8.rec,MU8.rc,MU8.lib)}
function mu8Row(s,src){const on=MU8.pick&&MU8.pick[0]===s[0],pl=MU8.play&&MU8.play[0]===s[0];
  return `<button class="mu8r${on?' on':''}${pl?' pl':''}" data-n="${s[0]}" data-src="${src}"><i style="background:${MU8C[s[2]]}"><u><s></s><s></s><s></s></u></i><span><b>${s[0]}</b><small>${s[1]}</small></span><em aria-hidden="true">${pl?'<svg viewBox="0 0 24 24"><rect x="7" y="6" width="3.6" height="12" rx="1"/><rect x="13.4" y="6" width="3.6" height="12" rx="1"/></svg>':'<svg viewBox="0 0 24 24"><path d="M8 5.5v13l11-6.5z"/></svg>'}</em></button>`}
function mu8Body(){const q=(MU8.q||'').trim().toLowerCase();
  if(q){const seen={},L=mu8All().filter(s=>{if(seen[s[0]])return false;seen[s[0]]=1;return (s[0]+' '+s[1]).toLowerCase().includes(q)});return `<div class="mu8h">「${MU8.q}」</div>`+(L.length?L.map(s=>mu8Row(s,'q')).join(''):'<p class="mu8no">見つかりませんでした</p>')}
  if(MU8.tab==='rec')return `<div class="mu8h">あなたへの おすすめ</div><div class="mu8big">${MU8.rec.slice(0,4).map(s=>`<button class="mu8c${MU8.pick&&MU8.pick[0]===s[0]?' on':''}${MU8.play&&MU8.play[0]===s[0]?' pl':''}" data-n="${s[0]}"><i style="background:${MU8C[s[2]]}"><u><s></s><s></s><s></s></u></i><b>${s[0]}</b><small>${s[1]}</small></button>`).join('')}</div><div class="mu8h">いま 人気</div>${MU8.rec.slice(2).map(s=>mu8Row(s,'rec')).join('')}`;
  if(MU8.tab==='rc')return `<div class="mu8h">最近 聴いた 曲</div>${MU8.rc.map(s=>mu8Row(s,'rc')).join('')}`;
  return `<div class="mu8h">ライブラリ ・ 曲</div>${MU8.lib.map(s=>mu8Row(s,'lib')).join('')}`}
function mu8Draw(){const S=$('mu8');if(!S)return;S.querySelector('.mu8b').innerHTML=mu8Body();S.querySelector('.mu8sg').dataset.t=MU8.tab;S.querySelectorAll('.mu8sg button').forEach(b=>b.classList.toggle('on',b.dataset.t===MU8.tab));
  S.querySelectorAll('.mu8r,.mu8c').forEach(r=>r.onclick=()=>{const s=mu8All().find(x=>x[0]===r.dataset.n);if(!s)return;
    if(MU8.pick&&MU8.pick[0]===s[0]&&MU8.play&&MU8.play[0]===s[0]){mu8Stop();hap('soft',null,{norip:1})}else{MU8.pick=s;mu8Start(s);hap('sel','コツッ(えらぶ ・ 流れる)')}mu8Draw();mu8Bar()});mu8Bar()}
function mu8Start(s){MU8.play=s;MU8.t0=performance.now();mu8Sound(s[2],true);cancelAnimationFrame(MU8.raf);const f=()=>{const S=$('mu8'),p=S&&S.querySelector('.mu8pp i');if(!MU8.play)return;const k=((performance.now()-MU8.t0)/30000)%1;p&&(p.style.width=(k*100).toFixed(1)+'%');MU8.raf=requestAnimationFrame(f)};MU8.raf=requestAnimationFrame(f)}
function mu8Stop(){MU8.play=null;mu8Sound(0,false);cancelAnimationFrame(MU8.raf);mu8Chip()}
function mu8Bar(){const S=$('mu8');if(!S)return;const B=S.querySelector('.mu8ft'),s=MU8.pick;B.classList.toggle('on',!!s);
  if(s){B.querySelector('.mu8m i').style.background=MU8C[s[2]];B.querySelector('.mu8m b').textContent=s[0];B.querySelector('.mu8m small').textContent=s[1]+(MU8.play?' ・ プレビュー':'');B.querySelector('.mu8m').classList.toggle('pl',!!MU8.play)}
  const g=S.querySelector('.mu8go');g.disabled=!s;g.textContent=s?'この曲にする':'曲を えらんでください'}
function mu8Open(){let S=$('mu8');const con=!!MU8.con;
  if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="mu8" id="mu8" role="dialog" aria-label="今日の 1曲"></section>');S=$('mu8')}
  S.innerHTML=`<i class="mu8bk" data-a="x"></i><div class="mu8s"><div class="mu8gr" data-a="drag"><i></i></div>
   <div class="mu8t"><b>今日の 1曲</b><span class="mu8sv">${con?'<i></i>Apple Music':''}</span></div>
   ${con?`<label class="mu8q"><svg viewBox="0 0 24 24"><circle cx="11" cy="11" r="6.5"/><path d="M16 16l4 4"/></svg><input id="mu8in" placeholder="曲名 ・ アーティスト" autocomplete="off" value="${MU8.q||''}"></label>
   <div class="mu8sg" data-t="${MU8.tab}"><i></i><button data-t="rec">おすすめ</button><button data-t="rc">最近</button><button data-t="lib">ライブラリ</button></div>
   <div class="mu8b"></div>
   <div class="mu8ft"><div class="mu8m"><i><u><s></s><s></s><s></s></u></i><span><b></b><small></small></span><em class="mu8pp"><i></i></em></div>${MSEL?'<button class="mu8rm" data-a="rm">はずす</button>':''}<button class="mu8go" disabled>曲を えらんでください</button></div>`
   :`<div class="mu8cn"><div class="mu8cd"><i class="a"></i><i class="b"></i><i class="c"></i></div><b>今日の 写真に、1曲</b><p>友だちが 写真を ひらくと、この曲が 流れます</p><button class="mu8con" data-a="con"><svg viewBox="0 0 24 24"><path d="M9 17.5V6.2l10-2v11.3"/><circle cx="6.8" cy="17.6" r="2.6"/><circle cx="16.8" cy="15.6" r="2.6"/></svg>Apple Music と つなぐ</button><small>ライブラリと 再生の 記録を つかって、おすすめを 出します</small></div>`}</div>`;
  const cl=()=>mu8Close();S.querySelectorAll('[data-a="x"]').forEach(b=>b.onclick=cl);
  const cb=S.querySelector('[data-a="con"]');cb&&(cb.onclick=()=>{hap('pop','ぷにっ(つなぐ)');cb.classList.add('ld');cb.textContent='つないで います…';setTimeout(()=>{MU8.con=true;hap('success','トトトン(つながった)');mu8Open()},900)});
  const rm=S.querySelector('[data-a="rm"]');rm&&(rm.onclick=()=>{MSEL=null;MU8.pick=null;mu8Stop();setMus();mu8Chip();hap('soft','ふわっ(はずす)');cl()});
  S.querySelectorAll('.mu8sg button').forEach(b=>b.onclick=()=>{if(MU8.tab===b.dataset.t)return;MU8.tab=b.dataset.t;MU8.q='';const i=$('mu8in');i&&(i.value='');hap('sel','コツッ(タブ)');mu8Draw();const bd=S.querySelector('.mu8b');bd&&!Z8RM()&&bd.animate([{opacity:0,transform:'translateY(8px)'},{opacity:1,transform:'none'}],{duration:260,easing:'cubic-bezier(.2,.9,.25,1)'})});
  const inp=$('mu8in');inp&&(inp.oninput=()=>{MU8.q=inp.value;mu8Draw()});
  const go=S.querySelector('.mu8go');go&&(go.onclick=()=>{const s=MU8.pick;if(!s)return;let i=MUS.am.findIndex(x=>x[0]===s[0]);if(i<0){MUS.am.push([s[0],s[1]]);i=MUS.am.length-1}
    MCO[i]=MU8C[s[2]];MSEL={s:'am',i};setMus();hap('success','やさしく2回(きまった)');if(!MU8.play)mu8Start(s);MU8.vol=1;mu8Close(true);mu8Chip();try{_toast('♪ '+s[0]+' を つけました')}catch(e){}});
  const H=S.querySelector('.mu8s');let y0=0,dy=0,dr=false;S.querySelectorAll('[data-a="drag"]').forEach(g=>{g.onpointerdown=e=>{dr=true;y0=e.clientY;dy=0;try{g.setPointerCapture(e.pointerId)}catch(_){}H.style.transition='none'};g.onpointermove=e=>{if(!dr)return;dy=Math.max(0,e.clientY-y0);H.style.transform=`translateY(${dy}px)`};g.onpointerup=g.onpointercancel=()=>{if(!dr)return;dr=false;H.style.transition='';H.style.transform='';if(dy>110)cl()}});
  if(con){MU8.pick=MU8.pick||(MSEL?mu8All().find(x=>x[0]===MUS[MSEL.s][MSEL.i][0])||null:null);mu8Draw()}
  void S.offsetWidth;S.classList.add('on');hap('pop','ぷにっ(音楽)')}
function mu8Close(keep){const S=$('mu8');if(!S)return;S.classList.remove('on');if(!keep&&!MSEL)mu8Stop();else if(!keep&&MSEL){const s=MUS[MSEL.s][MSEL.i];if(!MU8.play||MU8.play[0]!==s[0])mu8Stop()}mu8Chip()}
/* タグ画面の 音楽の チップ:流れて いる 間は 波が 動く ・ 押すと とめる / ながす ・ 長押しで えらびなおす */
function mu8Chip(){const b=$('msc');if(!b)return;b.classList.toggle('mu8on',!!(MSEL&&MU8.play));b.classList.toggle('mu8ps',!!(MSEL&&!MU8.play))}
(()=>{const b=$('msc');if(!b)return;let lp=0,lng=false;b.onclick=null;
  b.addEventListener('pointerdown',()=>{lng=false;lp=setTimeout(()=>{lng=true;hap('pop');mu8Open()},450)});
  b.addEventListener('pointerup',()=>{clearTimeout(lp)});b.addEventListener('pointerleave',()=>clearTimeout(lp));
  b.addEventListener('click',e=>{e.stopImmediatePropagation();if(lng)return;if(!MSEL){mu8Open();return}const s=mu8All().find(x=>x[0]===MUS[MSEL.s][MSEL.i][0])||[MUS[MSEL.s][MSEL.i][0],MUS[MSEL.s][MSEL.i][1],MSEL.i%6];
    if(MU8.play){mu8Stop();hap('soft','ふわっ(とめる)')}else{MU8.pick=s;mu8Start(s);hap('tick','コツ(ながす)')}mu8Chip()},true)})();
/* 撮影画面へ 行っても 小さく 流れる ・ Home へ もどったら とまる */
{const _c=toCam;toCam=function(){_c();if(MU8.play){MU8.vol=.45;try{MU8A.g&&MU8A.g.gain.setTargetAtTime(.07*.45,MU8A.ctx.currentTime,.3)}catch(e){}}}}
{const _h=toHome;toHome=function(){_h();if(MU8.play)mu8Stop()}}

/* ---------- C. 前日の 写真が ひらく(しぼりが ひらく → 光から 現像)+ 1回 タップで 大きく ---------- */
const RV8={on:false,n:1,cnt:1,i:0,done:false,t:[],raf:0};
const RV8P=['d','b','a','e','c','f'],RV8T=['18:42','12:17','20:34'],RV8G=['#夕焼け','#放課後','#帰り道'],RV8L=['鎌倉市','藤沢市','武蔵野市'];
function rv8T(f,ms){RV8.t.push(setTimeout(()=>{if(RV8.on)f()},ms))}
function rv8Iris(r,Rm,tw,ring){const c=document.querySelector('#rv8 .rv8ir');if(!c)return;const x=c.getContext('2d'),W=300,H=400,cx=150,cy=200,n=7,R=262;x.setTransform(2,0,0,2,0,0);x.clearRect(0,0,W,H);
  if(Rm>=R){return}
  x.fillStyle='#0B0C0D';x.fillRect(0,0,W,H);
  x.save();x.beginPath();x.arc(cx,cy,Rm,0,7);x.clip();x.clearRect(0,0,W,H);
  r=Math.max(.6,r);const V=[];for(let k=0;k<n;k++){const a=tw+k*2*Math.PI/n;V.push([cx+r*Math.cos(a),cy+r*Math.sin(a)])}
  for(let k=0;k<n;k++){const a=V[k],b=V[(k+1)%n];let dx=b[0]-a[0],dy=b[1]-a[1];const L=Math.hypot(dx,dy)||1;dx/=L;dy/=L;const mx=(a[0]+b[0])/2-cx,my=(a[1]+b[1])/2-cy;let ox=mx-(mx*dx+my*dy)*dx,oy=my-(mx*dx+my*dy)*dy;const ol=Math.hypot(ox,oy)||1;ox/=ol;oy/=ol;
    const E=2*R;x.beginPath();x.moveTo(a[0],a[1]);x.lineTo(a[0]+dx*E,a[1]+dy*E);x.lineTo(a[0]+dx*E+ox*E,a[1]+dy*E+oy*E);x.lineTo(a[0]+ox*E,a[1]+oy*E);x.closePath();
    const g=x.createLinearGradient(a[0],a[1],a[0]+ox*120,a[1]+oy*120);g.addColorStop(0,k%2?'#26282C':'#2E3035');g.addColorStop(1,'#0E0F11');x.fillStyle=g;x.fill();
    x.beginPath();x.moveTo(a[0],a[1]);x.lineTo(a[0]+dx*E,a[1]+dy*E);x.strokeStyle='rgba(255,255,255,.16)';x.lineWidth=1;x.stroke()}
  x.restore();
  if(ring>0){x.beginPath();x.arc(cx,cy,Rm-1,0,7);x.strokeStyle=`rgba(200,242,90,${(.9*ring).toFixed(2)})`;x.lineWidth=2.5;x.shadowColor='rgba(200,242,90,.8)';x.shadowBlur=14*ring;x.stroke();x.shadowBlur=0}}
function rv8Dev(e){const im=document.querySelector('#rv8 .rv8ph img');if(!im)return;const q=Math.max(0,Math.min(1,e));
  im.style.filter=`brightness(${(3.2-2.2*q).toFixed(3)}) saturate(${(1.05*q).toFixed(3)}) contrast(${(.6+.4*q).toFixed(3)}) blur(${(16*(1-q)).toFixed(2)}px)`;im.style.transform=`scale(${(1.08-.08*q).toFixed(4)})`}
function rv8Open(n,rare,cnt){if(RV8.on)return;RV8.on=true;RV8.n=n||1;RV8.cnt=cnt||RV8.cnt||1;RV8.rare=!!rare;RV8.done=false;RV8.t.forEach(clearTimeout);RV8.t=[];
  let S=$('rv8');if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="rv8" id="rv8" aria-label="きのうの 写真が ひらく"></section>');S=$('rv8')}
  const k=(RV8.n-1)%3,p=RV8P[k],y=new Date(Date.now()-864e5);
  S.className='rv8'+(rare?' rare':'');
  S.innerHTML=`<i class="rv8bg"></i><div class="rv8hd"><small>YESTERDAY ・ ${y.getMonth()+1}/${y.getDate()}</small><div class="rv8dt">${Array.from({length:RV8.cnt},(_,i)=>`<i class="${i<RV8.i?'d':i===RV8.i?'on':''}"></i>`).join('')}</div></div>
   <div class="rv8st"><button class="rv8cd" aria-label="大きく 見る"><div class="rv8ph"><img src="${PH[p]}" alt=""><i class="rv8lk"></i></div><canvas class="rv8ir" width="600" height="800"></canvas>
    <span class="rv8tm">${RV8T[k]}</span><span class="rv8tg">${RV8G[k]}</span>${rare?'<b class="rv8rr">RARE</b>':''}</button></div>
   <p class="rv8hi"><svg viewBox="0 0 24 24"><path d="M15 4h5v5M9 20H4v-5M20 4l-6 6M4 20l6-6"/></svg>タップで 大きく</p>
   <div class="rv8ac"><button class="rv8y">友だちに 公開</button><button class="rv8n">自分だけ</button></div>
   <div class="rv8fv" aria-hidden="true"><div class="rv8fz"><img src="${PH[p]}" alt=""></div><i class="rv8fs"></i>
    <div class="rv8fh"><button data-a="fx" aria-label="とじる"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button><span><b>${RV8T[k]}</b><small>${RV8L[k]} ・ きのう</small></span><i></i></div>
    <div class="rv8ff"><div class="rv8fg"><span>${RV8G[k]}</span>${rare?'<span class="r">RARE</span>':''}</div><div class="rv8ac2"><button class="rv8y">友だちに 公開</button><button class="rv8n">自分だけ</button></div></div></div>`;
  S.classList.add('on');S.setAttribute('aria-hidden','false');hap('soft','ふわっ(暗室)');
  const C=S.querySelector('.rv8cd');rv8Dev(0);rv8Iris(0,150,0,0);
  const fin=()=>{if(RV8.done)return;RV8.done=true;RV8.t.forEach(clearTimeout);RV8.t=[];cancelAnimationFrame(RV8.raf);rv8Iris(999,999,0,0);rv8Dev(1);S.classList.add('dn');
    hap('heart','ドクン(ひらいた)');!Z8RM()&&S.querySelector('.rv8tg').animate([{transform:'scale(2.6) rotate(-30deg)',opacity:0},{transform:'scale(.9) rotate(9deg)',opacity:1,offset:.6},{transform:'scale(1) rotate(6deg)',opacity:1}],{duration:460,delay:120,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'both'});
    setTimeout(()=>RV8.on&&hap('pop','ぷにっ(タグ)'),260);if(RV8.rare)setTimeout(()=>RV8.on&&hap('thud','ドン(RARE)'),520)};
  if(Z8RM()){fin();return}
  /* 0 〜 0.6秒:しぼりが とじて いる ・ 黄緑の 輪が 光る */
  C.animate([{transform:'translateY(30px) scale(.94)',opacity:0},{transform:'none',opacity:1}],{duration:520,easing:'cubic-bezier(.2,.9,.25,1)'});
  let rg=0;const t0=performance.now();
  const loop=ts=>{if(!RV8.on||RV8.done)return;const t=ts-t0;
    const ring=t<600?Math.min(1,t/300):Math.max(0,1-(t-1150)/300);
    const o=Math.max(0,Math.min(1,(t-600)/600)),oe=1-Math.pow(1-o,3);
    const m=Math.max(0,Math.min(1,(t-1150)/300)),me=m*m*(3-2*m);
    rv8Iris(me>0?Math.max(oe*150*1.12,(150+me*120)*1.12):oe*150*1.12,150+me*120,oe*.75,ring);
    const d=Math.max(0,Math.min(1,(t-1100)/1500));rv8Dev(1-Math.pow(1-d,2.2));
    if(t>1100){const tk=Math.floor(d*6);if(tk>rg){rg=tk;hap('tick',null,{norip:1})}}
    if(t>=2650){fin();return}RV8.raf=requestAnimationFrame(loop)};
  RV8.raf=requestAnimationFrame(loop);
  rv8T(()=>hap('shutter','カシャッ(しぼりが ひらく)'),600);
  rv8T(()=>{const L=S.querySelector('.rv8lk');L&&L.animate([{transform:'translateX(-120%) skewX(-16deg)',opacity:0},{opacity:RV8.rare?1:.75,offset:.3},{transform:'translateX(160%) skewX(-16deg)',opacity:0}],{duration:1100,easing:'cubic-bezier(.4,0,.2,1)'})},1400);
  /* とちゅうで タップ = すぐ さいごへ */
  C.onclick=()=>{if(!RV8.done){fin();return}rv8Full(true)};
  S.querySelectorAll('.rv8y').forEach(b=>b.onclick=()=>rv8Pick(true));S.querySelectorAll('.rv8n').forEach(b=>b.onclick=()=>rv8Pick(false));
  S.querySelector('[data-a="fx"]').onclick=()=>rv8Full(false);
  /* 全画面:2回 タップで 2倍 ・ 下へ ひっぱって とじる */
  const F=S.querySelector('.rv8fv'),Z=S.querySelector('.rv8fz');let lt=0,zm=false,y0=0,dy=0,dr=false;
  Z.addEventListener('pointerdown',e=>{dr=true;y0=e.clientY;dy=0;try{Z.setPointerCapture(e.pointerId)}catch(_){}});
  Z.addEventListener('pointermove',e=>{if(!dr||zm)return;dy=Math.max(0,(e.clientY-y0)/SC);Z.style.transform=`translateY(${dy}px) scale(${(1-dy/1600).toFixed(3)})`;F.style.setProperty('--fa',(1-dy/500).toFixed(2))});
  Z.addEventListener('pointerup',e=>{dr=false;if(dy>110){rv8Full(false);return}Z.style.transform='';F.style.setProperty('--fa',1);
    const n=performance.now();if(dy<6&&n-lt<320){lt=0;zm=!zm;const r=Z.getBoundingClientRect(),ox=(e.clientX-r.left)/r.width*100,oy=(e.clientY-r.top)/r.height*100;const I=Z.querySelector('img');I.style.transformOrigin=`${ox}% ${oy}%`;I.style.transform=zm?'scale(2.2)':'';hap('tick')}else lt=n;dy=0})}
function rv8Full(on){const S=$('rv8');if(!S)return;const F=S.querySelector('.rv8fv'),C=S.querySelector('.rv8cd');
  if(on){const a=C.getBoundingClientRect(),b=S.getBoundingClientRect();F.style.setProperty('--fa',1);F.classList.add('on');F.setAttribute('aria-hidden','false');hap('pop','ぷにっ(大きく)');
    if(!Z8RM()){const sx=a.width/b.width,sy=a.height/b.height,tx=(a.left-b.left)/SC,ty=(a.top-b.top)/SC;const Z=F.querySelector('.rv8fz');
      Z.animate([{transform:`translate(${tx}px,${ty}px) scale(${sx},${sy})`,borderRadius:'26px'},{transform:'none',borderRadius:'0px'}],{duration:480,easing:'cubic-bezier(.2,.9,.25,1)'});
      F.querySelectorAll('.rv8fh,.rv8ff').forEach((e,i)=>e.animate([{opacity:0,transform:`translateY(${i?18:-12}px)`},{opacity:1,transform:'none'}],{duration:360,delay:240,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}))}}
  else{const Z=F.querySelector('.rv8fz');Z.style.transform='';const I=Z.querySelector('img');I.style.transform='';
    if(!Z8RM()){const a=C.getBoundingClientRect(),b=S.getBoundingClientRect();const sx=a.width/b.width,sy=a.height/b.height,tx=(a.left-b.left)/SC,ty=(a.top-b.top)/SC;
      Z.animate([{transform:'none',borderRadius:'0px'},{transform:`translate(${tx}px,${ty}px) scale(${sx},${sy})`,borderRadius:'26px'}],{duration:380,easing:'cubic-bezier(.4,0,.2,1)'}).onfinish=()=>{F.classList.remove('on')};F.style.setProperty('--fa',0)}
    else F.classList.remove('on');F.setAttribute('aria-hidden','true');hap('soft',null,{norip:1})}}
function rv8Pick(pub){const S=$('rv8');if(!S||!RV8.done)return;const C=S.querySelector('.rv8cd'),F=S.querySelector('.rv8fv');F.classList.remove('on');
  hap(pub?'success':'soft',pub?'トトトン(公開)':'ふわっ(自分だけ)');
  const next=()=>{RV8.on=false;if(RV8.i+1<RV8.cnt){RV8.i++;rv8Open(RV8.n+1,false,RV8.cnt)}else{RV8.i=0;RV8.cnt=1;S.classList.remove('on');S.setAttribute('aria-hidden','true')}};
  try{_toast(pub?'公開しました ・ 友だちの きのうに ならびます':'自分だけ ・ ME に のこります')}catch(e){}
  if(Z8RM()){next();return}
  C.animate(pub?[{transform:'none',opacity:1},{transform:'translateY(-40px) scale(.96) rotate(-2deg)',opacity:1,offset:.35},{transform:'translateY(-520px) scale(.7) rotate(4deg)',opacity:0}]:[{transform:'none',opacity:1},{transform:'translateY(380px) scale(.5)',opacity:0}],{duration:620,easing:'cubic-bezier(.5,0,.2,1)',fill:'forwards'}).onfinish=next}
/* 古い 現像(モザイク ・ ふって 現像)→ 新しい 形へ */
try{openRvl=function(n,rare){rv8Open(n,rare,1)}}catch(e){}
Object.assign(window.__kit||(window.__kit={}),{rv8:(o={})=>{RV8.i=0;rv8Open(o.n||1,!!o.rare,o.cnt||1)},rv8At:ms=>{const S=$('rv8');if(!S)return;RV8.done=true;RV8.t.forEach(clearTimeout);cancelAnimationFrame(RV8.raf);const t=ms;
    const ring=t<600?Math.min(1,t/300):Math.max(0,1-(t-1150)/300),o=Math.max(0,Math.min(1,(t-600)/600)),oe=1-Math.pow(1-o,3),m=Math.max(0,Math.min(1,(t-1150)/300)),me=m*m*(3-2*m),d=Math.max(0,Math.min(1,(t-1100)/1500));
    rv8Iris(me>0?Math.max(oe*150*1.12,(150+me*120)*1.12):oe*150*1.12,150+me*120,oe*.75,ring);rv8Dev(1-Math.pow(1-d,2.2));S.getAnimations({subtree:true}).forEach(a=>a.finish())},
  rv8Full:()=>rv8Full(true),mu8:o=>{if(o&&o.con)MU8.con=true;if(o&&o.tab)MU8.tab=o.tab;if(o&&o.pick){MU8.pick=mu8All().find(x=>x[0]===o.pick)||null}mu8Open();if(o&&o.pick&&MU8.pick){MU8.play=MU8.pick;mu8Draw()}},mu8Off:()=>{mu8Sound(0,false)},
  mu8Set:name=>{MU8.con=true;const s=mu8All().find(x=>x[0]===name)||MU8.rec[0];let i=MUS.am.findIndex(x=>x[0]===s[0]);if(i<0){MUS.am.push([s[0],s[1]]);i=MUS.am.length-1}MCO[i]=MU8C[s[2]];MSEL={s:'am',i};MU8.pick=s;MU8.play=s;setMus();mu8Chip()},q8:()=>q8Today()});

/* ---------- D. yesterday と Home の アイコンを 大きく(56)---------- */
/* CSS のみ */

/* モック だけ:デモボタン */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-x82]'))return;
  C.insertAdjacentHTML('beforeend',[['rv','ひらく(新)'],['rv2','ひらく:2枚'],['mu','音楽(つないだ あと)']].map(([k,t])=>`<button data-x82="${k}">${t}</button>`).join(''));
  C.querySelectorAll('[data-x82]').forEach(b=>b.onclick=()=>{const k=b.dataset.x82;
    if(k==='rv')__kit.rv8({n:1});if(k==='rv2')__kit.rv8({n:1,cnt:2});
    if(k==='mu'){try{if(cur!=='tag'){const x=[...document.querySelectorAll('#ctl button')].find(b=>b.dataset.c==='tag');x&&x.click()}}catch(e){}setTimeout(()=>__kit.mu8({con:true}),900)}})})();
