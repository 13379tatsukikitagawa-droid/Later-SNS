# アニメーション 一覧(モックの コードから 自動抽出)

- `el.animate([キーフレーム], {duration: ミリ秒, delay, easing})` が Web の アニメーション。**duration / delay / easing / キーフレームの 値は そのまま SwiftUI に 移す**。
- easing の 変換: `cubic-bezier(a,b,c,d)` → `.timingCurve(a,b,c,d, duration: 秒)`。b や d が 1 を 超える(はねる)ものも そのまま 使える。`linear` → `.linear`、`ease` → `.easeInOut`。
- `offset:.6` は 全体の 60% の 時点の キーフレーム(SwiftUI では `keyframeAnimator` の 各区間の 長さで 表す)。
- `fill:"backwards"` = delay 中は 最初の キーフレームの 見た目で 待つ。
- `clipPath: circle(...)` = 円が 広がって 画面が ひらく 表現 → SwiftUI では `.clipShape(Circle().scale(...))` か `mask`。


## app.js

### タグ画面(黒・2つまで)
- `app.js:130` **setMus()** 対象 `b`  
  `([{scale:'.86'},{scale:'1.05',offset:.6},{scale:'1'}],{duration:460,easing:'cubic-bezier(.3,1.5,.4,1)'})`
- `app.js:136` **onfinish()** 対象 `f`  
  `([{transform:'translate(0,0) scale(1)'},{transform:`translate(${dx*.5}px,${dy*.5-70}px) scale(1.14) rotate(-6deg)`,offset:.5},{transform:`translate(${dx}px,${dy}px) scale(.9)`,opacity:.2}],{duration:460,easing:'cubic-bezier(.4,0,.2,1)'})`
- `app.js:138` **onclick()** 対象 `s`  
  `([{transform:'scale(1)'},{transform:'scale(.9)',offset:.35},{transform:'scale(1)'}],{duration:260})`
### 画面の切りかえ
- `app.js:146` **fadeTo()** 対象 `to`  
  `([{opacity:0,transform:'scale(1.03)'},{opacity:1,transform:'none'}],{duration:ms,easing:'cubic-bezier(.2,.8,.2,1)'})`
- `app.js:147` **onfinish()** 対象 `from`  
  `([{opacity:1,transform:'none'},{opacity:0,transform:'scale(.96)'}],{duration:ms*.8,fill:'forwards'})`
- `app.js:157` **onfinish()** 対象 `const an=from`  
  `([{opacity:1,transform:'none',filter:'blur(0px)'},{opacity:0,transform:'scale(.93)',filter:'blur(8px)'}],{duration:320,easing:'cubic-bezier(.5,0,.6,1)',fill:'forwards'})`
- `app.js:159` **onfinish()** 対象 `$('win')`  
  `(WK_IN,{duration:720,easing:'cubic-bezier(.6,0,.25,1)'})`
- `app.js:160` **onfinish()** 対象 `$('live')`  
  `([{transform:'scale(1.1)'},{transform:'scale(.985)',offset:.6},{transform:'scale(1)'}],{duration:720,easing:'cubic-bezier(.6,0,.25,1)'})`
- `app.js:162` **onfinish()** 対象 `BR.forEach((b,i)=>b`  
  `([{transform:`translate(${S[i][0]}px,${S[i][1]}px)`,opacity:0},{transform:`translate(${BD[i][0]*11}px,${BD[i][1]*11}px)`,opacity:1,offset:.58},{transform:`translate(${-BD[i][0]*3}px,${-BD[i][1]*3}px)`,offset:.8},{transform:'translate(0,0)'}],{duration:720,easing:'cubic-bezier(.6,0,.25,1)'})`
- `app.js:168` **leaveCam()** 対象 `toCam._from.getAnimations().forEach(a=>a.cancel())}$('win')`  
  `(WK_OUT,{duration:420,easing:'cubic-bezier(.4,0,.2,1)',fill:'forwards'})`
- `app.js:169` **leaveCam()** 対象 `nx`  
  `([{opacity:0,transform:'scale(1.04)'},{opacity:1,transform:'none'}],{duration:420,delay:100,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'})`
- `app.js:170` **onfinish()** 対象 `cam`  
  `([{opacity:1},{opacity:0}],{duration:380,delay:120,fill:'forwards'})`
### 撮影画面
- `app.js:230` **snap()** 対象 `disc`  
  `([{transform:'scale(.36)'},{transform:'scale(.1)',offset:.3},{transform:'scale(1.1)',offset:.75},{transform:'scale(1)'}],{duration:320,easing:'cubic-bezier(.3,1.3,.5,1)'})`
- `app.js:231` **onfinish()** 対象 `r`  
  `([{transform:'scale(.6)',opacity:1},{transform:'scale(2.4)',opacity:0}],{duration:520,easing:'cubic-bezier(.2,.8,.2,1)'})`
- `app.js:242` **setMode()** 対象 `$('live')`  
  `([{filter:'brightness(1.25)'},{filter:'none'}],{duration:240,easing:'ease-out'})`
- `app.js:265` **onfinish()** 対象 `r`  
  `([{transform:'scale(.6)',opacity:1},{transform:'scale(2.2)',opacity:0}],{duration:480,easing:'cubic-bezier(.2,.8,.2,1)'})`
- `app.js:280` **shoot()** 対象 `bl`  
  `(mvd?[{opacity:0},{opacity:.7,offset:.3},{opacity:0}]:[{opacity:0},{opacity:1,offset:.25},{opacity:1,offset:.55},{opacity:0}],{duration:mvd?220:150})`
- `app.js:281` **onfinish()** 対象 `wf`  
  `([{opacity:flash?1:.55},{opacity:0}],{duration:flash?420:260,easing:'ease-out'})`
- `app.js:281` **onfinish()** 対象 `f`  
  `([{opacity:.85},{opacity:0}],{duration:360})`
- `app.js:287` **onfinish()** 対象 `milk`  
  `([{opacity:0},{opacity:.96}],{duration:420,fill:'forwards'})`
- `app.js:288` **onfinish()** 対象 `ck`  
  `([{left:'16px',top:'112px',width:'358px',height:'500px',borderRadius:'30px',transform:'rotate(0deg)'},{left:'95px',top:'250px',width:'200px',height:'250px',borderRadius:'5px',transform:'rotate(-5deg)'}],{duration:480,easing:E,fill:'forwards'})`
- `app.js:289` **onfinish()** 対象 `im`  
  `([{left:'0px',top:'0px',right:'0px',bottom:'0px'},{left:'10px',top:'10px',right:'10px',bottom:'42px'}],{duration:480,easing:E,fill:'forwards'})`
- `app.js:290` **onfinish()** 対象 `dd`  
  `([{opacity:0},{opacity:1}],{duration:250,delay:300,fill:'forwards'})`
- `app.js:290` **onfinish()** 対象 `if(mt)mt`  
  `([{opacity:0},{opacity:1}],{duration:250,delay:300,fill:'forwards'})`
- `app.js:296` **onfinish()** 対象 `ck`  
  `([{left:'95px',top:'250px',width:'200px',height:'250px',transform:'rotate(-5deg)'},{left:'150px',top:'330px',width:'130px',height:'160px',transform:'rotate(8deg)',offset:.5},{left:tx+'px',top:ty+'px',width:tw+'px',height:th+'px',transform:'rotate(-4deg)'}],{duration:600,easing:'cubic-bezier(.5,0,.25,1)',fill:'forwards'})`
- `app.js:297` **onfinish()** 対象 `im`  
  `([{left:'10px',top:'10px',right:'10px',bottom:'42px'},{left:'5px',top:'5px',right:'5px',bottom:'17px'}],{duration:600,fill:'forwards'})`
- `app.js:297` **onfinish()** 対象 `dd`  
  `([{opacity:1},{opacity:0}],{duration:240,fill:'forwards'})`
- `app.js:297` **onfinish()** 対象 `if(mt2)mt2`  
  `([{opacity:1},{opacity:0}],{duration:240,fill:'forwards'})`
- `app.js:298` **onfinish()** 対象 `$('tcard')`  
  `([{transform:'scale(1)'},{transform:'scale(1.03)',offset:.3},{transform:'scale(1)'}],{duration:420,easing:'cubic-bezier(.3,1.5,.5,1)'})`
### ホーム(v17 の形 ・ 撮ったあとは 毎回ここへ)
- `app.js:367` **onclick()** 対象 `g`  
  `([{opacity:1,transform:'none'},{opacity:0,transform:'scale(.96)'}],{duration:260})`
- `app.js:372` **homeIn()** 対象 `const A=(el,k,o)=>el&&el`  
  `(k,Object.assign({fill:'backwards',easing:'cubic-bezier(.2,.9,.25,1)'},o))`
### ともだち(12人まで ・ ふって つながる ・ つつく)
- `app.js:413` **onfinish()** 対象 `r`  
  `([{transform:'scale(.4)',opacity:1},{transform:'scale(5.5)',opacity:0}],{duration:900,delay:i*120,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'})`
- `app.js:414` **onfinish()** 対象 `w`  
  `([{transform:'scale(.3) rotate(-10deg)',opacity:0},{transform:'scale(1.15) rotate(3deg)',opacity:1,offset:.45},{transform:'scale(1) rotate(-2deg)',opacity:1,offset:.8},{transform:'scale(1.05)',opacity:0}],{duration:1100,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `app.js:459` **onclick()** 対象 `c`  
  `([{opacity:0,transform:'translateY(18px) scale(.96)'},{opacity:1,transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `app.js:473` **onclick()** 対象 `if(was&&JN)$('jcard')`  
  `([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `app.js:485` **onclick()** 対象 `r`  
  `([{transform:'scale(.9)',opacity:0},{transform:'scale(1.03)',opacity:1,offset:.6},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})`
### 現像ビュー(カードを おすと:濃くなっていく ところを 見る)
- `app.js:549` **f()** 対象 `card&&card`  
  `([{transform:`rotate(var(--r)) scale(1)`},{transform:'rotate(var(--r)) scale(1.04)',offset:.3},{transform:'rotate(var(--r)) scale(1)'}],{duration:460,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:555` **openDvx()** 対象 `S.querySelectorAll('.dxp').forEach((p,j)=>p`  
  `([{opacity:0,transform:'translateY(46px) scale(.9)'},{opacity:1,transform:'none'}],{duration:620,delay:160+j*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
### Later yesterday(昨日の ホーム:Mondo / グループ / カレンダー)
- `app.js:589` **onclick()** 対象 `r`  
  `([{transform:'scale(.9)',opacity:0},{transform:'scale(1.03)',opacity:1,offset:.6},{transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `app.js:598` **ytab()** 対象 `t`  
  `([{opacity:0,transform:'translateY(16px)'},{opacity:1,transform:'none'}],{duration:360,easing:'cubic-bezier(.2,.9,.25,1)'})`
- `app.js:602` **onfinish()** 対象 `r`  
  `([{transform:'translate(-50%,-50%) scale(.5)',opacity:.9},{transform:'translate(-50%,-50%) scale(3.6)',opacity:0}],{duration:640,delay:i*110,easing:'cubic-bezier(.2,.8,.3,1)',fill:'backwards'})`
- `app.js:603` **yIntro()** 対象 `s,#ytg .ypl,#ytg .yme,#ytg .ysamp,#ytg .grow,#ynav')].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(26px) scale(.97)'},{opacity:1,transform:'none'}],{duration:560,delay:1000+i*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `app.js:603` **yIntro()** 対象 `if(!$('ylock').classList.contains('hide'))$('ylock')`  
  `([{opacity:0},{opacity:1}],{duration:500,delay:1500,fill:'backwards'})`
- `app.js:606` **onfinish()** 対象 `Y`  
  `([{clipPath:`circle(0px at ${o.x}px ${o.y}px)`},{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`}],{duration:700,easing:'cubic-bezier(.3,.85,.25,1)'})`
- `app.js:611` **onfinish()** 対象 `Y`  
  `([{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`},{clipPath:`circle(0px at ${o.x}px ${o.y}px)`}],{duration:520,easing:'cubic-bezier(.5,0,.7,.3)',fill:'forwards'})`
- `app.js:615` **dbl()** 対象 `el`  
  `([{transform:'scale(1)'},{transform:'scale(.84)',offset:.25},{transform:'scale(1.14)',offset:.6},{transform:'scale(1)'}],{duration:440,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:616` **dbl()** 対象 `el`  
  `([{transform:'scale(1)'},{transform:'scale(.9)',offset:.4},{transform:'scale(1)'}],{duration:200})`
- `app.js:620` **hintDbl()** 対象 `HAV`  
  `([{transform:'scale(1)'},{transform:'scale(1.16)',offset:.4},{transform:'scale(1)'}],{duration:320,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:621` **onfinish()** 対象 `r`  
  `([{transform:'translate(-50%,-50%) scale(.6)',opacity:.8},{transform:'translate(-50%,-50%) scale(2.6)',opacity:0}],{duration:800})`
- `app.js:642` **onclick()** 対象 `b`  
  `([{scale:1},{scale:.82,offset:.3},{scale:1.18,offset:.65},{scale:1}],{duration:480,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:643` **onclick()** 対象 `b`  
  `([{rotate:'var(--r)'},{rotate:'calc(var(--r) + 14deg)',offset:.3},{rotate:'calc(var(--r) - 10deg)',offset:.62},{rotate:'var(--r)'}],{duration:520,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `app.js:644` **yHeroIn()** 対象 `const A=(el,k,o)=>el&&el`  
  `(k,Object.assign({fill:'backwards',easing:'cubic-bezier(.3,1.4,.5,1)'},o))`
- `app.js:654` **onclick()** 対象 `r`  
  `([{rotate:'0deg'},{rotate:'540deg'}],{duration:900,easing:'cubic-bezier(.2,.8,.2,1)'})`
- `app.js:654` **onclick()** 対象 `$('ycore')`  
  `([{scale:1},{scale:.9,offset:.2},{scale:1.1,offset:.5},{scale:1}],{duration:560,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:675` **up()** 対象 `c`  
  `([{transform:c.style.transform},{transform:'translate(-150px,-30px) rotate(-18deg)',offset:.45},{transform:'translate(30px,16px) rotate(9deg) scale(.9)'}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)'})`
- `app.js:696` **onfinish()** 対象 `b`  
  `([{transform:'translate(-50%,-50%) scale(.4)',opacity:1},{transform:`translate(calc(-50% + ${Math.cos(a)*r}px),calc(-50% + ${Math.sin(a)*r}px)) scale(1.1) rotate(${Math.random()*80-40}deg)`,opacity:0}],{duration:620,easing:'cubic-bezier(.2,.8,.3,1)'})`
- `app.js:742` **openFriend()** 対象 `F.querySelectorAll('.fp,.fr0').forEach((x,i)=>x`  
  `([{opacity:0,transform:'translateY(18px) scale(.9)'},{opacity:1,transform:'none'}],{duration:480,delay:180+i*50,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
### オープニング(アプリを ひらいたとき ・ 約3.4秒)
- `app.js:754` **openAnims()** 対象 `OA.push(el`  
  `(k,Object.assign({fill:fill||'both',easing:'cubic-bezier(.2,.8,.2,1)'},o))`
- `app.js:796` **goShoot()** 対象 `m`  
  `([{transform:'scale(1)'},{transform:'scale(.95,.92)',offset:.3},{transform:'scale(1.04)'}],{duration:260})`
### 翌朝 9:00:現像 → 上映
- `app.js:815` **rp()** 対象 `$('fog')`  
  `([{opacity:.97,filter:'blur(0px)'},{opacity:.5,filter:'blur(6px)',offset:.6},{opacity:0,filter:'blur(10px)'}],{duration:1700,easing:'cubic-bezier(.4,0,.3,1)',fill:'forwards'})`
- `app.js:815` **rp()** 対象 `$('dvt')`  
  `([{opacity:1},{opacity:0}],{duration:900,fill:'forwards'})`
- `app.js:816` **rp()** 対象 `dch`  
  `([{transform:'rotate(-3deg)'},{transform:'rotate(-1.5deg) scale(1.01)',offset:.5},{transform:'rotate(-3deg)'}],{duration:1700,easing:'ease-in-out'})`
### 現像の画面(撮影のあと:前日の1枚が チェキのように ひらく → 投稿を えらぶ → ホーム)
- `app.js:861` **T()** 対象 `return}
  $('dkg')`  
  `([{opacity:0},{opacity:1}],{duration:900,fill:'forwards'})`
- `app.js:862` **T()** 対象 `$('dkslit')`  
  `([{transform:'scaleX(0)'},{transform:'scaleX(1)'}],{duration:420,delay:250,easing:'cubic-bezier(.3,1,.4,1)',fill:'forwards'})`
- `app.js:864` **onfinish()** 対象 `// チェキが スロットから 出てくる
  S`  
  `([{transform:'translateY(-104%)'},{transform:'translateY(-70%)',offset:.3},{transform:'translateY(-64%)',offset:.42},{transform:'translateY(-18%)',offset:.8},{transform:'translateY(0)'}],{duration:1400,delay:600,easing:'linear',fill:'forwards'})`
- `app.js:865` **onfinish()** 対象 `$('dkhint')`  
  `([{opacity:0},{opacity:1}],{duration:500})`
- `app.js:882` **rvDone()** 対象 `$('dkgl')`  
  `([{transform:'translateX(-120%) skewX(-18deg)',opacity:0},{opacity:1,offset:.2},{transform:'translateX(220%) skewX(-18deg)',opacity:0}],{duration:900,delay:120,easing:'cubic-bezier(.4,0,.2,1)'})`
- `app.js:883` **rvDone()** 対象 `C`  
  `([{transform:'scale(1) rotate(0deg)'},{transform:'scale(1.05) rotate(-2.5deg)',offset:.35},{transform:'scale(1) rotate(-1.5deg)'}],{duration:620,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'forwards'})`
- `app.js:884` **rvDone()** 対象 `$('dktg')`  
  `([{transform:'scale(2.6) rotate(-30deg)',opacity:0},{transform:'scale(.9) rotate(9deg)',opacity:1,offset:.6},{transform:'scale(1) rotate(7deg)',opacity:1}],{duration:460,delay:520,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'both'})`
- `app.js:886` **rvDone()** 対象 `$('rrs')`  
  `([{transform:'scale(3) rotate(-30deg)',opacity:0},{transform:'scale(.9) rotate(-9deg)',opacity:.95,offset:.6},{transform:'scale(1) rotate(-9deg)',opacity:.95}],{duration:520,delay:820,easing:'cubic-bezier(.3,1.5,.4,1)',fill:'both'})`
- `app.js:894` **up()** 対象 `if(!RV2.done)C`  
  `([{transform:C.style.transform},{transform:'none'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
### グループを つくる(1から:なまえ → つくる → リンク)
- `app.js:912` **gnSync()** 対象 `if(!matchMedia('(prefers-reduced-motion:reduce)').matches)$('gav')`  
  `([{scale:'1'},{scale:'1.16',offset:.4},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:916` **onfinish()** 対象 `e`  
  `([{translate:'0 0',opacity:1,scale:1},{translate:`${Math.cos(ang)*d}px ${Math.sin(ang)*d}px`,opacity:0,scale:.4}],{duration:900+Math.random()*500,easing:'cubic-bezier(.2,.8,.3,1)',delay:Math.random()*120})`
- `app.js:927` **openGnw()** 対象 `$('gav')`  
  `([{scale:'.3',opacity:0},{scale:'1.12',opacity:1,offset:.65},{scale:'1'}],{duration:600,delay:120,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `app.js:928` **onfinish()** 対象 `s`  
  `([{translate:'0px 0px',scale:.2,opacity:0},{translate:`${x}px ${y}px`,scale:1,opacity:1}],{duration:620,delay:360+i*70,easing:'cubic-bezier(.3,1.35,.5,1)',fill:'backwards'})`
- `app.js:929` **onfinish()** 対象 `[$('gp1'),$('gcta')].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:520,delay:700+i*80,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `app.js:943` **onclick()** 対象 `$('gp1')`  
  `([{opacity:1,transform:'none'},{opacity:0,transform:'translateY(-14px)'}],{duration:260,fill:'forwards',easing:'ease-in'})`
- `app.js:946` **onclick()** 対象 `s`  
  `([{translate:`${x}px ${y}px`,scale:1},{translate:`${x*.55}px ${y*.55}px`,scale:.85,offset:.45},{translate:'0px 0px',scale:.3,opacity:.0}],{duration:820,delay:i*30,easing:'cubic-bezier(.5,0,.7,.4)',fill:'forwards'})`
- `app.js:947` **onclick()** 対象 `if(!T)$('gav')`  
  `([{scale:'1'},{scale:'.9',offset:.7},{scale:'1.24',offset:.9},{scale:'1'}],{duration:980,easing:'ease-in-out'})`
- `app.js:948` **onclick()** 対象 `if(!T)$('gfl')`  
  `([{opacity:0},{opacity:.85,offset:.3},{opacity:0}],{duration:520})`
- `app.js:953` **onclick()** 対象 `s`  
  `([{translate:'0px 0px',scale:.3,opacity:0},{translate:`${x}px ${y}px`,scale:1,opacity:1}],{duration:520,delay:i*40,easing:'cubic-bezier(.3,1.35,.5,1)'})`
- `app.js:963` **onclick()** 対象 `s`  
  `([{translate:'0px 0px',scale:.3,opacity:0},{translate:`${x}px ${y}px`,scale:1.08,opacity:1,offset:.7},{translate:`${x}px ${y}px`,scale:1}],{duration:720,delay:60+i*50,easing:'cubic-bezier(.2,.9,.3,1)'})`
- `app.js:964` **onclick()** 対象 `$('gp2')`  
  `([{opacity:0,transform:'translateY(26px)'},{opacity:1,transform:'none'}],{duration:560,delay:260,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `app.js:971` **gnShowCode()** 対象 `t`  
  `([{opacity:0,filter:'blur(10px)',transform:'translateY(8px)'},{opacity:1,filter:'blur(0)',transform:'none'}],{duration:700,delay:600+i*110,easing:'cubic-bezier(.2,.7,.3,1)',fill:'backwards'})`
- `app.js:973` **onclick()** 対象 `tion:reduce)').matches)$('gwt').querySelectorAll('i').forEach((t,i)=>t`  
  `([{color:'#fff'},{color:'#9ED6A5',textShadow:'0 0 18px rgba(36,160,60,.9)'},{color:'#fff'}],{duration:700,delay:i*50})`
### はじめての 合図(説明しない。1回に 1つ・さわったら 消える・二度と 出ない)
- `app.js:1007` **onfinish()** 対象 `c.b`  
  `([{opacity:1,scale:'1'},{opacity:0,scale:'.85'}],{duration:180,easing:'ease-in'})`
- `app.js:1007` **onfinish()** 対象 `if(c.h)c.h`  
  `([{opacity:1},{opacity:0}],{duration:180})`
- `app.js:1014` **cmShow()** 対象 `b`  
  `([{opacity:0,transform:`translateY(${d.p==='up'?10:-10}px) scale(.8)`},{opacity:1,transform:'none'}],{duration:520,easing:'cubic-bezier(.3,1.5,.5,1)'})`
- `app.js:1015` **cmShow()** 対象 `if(h)h`  
  `([{opacity:0,scale:'1.25'},{opacity:1,scale:'1'}],{duration:520,easing:'cubic-bezier(.3,1.3,.5,1)'})`
### グループの 部屋(チャット):写真のまわりで 話す。タグが スタンプ。7日で 消える
- `app.js:1044` **onclick()** 対象 `b`  
  `([{scale:'1'},{scale:'1.15'},{scale:'1'}],{duration:300})`
- `app.js:1070` **onclick()** 対象 `if(t)t`  
  `([{scale:'2.2',rotate:'-30deg',opacity:0},{scale:'.9',opacity:1,offset:.6},{scale:'1'}],{duration:460,easing:'cubic-bezier(.3,1.5,.4,1)'})`
- `app.js:1071` **onclick()** 対象 `else el`  
  `([{opacity:0,transform:`translate(${me?30:-20}px,26px) scale(.7)`},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.4,1)'})`
- `app.js:1081` **rmStick()** 対象 `a&&a`  
  `([{scale:'2.6',opacity:0},{scale:'.85',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1114` **onfinish()** 対象 `e`  
  `([{transform:'translateY(-30px) rotate(0)',opacity:1},{transform:`translate(${(Math.random()-.5)*120}px,${420+Math.random()*260}px) rotate(${(Math.random()-.5)*900}deg)`,opacity:0}],{duration:1500+Math.random()*900,easing:'cubic-bezier(.2,.6,.4,1)',delay:Math.random()*250})`
- `app.js:1116` **rmAll()** 対象 `$('rmav').querySelectorAll('.rma').forEach((b,i)=>b`  
  `([{scale:'1'},{scale:'1.25'},{scale:'1'}],{duration:420,delay:i*70,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1122` **onclick()** 対象 `$('rmav').querySelectorAll('.rma').forEach((b,i)=>b`  
  `([{scale:'0',opacity:0},{scale:'1',opacity:1}],{duration:420,delay:160+i*55,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'})`
- `app.js:1123` **onclick()** 対象 `[...$('rml').children].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(18px)'},{opacity:1,transform:'none'}],{duration:420,delay:200+i*45,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
### はじめての 設定:サインイン → なまえ → タグ/アイコン → ともだち → 通知 → ながおしで はじめる
- `app.js:1147` **obSync()** 対象 `if(ch&&!obRM())$('obph')`  
  `([{scale:'1'},{scale:'1.06',offset:.4},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1167` **obTag()** 対象 `s&&s`  
  `([{scale:'2.4',opacity:0},{scale:'.9',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1172` **onclick()** 対象 `d&&d`  
  `([{scale:'0',opacity:0},{scale:'1.2',opacity:1,offset:.6},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1174` **onclick()** 対象 `p&&!obRM())[...L.querySelectorAll('.obrw:not(.inv)')].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(16px) scale(.96)'},{opacity:1,transform:'none'}],{duration:400,delay:i*70,easing:'cubic-bezier(.3,1.4,.4,1)',fill:'backwards'})`
- `app.js:1194` **obAct()** 対象 `if(!obRM())$('obn')`  
  `([{scale:'1'},{scale:'1.05'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1199` **sw()** 対象 `[X,F].forEach((e,i)=>e`  
  `([{opacity:0,transform:`translateY(${22*d}px)`},{opacity:1,transform:'none'}],{duration:440,delay:i*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `app.js:1201` **onfinish()** 対象 `return}
  F`  
  `([{opacity:1},{opacity:0}],{duration:160,fill:'forwards'})`
- `app.js:1201` **onfinish()** 対象 `X`  
  `([{opacity:1,transform:'none'},{opacity:0,transform:`translateY(${-14*d}px)`}],{duration:170,easing:'ease-in',fill:'forwards'})`
- `app.js:1205` **onfinish()** 対象 `s`  
  `([{transform:'none',opacity:0},{opacity:1,offset:.2},{transform:`translate(${-Math.cos(ang)*r}px,${-Math.sin(ang)*r}px) scale(.4)`,opacity:0}],{duration:520-p*200,easing:'cubic-bezier(.5,0,.9,.6)'})`
- `app.js:1220` **T()** 対象 `return}
  fl`  
  `([{opacity:1},{opacity:1,offset:.25},{opacity:0}],{duration:620,fill:'forwards'})`
- `app.js:1221` **T()** 対象 `lg`  
  `([{opacity:0,transform:'scale(3.2)',filter:'blur(16px)'},{opacity:1,transform:'scale(.92)',filter:'blur(0)',offset:.6},{transform:'scale(1.03)',offset:.8},{opacity:1,transform:'none'}],{duration:640,delay:160,easing:'cubic-bezier(.2,.8,.3,1)',fill:'both'})`
- `app.js:1222` **T()** 対象 `W`  
  `([{transform:'translate(0,0)'},{transform:'translate(-6px,3px)'},{transform:'translate(5px,-4px)'},{transform:'translate(-3px,2px)'},{transform:'none'}],{duration:320})`
- `app.js:1223` **T()** 対象 `ir`  
  `([{transform:'scale(0)'},{transform:'scale(3.4)'}],{duration:760,easing:'cubic-bezier(.6,0,.2,1)',fill:'forwards'})`
- `app.js:1231` **T()** 対象 `const A=(e,k,o)=>e`  
  `(k,Object.assign({fill:'forwards'},o))`
- `app.js:1249` **onfinish()** 対象 `$('obc')`  
  `([{transform:'translateY(-300px) rotate(-14deg)',opacity:0},{transform:'translateY(14px) rotate(2deg)',opacity:1,offset:.7},{transform:'none'}],{duration:900,delay:120,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'})`
- `app.js:1250` **onfinish()** 対象 `[$('obl'),$('obwall')].forEach(e=>e`  
  `([{opacity:0}],{duration:900,fill:'backwards',composite:'replace'})`
- `app.js:1251` **onfinish()** 対象 `[...$('obx').children,...$('obf').children].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:520,delay:700+i*80,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
### v28 暗室(Home の 下):ACTIVE / YESTERDAY / MONDO / ALBUMS / FRIEN
- `app.js:1312` **arcBindTile()** 対象 `if(rg)an=rg`  
  `([{strokeDashoffset:201},{strokeDashoffset:0}],{duration:520,fill:'forwards'})`
- `app.js:1344` **openAv()** 対象 `if(!matchMedia('(prefers-reduced-motion:reduce)').matches)$('avp')`  
  `([{transform:'scale(.9)',opacity:0,borderRadius:'60px'},{transform:'none',opacity:1,borderRadius:'30px'}],{duration:420,easing:'cubic-bezier(.3,1.3,.4,1)'})`
- `app.js:1348` **avDoKeep()** 対象 `}
  $('avk')`  
  `([{scale:'1'},{scale:'1.4',rotate:'-20deg'},{scale:'1'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
### v32 まんなかの 万能ボタン:いま いちばんの ことを 真ん中に、ほかは まわりに
- `app.js:1391` **renderOrb()** 対象 `if(!matchMedia('(prefers-reduced-motion:reduce)').matches)bt`  
  `([{scale:'1'},{scale:'.82'},{scale:'1.08'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `app.js:1396` **up()** 対象 `$('ofl2')`  
  `([{opacity:0,transform:'scale(.6)'},{opacity:.95,offset:.3},{opacity:0,transform:'scale(1.6)'}],{duration:420,easing:'ease-out'})`
- `app.js:1396` **up()** 対象 `$('oir')`  
  `([{transform:'rotate(0deg) scale(1)'},{transform:'rotate(90deg) scale(.6)',offset:.45},{transform:'rotate(120deg) scale(1)'}],{duration:420,easing:'cubic-bezier(.4,0,.2,1)'})`
- `app.js:1397` **up()** 対象 `if(!rm)S`  
  `([{scale:'1'},{scale:'1.08'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'})`
### v37 Mondo(世界の きのう):スクロールで 見る
- `app.js:1439` **onclick()** 対象 `f&&f`  
  `([{opacity:.3,transform:'translateY(10px)'},{opacity:1,transform:'none'}],{duration:320})`
- `app.js:1445` **onfinish()** 対象 `s`  
  `([{transform:'scale(.2)',opacity:1},{transform:'scale(2.4)',opacity:0}],{duration:700,easing:'cubic-bezier(.2,.8,.3,1)'})`
- `app.js:1461` **up()** 対象 `g&&g`  
  `([{transform:'rotate(0) scale(1)'},{transform:'rotate(40deg) scale(.55)',offset:.4},{transform:'rotate(0) scale(1)'}],{duration:380,easing:'cubic-bezier(.4,0,.2,1)'})`

## v46.js

### v46
- `v46.js:53` **openLive()** 対象 `K`  
  `([{left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px',borderRadius:r.h/2+'px'},{left:(L-4)+'px',top:(T-2)+'px',width:(W+8)+'px',height:(H2+6)+'px',borderRadius:'38px',offset:.62},{left:L+'px',top:T+'px',width:W+'px',height:H2+'px',borderRadius:'36px'}],{duration:620,easing:'cubic-bezier(.3,.9,.3,1)'})`
- `v46.js:54` **openLive()** 対象 `inn`  
  `([{opacity:0,filter:'blur(8px)',transform:'scale(.96)'},{opacity:1,filter:'blur(0)',transform:'none'}],{duration:420,delay:150,easing:'cubic-bezier(.2,.9,.3,1)',fill:'both'})`
- `v46.js:55` **openLive()** 対象 `[...inn.querySelectorAll('.lf,.lpgo,.lptr .sh')].forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(10px) scale(.9)'},{opacity:1,transform:'none'}],{duration:460,delay:300+i*50,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'backwards'})`
- `v46.js:58` **closeLive()** 対象 `inn`  
  `([{opacity:1},{opacity:0,filter:'blur(6px)'}],{duration:160,fill:'forwards'})`
- `v46.js:59` **closeLive()** 対象 `const a=K`  
  `([{left:K.style.left,top:K.style.top,width:K.style.width,height:K.style.height,borderRadius:'36px'},{left:r.x+'px',top:r.y+'px',width:r.w+'px',height:r.h+'px',borderRadius:r.h/2+'px'}],{duration:fast?300:440,easing:'cubic-bezier(.5,0,.2,1)',fill:'forwards'})`
- `v46.js:72` **lockGo()** 対象 `if(el)el`  
  `([{scale:'1'},{scale:'.9'},{scale:'1.06'},{scale:'1'}],{duration:360,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v46.js:92` **goMe()** 対象 `s`  
  `([{boxShadow:'0 0 0 0 rgba(36,160,60,.0)'},{boxShadow:'0 0 0 4px rgba(36,160,60,.9)'},{boxShadow:'0 0 0 0 rgba(36,160,60,0)'}],{duration:900})`
- `v46.js:109` **onclick()** 対象 `b`  
  `([{scale:'1'},{scale:'.86'},{scale:'1'}],{duration:260})`
- `v46.js:112` **onclick()** 対象 `[...P.querySelectorAll('.sht button')].forEach((b,i)=>b`  
  `([{opacity:0,transform:'translateY(14px)'},{opacity:1,transform:'none'}],{duration:420,delay:120+i*40,easing:'cubic-bezier(.3,1.4,.5,1)',fill:'backwards'})`
- `v46.js:120` **roomMenu()** 対象 `$('rmav').querySelectorAll('.rma').forEach((b,i)=>b`  
  `([{scale:'1'},{scale:'1.3'},{scale:'1'}],{duration:420,delay:i*80,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v46.js:148` **rmHead()** 対象 `b`  
  `([{scale:'1'},{scale:'1.18'},{scale:'1'}],{duration:320,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v46.js:157` **yMondo()** 対象 `setTimeout(()=>f.querySelectorAll('.mof').forEach((c,i)=>i<4&&c`  
  `([{rotate:'0deg'},{rotate:'-2.5deg'},{rotate:'2.5deg'},{rotate:'0deg'}],{duration:420,delay:i*60})`
- `v46.js:168` **onclick()** 対象 `$('otc')`  
  `([{transform:'translateX(40px) rotate(6deg)',opacity:0},{transform:'rotate(-4deg)',opacity:1}],{duration:460,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `v46.js:183` **arcFriends()** 対象 `s`  
  `([{scale:'1'},{scale:'.8'},{scale:'1.12'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v46.js:184` **arcFriends()** 対象 `c`  
  `([{opacity:0,transform:'scale(.85)'},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `v46.js:189` **arcFriends()** 対象 `st&&st`  
  `([{rotate:'0deg'},{rotate:'-14deg'},{rotate:'12deg'},{rotate:'-6deg'},{rotate:'0deg'}],{duration:520})`
- `v46.js:191` **arcFriends()** 対象 `s`  
  `([{scale:'0',filter:'brightness(3)'},{scale:'1.3',offset:.55},{scale:'1',filter:'none'}],{duration:760,easing:'cubic-bezier(.3,1.5,.5,1)'})`

## v48.js

### v48 friend 画面(暗室・12の 席)
- `v48.js:38` **fBind()** 対象 `s`  
  `([{scale:'1'},{scale:'.8'},{scale:'1.12'},{scale:'1'}],{duration:380,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v48.js:42` **onclick()** 対象 `b`  
  `([{scale:'1'},{scale:'.9'},{scale:'1.04'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v48.js:47` **fSoft()** 対象 `C`  
  `([{opacity:0,transform:'scale(.86)'},{opacity:1,transform:'none'}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `v48.js:49` **fPoke()** 対象 `av`  
  `([{rotate:'0deg'},{rotate:'-16deg'},{rotate:'14deg'},{rotate:'-6deg'},{rotate:'0deg'}],{duration:520})`
- `v48.js:66` **openFriend()** 対象 `F.querySelectorAll('.fs').forEach((s,i)=>s`  
  `([{opacity:0,scale:'.3'},{opacity:1,scale:'1'}],{duration:520,delay:200+i*45,easing:'cubic-bezier(.3,1.5,.5,1)',fill:'backwards'})`
- `v48.js:67` **openFriend()** 対象 `F.querySelectorAll('.fme,.frw,.fwy button').forEach((x,i)=>x`  
  `([{opacity:0,transform:'translateY(20px)'},{opacity:1,transform:'none'}],{duration:520,delay:500+i*45,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `v48.js:74` **onfinish()** 対象 `r`  
  `([{transform:'scale(.4)',opacity:1},{transform:'scale(5.5)',opacity:0}],{duration:900,delay:i*120,easing:'cubic-bezier(.2,.8,.2,1)',fill:'backwards'})`
- `v48.js:76` **onfinish()** 対象 `w`  
  `([{transform:'scale(.3) rotate(-10deg)',opacity:0},{transform:'scale(1.15) rotate(3deg)',opacity:1,offset:.45},{transform:'scale(1) rotate(-2deg)',opacity:1,offset:.8},{transform:'scale(1.05)',opacity:0}],{duration:1100,easing:'cubic-bezier(.3,1.4,.5,1)'})`

## v49.js


## v50.js

### v50 ME:7日の フィルム と Recap
- `v50.js:10` **openMe()** 対象 `W.querySelectorAll('.mrc,.mstrip,.msty,.mday').forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(26px)'},{opacity:1,transform:'none'}],{duration:560,delay:120+i*60,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `v50.js:11` **openMe()** 対象 `s&&s`  
  `([{transform:'translateX(220px)'},{transform:'none'}],{duration:900,easing:'cubic-bezier(.2,.9,.25,1)'})`
- `v50.js:26` **onclick()** 対象 `$('mrc')`  
  `([{scale:'1'},{scale:'.97'},{scale:'1'}],{duration:300})`
- `v50.js:42` **meGo()** 対象 `bars[i].firstChild`  
  `([{width:'0%'},{width:'100%'}],{duration:meDur(s),fill:'forwards'})`

## v51.js

### v51 プロフィール(右上の まるを 1回 タップ)
- `v51.js:34` **openPrf()** 対象 `P`  
  `([{clipPath:`circle(0px at ${o.x}px ${o.y}px)`},{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`}],{duration:680,easing:'cubic-bezier(.3,.85,.25,1)'})`
- `v51.js:36` **openPrf()** 対象 `C`  
  `([{transform:'translateY(-260px) rotate(-18deg)',opacity:0},{transform:'translateY(14px) rotate(1deg)',opacity:1,offset:.6},{transform:'none'}],{duration:820,delay:120,easing:'cubic-bezier(.3,1.2,.4,1)',fill:'backwards'})`
- `v51.js:38` **openPrf()** 対象 `s`  
  `([{scale:'0',opacity:0},{scale:'1.25',opacity:1,offset:.6},{scale:'1'}],{duration:520,delay:700+i*110,easing:'cubic-bezier(.3,1.6,.4,1)',fill:'backwards'})`
- `v51.js:39` **openPrf()** 対象 `lectorAll('.pnm,.pstat,.pact button,.pme,.pyr,.pset').forEach((e,i)=>e`  
  `([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:560,delay:420+i*50,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `v51.js:42` **onfinish()** 対象 `P`  
  `([{clipPath:`circle(1000px at ${o.x}px ${o.y}px)`},{clipPath:`circle(0px at ${o.x}px ${o.y}px)`}],{duration:460,easing:'cubic-bezier(.5,0,.7,.3)',fill:'forwards'})`
- `v51.js:55` **pfBind()** 対象 `s`  
  `([{scale:'1'},{scale:'1.3',rotate:'8deg'},{scale:'.92',rotate:'-4deg'},{scale:'1',rotate:'0deg'}],{duration:480,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v51.js:56` **onclick()** 対象 `b`  
  `([{scale:'1'},{scale:'.92'},{scale:'1'}],{duration:260})`
- `v51.js:57` **onclick()** 対象 `setTimeout(()=>f`  
  `([{boxShadow:'0 0 0 0 rgba(59,211,90,0)'},{boxShadow:'0 0 0 3px rgba(59,211,90,.9)'},{boxShadow:'0 0 0 0 rgba(59,211,90,0)'}],{duration:900})`
- `v51.js:58` **onclick()** 対象 `b`  
  `([{scale:'1'},{scale:'.88'},{scale:'1.05'},{scale:'1'}],{duration:340,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v51.js:64` **onclick()** 対象 `i`  
  `([{scale:'1'},{scale:'2.4'},{scale:'1'}],{duration:360})`
- `v51.js:72` **pfBurst()** 対象 `$('pck')`  
  `([{transform:'rotate(-2deg)'},{transform:'rotate(3deg) scale(1.04)'},{transform:'rotate(-2deg)'}],{duration:300,iterations:2})`
- `v51.js:73` **pfBurst()** 対象 `s`  
  `([{transform:`translate(-50%,-50%) translate(var(--x),var(--y)) rotate(var(--r))`},{transform:`translate(-50%,-50%) translate(calc(var(--x) + ${(Math.cos(a)*160).toFixed(0)}px),calc(var(--y) + ${(Math.sin(a)*160).toFixed(0)}px)) rotate(${i%2?200:-200}deg)`,offset:.45},{transform:`translate(-50%,-50%) translate(var(--x),var(--y)) rotate(var(--r))`}],{duration:1100,delay:i*40,easing:'cubic-bezier(.3,1.25,.4,1)'})`

## v52.js

### v52 プロフィールを その場で 部分的に なおす
- `v52.js:9` **pfEdit()** 対象 `bar`  
  `([{transform:'translateY(-30px)',opacity:0},{transform:'none',opacity:1}],{duration:380,easing:'cubic-bezier(.3,1.4,.5,1)'})`
- `v52.js:17` **pfEdit()** 対象 `$('ped').querySelectorAll('.pes').forEach((s,i)=>s`  
  `([{opacity:0,transform:'translateY(24px)'},{opacity:1,transform:'none'}],{duration:480,delay:120+i*70,easing:'cubic-bezier(.3,1.3,.5,1)',fill:'backwards'})`
- `v52.js:21` **peGo()** 対象 `el`  
  `([{boxShadow:'0 0 0 0 rgba(59,211,90,0)'},{boxShadow:'0 0 0 3px rgba(59,211,90,.9)'},{boxShadow:'0 0 0 0 rgba(59,211,90,0)'}],{duration:900})`
- `v52.js:35` **onclick()** 対象 `$('pck')`  
  `([{transform:'rotate(-3deg) scale(1)'},{transform:'rotate(-1deg) scale(1.05)'},{transform:'rotate(-3deg) scale(1)'}],{duration:420,easing:'cubic-bezier(.3,1.6,.4,1)'})`
- `v52.js:48` **onclick()** 対象 `C`  
  `([{transform:'rotate(-3deg)'},{transform:'rotate(2deg) scale(1.08)'},{transform:'rotate(-3deg)'}],{duration:520,easing:'cubic-bezier(.3,1.6,.4,1)'})`

## CSS の @keyframes(くり返し・常に動いている もの)

後ろに 書かれた 同じ名前が 優先。`animation: 名前 秒 ...` で 使われる。

- `gr` { 0%{transform:translate(0,0)}20%{transform:translate(-14px,9px)}40%{transform:translate(10px,-12px)}60%{transform:translate(-8px,-6px)}80%{transform:translate(12px,10px)} }  
  使う所: `.grain → gr .9s steps(5) infinite; .mgr → gr .5s steps(4) infinite`
- `shk` { 15%{transform:translateX(-9px)}35%{transform:translateX(8px)}55%{transform:translateX(-5px)}75%{transform:translateX(3px)} }  
  使う所: `.shake → shk .42s`
- `flk` { 0%{opacity:.2}35%{opacity:1}60%{opacity:.3}100%{opacity:1} }  
  使う所: `.cnt.flick .lit → flk .32s steps(4)`
- `hp` { 30%{color:#24A73E;transform:scale(1.06)} }  
  使う所: `.hint.p → hp .9s`
- `vb` { 50%{opacity:.35} }  
  使う所: `.vol → vb 2.8s ease-in-out infinite`
- `vg` { 0%{opacity:1;width:10px;box-shadow:0 0 40px #9ED6A5} }  
  使う所: `.vol.go → vg .6s`
- `rp` { to{transform:scale(var(--s,4));opacity:0} }  
  使う所: `#rip i → rp .55s ease-out forwards`
- `qk` { 20%{transform:translate(-2.5px,1px)}40%{transform:translate(2.5px,-1px)}60%{transform:translate(-1.5px,1px)}80%{transform:translate(1px,0)} }  
  使う所: `.phone.qk → qk .28s linear`
- `hsw` { 0%{transform:rotate(var(--r))}15%{transform:rotate(calc(var(--r) + 12deg))}35%{transform:rotate(calc(var(--r) - 8deg))}55%{transform:rotate(calc(var(--r) + 5deg))}75%{transform:rotate(calc(var(--r) - 2.5deg))}100%{transform:rotate(var(--r))} }  
  使う所: `.hck.sw → hsw 1.3s cubic-bezier(.3,.1,.3,1)`
- `recb` { 50%{opacity:.15} }  
  使う所: `.recp i → recb 1s steps(2) infinite`
- `pflk` { 0%{filter:brightness(1.6)}18%{filter:brightness(.6)}36%{filter:brightness(1.4)}54%{filter:brightness(.8)}72%{filter:brightness(1.2)}100%{filter:none} }  
  使う所: `.dcheki.flick .dim → pflk .55s steps(1)`
- `pl` { 50%{filter:brightness(1.025) contrast(1.02)} }  
  使う所: `.dcheki.playing .dim → pl .16s steps(2) infinite`
- `kb` { 0%{transform:scale(1) translate(0,0)}25%{transform:scale(1.03) translate(-2px,1px)}50%{transform:scale(1.06) translate(1px,-1px)}75%{transform:scale(1.09) translate(-1px,0)}100%{transform:scale(1.12) translate(1px,1px)} }  
  使う所: `.dcheki.playing.fb img → kb 6s linear infinite`
- `bob` { 0%,100%{transform:rotate(var(--r)) scale(1.07)}50%{transform:rotate(calc(var(--r) + 1.8deg)) scale(1.07) translateY(-5px)} }  
  使う所: `.hck.knx → bob 4.2s ease-in-out infinite`
- `trk` { 0%{transform:translateX(0);filter:none}8%{transform:translateX(-7px) skewX(-4deg);filter:contrast(1.5) saturate(1.6)}16%{transform:translateX(5px);filter:none}28%{transform:translateX(-3px) skewX(2deg);filter:contrast(1.25)}40%{transform:none;filter:none}100%{transform:none} }  
  使う所: `#dim.trk → trk .75s steps(1) 1`
- `lkd` { 50%{transform:translate(22px,30px) scale(1.1)} }  
  使う所: `.lk1 → lkd 14s ease-in-out infinite; .lk2 → lkd 17s ease-in-out infinite reverse`
- `fgone` { 0%{background:#239E3C;transform:scale(1.5)}100%{background:#DCDBE1;transform:none} }  
  使う所: `.hfb i.gone → fgone .6s cubic-bezier(.3,1.4,.5,1)`
- `orip` { 0%{transform:scale(1);opacity:.9}100%{transform:scale(1.42);opacity:0} }  
  使う所: `.orip → orip 6.4s cubic-bezier(.2,.6,.3,1) infinite`
- `rspin` { to{transform:rotate(360deg)} }  
  使う所: `.oir → rspin 40s linear infinite; .oau → rspin 30s linear infinite`
- `fl1` { 50%{transform:translateY(-7px) rotate(10deg)} }  
  使う所: `.orb .s3 → fl1 7s ease-in-out infinite -2s; .dusk .d1 → fl1 5.5s ease-in-out infinite`
- `fl2` { 50%{transform:translateY(5px) rotate(-8deg)} }  
  使う所: `.dusk .d2 → fl2 6.5s ease-in-out infinite -1s; .axh .dd.in → fl2 6s ease-in-out infinite`
- `pulse` { 50%{transform:scale(1.5);opacity:.6} }  
  使う所: `.tim.milk::after → pulse 2.2s ease-in-out infinite`
- `glint` { 0%,55%{background-position:130% 0}100%{background-position:-30% 0} }  
  使う所: `.hmoon::after → glint 7s ease-in-out infinite`
- `sheen` { to{left:130%} }  
  使う所: `.tpv .sheen.go → sheen 1s cubic-bezier(.3,.6,.3,1)`
- `chipin` { 0%{transform:scale(.3) rotate(-8deg);opacity:0}60%{transform:scale(1.08) rotate(2deg);opacity:1}100%{transform:none} }  
  使う所: `.tch.in → chipin .52s cubic-bezier(.25,1.6,.45,1); .ginv.in → chipin .6s cubic-bezier(.25,1.5,.45,1)`
- `chipout` { to{transform:scale(.4);opacity:0} }  
  使う所: `.tch.out → chipout .28s ease-in forwards`
- `mq` { to{transform:translateX(-50%)} }  
  使う所: `.mqt → mq 44s linear infinite`
- `phs` { 25%{transform:translate(-2px,1px) rotate(-2deg)}75%{transform:translate(2px,-1px) rotate(2deg)} }  
  使う所: `.fr0 .phs.sh → phs .16s linear infinite`
- `fnew` { 0%{transform:scale(.2) rotate(-30deg);opacity:0}100%{transform:none;opacity:1} }  
  使う所: `.fp.new .fav → fnew .7s cubic-bezier(.3,1.6,.4,1)`
- `fwob` { 25%{transform:rotate(-12deg)}55%{transform:rotate(9deg)}80%{transform:rotate(-4deg)} }  
  使う所: `.fp.wob .fav → fwob .5s`
- `fwob2` { 15%{transform:rotate(-20deg) scale(1.12)}35%{transform:rotate(16deg) scale(1.12)}55%{transform:rotate(-10deg)}75%{transform:rotate(6deg)} }  
  使う所: `.fp.wob2 .fav → fwob2 .7s`
- `gone2` { to{opacity:0;transform:scale(.94)} }  
  使う所: `.gone2 → gone2 .3s forwards`
- `bub` { to{transform:translateY(-200px);opacity:0} }  
  使う所: `.dvc .bub i → bub 4s linear infinite; .dxc .bub i → bub 4s linear infinite`
- `kp` { 20%,70%{opacity:1} }  
  使う所: `.ydc.kept .keep → kp 1.4s`
- `wknpop` { 40%{transform:scale(1.18)} }  
  使う所: `.wkn b.pop → wknpop .55s cubic-bezier(.3,1.8,.4,1)`
- `wkring` { from{opacity:.15;transform:scale(1.35)}to{opacity:1;transform:scale(1)} }  
  使う所: `.wkd .fs i.hold::after → wkring .52s linear both`
- `wkIn` { from{opacity:0;transform:translateX(70px) rotate(2deg) scale(.96)} }  
  使う所: `#wks:not(.pre) .wkd → wkIn .8s cubic-bezier(.2,.9,.25,1) backwards`
- `fdev` { from{filter:brightness(.15) saturate(0) blur(4px)}55%{filter:brightness(1.45) saturate(.5) blur(1px)} }  
  使う所: `#wks:not(.pre) .wkd .fs i → fdev .9s ease-out backwards`
- `fuse` { from{transform:scaleX(0)} }  
  使う所: `#wks:not(.pre) .fuse i → fuse 1s cubic-bezier(.2,.9,.25,1) backwards`
- `ember` { 0%,100%{box-shadow:0 0 0 1.5px rgba(36,167,62,.55),0 0 10px rgba(36,167,62,.25)}50%{box-shadow:0 0 0 1.5px rgba(36,167,62,.95),0 0 28px rgba(36,167,62,.55)} }
- `ash` { 0%{transform:translate(0,0);opacity:0}15%{opacity:.95}100%{transform:translate(var(--dx,6px),-84px);opacity:0} }  
  使う所: `.ash i → ash 2.6s linear infinite`
- `wkcin` { from{opacity:0;transform:translateY(8px)} }  
  使う所: `.wkcap.sw>* → wkcin .38s cubic-bezier(.2,.9,.25,1) backwards`
- `segin` { from{transform:scaleX(0)} }  
  使う所: `.wsg i.on → segin .4s cubic-bezier(.2,.9,.25,1) backwards`
- `mzdrift` { to{transform:scale(1.14) rotate(5deg)} }  
  使う所: `.dxc .mz → mzdrift 9s ease-in-out infinite alternate`
- `grn` { 0%{transform:translate(0,0)}25%{transform:translate(-14px,9px)}50%{transform:translate(11px,-12px)}75%{transform:translate(-8px,-6px)}100%{transform:translate(6px,13px)} }  
  使う所: `.dxc .gr → grn .5s steps(4) infinite; .chk::after → grn .6s steps(4) infinite`
- `ypulse` { 50%{box-shadow:0 0 0 7px rgba(47,168,71,.08)} }  
  使う所: `.ypill .yd → ypulse 2.2s ease-in-out infinite`
- `yfl` { to{translate:0 -6px} }  
  使う所: `.yme i → yfl 6s ease-in-out infinite alternate`
- `seatfl` { 50%{margin-top:-31px} }  
  使う所: `.yseat → seatfl 4.6s ease-in-out infinite`
- `hiDraw` { from{transform:scaleX(0)} }  
  使う所: `.yhl .hi.draw::after → hiDraw .7s cubic-bezier(.3,.9,.3,1) 1s backwards`
- `mnote` { 0%,100%{transform:translateY(0) rotate(0)}50%{transform:translateY(-2px) rotate(-8deg)} }  
  使う所: `.msc.has svg → mnote 1.6s ease-in-out infinite`
- `mring` { to{transform:rotate(360deg)} }  
  使う所: `#tag .msc:not(.has)::before → mring 14s linear infinite`
- `mspin` { to{transform:rotate(360deg)} }  
  使う所: `#tag .msc.has .mdisc → mspin 6s linear infinite`
- `meq` { 0%,100%{height:4px}50%{height:14px} }  
  使う所: `#tag .meq s → meq 900ms ease-in-out infinite`
- `gbd` { to{transform:translate(46px,-38px) scale(1.12)} }  
  使う所: `.ob .obg b:nth-child(1) → gbd 15s ease-in-out infinite alternate; .ob .obg b:nth-child(2) → gbd 19s ease-in-out infinite alternate-reverse`
- `gor` { to{rotate:360deg} }  
  使う所: `.gseats → gor 80s linear infinite`
- `gcr` { to{rotate:360deg} }  
  使う所: `.gnsi → gcr 80s linear infinite reverse,gfl 4.2s ease-in-out infinite alternate; .gnseat.gpl .gnsi → gcr 80s linear infinite reverse,gpl .6s cubic-bezier(.3,1.5,.4,1)`
- `gfl` { from{translate:0 -4px}to{translate:0 5px} }  
  使う所: `.gnsi → gfl 4.2s ease-in-out infinite alternate`
- `gpl` { 0%{scale:1}40%{scale:1.3;box-shadow:0 0 34px 2px color-mix(in srgb,var(--k) 90%,transparent)}100%{scale:1} }  
  使う所: `.gnseat.gpl .gnsi → gpl .6s cubic-bezier(.3,1.5,.4,1)`
- `grr` { to{transform:rotate(360deg)} }  
  使う所: `.grg → grr 14s linear infinite`
- `cmbob` { 50%{translate:0 -4px} }  
  使う所: `/* はじめての 合図 */
.cmb → cmbob 2.4s ease-in-out .6s infinite`
- `cmdot` { to{box-shadow:0 0 0 9px rgba(37,169,63,0)} }  
  使う所: `.tdv .tdl i → cmdot 1.6s ease-out infinite; .orb .omo i → cmdot 1.6s ease-out infinite`
- `cmhp` { 0%{box-shadow:0 0 0 2.5px #25A93F,0 0 0 0 rgba(37,169,63,.45)}100%{box-shadow:0 0 0 2.5px #25A93F,0 0 0 16px rgba(37,169,63,0)} }  
  使う所: `.cmh → cmhp 1.8s ease-out infinite`
- `cmfill` { 0%,8%{--cma:0deg;opacity:1}70%{--cma:360deg;opacity:1}85%,100%{--cma:360deg;opacity:0} }  
  使う所: `.cmh.press::before → cmfill 2.2s cubic-bezier(.4,0,.3,1) infinite`
- `cmtap` { 0%{scale:1.4;opacity:0}10%{scale:.85;opacity:1}70%{scale:.85;opacity:1}85%,100%{scale:1.3;opacity:0} }  
  使う所: `.cmh.press::after → cmtap 2.2s cubic-bezier(.4,0,.3,1) infinite`
- `rmpk` { from{opacity:.9;scale:1}to{opacity:0;scale:1.5} }  
  使う所: `.rma.pk::after → rmpk .9s ease-out 2`
- `rmtd` { 50%{scale:.78} }  
  使う所: `.rmwk i.t → rmtd 1.8s ease-in-out infinite`
- `mty` { 0%,60%,100%{translate:0 0;opacity:.4}30%{translate:0 -5px;opacity:1} }  
  使う所: `.rm .mty i → mty 1s ease-in-out infinite`
- `rlk` { 0%,45%{opacity:0}100%{opacity:1} }  
  使う所: `.rvl.rare.on .rlk → rlk 6.2s cubic-bezier(.3,.1,.3,1) forwards`
- `obfl` { from{translate:0 -4px}to{translate:0 5px} }  
  使う所: `/* チェキ */
.ob .obc → obfl 5s ease-in-out infinite alternate; .ob .obfr i → obfl 4s ease-in-out infinite alternate`
- `obsh` { 0%,55%{translate:-100% 0}100%{translate:100% 0} }  
  使う所: `.tf.dv::after → obsh 3.4s ease-in-out infinite; #dvx .dxsh → obsh 3.6s ease-in-out infinite`
- `obwl` { to{transform:translateY(-50%)} }  
  使う所: `.ob .obwall .col → obwl 38s linear infinite`
- `osf` { 50%{transform:translateY(-4px)} }  
  使う所: `.osb → osf 5s ease-in-out infinite`
- `obr` { from{transform:scale(.92);opacity:.9}to{transform:scale(1.35);opacity:0} }  
  使う所: `.orz .osh::after → obr 2.6s ease-out infinite`
- `oscr` { 50%{transform:translateY(5px);opacity:.5} }  
  使う所: `.oscr → oscr 2.2s ease-in-out infinite`
- `mau` { 50%{transform:scale(1.18);opacity:.6} }  
  使う所: `.moone .aura → mau 3.4s ease-in-out infinite`
- `mpn` { 50%{transform:scale(1.15)} }  
  使う所: `.pin → mpn 2.4s ease-in-out infinite`
- `mbr` { 50%{transform:scale(1.08);opacity:.4} }  
  使う所: `/* オーロラ → あたたかい 光 ひとつ */
.oau → mbr 6s ease-in-out infinite`
- `lpa` { to{--lpa:360deg} }  
  使う所: `.afc .rad → lpa 7s linear infinite; .fhero .rad → lpa 7s linear infinite`
- `lpsh` { 0%,72%{background-position:130% 0}100%{background-position:-60% 0} }  
  使う所: `.lp::after → lpsh 6s ease-in-out infinite`
- `lpdot` { 0%{box-shadow:0 0 0 0 rgba(36,160,60,.6)}75%,100%{box-shadow:0 0 0 7px rgba(36,160,60,0)} }  
  使う所: `.afh .lv i → lpdot 1.8s ease-out infinite; .mohd .mmk .dot → lpdot 1.8s ease-out infinite`
- `lfsh` { from{background-position:150% 0}to{background-position:-50% 0} }  
  使う所: `.lf.on::after → lfsh 2.4s linear infinite`
- `qls` { to{top:88%} }  
  使う所: `.qfr .ls → qls 1.5s ease-in-out infinite alternate`
- `qbr` { 50%{transform:scale(1.03)} }  
  使う所: `.qfr → qbr 2s ease-in-out infinite`
- `nxp` { 50%{transform:scale(1.15);box-shadow:0 0 16px rgba(36,160,60,.5)} }  
  使う所: `.seat.e.nx i → nxp 1.8s ease-in-out infinite; .fs.e.nx i → nxp 1.8s ease-in-out infinite`
- `land` { from{transform:scale(.6);opacity:1}to{transform:scale(2.6);opacity:0} }  
  使う所: `.seat .land → land .9s cubic-bezier(.2,.8,.3,1) forwards`
- `shkw` { 0%,70%,100%{transform:rotate(0)}75%{transform:rotate(-16deg)}80%{transform:rotate(14deg)}85%{transform:rotate(-10deg)}90%{transform:rotate(6deg)} }  
  使う所: `.afc .shk svg → shkw 2.6s ease-in-out infinite; .fhold .ph → shkw 2.6s ease-in-out infinite`
- `dsh` { 10%,90%{transform:translateX(-2px) rotate(-.4deg)}20%,80%{transform:translateX(4px) rotate(.6deg)}30%,50%,70%{transform:translateX(-7px) rotate(-.8deg)}40%,60%{transform:translateX(7px) rotate(.8deg)} }  
  使う所: `.afc.shk2 → dsh .6s cubic-bezier(.36,.07,.19,.97)`
- `fhsh` { 25%{transform:translate(calc(var(--hk)*-3px),calc(var(--hk)*1px))}75%{transform:translate(calc(var(--hk)*3px),calc(var(--hk)*-1px))} }  
  使う所: `.fhero.hold → fhsh .14s linear infinite`
- `fsnew` { 0%{scale:0;filter:brightness(3)}55%{scale:1.3}100%{scale:1;filter:none} }  
  使う所: `.fs.new → fsnew .9s cubic-bezier(.3,1.5,.5,1)`
- `chb` { 0%,100%{transform:translateY(0)}50%{transform:translateY(-2.5px)} }  
  使う所: `.crowd .ch>* → chb 2.8s ease-in-out infinite`
- `chj` { 0%,100%{transform:translate(0,0) rotate(0)}25%{transform:translate(-1.5px,-2px) rotate(-3deg)}75%{transform:translate(1.5px,-1px) rotate(3deg)} }  
  使う所: `.fhero.hold .crowd .ch>* → chj .16s linear infinite`
- `fbf` { 50%{translate:0 -14px} }  
  使う所: `.fbg .ck → fbf 9s ease-in-out infinite; .pbg .ck → fbf 10s ease-in-out infinite`
- `tgin` { from{transform:rotate(var(--r)) scale(0)} }  
  使う所: `.fmc .tg → tgin .6s cubic-bezier(.3,1.6,.4,1) backwards`
- `mshine` { from{background-position:120% 0}to{background-position:-130% 0} }  
  使う所: `.mohd .mh .ml2 → mshine 5s linear infinite`
- `mlt` { from{opacity:0;transform:translateY(.55em) rotate(8deg);filter:blur(6px)} }  
  使う所: `.mohd.in .mlt → mlt .7s cubic-bezier(.2,1.4,.4,1) backwards`
- `mglb` { from{transform:scale(0) rotate(-120deg)} }  
  使う所: `.mohd.in .glb → mglb .9s cubic-bezier(.2,1.6,.4,1) backwards`
- `gmer` { from{transform:translateX(-12px)}to{transform:translateX(12px)} }  
  使う所: `.glb .mer → gmer 4s linear infinite`
- `gpin` { 50%{transform:translateY(-2px)} }  
  使う所: `.glb .pin → gpin 1.6s ease-in-out infinite`
- `msw` { from{stroke-dashoffset:330} }  
  使う所: `.mohd.in .msw2 path → msw 1s cubic-bezier(.6,0,.2,1) backwards`
- `mtk` { to{transform:translateX(-50%)} }  
  使う所: `.mtr → mtk 26s linear infinite`
- `mkb` { from{transform:scale(1.02)}to{transform:scale(1.14) translate(2%,-2%)} }  
  使う所: `.mrc .cv i → mkb 9s ease-in-out infinite alternate`
- `mpl` { 0%{box-shadow:0 0 0 0 rgba(255,255,255,.45)}80%,100%{box-shadow:0 0 0 18px rgba(255,255,255,0)} }  
  使う所: `.mrc .pl → mpl 2.2s ease-out infinite`
- `msin` { from{opacity:0;transform:scale(1.06)} }  
  使う所: `.msl → msin .5s cubic-bezier(.2,.9,.3,1) both; .msl.m-day .dk → msin .6s .05s both`
- `msout` { to{opacity:0;transform:scale(.97)} }  
  使う所: `.msl.out → msout .5s ease forwards`
- `mday` { from{opacity:0;transform:translateY(40px) scale(.8);filter:blur(10px)} }  
  使う所: `.msl.m-day b → mday .7s cubic-bezier(.2,1.4,.4,1) .08s both; .en>b → mday .8s cubic-bezier(.2,1.3,.4,1) .3s both`
- `mken` { from{transform:scale(1.18) translate(2%,1%)}to{transform:scale(1.04)} }  
  使う所: `.msl.m-ph .fx>i → mken 1.6s ease-out both`
- `tgpop` { from{transform:rotate(-4deg) scale(0)} }  
  使う所: `.msl.m-ph .sr → tgpop .5s cubic-bezier(.3,1.6,.4,1) .3s both; .pet .tc.nw → tgpop .45s cubic-bezier(.3,1.6,.4,1)`
- `ckin` { from{transform:translateY(120px) rotate(calc(var(--r) * -3));opacity:0} }  
  使う所: `.msl.m-ph .fx.ck → ckin .7s cubic-bezier(.3,1.4,.5,1) both`
- `mbeat` { 0%{transform:scale(1.25)}35%{transform:scale(.98)}100%{transform:scale(1.04)} }  
  使う所: `.mrp.st-beat .msl.m-ph .fx>i → mbeat .56s cubic-bezier(.2,1.6,.4,1) both`
- `mosin` { from{opacity:0;transform:scale(.6) rotate(-6deg)} }  
  使う所: `.en .mos i → mosin .6s cubic-bezier(.3,1.4,.5,1) both`
- `mkb2` { from{background-position:0% 20%}to{background-position:100% 80%} }  
  使う所: `.mrc .cv i → mkb2 9s ease-in-out infinite alternate`
- `pbg` { to{transform:translate(10%,6%) rotate(12deg) scale(1.1)} }  
  使う所: `.pbg .g → pbg 12s ease-in-out infinite alternate`
- `pbo` { 50%{transform:translateY(-4px) rotate(-2deg)} }  
  使う所: `.pck .pic b → pbo 3.4s ease-in-out infinite`
- `pstw` { 50%{rotate:3deg} }  
  使う所: `.pst → pstw 4s ease-in-out infinite`
- `pfm` { 0%,80%,100%{transform:none}88%{transform:translateY(-4px)} }  
  使う所: `.pme .pmf i → pfm 4s ease-in-out infinite`
- `pjig` { from{rotate:-2.5deg}to{rotate:2.5deg} }  
  使う所: `.prf.ed .pst.me → pjig .32s ease-in-out infinite alternate`
- `pbgin` { from{transform:scale(0)} }  
  使う所: `.pbg1,.pbg2 → pbgin .5s cubic-bezier(.3,1.6,.4,1) backwards .15s`