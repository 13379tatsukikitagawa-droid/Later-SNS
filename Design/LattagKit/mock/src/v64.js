/* ================= v64 ・ Mondo ページを かっこよく =================
   点の 地球(昼は 白 ・ 夜は 街の 灯り)+「9:00 の 線」+ 浮かぶ チェキ + 人気の タグ(光の 強さだけ) */
const MN={rot:0,boost:0,raf:0,P:null,last:'',cv:null};
const MNC=[{n:'TOKYO',la:35.7,lo:139.7,p:'a'},{n:'SEOUL',la:37.6,lo:127},{n:'SYDNEY',la:-33.9,lo:151.2},{n:'DUBAI',la:25.2,lo:55.3},{n:'PARIS',la:48.9,lo:2.3,p:'e'},{n:'LONDON',la:51.5,lo:-.1},{n:'LAGOS',la:6.5,lo:3.4},{n:'SÃO PAULO',la:-23.5,lo:-46.6,p:'c'},{n:'NEW YORK',la:40.7,lo:-74,p:'f'},{n:'MEXICO CITY',la:19.4,lo:-99.1},{n:'LOS ANGELES',la:34,lo:-118.2},{n:'HONOLULU',la:21.3,lo:-157.9}];
const MNT=['#夕焼け','#放課後','#帰り道'];
function mnPts(){if(MN.P)return MN.P;const N=2800,P=[],G=Math.PI*(3-Math.sqrt(5));
  for(let i=0;i<N;i++){const y=1-(i/(N-1))*2,r=Math.sqrt(1-y*y),th=G*i,lat=Math.asin(y),lon=Math.atan2(Math.sin(th)*r,Math.cos(th)*r);
    const land=Math.sin(lon*2.1+1.3)*Math.cos(lat*2.6)+Math.sin(lon*4.7+lat*3.1)*.55+Math.cos(lon*1.3-lat*5.2)*.35>.25;
    P.push({lat,lon,land,city:land&&((i*7919)%100)<17})}
  return MN.P=P}
function mnDraw(){MN.raf=requestAnimationFrame(mnDraw);const cv=document.getElementById('mncv');if(!cv)return;
  const vis=$('home').classList.contains('on')&&window.HPG&&Math.abs(HPG.x+3*390)<390;if(!vis)return;
  const rm=matchMedia('(prefers-reduced-motion:reduce)').matches;MN.rot+=rm?0:(.0016+MN.boost);MN.boost*=.95;
  const x=cv.getContext('2d'),D=2,W=310,R=124,cx=155,cy=155,tilt=.38,sun=.2,l9=sun-Math.PI/4;x.setTransform(D,0,0,D,0,0);x.clearRect(0,0,W,W);
  /* 大気(地球の ふちの 光) */
  const g=x.createRadialGradient(cx,cy,R*.92,cx,cy,R*1.18);g.addColorStop(0,'rgba(80,220,120,.42)');g.addColorStop(1,'rgba(80,220,120,0)');x.fillStyle=g;x.beginPath();x.arc(cx,cy,R*1.18,0,6.283);x.fill();
  const b=x.createRadialGradient(cx-R*.35,cy-R*.4,R*.1,cx,cy,R);b.addColorStop(0,'#13301F');b.addColorStop(1,'#050A07');x.fillStyle=b;x.beginPath();x.arc(cx,cy,R,0,6.283);x.fill();x.strokeStyle='rgba(126,224,143,.45)';x.lineWidth=1;x.beginPath();x.arc(cx,cy,R,0,6.283);x.stroke();
  const pr=(lat,lo)=>{const X=Math.cos(lat)*Math.sin(lo),Y=Math.sin(lat),Z=Math.cos(lat)*Math.cos(lo);const Y2=Y*Math.cos(tilt)-Z*Math.sin(tilt),Z2=Y*Math.sin(tilt)+Z*Math.cos(tilt);return [cx+X*R,cy-Y2*R,Z2]};
  for(const p of mnPts()){const lo=p.lon+MN.rot,[sx,sy,z]=pr(p.lat,lo);if(z<0)continue;const day=Math.cos(lo-sun)*Math.cos(p.lat),e=.35+z*.65;
    if(p.land){if(day>0){x.fillStyle=`rgba(245,243,236,${(.35+day*.6)*e})`;x.fillRect(sx-1.35,sy-1.35,2.7,2.7)}else if(p.city){x.fillStyle=`rgba(200,242,90,${.9*e})`;x.fillRect(sx-1,sy-1,2,2)}else{x.fillStyle=`rgba(245,243,236,${.13*e})`;x.fillRect(sx-.9,sy-.9,1.8,1.8)}}
    else{x.fillStyle=`rgba(245,243,236,${(day>0?.07:.035)*e})`;x.fillRect(sx-.5,sy-.5,1,1)}}
  /* 9:00 の 線 */
  x.save();x.strokeStyle='rgba(200,242,90,.95)';x.lineWidth=1.6;x.shadowColor='rgba(200,242,90,.9)';x.shadowBlur=8;x.setLineDash([2,4]);x.beginPath();let st=false;
  for(let la=-1.45;la<=1.45;la+=.04){const [sx,sy,z]=pr(la,l9);if(z<0){st=false;continue}st?x.lineTo(sx,sy):x.moveTo(sx,sy);st=true}x.stroke();x.restore();
  /* 街 と 浮かぶ チェキ */
  let near=null,nd=9;const lk=!shots;
  MNC.forEach(c=>{const la=c.la*Math.PI/180,lo=c.lo*Math.PI/180+MN.rot,[sx,sy,z]=pr(la,lo);let d=((lo-l9)%6.283+6.283)%6.283;d=Math.min(d,6.283-d);
    if(z>0&&d<nd){nd=d;near=c}
    if(z>0){const hot=d<.09;x.fillStyle=hot?'#C8F25A':'rgba(255,255,255,.85)';x.beginPath();x.arc(sx,sy,hot?3.2:2,0,6.283);x.fill();
      if(hot){const t=(performance.now()%1400)/1400;x.strokeStyle=`rgba(200,242,90,${1-t})`;x.lineWidth=1.4;x.beginPath();x.arc(sx,sy,3+t*14,0,6.283);x.stroke()}}
    if(c.p){const el=document.getElementById('mnp-'+c.p);if(el){if(z<.15){el.style.opacity=0}else{const s=.62+z*.5;el.style.opacity=Math.min(1,(z-.15)*3);el.style.transform=`translate(${sx.toFixed(1)}px,${(sy-6).toFixed(1)}px) scale(${s.toFixed(3)}) rotate(${((sx-cx)/R*8).toFixed(1)}deg)`}}}});
  /* いま 9:00 の 街 */
  if(near&&near.n!==MN.last){MN.last=near.n;const N=document.getElementById('mnnc');if(N){N.textContent=near.n;const w=N.parentElement;w.classList.remove('ch');void w.offsetWidth;w.classList.add('ch')}
    if(window.HPG&&HPG.i===3)hap('tick','コツッ(9:00 の 街が かわった)',{norip:1,gap:400})}}
function mnHTML(){const lk=!shots,m=ORB&&ORB.A.mondo;
  return hpHead(3,'mondo',lk?'LOCKED':'TOP 3')+`<span class="mnsub hpe">the world, <b>yesterday.</b></span>
    <div class="mng${lk?' lk':''}" id="mng" role="img" aria-label="世界の 地図。いま 朝 9:00 の 街から、きのうの 写真が ひらく"><canvas id="mncv" width="620" height="620"></canvas>${MNC.filter(c=>c.p).map(c=>`<span class="mnp" id="mnp-${c.p}" style="opacity:0"><i style="background-image:url(${PH[c.p]})"></i></span>`).join('')}</div>
    <div class="mnr hpe${lk?' lk':''}">${MNT.map((t,j)=>`<div class="r" style="--j:${j}"><span class="n">0${j+1}</span><span class="t">${t}</span><span class="l">${[5,8,11,14,11].map((h,k)=>`<i class="${k<5-j?'on':''}" style="height:${h}px"></i>`).join('')}</span><span class="k">${ICO.lock}</span></div>`).join('')}</div>
    <span class="mnn hpe"><i></i><b>NOW 9:00</b>·<em id="mnnc">${MN.last||'LONDON'}</em></span>`+hpGoBtn(lk?'Shoot first':'Explore',lk)}
{const _hr=hpRender;hpRender=function(only){_hr(only);try{if(!only||only===3){const C=$('hpc3');if(!C||!ORB)return;C.className='hpc pm';C.innerHTML=mnHTML();
  const lk=!shots,m=ORB.A.mondo;C.querySelector('[data-a="go"]').onclick=()=>{if(lk){hap('pop');ORB.A.shoot&&ORB.A.shoot.run();return}hap('pop');m.run()};
  $('mng').onclick=e=>{e.stopPropagation();MN.boost=.06;hap('soft','ふわっ(地球を まわす)',{norip:1})};
  MN.last='';if(!MN.raf)MN.raf=requestAnimationFrame(mnDraw)}}catch(e){console.error(e)}};window.hpRender=hpRender}
try{hpRender(3)}catch(e){console.error(e)}
window.MN=MN;
/* 見本づくり ・ テスト用(実機には 入れない) */
window.__kit={FR:()=>FR,GRP:()=>GRP,TW:()=>TW,hpGo:i=>hpGo(i),MN:()=>MN,
  openFC:(i)=>openFC(FR[i||0],document.querySelector('.fck')||document.body),openDM:i=>openDM(FR[i||0]),openAdd:()=>openAdd(),
  openMe:()=>{try{return openMe()}catch(e){return 'x:'+e.message}},openTrip:()=>openTrip(),
  fillTrip:()=>{TW.g.n='京都 2泊3日';TW.g.m=FR.slice(0,3);try{twDraw()}catch(e){}},tripCreate:()=>tripCreate(),
  openPass:()=>openPass(GRP.find(g=>g.trip)),tripSet:()=>tripSet(GRP.find(g=>g.trip))};
