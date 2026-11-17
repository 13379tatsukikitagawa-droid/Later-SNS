
/* ================= v67(PROMPT v70)・ Home 下の Friends カード(Instagram / BeReal の 形)================= */
const I67={go:'<svg viewBox="0 0 24 24"><path d="M9 6l6 6-6 6"/></svg>',plus:'<svg viewBox="0 0 24 24"><path d="M12 6v12M6 12h12"/></svg>',
  x:'<svg viewBox="0 0 24 24"><path d="M7 7l10 10M17 7L7 17"/></svg>',
  qr:'<svg viewBox="0 0 24 24"><rect x="4" y="4" width="6" height="6" rx="1"/><rect x="14" y="4" width="6" height="6" rx="1"/><rect x="4" y="14" width="6" height="6" rx="1"/><path d="M14 14h2v2h-2zM18 18h2v2h-2z"/></svg>',
  id:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="4"/><path d="M16 8v5a2.5 2.5 0 005 0v-1a9 9 0 10-3.5 7.1"/></svg>',
  sh:'<svg viewBox="0 0 24 24"><path d="M12 3v12M7 8l5-5 5 5"/><path d="M5 13v5a2 2 0 002 2h10a2 2 0 002-2v-5"/></svg>'};
const a67Share=()=>openShare({t:'Lattag で つながろう ・ ゆい(@yui_0612)\nhttps://lattag.app/u/yui_0612',h:'ゆい'});
arcFriends=function(ni){const B=$('afc');if(!B)return;B.className='afc v67';const ax=$('afcn')&&$('afcn').parentElement;if(ax)ax.style.display='none';
  const RQ=(typeof REQ!=='undefined'&&REQ)||[],V=FR.slice().sort((a,b)=>b.k-a.k),took=V.filter(f=>f.k>0).length;
  let h=`<div class="a67h" data-a="go"><b>Friends</b>${took?`<span class="lv"><i></i>${took} SHOT TODAY</span>`:''}<button class="go" aria-label="Friends を ひらく">${I67.go}</button></div>`;
  if(FR.length){
    h+=`<div class="a67r" id="a67r"><button class="a67b me" data-a="add" aria-label="友だちを ふやす"><span class="c"><i style="background-image:url(${PH.f})"></i><u>${I67.plus}</u></span><small>ふやす</small></button>
      ${V.map(f=>{const i=FR.indexOf(f),T=fTimes(f);return `<button class="a67b${f.k?' k':''}" data-i="${i}" aria-label="${f.n}"><span class="c"><i style="background-image:url(${fPic(f)})"></i>${f.k?`<em>${T[f.k-1]}</em>`:`<s class="${POKED.has(i)?'dn':''}" data-a="poke" role="button" aria-label="${f.n} を つつく">${IHAND}</s>`}</span><small>${f.n}</small></button>`}).join('')}</div>`;
    if(RQ.length)h+=`<button class="a67q" data-a="go"><span class="avs">${RQ.slice(0,3).map(r=>`<i style="background-image:url(${fPic(r.f)})"></i>`).join('')}</span><i class="dt"></i><span class="tx"><b>${RQ[0].f.n}${RQ.length>1?` ほか${RQ.length-1}人`:''}</b><small>友だちに なりたい</small></span><span class="ck">確認</span></button>`;
  }else{
    h+=`<p class="a67s">${RQ.length?'友だちに なりたい 人が います。':'つながると、毎朝 9:00 に きのうを 見せあえます。'}</p>
      <div class="a67c" id="a67c">${RQ.map((r,i)=>`<div class="a67k" data-q="${i}"><button class="x" data-a="no" aria-label="あとで">${I67.x}</button><span class="p" style="background-image:url(${fPic(r.f)})"></span><b>${r.f.n}</b><small>${FID(r.f)}</small><em>${r.at} ・ 申請</em><button class="ok" data-a="ok">承認</button></div>`).join('')}
        <div class="a67k iv pr" data-a="link"><span class="p">${I67.sh}</span><b>リンクを 送る</b><small>LINE ・ AirDrop など</small><button class="ok" data-a="link">送る</button></div>
        <div class="a67k iv" data-a="qr"><span class="p">${I67.qr}</span><b>QR を 見せる</b><small>となりの 友だちに</small><button class="ok" data-a="qr">ひらく</button></div>
        <div class="a67k iv" data-a="id"><span class="p">${I67.id}</span><b>ID で さがす</b><small>@ID を 知って いる</small><button class="ok" data-a="id">さがす</button></div></div>`;
  }
  B.innerHTML=h;
  const go=e=>{e.stopPropagation();hap('pop','ぷにっ(Friends へ)');openFriend()};
  B.querySelectorAll('[data-a="go"]').forEach(b=>b.onclick=go);
  B.querySelectorAll('[data-a="add"],[data-a="qr"]').forEach(b=>b.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(QR)');openAdd()});
  B.querySelectorAll('[data-a="id"]').forEach(b=>b.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(ID)');openAdd();setTimeout(()=>{const i=$('adin');i&&i.focus()},420)});
  B.querySelectorAll('[data-a="link"]').forEach(b=>b.onclick=e=>{e.stopPropagation();hap('pop','ぷにっ(リンク)');a67Share()});
  B.querySelectorAll('.a67k[data-q]').forEach(c=>{const i=+c.dataset.q;
    c.querySelector('[data-a="ok"]').onclick=e=>{e.stopPropagation();hap('click','カチッ(承認)',{norip:1});c.animate([{transform:'none',opacity:1},{transform:'scale(1.05)',offset:.3},{transform:'translateY(-30px) scale(.8)',opacity:0}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'});setTimeout(()=>reqAccept(i),380)};
    c.querySelector('[data-a="no"]').onclick=e=>{e.stopPropagation();c.animate([{opacity:1},{opacity:0,transform:'scale(.9)'}],{duration:240,fill:'forwards'});setTimeout(()=>reqLater(i),220)}});
  B.querySelectorAll('.a67b[data-i]').forEach(c=>{const i=+c.dataset.i,f=FR[i];c.onclick=e=>{e.stopPropagation();const pk=e.target.closest('[data-a="poke"]');
    if(pk){if(!POKED.has(i))pk.classList.add('dn');fPoke2(i,c);return}hap('sel','コツッ('+f.n+')');openFC(f,c)}});
  if(ni!=null&&FR[ni]){const c=B.querySelector(`.a67b[data-i="${ni}"]`);c&&c.animate([{transform:'scale(.3)',opacity:0},{transform:'scale(1.12)',opacity:1,offset:.7},{transform:'none'}],{duration:620,easing:'cubic-bezier(.3,1.3,.5,1)'})}
  B._in67=false;af67In()};
/* 画面に 入って きたら:丸が 左から ぽんぽん ・ カードが すべって 入る */
function af67In(){const B=$('afc'),hs=$('hs');if(!B||B._in67||!B.offsetParent)return;const r=B.getBoundingClientRect(),h=hs.getBoundingClientRect();if(r.top>h.bottom-90*SC||r.bottom<h.top)return;B._in67=true;
  if(matchMedia('(prefers-reduced-motion:reduce)').matches)return;
  B.querySelectorAll('.a67b').forEach((c,j)=>{c.animate([{transform:'scale(.4)',opacity:0},{transform:'scale(1.08)',opacity:1,offset:.7},{transform:'none'}],{duration:520,delay:60+j*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'});if(j<5)setTimeout(()=>hap('tick',null,{norip:1}),60+j*60+300)});
  B.querySelectorAll('.a67k').forEach((c,j)=>c.animate([{transform:'translateX(40px)',opacity:0},{transform:'none',opacity:1}],{duration:520,delay:80+j*70,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'}));
  B.querySelectorAll('.a67q').forEach(c=>c.animate([{transform:'translateY(14px)',opacity:0},{transform:'none',opacity:1}],{duration:440,delay:360,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}))}
afIn=af67In;$('hs').addEventListener('scroll',af67In,{passive:true});
try{arcFriends()}catch(e){console.error(e)}
Object.assign(window.__kit||(window.__kit={}),{clearReq:()=>{REQ.length=0;try{renderFriends()}catch(e){}try{arcFriends()}catch(e){}}});
