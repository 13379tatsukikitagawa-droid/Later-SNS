/* ===== v116(モック v117 ・ PROMPT v131 案):Home の 3つの ボタンを やめる ・ # を 大きく ・ 3案 ===== */
U9.hx='row';
const U9HI={lock:'<svg viewBox="0 0 24 24"><rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 018 0v3"/></svg>'};
function u9HData(){const RQ=(typeof REQ!=='undefined'&&REQ)||[],took=FR.filter(f=>f.k>0).length;let T=null;try{const now=Date.now();T=(G9.trips||[]).find(t=>t.from<=now&&t.to>=now)||null}catch(e){}
  const h=new Date().getHours(),open=h>=9,tday=T?Math.max(1,Math.round((Date.now()-T.from)/864e5)+1):0,tD=T?Math.round((T.to-T.from)/864e5)+1:0;
  return {RQ,took,T,open,tday,tD}}
function u9HDraw(){const H=$('home'),N=$('hpi');if(!H||!N)return;const k=U9.hx;
  ['tab','row','stk'].forEach(x=>H.classList.toggle('u9h-'+x,k===x));H.classList.toggle('u9h',!!k&&k!=='off');
  const G=$('hpg')||H;let B=G.querySelector('.u9hb');if(!B){G.insertAdjacentHTML('beforeend','<nav class="u9hb" aria-label="ページ"></nav>');B=G.querySelector('.u9hb')}
  B.className='u9hb '+k;const cur=(typeof HPG!=='undefined'&&HPG.i)||0,D=u9HData(),bc=i=>{const b=N.querySelector(`button[data-i="${i}"] i`);return b?b.style.getPropertyValue('--bc'):'#C8F25A'};
  const em=D.RQ.length?`<em>${D.RQ.length}</em>`:'';
  if(k==='tab')B.innerHTML=[[0,'カメラ'],[1,'友だち'],[2,'Trip'],[3,'きのう']].map(([i,l])=>`<button data-go="${i}" class="${cur===i?'on':''}" style="--bc:${i?bc(i):'#C8F25A'}"><i></i>${l}${i===1?em:''}</button>`).join('');
  if(k==='row'){const fav=(D.RQ.length?D.RQ.map(r=>r.f.n):FR.map(f=>f.n)).slice(0,3),fp=FR.length?fPic(FR[0]):PH.a;
    B.innerHTML=`<button data-go="1" style="--bc:${bc(1)};--fs:34px" class="${cur===1?'on':''}" aria-label="Friends"><i class="bg tint" style="--ph:url(${fp})"></i><span class="top"><span class="avs">${fav.length?fav.map(n=>g9Av(n,24)).join(''):''}</span>${em}</span><b>Friends</b><small>${D.RQ.length?D.RQ.length+'人 から 申請':D.took?D.took+'人 撮った':FR.length?'まだ だれも':'よんで みよう'}</small></button>
      <button data-go="2" style="--bc:${bc(2)};--fs:46px" class="${cur===2?'on':''}" aria-label="Trip"><i class="bg" style="--ph:url(${PH[D.T&&D.T.cv||'b']})"></i><span class="top">${D.T?`<span class="tag">DAY ${D.tday} / ${D.tD}</span>`:''}</span><b>Trip</b><small>${D.T?g9E(D.T.n)+' ・ いま':'つくる'}</small></button>
      <button data-go="3" style="--bc:${bc(3)};--fs:30px" aria-label="Yesterday"><i class="bg${D.open?'':' lk'}" style="--ph:url(${PH.d})"></i>${D.open?'':`<span class="lock">${U9HI.lock}</span>`}<b>Yesterday</b><small>${D.open?'ひらいた':'9:00 に ひらく'}</small></button>`;
    requestAnimationFrame(()=>B.querySelectorAll('button b').forEach(t=>{const w=t.parentElement.clientWidth-22;let f=parseFloat(getComputedStyle(t).fontSize);while(t.scrollWidth>w&&f>16){f-=1;t.style.setProperty('--fs',f+'px')}}))}
  if(k==='stk'){const ic=i=>{const b=N.querySelector(`button[data-i="${i}"] i svg`);return b?b.outerHTML:''};
    B.innerHTML=[[1,'友だち'],[2,'Trip'],[3,'きのう']].map(([i,l])=>`<button data-go="${i}" class="${cur===i?'on':''}" style="--bc:${bc(i)}"><i>${ic(i)}</i>${l}${i===1?em:''}</button>`).join('')}
  B.querySelectorAll('[data-go]').forEach(b=>b.onclick=e=>{e.stopPropagation();const i=+b.dataset.go;hap('pop','ぷにっ');if(i===0){try{hpGo(0)}catch(_){}return}const t=N.querySelector(`button[data-i="${i}"]`);if(t)t.click();else try{hpGo(i)}catch(_){}});
  const O=$('orb');if(O&&!O.querySelector('.u9lh'))O.insertAdjacentHTML('beforeend','<span class="u9lh">タップで 撮る</span>');
  const L=$('lens');if(L&&!L._u9h){L._u9h=1;L.style.cursor='pointer';L.setAttribute('role','button');L.setAttribute('aria-label','撮る');L.addEventListener('click',e=>{if(!H.classList.contains('u9h'))return;e.stopPropagation();hap('shutter');try{goShoot()}catch(_){}})}}
(()=>{const _r=renderHome;renderHome=function(){const r=_r.apply(this,arguments);try{u9HDraw()}catch(e){console.warn(e)}return r}})();
(()=>{const _g=hpGo;hpGo=function(){const r=_g.apply(this,arguments);try{u9HDraw()}catch(e){}return r};window.hpGo=hpGo})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9hx]'))return;
  C.insertAdjacentHTML('beforeend',['tab:★ v117 下:ことばの タブ','row:★ v117 下:中身の 列','stk:★ v117 下:柵の ステッカー','off:★ v117 下:今(オーラ)'].map(s=>{const i=s.indexOf(':');return `<button data-u9hx="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9hx]').forEach(b=>b.onclick=()=>{U9.hx=b.dataset.u9hx;u9Demo('home')})})();
window.__kit=Object.assign(window.__kit||{},{u9hx:k=>{U9.hx=k;try{renderHome()}catch(e){}}});
try{u9HDraw()}catch(e){console.warn(e)}
