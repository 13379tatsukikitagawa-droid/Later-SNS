/* ===== v90(モック v91 ・ PROMPT v100):アプリ ぜんたいに バイブ =====
   1. 新しい バイブ 5つ:notch(きざみ)・ edge(はじ)・ stretch(のびる)・ knock(かぎ)・ sig(Lattag の サイン)
   2. スクロール:区切りを こえる たび カリッ ・ かぎの 区切りは コツコツ ・ はじに 当たると コン ・ はやい スクロールは だまる
   3. はじを こえて ひっぱる:ググッ(のびる)→ はなすと ふわっ
   4. Home の 横スライド:指で 引いて いる 間、半分を こえたら コツッ(はなすと つぎへ)
   5. Mondo の 地球:指で まわせる ・ 15° ごとに カリッ(なげると だんだん ゆっくり)
   6. 「ひらくまで」を 長押し:1秒ごとに 時間を さわれる(分が かわると カチッ)
   7. 9:00 / 24:00 の 10秒 前:カウントダウン → 9:00 = ドクン + トトトン / 24:00 = ドン
   8. Lattag の 字を タップ:サイン「ラ・タッ・グ」
   9. 設定:バイブ しっかり / ひかえめ / オフ */
HP.notch={v:[5],a:.22,l:'カリッ(きざみ)'};HP.edge={v:[14],a:.45,l:'コン(はじ)'};HP.stretch={v:[9],a:.3,l:'ググッ(のびる)'};
HP.knock={v:[8,62,8],a:.4,l:'コツコツ(かぎ)',seq:[70]};HP.sig={v:[18,90,10,50,26],a:.8,l:'ラ・タッ・グ(Lattag)',seq:[110,180]};
const H9={log:[],lv:'std',sc:new WeakMap(),hp:null,gk:null,gd:null,beat:0};const H9DEC=new Set(['notch','tick','soft','stretch','edge','knock']);
const H9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
/* ---- 0. 強さの 設定(しっかり / ひかえめ / オフ)---- */
{const _h=hap;hap=function(n,why,o){if(H9.lv==='off')return;if(H9.lv==='low'&&H9DEC.has(n))return;if(n==='tick'&&why&&/街が かわった/.test(why)&&(H9.gd||Math.abs((typeof MN!=='undefined'&&MN.boost)||0)>.006))return;H9.lt=performance.now();H9.log.push(n+(why?':'+why:''));if(H9.log.length>300)H9.log.shift();return _h(n,why,o)};window.hap=hap}

/* ---- 1. スクロール(どの 画面でも 同じ きまり)---- */
const H9SKIP=['#wkst','#hpt','.z9 *','.tw8m','.mql'];const H9NM={arc:'Today',afc:'Friends',aact:'Active',ayh:'Yesterday',ayg:'グループ',amd:'Mondo',aal:'Albums',otd:'On this day',tdv:'今日の フィルム',dusk:'夕方'};
function h9Kids(t,hz){const R=t.getBoundingClientRect(),out=[],V=hz?t.clientWidth:t.clientHeight;
  const add=(P,d)=>{for(const c of P.children){if(c.offsetParent===null)continue;const r=c.getBoundingClientRect(),sz=hz?r.width:r.height;if(sz<40)continue;
    if(sz>V*.9&&d<3&&c.children.length>1){add(c,d+1);continue}out.push({el:c,s:hz?r.left-R.left+t.scrollLeft:r.top-R.top+t.scrollTop})}};add(t,0);out.sort((a,b)=>a.s-b.s);return out}
function h9Idx(K,line){let k=-1;for(let i=0;i<K.length;i++)if(K[i].s<=line)k=i;return k}
function h9Name(el){return H9NM[el.id]||(el.getAttribute('aria-label')||'').slice(0,12)||((el.querySelector('b,h2,h3,small')||{}).textContent||'').trim().slice(0,10)}
document.addEventListener('scroll',e=>{const t=e.target;if(!(t instanceof Element)||!t.closest('#phone')||H9SKIP.some(s=>t.matches(s)))return;
  const hz=t.scrollWidth-t.clientWidth>t.scrollHeight-t.clientHeight+4,pos=hz?t.scrollLeft:t.scrollTop,max=hz?t.scrollWidth-t.clientWidth:t.scrollHeight-t.clientHeight,now=performance.now();
  let S=H9.sc.get(t);const line=pos+(hz?t.clientWidth*.5:t.clientHeight*.35);
  if(!S){S={p:pos,t:now,K:h9Kids(t,hz),kt:now,edge:1,mv:0};S.k=h9Idx(S.K,line);H9.sc.set(t,S);return}
  if(now-S.kt>1500){S.K=h9Kids(t,hz);S.kt=now}
  const v=(pos-S.p)/Math.max(1,now-S.t);S.p=pos;S.t=now;S.mv=1;
  const k=h9Idx(S.K,line);if(k!==S.k){const dn=k>S.k,el=(S.K[dn?k:S.k]||{}).el;S.k=k;
    if(el&&Math.abs(v)<2.4){const nm=h9Name(el);el.classList.contains('lk')?hap('knock',`コツコツ(かぎ ・ ${nm})`,{norip:1,gap:120}):hap('notch',`カリッ(${nm||'つぎ'})`,{norip:1,gap:55})}}
  if((pos<=0||pos>=max-1)&&!S.edge&&Math.abs(v)>.45){S.edge=1;hap('edge','コン(はじ)',{norip:1,gap:400})}
  if(pos>24&&pos<max-24)S.edge=0;
  clearTimeout(S.end);if(hz)S.end=setTimeout(()=>{if(S.mv){S.mv=0;hap('sel','コツッ(とまった)',{norip:1,gap:200})}},140)},true);
/* ---- 2. はじを こえて ひっぱる(モックは マウスの ホイール / 実機は ScrollView の はみ出し)---- */
document.addEventListener('wheel',e=>{const p=$('phone');if(!p||!p.contains(e.target))return;let t=e.target;while(t&&t!==p){const s=getComputedStyle(t);if(/(auto|scroll)/.test(s.overflowY)&&t.scrollHeight>t.clientHeight+4)break;t=t.parentElement}
  if(!t||t===p||Math.abs(e.deltaX)>Math.abs(e.deltaY))return;const top=t.scrollTop<=0&&e.deltaY<0,bot=t.scrollTop>=t.scrollHeight-t.clientHeight-1&&e.deltaY>0;if(!top&&!bot)return;
  const S=H9.pl||(H9.pl={a:0,n:0});S.a+=Math.abs(e.deltaY);const n=Math.min(3,Math.floor(S.a/90));if(n>S.n){S.n=n;hap('stretch',`ググッ(のびる ${n}/3)`,{norip:1});if(!H9RM()){t.style.transition='transform .12s';t.style.transform=`translateY(${(top?1:-1)*n*7}px)`}}
  clearTimeout(S.tm);S.tm=setTimeout(()=>{if(S.n){hap('soft','ふわっ(もどる)',{norip:1});t.style.transition='transform .42s cubic-bezier(.3,1.5,.5,1)';t.style.transform=''}H9.pl=null},260)},{passive:true,capture:true});

/* ---- 3. Home の 横スライド:半分を こえたら コツッ ---- */
{const _l=hpLayout;hpLayout=function(px){_l(px);const T=$('hpg');if(!T||!T.classList.contains('drg'))return;const r=Math.max(0,Math.min(HPK.length-1,Math.round(-px/390)));if(H9.hp===null)H9.hp=HPG.i;
  if(r!==H9.hp){H9.hp=r;hap('sel',`コツッ(はなすと ${['Camera','Friends','Trip','Mondo'][r]||''} へ)`,{norip:1,gap:80})}}}
{const _g=hpGo;hpGo=function(i,v){_g(i,v);H9.hp=null}}

/* ---- 4. Mondo の 地球:指で まわす ・ 15° ごとに カリッ ---- */
document.addEventListener('pointerdown',e=>{const g=e.target.closest&&e.target.closest('#mng');if(!g||e.button)return;e.stopPropagation();H9.gd={x:e.clientX,t:performance.now(),v:0,m:0};hap('soft','そっと(地球を つかむ)',{norip:1})},true);
document.addEventListener('pointermove',e=>{const d=H9.gd;if(!d)return;e.stopPropagation();const now=performance.now(),dx=(e.clientX-d.x)/(typeof SC!=='undefined'?SC:1);d.x=e.clientX;d.m+=Math.abs(dx);
  try{MN.rot+=dx*.0065;MN.last=''}catch(_){}d.v=d.v*.6+(dx/Math.max(1,now-d.t))*.4;d.t=now},true);
['pointerup','pointercancel'].forEach(n=>document.addEventListener(n,e=>{const d=H9.gd;if(!d)return;e.stopPropagation();H9.gd=null;if(d.m>6){H9.eat=1;setTimeout(()=>H9.eat=0,60);try{MN.boost=Math.max(-.12,Math.min(.12,d.v*.012))}catch(_){}}},true));
document.addEventListener('click',e=>{if(H9.eat&&e.target.closest&&e.target.closest('#mng')){e.stopPropagation();e.preventDefault()}},true);
(function h9Spin(){try{const st=Math.PI/12,k=Math.floor(MN.rot/st);if(H9.gk===null)H9.gk=k;if(k!==H9.gk){H9.gk=k;if(H9.gd||Math.abs(MN.boost)>.006)hap('notch','カリッ(地球が 15° まわる)',{norip:1,gap:40})}}catch(_){}requestAnimationFrame(h9Spin)})();

/* ---- 5. 「ひらくまで」を 長押し:時間を さわる ---- */
(()=>{const B=$('hst');if(!B)return;let tm=0,iv=0,eat=0,lastM=-1;
  const stop=()=>{clearTimeout(tm);clearInterval(iv);iv=0;if(H9.beat){H9.beat=0;B.classList.remove('h9beat');hap('soft',null,{norip:1})}};
  B.addEventListener('pointerdown',()=>{tm=setTimeout(()=>{H9.beat=1;eat=1;B.classList.add('h9beat');hap('pop','ぷにっ(時間を さわる)',{norip:1});
    const go=()=>{const d=new Date(),m=d.getMinutes();if(m!==lastM&&lastM>=0)hap('click',`カチッ(${d.getHours()}:${String(m).padStart(2,'0')})`,{norip:1});else hap('tick',`チッ(${d.getSeconds()}秒)`,{norip:1});lastM=m;
      if(!H9RM())B.animate([{transform:'scale(1)'},{transform:'scale(1.035)'},{transform:'scale(1)'}],{duration:260,easing:'ease-out'})};
    setTimeout(()=>{go();iv=setInterval(go,1000)},1000-new Date().getMilliseconds())},450)});
  ['pointerup','pointercancel','pointerleave'].forEach(n=>B.addEventListener(n,stop));
  B.addEventListener('click',e=>{if(eat){eat=0;e.stopImmediatePropagation();e.preventDefault()}},true)})();

/* ---- 6. 9:00 / 24:00 の 10秒 前 ---- */
function h9Count(k){if(H9.cd)return;H9.cd=1;const nine=k!=='night';[10,9,8,7,6,5,4,3,2,1].forEach((n,j)=>setTimeout(()=>{hap(n<=3?'click':'tick',`${n}`,{norip:1});h9Big(String(n),n<=3)},j*1000));
  setTimeout(()=>{H9.cd=0;if(nine){hap('heart','ドクン(9:00)');setTimeout(()=>hap('success','トトトン(ひらいた)',{norip:1}),260);h9Big('9:00',1)}else{hap('thud','ドン(消灯)');h9Big('0:00',1,1)}},10000)}
function h9Big(t,hot,dark){const P=$('phone');let E=$('h9cd');if(!E){P.insertAdjacentHTML('beforeend','<b class="h9cd" id="h9cd"></b>');E=$('h9cd')}E.textContent=t;E.className='h9cd'+(hot?' hot':'')+(dark?' dk':'');void E.offsetWidth;E.classList.add('on')}
setInterval(()=>{const d=new Date(),s=d.getSeconds(),m=d.getMinutes(),h=d.getHours();if(m===59&&s===50&&(h===8||h===23)&&typeof cur!=='undefined'&&cur==='home')h9Count(h===8?'nine':'night')},1000);

/* ---- 7. Lattag の 字:サイン ---- */
(()=>{const L=document.querySelector('#hhd .lg');if(!L)return;L.addEventListener('click',e=>{if(e.target.closest('#dsw'))return;hap('sig','ラ・タッ・グ');if(!H9RM())L.animate([{transform:'none'},{transform:'scale(1.06)',offset:.2},{transform:'scale(.98)',offset:.45},{transform:'scale(1.03)',offset:.7},{transform:'none'}],{duration:420,easing:'ease-out'})})})();

/* ---- 8. 設定:バイブの 強さ ---- */
{const _x=x8Set;x8Set=function(on){_x(on);if(!on)return;const S=$('x8set');if(!S||S.querySelector('.h9set'))return;const G=[...S.querySelectorAll('.x8gr')].find(g=>/表示/.test(g.querySelector('small')?.textContent||''));if(!G)return;
  G.insertAdjacentHTML('beforeend',`<div class="x8rw x8lg h9set"><span>バイブ</span><div class="h9sg" data-v="${H9.lv}"><i></i><button data-h="std">しっかり</button><button data-h="low">ひかえめ</button><button data-h="off">オフ</button></div></div>`);
  G.querySelectorAll('.h9sg button').forEach(b=>b.onclick=e=>{e.stopPropagation();H9.lv=b.dataset.h;b.parentNode.dataset.v=H9.lv;
    if(H9.lv==='std'){hap('sel','コツッ');setTimeout(()=>hap('notch',null,{norip:1}),140);setTimeout(()=>hap('notch',null,{norip:1}),200)}else if(H9.lv==='low')hap('sel','コツッ(ひかえめ:きざみ は なし)');else try{_toast('バイブ オフ(だいじな 時も 鳴らない)')}catch(_){}})}}


/* ---- 9. バイブが 書かれて いない ボタン:押したら コツ(全部の ボタンに 手ごたえ)---- */
document.addEventListener('pointerdown',e=>{if(e.target.closest&&e.target.closest('#phone'))H9.pd=performance.now()},true);
document.addEventListener('click',e=>{const b=e.target.closest&&e.target.closest('#phone button,#phone [role="button"],#phone a,#phone [data-a]');if(!b||b.disabled)return;const t0=H9.pd||0;
  setTimeout(()=>{if((H9.lt||0)<t0)hap('tick','コツ(ボタン)',{norip:1,gap:60})},30)});
/* デモボタン ・ テスト用 */
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-h9]'))return;C.insertAdjacentHTML('beforeend','<button data-h9="nine">9:00 の 10秒前</button><button data-h9="night">24:00 の 10秒前</button><button data-h9="set">設定(バイブ)</button>');
  C.querySelector('[data-h9="nine"]').onclick=()=>h9Count('nine');C.querySelector('[data-h9="night"]').onclick=()=>h9Count('night');C.querySelector('[data-h9="set"]').onclick=()=>{try{x8Set(true)}catch(e){}}})();
window.__kit=Object.assign(window.__kit||{},{H9:()=>H9,h9Count:k=>h9Count(k),h9Lv:l=>{H9.lv=l},x8Set:o=>x8Set(o)});
