/* ===== v111(モック v112 ・ PROMPT v125):Home の 3つの ボタン 第3の 4案 ===== */
U9DVK.push('ph','bk','bn','sp');
(()=>{const _dv=u9DV;u9DV=function(){_dv();const N=$('hpi');if(!N)return;const ph={1:PH.b,2:PH.f,3:PH.d},rt={1:'FRIENDS ・ FRIENDS ・ ',2:'TRIP ・ TRIP ・ TRIP ・ ',3:'YESTERDAY ・ YESTERDAY ・ '};
  N.querySelectorAll('button[data-i]').forEach(b=>{const n=+b.dataset.i;if(!ph[n])return;b.style.setProperty('--ph',`url(${ph[n]})`);
    if(!b.querySelector('.u9dr'))b.insertAdjacentHTML('beforeend',`<svg class="u9dr" viewBox="0 0 80 80" aria-hidden="true"><defs><path id="u9dp${n}" d="M40 40m-30.500 0a30.500 30.500 0 1 1 61 0a30.500 30.500 0 1 1 -61 0"/></defs><text><textPath href="#u9dp${n}" textLength="188">${rt[n]}</textPath></text></svg>`)})}})();
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9v="ph"]'))return;
  C.insertAdjacentHTML('beforeend',['ph:★ v112 ボタン:写真入り','bk:★ v112 ボタン:カラーブロック','bn:★ v112 ボタン:大 1 + 小 2','sp:★ v112 ボタン:スタンプ'].map(s=>{const i=s.indexOf(':');return `<button data-u9v="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9v]').forEach(b=>b.onclick=()=>{U9.dv=b.dataset.u9v;u9Demo('home')})})();
try{u9DV()}catch(e){console.warn(e)}
