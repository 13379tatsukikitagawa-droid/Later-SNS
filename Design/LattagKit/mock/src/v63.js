/* ================= v63 =================
   1) まんなか = カメラの 絵だけ   2) 上と 下を ガラスに   3) はじめての 日も いつもの Home */
var NEWU=false;
const CMG='<svg class="cmg" viewBox="-4 -2 72 54"><path class="bd" d="M10 12h9l4-6.5a3 3 0 012.6-1.5h12.8a3 3 0 012.6 1.5L45 12h9a6 6 0 016 6v24a6 6 0 01-6 6H10a6 6 0 01-6-6V18a6 6 0 016-6z"/><circle class="ln" cx="32" cy="29" r="11.5"/><circle class="ap" cx="32" cy="29" r="5.2"/><circle class="fl" cx="51.5" cy="20" r="2.4"/></svg>';
const CMY='<svg class="cmg" viewBox="-4 -4 72 72"><rect class="bd" x="14" y="4" width="44" height="50" rx="5" transform="rotate(8 36 29)"/><rect class="bd" x="8" y="10" width="44" height="50" rx="5" transform="rotate(-6 30 35)" style="fill:rgba(0,0,0,.25)"/><circle class="ap" cx="29" cy="30" r="4"/><path class="ln" d="M14 52l12-11 8 7 7-5 9 8" transform="rotate(-6 30 35)"/></svg>';
function g63Icon(){const I=$('lnic');if(!I||!ORB)return;const y=ORB.main==='yday';if(I.dataset.k!==(y?'y':'s')){I.dataset.k=y?'y':'s';I.innerHTML=y?CMY:CMG}
  const L=$('lens');L.setAttribute('aria-label',y?'Yesterday を ひらく':`撮る。あと ${3-Math.min(3,shots)} 枚`)}

/* --- 上:プロフィールの 輪 = 今日の フィルム(撮った ぶん だけ 緑)--- */
function g63Top(){const a=document.querySelector('#home .hh .av');if(a)a.style.setProperty('--fp',(Math.min(3,shots)/3).toFixed(3))}

/* --- 下:月の 中身を 組みなおす --- */
function g63Moon(){const M=$('hmoon');if(!M)return;if(!M.querySelector('.lgr')){M.insertAdjacentHTML('beforeend','<span class="lgr"></span>')}
  const t=$('hmt'),s=$('hms'),n=Math.min(3,shots),left=3-n,lock=n>=3;
  const row=M.querySelector('.mrow')||(()=>{const r=document.createElement('span');r.className='mrow';t.parentNode.insertBefore(r,t);r.appendChild(t);return r})();
  if(!row.querySelector('svg'))row.insertAdjacentHTML('afterbegin','<svg viewBox="0 0 64 48"><path d="M10 12h9l4-6.5a3 3 0 012.6-1.5h12.8a3 3 0 012.6 1.5L45 12h9a6 6 0 016 6v24a6 6 0 01-6 6H10a6 6 0 01-6-6V18a6 6 0 016-6z" fill="none" stroke="#fff" stroke-width="4.4" stroke-linejoin="round"/><circle cx="32" cy="29" r="10.5" fill="none" stroke="#fff" stroke-width="4.4"/></svg>');
  row.querySelector('svg').style.display=lock?'none':'';
  s.innerHTML=lock?'あした 9:00 に ひらく':`<span class="fd">${[0,1,2].map(j=>`<i class="${j<n?'u':''}"></i>`).join('')}</span>のこり ${left}こま`}

/* --- はじめての 日 --- */
function g63New(){const H=$('home');H.classList.add('d2');H.classList.toggle('nu',NEWU);
  ['ayh','amd','aal','otd'].forEach(id=>{const e=$(id);const p=e&&e.previousElementSibling;if(p&&p.classList.contains('axh'))p.classList.add('nuh')});
  if(!$('anew')){const g=$('ayg');if(g)g.insertAdjacentHTML('afterend',`<div class="anew" id="anew" aria-label="きのうの 写真は あした から"><div class="fan"><i style="--r:-10deg;--x:-70px;--y:12px"></i><i style="--r:10deg;--x:70px;--y:12px"></i><i class="m" style="--r:0deg;--x:0px;--y:0px"><b>TODAY'S 1ST</b></i></div>
      <h4>Yesterday</h4><p>今日 撮った 1枚が、あしたの 朝 9:00 に<br>ここで ひらきます。</p><div class="cd"><span><i></i><em id="anct">9:00 まで</em></span></div></div>`)}
  g63Count();try{hpRender(4)}catch(e){}}
function g63Count(){const e=$('anct');if(!e)return;const n=new Date(),t=new Date(n);t.setHours(9,0,0,0);if(t<=n)t.setDate(t.getDate()+1);const m=Math.round((t-n)/60000);e.textContent=`9:00 まで ${Math.floor(m/60)}h ${p2(m%60)}m`}
setInterval(g63Count,30000);
{const _sd=setDay;setDay=function(d2){NEWU=!d2;_sd(true);g63New()};window.setDay=setDay}
/* デモの ボタン「初回 ⇄ 2日目から」→「はじめて ⇄ いつも」 */
{const b=document.querySelector('#ctl button[data-c="day"]');if(b){b.textContent='はじめて ⇄ いつも';b.onclick=e=>{e.stopPropagation();if(cur!=='home')toHome();if($('fscr').classList.contains('on'))closeFriend();cmHide();
  setDay(NEWU);homeFocus();toast(NEWU?'はじめての Home(きのうが まだ ない)':'いつもの Home')}}}
/* 合図:はじめての 日は「ここから、1枚目」、いつもは「撮ると、きのうが 1枚 ひらく」 */
try{CMD.forEach(d=>{if(d.k==='first'){d.c=()=>NEWU&&shots===0;d.t='lens'}if(d.k==='unlock')d.c=()=>!NEWU&&shots===0})}catch(e){}
/* 横スライドの Yesterday ページも、はじめての 日は「あした から」 */
{const _hr=hpRender;hpRender=function(only){_hr(only);try{if(!only||only===4){const C=$('hpc4');if(!C)return;C.classList.toggle('nu',NEWU);const f=C.querySelector('.hpfan');if(f)f.classList.toggle('nu',NEWU);
  if(NEWU){const st=C.querySelector('.hph .st');if(st)st.textContent='FROM TOMORROW';const ys=C.querySelector('.hpys');if(ys)ys.style.display='none';const lk=C.querySelector('.hpfan em');if(lk)lk.style.display='none';
    const go=C.querySelector('[data-a="go"]');if(go){go.classList.remove('lk');go.querySelector('span').textContent='撮ると、あした ひらく';go.onclick=()=>{hap('pop');ORB.A.shoot?ORB.A.shoot.run():toast('今日 撮った 1枚が、あしたの 9:00 に ひらきます')}}}}}catch(e){console.error(e)}};window.hpRender=hpRender}

{const _r=renderOrb;renderOrb=function(){_r();try{g63Icon();g63Top()}catch(e){console.error(e)}};window.renderOrb=renderOrb}
{const _rh=renderHome;renderHome=function(){_rh();try{g63Moon();g63Top()}catch(e){console.error(e)}};window.renderHome=renderHome}
try{renderOrb();renderHome();g63New()}catch(e){console.error(e)}
