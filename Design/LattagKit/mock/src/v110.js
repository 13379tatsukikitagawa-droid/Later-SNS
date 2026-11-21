/* ===== v110(モック v111 ・ PROMPT v124):Home の 3つの ボタン 追加の 5案 ===== */
const U9DVK=['pill','cheki','ring','tile','tk','st','mk','inf','wd'];
function u9DV(){const H=$('home'),N=$('hpi');if(!H||!N)return;U9DVK.forEach(k=>H.classList.toggle('u9dv-'+k,U9.dv===k));
  const RQ=(typeof REQ!=='undefined'&&REQ)||[],took=FR.filter(f=>f.k>0).length;
  const sub={1:RQ.length?`${RQ.length}人 から 申請`:took?`${took}人 撮った`:FR.length?'まだ だれも':'よぼう',2:'みんなで 撮る',3:'9:00 に ひらく'},wd={1:'Friends',2:'Trip',3:'Yesterday'};
  N.querySelectorAll('button[data-i]').forEach(b=>{const i=b.querySelector('i');if(i)b.style.setProperty('--bc',i.style.getPropertyValue('--bc'));const n=+b.dataset.i;if(!sub[n])return;const e0=i&&i.querySelector('em');let de=b.querySelector('.u9de');if(e0){if(!de){b.insertAdjacentHTML('beforeend','<em class="u9de"></em>');de=b.querySelector('.u9de')}de.textContent=e0.textContent}else if(de)de.remove();
    let s=b.querySelector('.u9ds');if(!s){b.insertAdjacentHTML('beforeend','<small class="u9ds"></small>');s=b.querySelector('.u9ds')}s.textContent=sub[n];
    if(!b.querySelector('.u9dw'))b.querySelector('span').insertAdjacentHTML('beforebegin',`<b class="u9dw">${wd[n]}</b>`)})}
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9v="tk"]'))return;
  C.insertAdjacentHTML('beforeend',['tk:★ v111 ボタン:チケット','st:★ v111 ボタン:ステッカーの 形','mk:★ v111 ボタン:ミルク','inf:★ v111 ボタン:じょうほう つき','wd:★ v111 ボタン:ことば'].map(s=>{const i=s.indexOf(':');return `<button data-u9v="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9v]').forEach(b=>b.onclick=()=>{U9.dv=b.dataset.u9v;u9Demo('home')})})();
try{u9DV()}catch(e){console.warn(e)}
