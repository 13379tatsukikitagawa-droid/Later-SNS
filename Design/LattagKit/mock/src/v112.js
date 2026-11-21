/* ===== v112(モック v113 ・ PROMPT v126):Home の 3つの ボタン「おしゃれ」4案 ===== */
U9DVK.push('gl','pp','ml','au');
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-u9v="gl"]'))return;
  C.insertAdjacentHTML('beforeend',['gl:★ v113 おしゃれ:ガラス','pp:★ v113 おしゃれ:紙','ml:★ v113 おしゃれ:モノクロ + 色の 線','au:★ v113 おしゃれ:オーラ'].map(s=>{const i=s.indexOf(':');return `<button data-u9v="${s.slice(0,i)}">${s.slice(i+1)}</button>`}).join(''));
  C.querySelectorAll('[data-u9v]').forEach(b=>b.onclick=()=>{U9.dv=b.dataset.u9v;u9Demo('home')})})();
try{u9DV()}catch(e){console.warn(e)}
