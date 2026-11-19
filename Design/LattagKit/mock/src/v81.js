
/* ================= v81(PROMPT v88)・ プロフィールの 編集を 新しい 見た目に ================= */
/* シールの 位置(自分の 3つ)を v87 に そろえる:編集の あとも 同じ 場所 */
try{[[-120,-112,-8,1.04],[118,-84,7,1],[-128,52,5,1]].forEach((v,i)=>{PFP[i]=v})}catch(e){}
{const _e=pfEdit;pfEdit=function(on){_e(on);try{const P=$('prf');if(!P)return;
  if(on){const b=$('phe');b&&(b.querySelector('b').textContent='編集');
    const h={pic:'写真',name:'名前',tag:'タグ'};P.querySelectorAll('#ped .pes').forEach(s=>{const t=s.querySelector('.peh b');t&&h[s.dataset.s]&&(t.textContent=h[s.dataset.s])});
    const g=P.querySelector('.pesg .cu input');g&&(g.placeholder='じぶんで 書く')}
  else{P.querySelectorAll('.pst:not(.me)').forEach(s=>s.remove())}}catch(e){console.error(e)}}}
Object.assign(window.__kit||(window.__kit={}),{pfEdit:v=>{try{pfEdit(v!==false)}catch(e){}}});
