/* כיוון תפילה — זיהוי הכיוון לפי רחוב (נתוני OpenStreetMap דרך Overpass).
   אזור שהורד פעם אחת נשמר בתיקייה הפרטית של התוסף ועובד מאז בלי אינטרנט.
   בלי רשת באוצריא אפשר לפתוח את אותה כתובת בדפדפן, לשמור את הקובץ ולטעון אותו כאן. */
const OVP=["https://overpass-api.de/api/interpreter","https://overpass.kumi.systems/api/interpreter"];
const ST={idx:[],area:null,sel:null,pan:[0,0],setHere:false,radius:1500,showSyn:true,lang:"he"};
const EMB=typeof EMB_STREETS!=="undefined"?EMB_STREETS:[];
/* כל אזור מובנה נמצא בקובץ משלו (st-NN.js) ונטען רק כשצריך. הקואורדינטות שמורות כהפרשים במאה-אלפיות המעלה. */
const EMB_DATA={};function EMB_PUT(a){EMB_DATA[a.k]=a}
function stDecode(a){if(!a||a.z!==2)return a;const B=[Math.round(a.lat*1e5),Math.round(a.lon*1e5)];
 a.w=a.w.map(([n,h,g])=>{const o=[];let x=B[0],y=B[1];for(let i=0;i<g.length;i+=2){x+=g[i];y+=g[i+1];o.push(x/1e5,y/1e5)}return[n,h,o]});
 a.s=(a.s||[]).map(([n,dx,dy])=>[n,(B[0]+dx)/1e5,(B[1]+dy)/1e5]);a.z=0;return a}
function stLoadEmb(e){if(e.w)return Promise.resolve(e);return new Promise(res=>{if(EMB_DATA[e.k])return res(stDecode(EMB_DATA[e.k]));
 const sc=document.createElement("script");sc.src=e.f;sc.onload=()=>res(stDecode(EMB_DATA[e.k])||null);sc.onerror=()=>res(null);document.head.append(sc)})}
const fsCall=(m,a)=>O?O.call(m,a).then(dat):Promise.reject(0);

/* ---- אחסון ---- */
async function stLoadIdx(){try{ST.idx=JSON.parse((await fsCall("fs.readFile",{path:"streets/index.json"})).content)||[]}catch(e){
 try{ST.idx=JSON.parse(localStorage.getItem("kivun-streets-idx")||"[]")}catch(e2){ST.idx=[]}}
 try{const r=dat(await O.call("storage.get",{key:"kivun-st-radius"}));if(+r)ST.radius=+r}catch(e){}
 try{const l=O?dat(await O.call("storage.get",{key:"kivun-st-lang"})):localStorage.getItem("kivun-st-lang");if(l==="orig")ST.lang="orig"}catch(e){}
 stSettings()}
async function stSaveIdx(){const s=JSON.stringify(ST.idx);try{await fsCall("fs.writeFile",{path:"streets/index.json",content:s})}catch(e){try{localStorage.setItem("kivun-streets-idx",s)}catch(e2){}}}
async function stWriteArea(a){const s=JSON.stringify(a),p="streets/"+a.k+".json";
 try{await fsCall("fs.writeFile",{path:p,content:s})}catch(e){try{localStorage.setItem("kivun-st-"+a.k,s)}catch(e2){throw new Error("אין מקום לשמירה")}}
 ST.idx=ST.idx.filter(x=>x.k!==a.k);ST.idx.push({k:a.k,lat:a.lat,lon:a.lon,r:a.r,d:a.d,n:a.w.length,name:a.name||""});await stSaveIdx();stSettings()}
async function stReadArea(k){const e=EMB.find(a=>a.k===k);if(e)return stLoadEmb(e);try{return JSON.parse((await fsCall("fs.readFile",{path:"streets/"+k+".json"})).content)}catch(e){
 try{return JSON.parse(localStorage.getItem("kivun-st-"+k))}catch(e2){return null}}}
async function stDelete(k){try{await fsCall("fs.deleteEntry",{path:"streets/"+k+".json"})}catch(e){}try{localStorage.removeItem("kivun-st-"+k)}catch(e){}
 ST.idx=ST.idx.filter(x=>x.k!==k);if(ST.area&&ST.area.k===k)ST.area=null;await stSaveIdx();stSettings();if(pos)map()}
/* האזור השמור שמכסה את המיקום (בשוליים של 150 מ' מהקצה) */
function stCover(){if(!pos)return null;let b=null;for(const a of ST.idx.concat(EMB)){const m=dist(pos,[a.lat,a.lon])*1000;if(m<=a.r-150&&(!b||m<b[1]))b=[a,m]}return b&&b[0]}

/* ---- נתונים ---- */
function stQuery(lat,lon,r){const a=`(around:${r},${lat.toFixed(5)},${lon.toFixed(5)})`;
 return`[out:json][timeout:60];(way["highway"]["name"]${a};nwr["amenity"="place_of_worship"]["religion"="jewish"]${a};);out tags geom;`}
function stUrl(i,lat,lon,r){return OVP[i]+"?data="+encodeURIComponent(stQuery(lat,lon,r))}
/* קבצי Overpass גולמיים, או קובץ שכבר נשמר מהתוסף */
function stCompact(j,lat,lon,r){if(j&&Array.isArray(j.w))return j;
 const all=j&&j.elements||[],els=all.filter(e=>e.type==="way"&&(e.tags||{}).highway&&Array.isArray(e.geometry)&&e.geometry.length>1);
 if(!els.length)throw new Error("בקובץ אין רחובות");
 if(lat==null){let s=0,t=0,c=0;for(const e of els)for(const g of e.geometry){s+=g.lat;t+=g.lon;c++}lat=s/c;lon=t/c;
  r=0;for(const e of els)for(const g of e.geometry)r=Math.max(r,dist([lat,lon],[g.lat,g.lon])*1000);r=Math.round(r)}
 const w=els.map(e=>{const t=e.tags||{};return[t["name:he"]||t.name||"",t.highway||"",e.geometry.flatMap(g=>[+g.lat.toFixed(6),+g.lon.toFixed(6)])]});
 const sy=[];for(const e of all){const t=e.tags||{};if(t.amenity!=="place_of_worship")continue;let p=null;
  if(e.lat!=null)p=[e.lat,e.lon];else if(e.bounds)p=[(e.bounds.minlat+e.bounds.maxlat)/2,(e.bounds.minlon+e.bounds.maxlon)/2];
  else if(Array.isArray(e.geometry)&&e.geometry.length){let a=0,b=0;for(const g of e.geometry){a+=g.lat;b+=g.lon}p=[a/e.geometry.length,b/e.geometry.length]}
  if(p)sy.push([t["name:he"]||t.name||"",+p[0].toFixed(5),+p[1].toFixed(5)])}
 return{v:1,s:sy,k:lat.toFixed(3)+"_"+lon.toFixed(3)+"_"+r,lat:+lat.toFixed(5),lon:+lon.toFixed(5),r,d:new Date().toISOString().slice(0,10),w}}
async function stDownload(){if(!pos)return;const m=$("stMsg");m.textContent="מוריד את רחובות האזור…";$("stDl").disabled=true;let j=null,err="";
 for(let i=0;i<OVP.length&&!j;i++){try{j=await getJ(stUrl(i,pos[0],pos[1],ST.radius))}catch(e){err=e}}
 $("stDl").disabled=false;
 if(!j){m.textContent="ההורדה לא הצליחה. ייתכן שאין חיבור, או שאוצריא עדיין לא מתירה את הכתובת. אפשר להשתמש בדרך שבלי אינטרנט שמתחת.";return}
 try{const a=stCompact(j,pos[0],pos[1],ST.radius);a.name=place||src;await stWriteArea(a);ST.area=a;m.textContent=`נשמרו ${a.w.length} רחובות. מעכשיו האזור זמין גם בלי אינטרנט.`;map()}
 catch(e){m.textContent="שמירת האזור נכשלה: "+(e.message||"שגיאה")}}
async function stImport(){const m=$("stMsg");let txt=null;
 if(O){try{const r=dat(await O.call("fs.pickUserFile",{title:"בחר את קובץ הרחובות ששמרת"}));if(!r||r.cancelled)return;
   txt=dat(await O.call("fs.readTextFile",{token:r.token}))}catch(e){m.textContent="לא ניתן לפתוח את הקובץ.";return}}
 else{txt=await new Promise(res=>{const f=document.createElement("input");f.type="file";f.onchange=()=>f.files[0]?f.files[0].text().then(res):res(null);f.click()});if(txt==null)return}
 try{const a=stCompact(JSON.parse(txt));await stWriteArea(a);ST.area=a;m.textContent=`נטענו ${a.w.length} רחובות ונשמרו לשימוש בלי אינטרנט.`;
  if(!pos||dist(pos,[a.lat,a.lon])*1000>a.r)setPos([a.lat,a.lon],"מרכז אזור הרחובות שנטען",null,false);else map()}
 catch(e){m.textContent="הקובץ אינו קובץ רחובות תקין. ודא ששמרת את כל הטקסט שהדפדפן הציג."}}
/* העתקה ללוח: קודם ממשק הלוח, ואם אינו זמין — העתקה דרך שדה זמני */
function copyText(t){const legacy=()=>{try{const a=document.createElement("textarea");a.value=t;a.setAttribute("readonly","");a.style.position="fixed";a.style.opacity="0";
  document.body.append(a);a.select();const ok=document.execCommand("copy");a.remove();return ok}catch(e){return false}};
 try{if(navigator.clipboard&&navigator.clipboard.writeText)return navigator.clipboard.writeText(t).then(()=>true,legacy)}catch(e){}return Promise.resolve(legacy())}
function stCopy(){const t=$("stUrl").textContent;if(t)copyText(t).then(ok=>$("stCopy").textContent=ok?"הועתק ✓":"סמן והעתק ידנית")}
/* "פתח בדפדפן": מעתיק את הכתובת ללוח ומנסה לפתוח אותה בדפדפן החיצוני */
function stBrowser(){if(!pos)return;const url=stUrl(0,pos[0],pos[1],ST.radius);$("stUrl").textContent=url;$("stUrlBox").hidden=false;
 copyText(url).then(ok=>{$("stCopy").textContent=ok?"הועתק ✓":"העתק כתובת";
  let w=null;try{w=window.open(url,"_blank","noopener")}catch(e){}
  $("stMsg").textContent=ok?"הכתובת הועתקה. אם הדפדפן לא נפתח, הדבק אותה (Ctrl+V) בשורת הכתובת של הדפדפן.":"סמן את הכתובת שלמטה, העתק אותה (Ctrl+C) והדבק בדפדפן."})}

/* ---- שמות רחובות בחו"ל: תעתיק לעברית (ניתן לכבות בהגדרות) ---- */
const TR_TYPE={street:"רחוב",st:"רחוב",rue:"רחוב",calle:"רחוב","улица":"רחוב",straat:"רחוב",strasse:"רחוב",gasse:"רחוב",
 avenue:"שדרת",ave:"שדרת",avenida:"שדרת",laan:"שדרת",allee:"שדרת",boulevard:"שדרות",blvd:"שדרות",bd:"שדרות","проспект":"שדרת",
 road:"דרך",rd:"דרך",way:"דרך",drive:"דרך",parkway:"דרך",weg:"דרך",steenweg:"דרך","шоссе":"כביש",
 lane:"סמטת",court:"חצר",close:"סמטת",mews:"סמטת","переулок":"סמטת",impasse:"סמטת",passage:"מעבר","проезд":"מעבר",
 place:"כיכר",square:"כיכר",plaza:"כיכר",platz:"כיכר",plein:"כיכר","площадь":"כיכר",
 bridge:"גשר",pont:"גשר",puente:"גשר",brug:"גשר",brucke:"גשר","мост":"גשר",quai:"רציף",kade:"רציף","набережная":"רציף",gardens:"גני",park:"פארק"};
const TR_SUF=["steenweg","straat","strasse","gasse","platz","plein","brucke","brug","allee","laan","quai","kade","weg"];
const TR_DROP=new Set(["de","la","le","les","des","du","del","van","der","den","of","the","el","von"]);
const TR_CYR={"а":"a","б":"b","в":"v","г":"g","д":"d","е":"e","ё":"yo","ж":"zh","з":"z","и":"i","й":"y","к":"k","л":"l","м":"m","н":"n","о":"o","п":"p","р":"r","с":"s","т":"t","у":"u","ф":"f","х":"kh","ц":"ts","ч":"ch","ш":"sh","щ":"sh","ъ":"","ы":"y","ь":"","э":"e","ю":"yu","я":"ya"};
const TR_FIN={"מ":"ם","נ":"ן","פ":"ף","צ":"ץ","כ":"ך"};
const TR_MULTI=[["tsch","צ'"],["sch","ש"],["sh","ש"],["ch","צ'"],["th","ת"],["ph","פ"],["kh","ח"],["zh","ז'"],["ck","ק"],["qu","קו"],["tz","צ"],["ts","צ"],["oo","ו"],["ee","י"],["ou","ו"],["ei","יי"],["ai","יי"],["ay","יי"],["ey","יי"],["ie","י"],["ij","יי"],["oe","ו"],["ui","וי"],["au","או"],["ss","ס"],["ll","ל"],["tt","ט"],["nn","נ"],["mm","מ"],["rr","ר"],["pp","פ"],["ff","פ"],["dd","ד"],["bb","ב"],["gg","ג"],["zz","ז"]];
const TR_ONE={b:"ב",d:"ד",f:"פ",g:"ג",h:"ה",j:"ג'",k:"ק",l:"ל",m:"מ",n:"נ",p:"פ",q:"ק",r:"ר",s:"ס",t:"ט",v:"ב",w:"ו",x:"קס",z:"ז"};
function trWord(w){if(/^\d+(st|nd|rd|th)?$/.test(w))return w.replace(/\D/g,"");let o="",i=0;
 while(i<w.length){const c=w[i],st=i===0,end=i===w.length-1;let m=TR_MULTI.find(([a])=>w.startsWith(a,i));
  if(m){o+=(st&&"aeiou".includes(m[0][0])?"א":"")+m[1];i+=m[0].length;continue}
  if(c==="a")o+=st?"א":end?"ה":"";else if(c==="e")o+=st?"א":"";else if(c==="i")o+=st?"אי":"י";
  else if(c==="o"||c==="u")o+=st?"או":"ו";else if(c==="y")o+="י";else if(c==="c")o+="eiy".includes(w[i+1]||"#")?"ס":"ק";
  else if(c==="h")o+=end?"":"ה";else o+=TR_ONE[c]||(/\d/.test(c)?c:"");i++}
 return o.replace(/[מנפצכ]$/,x=>TR_FIN[x])}
const TR_CACHE=new Map();
function trName(n){if(!n||/[֐-׿]/.test(n)||!/[A-Za-zÀ-ÿЀ-ӿ]/.test(n))return n;if(TR_CACHE.has(n))return TR_CACHE.get(n);
 let s=n.toLowerCase().replace(/[Ѐ-ӿ]/g,c=>TR_CYR[c]!=null?TR_CYR[c]:c);
 const typ=[];const words=n.toLowerCase().split(/[\s\-]+/).filter(Boolean);
 s=words.map(w=>{if(TR_TYPE[w]){typ.push(TR_TYPE[w]);return""}
  let x=w.normalize("NFD").replace(/[̀-ͯ]/g,"").replace(/ß/g,"ss").replace(/[Ѐ-ӿ]/g,c=>TR_CYR[c]!=null?TR_CYR[c]:c).replace(/^(d|l)'/,"").replace(/[^a-z0-9']/g,"");
  if(TR_TYPE[x]){typ.push(TR_TYPE[x]);return""}
  if(TR_DROP.has(x))return"";
  for(const f of TR_SUF)if(x.length>f.length+2&&x.endsWith(f)){typ.push(TR_TYPE[f]||"רחוב");x=x.slice(0,-f.length);break}
  return trWord(x.replace(/'/g,""))}).filter(Boolean).join(" ");
 const r=((typ[0]?typ[0]+" ":"")+s).trim()||n;TR_CACHE.set(n,r);return r}
const stNm=n=>ST.lang==="orig"?n:trName(n);

/* ---- ציור ---- */
const stM=()=>[111320*Math.cos(pos[0]*R),110540];
function stView(){const hw=300/zoom,[kx,ky]=stM();return{hw,hh:hw*.8,kx,ky,cx:ST.pan[0],cy:ST.pan[1]}}
function stXY(v,la,lo){const x=(lo-pos[1])*v.kx-v.cx,y=(la-pos[0])*v.ky-v.cy;return[200+x*200/v.hw,160-y*160/v.hh]}
async function streetMap(){const svg=$("map"),panel=$("stPanel");panel.hidden=false;const cov=stCover();
 if(!cov){ST.area=null;svg.innerHTML=`<text x="200" y="150" text-anchor="middle" font-size="14" fill="var(--color-on-surface)">אין עדיין מפת רחובות לאזור הזה</text><text x="200" y="174" text-anchor="middle" font-size="12" fill="var(--color-on-surface-dim)">אפשר להוריד אותה פעם אחת בכפתור שמתחת</text>`;
  $("stNone").hidden=false;$("stTxt").textContent="";return}
 $("stNone").hidden=true;
 if(!ST.area||ST.area.k!==cov.k){ST.area=await stReadArea(cov.k);ST.sel=null;if(!ST.area){svg.innerHTML="";$("stTxt").textContent=EMB.some(a=>a.k===cov.k)?"לא ניתן לטעון את נתוני האזור המובנים.":"קובץ האזור חסר. הורד אותו שוב.";return}stNames()}
 const v=stView(),b=bear(),P=(la,lo)=>stXY(v,la,lo),f=n=>n.toFixed(1);let lines="",labels="",hl="";
 for(let i=0;i<ST.area.w.length;i++){const[nmS,hw,g]=ST.area.w[i];let d="",best=null,bx=[1e9,-1e9,1e9,-1e9];
  for(let k=0;k<g.length;k+=2){const p=P(g[k],g[k+1]);bx=[Math.min(bx[0],p[0]),Math.max(bx[1],p[0]),Math.min(bx[2],p[1]),Math.max(bx[3],p[1])];d+=(k?"L":"M")+f(p[0])+","+f(p[1]);
   if(k){const q=P(g[k-2],g[k-1]),L=Math.hypot(p[0]-q[0],p[1]-q[1]);if(!best||L>best[0])best=[L,q,p]}}
  if(bx[1]<-50||bx[0]>450||bx[3]<-50||bx[2]>370)continue;const big=/^(motorway|trunk|primary|secondary)/.test(hw);
  lines+=`<path d="${d}" fill="none" stroke="var(--color-on-surface-dim)" stroke-opacity=".75" stroke-width="${big?4:2.5}" stroke-linecap="round" stroke-linejoin="round"/>`;
  if(best&&best[0]>70&&nmS){let a=Math.atan2(best[2][1]-best[1][1],best[2][0]-best[1][0])/R;if(a>90)a-=180;if(a<-90)a+=180;
   const cl=x=>Math.max(15,Math.min(385,x)),mx=cl((best[1][0]+best[2][0])/2),my=Math.max(15,Math.min(300,(best[1][1]+best[2][1])/2));
   labels+=`<text transform="translate(${f(mx)},${f(my)}) rotate(${f(a)})" y="-5" text-anchor="middle" font-size="11" fill="var(--color-on-surface)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">${esc(stNm(nmS))}</text>`}}
 if(ST.sel){const g=ST.area.w[ST.sel.i][2],q=P(g[ST.sel.k],g[ST.sel.k+1]),p=P(g[ST.sel.k+2],g[ST.sel.k+3]);
  hl=`<line x1="${f(q[0])}" y1="${f(q[1])}" x2="${f(p[0])}" y2="${f(p[1])}" stroke="var(--color-primary)" stroke-width="7" stroke-linecap="round"/>`}
 let syn="";if(ST.showSyn)for(const[sn,la,lo]of ST.area.s||[]){const p=P(la,lo);if(p[0]<-10||p[0]>410||p[1]<-10||p[1]>330)continue;
  syn+=`<g><title>${esc(sn||"בית כנסת")}</title><text x="${f(p[0])}" y="${f(p[1]+5)}" text-anchor="middle" font-size="14" fill="var(--color-primary)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">✡</text>`
   +(zoom>=2&&sn?`<text x="${f(p[0])}" y="${f(p[1]+18)}" text-anchor="middle" font-size="10" fill="var(--color-primary)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">${esc(sn)}</text>`:"")+"</g>"}
 const a=P(pos[0],pos[1]),L=150,e=[a[0]+Math.sin(b*R)*L,a[1]-Math.cos(b*R)*L];
 svg.innerHTML=lines+hl+labels+syn+`<line x1="${f(a[0])}" y1="${f(a[1])}" x2="${f(e[0])}" y2="${f(e[1])}" stroke="var(--color-primary)" stroke-width="3" stroke-dasharray="8 4"/><circle cx="${f(e[0])}" cy="${f(e[1])}" r="6" fill="var(--color-primary)"/>`
  +`<text x="${f(e[0])}" y="${f(e[1]-9)}" text-anchor="middle" font-size="12" fill="var(--color-on-surface)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">לירושלים</text>`
  +`<circle cx="${f(a[0])}" cy="${f(a[1])}" r="6" fill="var(--color-on-surface)" stroke="var(--color-surface)" stroke-width="2"/>`
  +`<text x="392" y="18" direction="rtl" text-anchor="start" font-size="12" fill="var(--color-on-surface-dim)">↑ צפון · ${Math.round(v.hw*2)} מ' לרוחב</text>`
  +`<text x="8" y="312" direction="ltr" text-anchor="start" font-size="10" fill="var(--color-on-surface-dim)">© OpenStreetMap contributors · ${esc(ST.area.d||"")}</text>`;
 stText()}
/* ההוראה: לאורך איזה רחוב לעמוד, ובכמה מעלות להסתובב ממנו */
function stText(){const t=$("stTxt");if(!ST.sel){t.textContent=ST.setHere?"לחץ במפה על המקום שבו אתה נמצא.":"לחץ במפה על הרחוב שלידך, ותקבל הוראה ביחס לכיוון שלו.";return}
 const g=ST.area.w[ST.sel.i][2],k=ST.sel.k,s=bearing([g[k],g[k+1]],[g[k+2],g[k+3]]),b=bear(),
  d1=((b-s+540)%360)-180,d2=((b-s+360)%360)-180,[sd,d]=Math.abs(d1)<=Math.abs(d2)?[s,d1]:[(s+180)%360,d2],n=stNm(ST.area.w[ST.sel.i][0])||"הרחוב";
 const turnS=Math.abs(d)<5?"וזה הכיוון.":`והסתובב ${Math.round(Math.abs(d))}° ${d>0?"ימינה":"שמאלה"}.`;
 t.textContent=`עמוד במקביל ל${n}, כשפניך לאורך הרחוב לכיוון ${nm(sd)}, ${turnS}`+(Math.abs(Math.abs(d)-90)<8?` (כמעט ניצב לרחוב: פנים אל הבתים שבצד ה${nm(b)} שלו.)`:"")}
function stClick(ev){if(!ST.area||!pos)return;const svg=$("map"),pt=svg.createSVGPoint();pt.x=ev.clientX;pt.y=ev.clientY;
 const c=pt.matrixTransform(svg.getScreenCTM().inverse()),v=stView();
 if(ST.setHere){const x=(c.x-200)*v.hw/200+v.cx,y=(160-c.y)*v.hh/160+v.cy,[kx,ky]=stM(),np=[pos[0]+y/ky,pos[1]+x/kx];
  ST.setHere=false;$("stHere").classList.remove("on");ST.pan=[0,0];zoomKeep(()=>setPos(np,"נקודה שסומנה במפת הרחובות",null,false));
  mode="m:"+np[0].toFixed(6)+","+np[1].toFixed(6);save(mode);return}
 let best=null;ST.area.w.forEach(([,,g],i)=>{for(let k=0;k+3<g.length;k+=2){const q=stXY(v,g[k],g[k+1]),p=stXY(v,g[k+2],g[k+3]),dx=p[0]-q[0],dy=p[1]-q[1],
  u=Math.max(0,Math.min(1,((c.x-q[0])*dx+(c.y-q[1])*dy)/(dx*dx+dy*dy||1))),dd=Math.hypot(q[0]+u*dx-c.x,q[1]+u*dy-c.y);if(!best||dd<best[0])best=[dd,i,k]}});
 if(best&&best[0]<14){ST.sel={i:best[1],k:best[2]};streetMap()}}
/* חיפוש רחוב: מסמן את הקטע הארוך ביותר שלו, מזיז אליו את המפה ונותן הוראה */
function stNames(){const d=$("stNames");if(!d||!ST.area)return;const n=[...new Set(ST.area.w.map(x=>stNm(x[0])).filter(Boolean))].sort((a,b)=>a.localeCompare(b,"he"));
 d.replaceChildren(...n.map(x=>{const o=document.createElement("option");o.value=x;return o}))}
function stFind(){const q=$("stQ").value.trim();if(!q||!ST.area)return;const nq=x=>x.replace(/["'״׳\-]/g,"").replace(/\s+/g," ").trim();
 const Q=nq(q);const nm2=x=>[nq(x[0]),nq(stNm(x[0]))];let ws=ST.area.w.map((x,i)=>[x,i]).filter(([x])=>nm2(x).some(v=>v===Q));if(!ws.length)ws=ST.area.w.map((x,i)=>[x,i]).filter(([x])=>nm2(x).some(v=>v.toLowerCase().includes(Q.toLowerCase())));
 if(!ws.length){$("stTxt").textContent=`לא נמצא רחוב בשם "${q}" באזור הזה.`;return}
 const[kx,ky]=stM();let best=null;for(const[[,,g],i]of ws)for(let k=0;k+3<g.length;k+=2){const L=Math.hypot((g[k+2]-g[k])*ky,(g[k+3]-g[k+1])*kx);if(!best||L>best[0])best=[L,i,k]}
 const g=ST.area.w[best[1]][2],k=best[2],mla=(g[k]+g[k+2])/2,mlo=(g[k+1]+g[k+3])/2;ST.sel={i:best[1],k};ST.pan=[(mlo-pos[1])*kx,(mla-pos[0])*ky];
 const far=Math.max(Math.abs(ST.pan[0]),Math.abs(ST.pan[1]));if(far>300/zoom)zoom=Math.max(.25,300/(far*1.2));streetMap()}
function zoomKeep(fn){const z=zoom;fn();zoom=z;map()}

/* ---- הגדרות: האזורים השמורים והסבר לעבודה בלי אינטרנט ---- */
function stSettings(){const l=$("stList");if(!l)return;l.replaceChildren();
 const eb=$("stEmb");if(eb)eb.textContent=EMB.length?`מובנים בתוסף, בלי הורדה (${EMB.length} אזורים): `+EMB.map(a=>a.name).join(", ")+".":"";
 if(!ST.idx.length){const li=document.createElement("li");li.textContent="עדיין לא נשמר אף אזור.";l.append(li)}
 for(const a of ST.idx){const li=document.createElement("li"),x=document.createElement("button");
  li.textContent=`${a.name||a.lat+", "+a.lon} — ${a.n} רחובות, ברדיוס ${a.r>=1000?(a.r/1000)+' ק"מ':a.r+" מ'"} (${a.d}) `;
  x.textContent="מחק";x.onclick=()=>stDelete(a.k);li.append(x);l.append(li)}
 $("stRad").value=String(ST.radius);if($("stLang"))$("stLang").value=ST.lang}

/* ---- חיבור לממשק ---- */
(function(){const prevMap=map;
 map=function(){if($("mapMode").value==="street"&&pos)return streetMap();$("stPanel").hidden=true;return prevMap()};
 $("mapMode").onchange=()=>map(); $("stDl").onclick=stDownload;$("stImp").onclick=stImport;$("stBrw").onclick=stBrowser;$("stCopy").onclick=stCopy;
 $("stGo").onclick=stFind;$("stQ").onkeydown=e=>{if(e.key==="Enter")stFind()};$("stSyn").onchange=()=>{ST.showSyn=$("stSyn").checked;streetMap()};
 $("stHere").onclick=()=>{ST.setHere=!ST.setHere;$("stHere").classList.toggle("on",ST.setHere);stText()};
 $("stLang").onchange=()=>{ST.lang=$("stLang").value;try{O?O.call("storage.set",{key:"kivun-st-lang",value:ST.lang}).catch(()=>{}):localStorage.setItem("kivun-st-lang",ST.lang)}catch(e){}if(ST.area){stNames();streetMap()}};
 $("stRad").onchange=()=>{ST.radius=+$("stRad").value;try{O&&O.call("storage.set",{key:"kivun-st-radius",value:ST.radius}).catch(()=>{})}catch(e){}};
 $("bSet").onclick=()=>{const o=$("set").hidden;pop("bHelp","help",false);pop("bFb","fb",false);pop("bSet","set",o)};
 const svg=$("map");let drag=null,moved=false;
 svg.addEventListener("pointerdown",e=>{if($("mapMode").value!=="street"||!ST.area)return;drag=[e.clientX,e.clientY,ST.pan[0],ST.pan[1]];moved=false});
 svg.addEventListener("pointermove",e=>{if(!drag)return;const r=svg.getBoundingClientRect(),v=stView(),dx=(e.clientX-drag[0])*400/r.width,dy=(e.clientY-drag[1])*320/r.height;
  if(Math.hypot(dx,dy)>4)moved=true;if(moved){ST.pan=[drag[2]-dx*v.hw/200,drag[3]+dy*v.hh/160];streetMap()}});
 addEventListener("pointerup",e=>{if(drag&&!moved&&e.target&&svg.contains(e.target))stClick(e);drag=null});
 const zr=$("zReset").onclick;$("zReset").onclick=()=>{ST.pan=[0,0];zr()};
 stLoadIdx();if(O)O.on("plugin.boot",()=>stLoadIdx())})();
