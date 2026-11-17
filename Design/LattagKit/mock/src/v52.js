/* ================= v52 プロフィールを その場で 部分的に なおす ================= */
fMe=function(){const c=OB.name||OB.cus?OB.col:0;return{n:OB.name||'ゆい',id:'@yui_0612',c:OBP[c],ci:c,tags:(OB.tags&&OB.tags.length?OB.tags:(OB.cus?[]:['#カフェ','#音楽','#夜型'])).slice(0,3),img:OB.img}};
var PD=null;
const PEPH=['d','a','c','e','b','f'];
function pfEdit(on){const P=$('prf');if(on){if(PF.edit)return;const m=fMe();PF.edit=true;PD={n:m.n,col:m.ci,img:m.img,tags:m.tags.slice(),o:JSON.stringify([m.n,m.ci,m.img,m.tags])};
    P.classList.add('ed');$('pbd').scrollTo({top:0,behavior:'smooth'});hap('pop','ぷにっ(なおす)');
    const C=$('pck');C.classList.remove('fl');
    const bar=document.createElement('div');bar.className='phe';bar.id='phe';bar.innerHTML=`<button class="cx" id="pecx">キャンセル</button><b>Edit</b><button class="ok" id="peok">完了</button>`;P.appendChild(bar);
    bar.animate([{transform:'translateY(-30px)',opacity:0},{transform:'none',opacity:1}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'});
    /* チェキの 上に 小さな バッジ */
    const fa=C.querySelector('.fa');fa.insertAdjacentHTML('beforeend',`<button class="pbg1" data-s="pic" aria-label="写真・色を かえる"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg></button><button class="pbg2" data-s="name" aria-label="名前を かえる"><svg viewBox="0 0 24 24"><path d="M4 20h4L19 9l-4-4L4 16z"/></svg></button>`);
    fa.querySelectorAll('[data-s]').forEach(b=>b.onclick=e=>{e.stopPropagation();peGo(b.dataset.s)});
    const pn=P.querySelector('.pnm');pn.insertAdjacentHTML('afterend',`<div class="ped" id="ped">
      <div class="pes" data-s="pic"><div class="peh"><b>Photo</b></div><div class="pep" id="pep"></div></div>
      <div class="pes" data-s="name"><div class="peh"><b>Name</b><em id="pecnt"></em></div><label class="pen"><input id="pein" maxlength="12" autocomplete="off" value="${rmEsc(PD.n)}"><button id="peclr" aria-label="けす">✕</button></label></div>
      <div class="pes" data-s="tag"><div class="peh"><b>Tags</b><em id="petc"></em></div><div class="pet" id="pet"></div><div class="pesg" id="pesg"></div></div></div>`);
    $('ped').querySelectorAll('.pes').forEach((s,i)=>s.animate([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:480,delay:120+i*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'}));
    peDraw();peBindStatic()}
  else{PF.edit=false;P.classList.remove('ed');$('phe')&&$('phe').remove();$('ped')&&$('ped').remove();P.querySelectorAll('.pbg1,.pbg2').forEach(b=>b.remove());pfTagsDraw(fMe().tags)}}
function peGo(s){const el=document.querySelector(`#ped .pes[data-s="${s}"]`);if(!el)return;hap('sel','コツッ');$('pbd').scrollTo({top:el.offsetTop-150,behavior:'smooth'});
  setTimeout(()=>{el.animate([{boxShadow:'0 0 0 0 rgba(59,211,90,0)'},{boxShadow:'0 0 0 3px rgba(59,211,90,.9)'},{boxShadow:'0 0 0 0 rgba(59,211,90,0)'}],{duration:900});if(s==='name')$('pein').focus({preventScroll:true})},420)}
function pePic(){const p=$('prf').querySelector('.pck .pic');if(!p)return;const c=OBP[PD.col];
  if(PD.img){p.style.background='';p.style.backgroundImage=`url(${PH[PD.img===true?'d':PD.img]})`;p.style.backgroundSize='cover';p.style.backgroundPosition='center';const b=p.querySelector('b');b&&(b.style.display='none')}
  else{p.style.background=`radial-gradient(circle at 30% 26%,#fff9,transparent 42%),linear-gradient(150deg,${c[0]},${c[1]})`;let b=p.querySelector('b');if(!b){b=document.createElement('b');p.prepend(b)}b.style.display='';b.textContent=[...PD.n][0]||'?'}
  const g=$('prf').querySelector('.pbg .g');g&&(g.style.background=`linear-gradient(160deg,${c[0]},${c[1]})`)}
function peName(){const P=$('prf');P.querySelector('.pck .nm').textContent=PD.n||' ';P.querySelector('.pnm b').textContent=PD.n||' ';const b=P.querySelector('.pck .pic b');if(b&&!PD.img)b.textContent=[...PD.n][0]||'?';$('pecnt').textContent=[...PD.n].length+' / 12'}
function pfTagsDraw(tags,ed){const H=$('phero');if(!H)return;H.querySelectorAll('.pst.me').forEach(s=>s.remove());
  tags.forEach((t,i)=>{const [X,Y,R,S]=PFP[i],c=PFT[i];const b=document.createElement('button');b.className='pst me';b.dataset.i=i;b.style.cssText=`--x:${X}px;--y:${Y}px;--r:${R}deg;--s:${S};--bg:${c[0]};--fg:${c[1]};--d:${i}`;b.innerHTML=rmEsc(t)+(ed?`<i class="px" data-t="${rmEsc(t)}" aria-label="はずす">✕</i>`:'');H.appendChild(b);
    if(ed)b.querySelector('.px').onclick=e=>{e.stopPropagation();peTag(t,false)}});
  if(ed&&tags.length<3){const i=tags.length,[X,Y,R]=PFP[i];const b=document.createElement('button');b.className='pst me padd';b.style.cssText=`--x:${X}px;--y:${Y}px;--r:${R}deg;--s:1;--d:${i}`;b.innerHTML='+ tag';b.onclick=e=>{e.stopPropagation();peGo('tag')};H.appendChild(b)}}
function peTag(t,add){if(add){if(PD.tags.includes(t))return;if(PD.tags.length>=3){hap('warn','やわらかく2回(3つまで)');shake($('pet'));_toast('タグは 3つまで');return}PD.tags.push(t);hap('pop','ペタッ(タグ)')}
  else{PD.tags=PD.tags.filter(x=>x!==t);hap('tick','ペリッ(はずす)')}peDraw(add?t:null)}
function peDraw(nw){const P=$('prf');const sl=$('pep')?$('pep').scrollLeft:0;
  $('pep').innerHTML=`<button class="cam" data-k="cam"><svg viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.4h6.8L17 8h3v11H4z"/><circle cx="12" cy="13.2" r="3.4"/></svg></button>`+PEPH.map(p=>`<button class="ph${PD.img===p||(PD.img===true&&p==='d')?' on':''}" data-p="${p}" style="background-image:url(${PH[p]})"></button>`).join('')+`<i class="sep"></i>`+OBP.map((c,i)=>`<button class="co${!PD.img&&PD.col===i?' on':''}" data-c="${i}" style="background:linear-gradient(150deg,${c[0]},${c[1]})"></button>`).join('');
  $('pep').querySelectorAll('button').forEach(b=>b.onclick=()=>{if(b.dataset.k){hap('shutter','カシャッ(カメラ)');PD.img='e'}else if(b.dataset.p){PD.img=b.dataset.p;hap('pop','ぷにっ(写真)')}else{PD.img=false;PD.col=+b.dataset.c;hap('sel','コツッ(色)')}pePic();peDraw();$('pck').animate([{transform:'rotate(-3deg) scale(1)'},{transform:'rotate(-1deg) scale(1.05)'},{transform:'rotate(-3deg) scale(1)'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})});
  $('pet').innerHTML=[0,1,2].map(i=>{const t=PD.tags[i],c=PFT[i];return t?`<span class="tc${t===nw?' nw':''}" style="--bg:${c[0]};--fg:${c[1]}">${rmEsc(t)}<button data-t="${rmEsc(t)}" aria-label="はずす">✕</button></span>`:`<span class="tc e">+</span>`}).join('');
  $('pet').querySelectorAll('button').forEach(b=>b.onclick=()=>peTag(b.dataset.t,false));
  const sg=[...new Set([...OBT,'#夕焼け','#放課後','#帰り道'])].filter(t=>!PD.tags.includes(t));
  $('pesg').innerHTML=sg.map(t=>`<button data-t="${t}">${t}</button>`).join('')+`<label class="cu"><span>#</span><input id="pecu" maxlength="10" placeholder="じぶんで"></label>`;
  $('pesg').querySelectorAll('button').forEach(b=>b.onclick=()=>{peTag(b.dataset.t,true)});
  const cu=$('pecu');cu.onkeydown=e=>{if(e.key==='Enter'&&!e.isComposing){const v=cu.value.trim().replace(/^[#＃]/,'');if(v){peTag('#'+v,true)}}};
  $('pep').scrollLeft=sl;$('petc').textContent=PD.tags.length+' / 3';pfTagsDraw(PD.tags,true);peName();peDirty()}
function peDirty(){const ch=JSON.stringify([PD.n,PD.col,PD.img,PD.tags])!==PD.o;const ok=$('peok');ok&&ok.classList.toggle('on',ch&&!!PD.n.trim())}
function peBindStatic(){const i=$('pein');i.addEventListener('input',e=>{PD.n=i.value.slice(0,12);peName();peDirty();if(!e.isComposing)hap('tick',null,{norip:1})});
  $('peclr').onclick=e=>{e.preventDefault();i.value='';PD.n='';peName();peDirty();i.focus();hap('tick')};
  $('peok').onclick=()=>{if(!PD.n.trim()){hap('warn','やわらかく2回(名前が ない)');peGo('name');return}if(!$('peok').classList.contains('on')){pfEdit(false);hap('soft');return}
    OB.name=PD.n.trim();OB.col=PD.col;OB.img=PD.img;OB.tags=PD.tags.slice();OB.cus=true;hap('success','トトトン(保存)',{norip:1});
    const C=$('pck');C.animate([{transform:'rotate(-3deg)'},{transform:'rotate(2deg) scale(1.08)'},{transform:'rotate(-3deg)'}],{duration:520,easing:'cubic-bezier(.3,1.6,.4,1)'});
    pfEdit(false);try{renderFriends()}catch(e){}_toast('プロフィールを 保存しました')};
  $('pecx').onclick=()=>{const ch=JSON.stringify([PD.n,PD.col,PD.img,PD.tags])!==PD.o;if(!ch){hap('soft');peRevert();return}
    actSheet('変更を すてますか?',[{l:'すてる',red:1,fn:()=>{ovClose('acs');peRevert()}}])}}
function peRevert(){const m=fMe();PD={n:m.n,col:m.ci,img:m.img,tags:m.tags.slice(),o:''};pePic();peName();pfEdit(false)}
/* ふだんの ときも:チェキの 名前・タグを 長押し → その 部分だけ なおす */
{const _op=openPrf;openPrf=function(f){PF.edit=false;_op(f);const P=$('prf');const nb=P.querySelector('.pnm b');if(nb){nb.style.cursor='pointer';nb.onclick=()=>{pfEdit(true);setTimeout(()=>peGo('name'),300)}}
  P.querySelectorAll('.pst.me').forEach(s=>{let t=0;s.addEventListener('pointerdown',()=>{t=setTimeout(()=>{if(!PF.edit){hap('thud','ドン(なおす)',{norip:1});pfEdit(true);setTimeout(()=>peGo('tag'),300)}},560)});['pointerup','pointerleave','pointermove'].forEach(ev=>s.addEventListener(ev,()=>clearTimeout(t)))})}}
{const _cp=closePrf;closePrf=function(){if(PF.edit){PF.edit=false}_cp()}}
