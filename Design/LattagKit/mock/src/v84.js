
/* ================= v84(PROMPT v92)・ QR = チェキ + # の 形(BeReal の 形を 参考に)================= */
const Q9M=["111111100101000001110010101111111", "100000101110100100010110001000001", "101110101110010100011110101011101", "101110101000110000011111001011101", "101110101100011010111011001011101", "100000101000011001101001001000001", "111111101010101010101010101111111", "000000000000111100111011100000000", "001001111011001000010100110111110", "111001000111101101001011111100001", "000011110111000001010111001111101", "011001000001001001110010100100000", "100101110111010010001111101111000", "111001000000010001100111001001001", "111100110001001001111001000101001", "000010011011010011101011111000010", "110001100101000100100011001100000", "110110001010001011001001011000111", "000101100111001101001111000011111", "100000000001010100001011001101000", "110011110101001100010001000000011", "000100010010111110100110000100011", "111101100100100011010001011110101", "000011000010000010000010000101000", "111110110011011011100011111110011", "000000001101010100011111100011101", "111111101101001001111000101010001", "100000101000010100001101100011011", "101110100011000101001101111110000", "101110100110010011101101010110010", "101110101101101101110011000010111", "100000100000000100101100100000000", "111111100111111001110100101010001"]; /* 本物の QR(誤り訂正 H ・ https://lattag.app/u/yui_0612)。本番は 端末で 作る */
const Q9={on:false,flip:false};const Q9RM=()=>matchMedia('(prefers-reduced-motion:reduce)').matches;
/* # の 形:QR の 中の 点で、# に 重なる 物を 緑に する(どちらも 濃い 色 なので 読める)*/
function q9InHash(x,y,N){const u=x/N,v=y/N,b=(a,lo,hi)=>a>=lo&&a<=hi;const V=(b(u,.27,.40)||b(u,.60,.73))&&b(v,.08,.92),H=(b(v,.27,.40)||b(v,.60,.73))&&b(u,.08,.92);return V||H}
function q9Fin(x,y,N){return (x<8&&y<8)||(x>N-9&&y<8)||(x<8&&y>N-9)}
function q9Svg(){const N=Q9M.length,c=N/2,ic=7.6;let d='',g='';
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){if(Q9M[y][x]!=='1'||q9Fin(x,y,N))continue;if(Math.abs(x+.5-c)<ic/2+.4&&Math.abs(y+.5-c)<ic/2+.4)continue;
    const k=Math.hypot(x+.5-c,y+.5-c)/c;const s=`<circle cx="${x+.5}" cy="${y+.5}" r=".43" style="--k:${k.toFixed(3)}"/>`;q9InHash(x+.5,y+.5,N)?g+=s:d+=s}
  const F=(x,y)=>`<g transform="translate(${x} ${y})"><rect width="7" height="7" rx="1" fill="#0B0C0D"/><rect x="1" y="1" width="5" height="5" rx=".15" fill="#FBFAF6"/><circle cx="3.5" cy="3.5" r="1.62" fill="#0B0C0D"/><circle cx="2.95" cy="2.9" r=".38" fill="#C8F25A"/></g>`;
  const I=(c-ic/2);
  return `<svg class="q9q" viewBox="-1 -1 ${N+2} ${N+2}" aria-label="QR コード"><g class="dk">${d}</g><g class="gr">${g}</g>${F(0,0)}${F(N-7,0)}${F(0,N-7)}
   <g class="ic" transform="translate(${I} ${I})"><rect width="${ic}" height="${ic}" rx="${(ic*.224).toFixed(2)}" fill="#C8F25A"/>
    <g fill="#0B0C0D"><rect x="${ic*.19}" y="${ic*.31}" width="${ic*.62}" height="${ic*.1}" rx="${ic*.05}"/><rect x="${ic*.19}" y="${ic*.59}" width="${ic*.62}" height="${ic*.1}" rx="${ic*.05}"/><rect x="${ic*.31}" y="${ic*.19}" width="${ic*.1}" height="${ic*.62}" rx="${ic*.05}"/><rect x="${ic*.59}" y="${ic*.19}" width="${ic*.1}" height="${ic*.62}" rx="${ic*.05}"/></g>
    <circle cx="${ic/2}" cy="${ic/2}" r="${ic*.15}" fill="#C8F25A" stroke="#0B0C0D" stroke-width="${ic*.035}"/><circle cx="${ic/2}" cy="${ic/2}" r="${ic*.1}" fill="#10141c"/><circle cx="${ic*.47}" cy="${ic*.46}" r="${ic*.03}" fill="#fff"/></g></svg>`}
const Q9I={x:'<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>',scan:'<svg viewBox="0 0 24 24"><path d="M4 8V5a1 1 0 011-1h3M16 4h3a1 1 0 011 1v3M20 16v3a1 1 0 01-1 1h-3M8 20H5a1 1 0 01-1-1v-3"/><rect x="8" y="8" width="3" height="3"/><rect x="13" y="8" width="3" height="3"/><rect x="8" y="13" width="3" height="3"/><path d="M13 13h3v3"/></svg>',
  link:'<svg viewBox="0 0 24 24"><path d="M10 14a4 4 0 005.7 0l3-3a4 4 0 00-5.7-5.7l-1 1"/><path d="M14 10a4 4 0 00-5.7 0l-3 3a4 4 0 005.7 5.7l1-1"/></svg>',
  chat:'<svg viewBox="0 0 24 24"><path d="M12 4.5c4.7 0 8.5 3 8.5 6.8s-3.8 6.8-8.5 6.8c-.8 0-1.6-.1-2.3-.3L6 19.5l.7-3.3c-1.4-1.2-2.2-2.9-2.2-4.9 0-3.8 3.8-6.8 7.5-6.8z"/></svg>',
  msg:'<svg viewBox="0 0 24 24"><path d="M12 4c4.8 0 8.5 3.2 8.5 7.2S16.8 18.4 12 18.4c-1 0-1.9-.1-2.7-.4L5 19.8l1.3-3.4C4.6 15 3.5 13.2 3.5 11.2 3.5 7.2 7.2 4 12 4z"/></svg>',
  save:'<svg viewBox="0 0 24 24"><path d="M12 4v11M7 10l5 5 5-5M5 19h14"/></svg>',more:'<svg viewBox="0 0 24 24"><circle cx="6" cy="12" r="1.6"/><circle cx="12" cy="12" r="1.6"/><circle cx="18" cy="12" r="1.6"/></svg>',ok:'<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9"/><path d="M8 12.3l2.7 2.7L16 9.6"/></svg>'};
function q9Open(){let m={n:'ゆい',id:'@yui_0612',tags:['#カフェ','#音楽','#夜型']};try{const f=fMe();m.n=f.n;m.id=f.id;m.tags=(f.tags||m.tags).slice(0,3)}catch(e){}
  const av=(()=>{try{return avUrl()}catch(e){return `url(${PH.d})`}})(),d=new Date(),st=`'${String(d.getFullYear()).slice(2)} ${String(d.getMonth()+1).padStart(2,'0')} ${String(d.getDate()).padStart(2,'0')}`;
  let S=$('q9');if(!S){$('phone').insertAdjacentHTML('beforeend','<section class="q9" id="q9" role="dialog" aria-label="QR コード"></section>');S=$('q9')}
  Q9.flip=false;S.innerHTML=`<i class="q9bg" style="--av:${av}"></i>
   <div class="q9h"><button data-a="x" aria-label="とじる">${Q9I.x}</button><button data-a="scan" aria-label="QR を 読む">${Q9I.scan}</button></div>
   <div class="q9st"><div class="q9c" id="q9c"><div class="q9f">
     <i class="q9tp"></i><div class="q9av" style="background-image:${av}"></div>
     <div class="q9win">${q9Svg()}<i class="q9gl"></i></div>
     <div class="q9ft"><div><b>${m.n}</b><small>${m.id}</small></div><span class="q9dt">${st}</span></div></div>
    <div class="q9b"><div class="q9ph" style="background-image:${av}"></div><div class="q9tg">${m.tags.map((t,i)=>`<span style="--r:${[-6,5,-3][i]}deg;--bg:${['#C8F25A','#EE5E9C','#9ED8FF'][i]};--fg:${['#111','#fff','#111'][i]}">${t}</span>`).join('')}</div><div class="q9ft"><div><b>${m.n}</b><small>LATTAG ・ SINCE 2026</small></div><span class="q9dt">${st}</span></div></div></div></div>
   <p class="q9hi">タップで うらがえす</p>
   <div class="q9ok" id="q9ok"><i>${Q9I.ok}</i><span>コピーしました</span></div>
   <div class="q9ac"><button data-a="copy"><i>${Q9I.link}</i><span>コピー</span></button><button data-a="line" class="ln"><i>${Q9I.chat}</i><span>LINE</span></button><button data-a="msg" class="ms"><i>${Q9I.msg}</i><span>メッセージ</span></button><button data-a="save"><i>${Q9I.save}</i><span>保存</span></button><button data-a="more"><i>${Q9I.more}</i><span>その他</span></button></div>`;
  S.classList.add('on');Q9.on=true;hap('pop','ぷにっ(QR)');
  const C=$('q9c'),F=S.querySelector('.q9f');
  if(!Q9RM()){C.animate([{transform:'translateY(-70px) rotate(-9deg) scale(.92)',opacity:0},{transform:'translateY(8px) rotate(-1deg)',opacity:1,offset:.65},{transform:'none',opacity:1}],{duration:620,easing:'cubic-bezier(.3,1.2,.4,1)'});
    S.querySelector('.q9av').animate([{transform:'translateX(-50%) scale(0)'},{transform:'translateX(-50%) scale(1.12)',offset:.6},{transform:'translateX(-50%) scale(1)'}],{duration:460,delay:300,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'backwards'});
    /* 点が まんなか から 現像 される ように 出る */
    S.querySelectorAll('.q9q circle[style]').forEach(c=>{const k=parseFloat(c.style.getPropertyValue('--k'));c.animate([{opacity:0,transform:'scale(.2)'},{opacity:1,transform:'none'}],{duration:260,delay:260+k*520,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'})});
    S.querySelectorAll('.q9q > g:not(.dk):not(.gr)').forEach((g,i)=>g.animate([{opacity:0,transform:'scale(.6)'},{opacity:1,transform:'none'}],{duration:380,delay:200+i*60,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'}));
    [380,560,740].forEach(t=>setTimeout(()=>Q9.on&&hap('tick',null,{norip:1}),t));
    S.querySelectorAll('.q9ac button').forEach((b,i)=>b.animate([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:420,delay:380+i*50,easing:'cubic-bezier(.2,.9,.25,1)',fill:'backwards'}))}
  /* なぞると かたむく ・ 光が 動く ・ タップで うらがえす */
  let dn=null;const st2=S.querySelector('.q9st');
  st2.onpointermove=e=>{if(Q9RM())return;const r=st2.getBoundingClientRect(),x=(e.clientX-r.left)/r.width-.5,y=(e.clientY-r.top)/r.height-.5;C.style.setProperty('--ry',(x*14).toFixed(1)+'deg');C.style.setProperty('--rx',(-y*10).toFixed(1)+'deg');C.style.setProperty('--gx',((x+.5)*100).toFixed(0)+'%')};
  st2.onpointerleave=()=>{C.style.setProperty('--ry','0deg');C.style.setProperty('--rx','0deg')};
  C.onpointerdown=e=>{dn={x:e.clientX,y:e.clientY}};C.onclick=e=>{if(dn&&Math.hypot(e.clientX-dn.x,e.clientY-dn.y)>8)return;Q9.flip=!Q9.flip;C.classList.toggle('fl',Q9.flip);S.querySelector('.q9hi').textContent=Q9.flip?'タップで QR に もどる':'タップで うらがえす';hap(Q9.flip?'pop':'sel',Q9.flip?'ぷにっ(うら)':'コツッ(QR)')};
  const A=(k,f)=>{const b=S.querySelector(`[data-a="${k}"]`);b&&(b.onclick=f)};
  A('x',()=>q9Close());A('scan',()=>{q9Close();setTimeout(()=>{try{openScan('fr')}catch(e){}},300)});
  const toast=t=>{const o=$('q9ok');o.querySelector('span').textContent=t;o.classList.remove('on');void o.offsetWidth;o.classList.add('on');clearTimeout(Q9.tt);Q9.tt=setTimeout(()=>o.classList.remove('on'),1800)};
  A('copy',()=>{try{navigator.clipboard&&navigator.clipboard.writeText('https://lattag.app/u/'+m.id.replace('@','')).catch(()=>{})}catch(e){}hap('success','トトン(コピー)');toast('コピーしました')});
  A('line',()=>{hap('pop');toast('LINE を ひらく(モック)')});A('msg',()=>{hap('pop');toast('メッセージ を ひらく(モック)')});
  A('save',()=>{hap('shutter','カシャッ(保存)');if(!Q9RM()){C.animate([{transform:'none'},{transform:'translateY(10px) scale(.97)',offset:.3},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'});const g=S.querySelector('.q9fl')||(()=>{S.insertAdjacentHTML('beforeend','<i class="q9fl"></i>');return S.querySelector('.q9fl')})();g.animate([{opacity:0},{opacity:.85,offset:.15},{opacity:0}],{duration:420})}toast('チェキを 写真に 保存しました')});
  A('more',()=>{hap('pop');try{openShare({t:`Lattag で つながろう ・ ${m.n}(${m.id})\nhttps://lattag.app/u/${m.id.replace('@','')}`,h:m.n})}catch(e){}})}
function q9Close(){const S=$('q9');if(!S)return;Q9.on=false;S.classList.remove('on');hap('soft',null,{norip:1})}
/* 入口:プロフィールの QR ・ Friends の「QR を 見せる」 */
{const _o=openPrf;openPrf=function(f){_o(f);try{const b=document.querySelector('#prf .pact button[data-a="qr"]');b&&b.addEventListener('click',e=>{e.stopImmediatePropagation();const C=$('pck');C&&C.classList.remove('fl');q9Open()},true)}catch(e){}}}
document.addEventListener('click',e=>{const b=e.target.closest&&e.target.closest('#yst [data-x8="qr"],.fq78 [data-a="myqr"]');if(!b)return;e.stopPropagation();e.preventDefault();hap('pop');q9Open()},true);
Object.assign(window.__kit||(window.__kit={}),{q9:()=>q9Open(),q9Flip:()=>{const C=$('q9c');C&&C.click()},q9Copy:()=>{const b=document.querySelector('#q9 [data-a="copy"]');b&&b.click()}});
(()=>{const C=$('ctl');if(!C||C.querySelector('[data-q9]'))return;C.insertAdjacentHTML('beforeend','<button data-q9="1">QR(チェキ)</button>');C.querySelector('[data-q9]').onclick=()=>q9Open()})();
