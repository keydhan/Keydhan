/* ==========================================
   KeyDhan™ V20.1 Enterprise
========================================== */

/* ---------- MENU ---------- */

const menuBtn=document.getElementById("menuBtn");
const menu=document.getElementById("menu");

if(menuBtn&&menu){

menuBtn.addEventListener("click",()=>{

menu.classList.toggle("show");

});

document.addEventListener("click",(e)=>{

if(!menu.contains(e.target)&&!menuBtn.contains(e.target)){

menu.classList.remove("show");

}

});

}

/* ---------- HIDDEN ADMIN ---------- */

let adminTap=0;
let adminTimer;

const adminLogo=document.getElementById("adminLogo");

if(adminLogo){

adminLogo.addEventListener("click",()=>{

adminTap++;

clearTimeout(adminTimer);

adminTimer=setTimeout(()=>{

adminTap=0;

},2000);

if(adminTap>=5){

window.location.href="/admin/";

}

});

}

/* ---------- FORMAT ---------- */

function money(v){

return "₹"+Number(v).toLocaleString("en-IN",{

maximumFractionDigits:2

});

}

/* ---------- EMI ---------- */

let chart=null;

function calc(){

const loan=document.getElementById("loan");
const rate=document.getElementById("rate");
const tenure=document.getElementById("tenure");
const type=document.getElementById("type");

let P=Number(loan.value);
let R=Number(rate.value);
let N=Number(tenure.value);

if(type.value==="y") N*=12;

if(!P||!R||!N){

alert("Please fill all fields.");

return;

}

const r=R/1200;

const EMI=P*r*Math.pow(1+r,N)/(Math.pow(1+r,N)-1);

const total=EMI*N;
const interest=total-P;

const flatYear=((interest/P)/(N/12))*100;
const flatMonth=flatYear/12;

emi.innerText=money(EMI);
interestEl.innerText=money(interest);
totalEl.innerText=money(total);
flatM.innerText=flatMonth.toFixed(2)+"%";
flatY.innerText=flatYear.toFixed(2)+"%";

results.style.display="block";
chartBox.style.display="none";

createAmortisation(P,r,EMI,N);

drawPie(P,interest);

}

/* ---------- ELEMENT SHORTCUTS ---------- */

const results=document.getElementById("results");
const chartBox=document.getElementById("chart");
const emi=document.getElementById("emi");
const interestEl=document.getElementById("interest");
const totalEl=document.getElementById("total");
const flatM=document.getElementById("flatM");
const flatY=document.getElementById("flatY");

/* ---------- AMORTISATION ---------- */

function createAmortisation(P,r,EMI,N){

const rows=document.getElementById("rows");

rows.innerHTML="";

let bal=P;

for(let i=1;i<=Math.min(N,240);i++){

const ip=bal*r;
const pp=EMI-ip;

bal=Math.max(0,bal-pp);

rows.innerHTML+=`
<tr>
<td>${i}</td>
<td>${money(pp)}</td>
<td>${money(ip)}</td>
<td>${money(bal)}</td>
</tr>`;

}

}

/* ---------- TOGGLE ---------- */

function toggleChart(){

chartBox.style.display=
chartBox.style.display==="block"
?"none":"block";

}

/* ---------- PIE CHART ---------- */

function drawPie(principal,interest){

const canvas=document.getElementById("emiChart");

if(!canvas) return;

const ctx=canvas.getContext("2d");

if(chart) chart.destroy();

chart=new Chart(ctx,{
type:"pie",
data:{
labels:["Principal","Interest"],
datasets:[{
data:[principal,interest],
backgroundColor:["#D4AF37","#4B5563"]
}]
},
options:{
plugins:{
legend:{
labels:{
color:"#fff"
}
}
}
}
});

}

/* ---------- PROPERTY AUTO FILL ---------- */

function enquire(property,amount){

const contact=document.getElementById("contact");

if(contact){

contact.scrollIntoView({

behavior:"smooth"

});

}

const budget=document.getElementById("budget");
const propertyName=document.getElementById("propertyName");
const message=document.getElementById("message");

if(budget) budget.value=amount;
if(propertyName) propertyName.value=property;

if(message){

message.value="I'm interested in "+property+".";

}

}

/* ---------- ENTER KEY ---------- */

["loan","rate","tenure"].forEach(id=>{

const field=document.getElementById(id);

if(field){

field.addEventListener("keypress",e=>{

if(e.key==="Enter") calc();

});

}

});

/* ---------- LEAD FORM API ---------- */

const form=document.getElementById("leadForm");

if(form){

form.addEventListener("submit",async function(e){

e.preventDefault();

const data={

name:document.getElementById("name").value,
mobile:document.getElementById("mobile").value,
email:document.getElementById("email").value,
interest:document.getElementById("loanType").value,
amount:document.getElementById("budget").value,
propertyId:document.getElementById("propertyName")?.value||"",
city:document.getElementById("city").value,
message:document.getElementById("message").value

};

try{

const res=await fetch("https://admin-api.keydhan.com/api/leads",{

method:"POST",

headers:{
"Content-Type":"application/json"
},

body:JSON.stringify(data)

});

const out=await res.json();

if(out.success){

showToast("Lead submitted successfully.");

form.reset();

}else{

showToast("Submission failed.");

}

}catch(err){

showToast("Server unavailable.");

}

});

}

/* ---------- TOAST ---------- */

function showToast(msg){

const old=document.getElementById("toast");

if(old) old.remove();

const div=document.createElement("div");

div.id="toast";

div.innerText=msg;

div.style.cssText=`
position:fixed;
bottom:20px;
right:20px;
background:#D4AF37;
color:#111;
padding:14px 20px;
border-radius:12px;
font-weight:700;
box-shadow:0 10px 30px rgba(0,0,0,.35);
z-index:9999;
`;

document.body.appendChild(div);

setTimeout(()=>{

div.remove();

},2500);

}

/* ---------- APP INFO ---------- */

const KeyDhan={

version:"V20.1",

security:"Cloudflare Access Ready",

status:"Production Ready"

};

console.log("KeyDhan™ V20.1 Loaded");


/* ---------- LIVE CMS CONTENT + PROPERTIES ---------- */
(async function loadKeyDhanCMS(){
 const API_URL="https://admin-api.keydhan.com/api";
 const safe=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
 try{
  const [cr,pr,sr,or]=await Promise.all([fetch(API_URL+"/content",{cache:"no-store"}),fetch(API_URL+"/properties",{cache:"no-store"}),fetch(API_URL+"/settings",{cache:"no-store"}),fetch(API_URL+"/loan-offers",{cache:"no-store"})]);
  const cd=cr.ok?await cr.json():{},pd=pr.ok?await pr.json():{},sd=sr.ok?await sr.json():{},od=or.ok?await or.json():{};
  const c=cd.content||{};const s=sd.settings||{};
  const set=(selector,value)=>{const el=document.querySelector(selector);if(el&&value)el.textContent=value};
  set(".hero h1",c.heroTitle);set(".hero p",c.heroSubtitle);set(".hero .btn",c.heroButton);set("#services h2",c.servicesTitle);set("#properties h2",c.propertiesTitle);set("#contact h2",c.contactTitle);set("footer h3",s.businessName||c.footerText);set("footer p",s.contactEmail);
  if(c.heroImage){const hero=document.querySelector(".hero");if(hero)hero.style.backgroundImage="linear-gradient(90deg,rgba(2,8,20,.88),rgba(2,8,20,.55)),url('"+c.heroImage.replace(/['()\\]/g,"")+"')";}
  const services=document.querySelector("#services .grid");if(services&&Array.isArray(c.services)&&c.services.length)services.innerHTML=c.services.map(x=>'<div class="card">'+safe(x)+'</div>').join("");
  const grid=document.querySelector("#properties .grid");const props=Array.isArray(pd.properties)?pd.properties:[];
  const priceLabel=v=>{const raw=String(v??"").trim();if(!raw)return "Price on request";if(/[₹]|lakh|lac|crore|cr\\b|\\bnegotiable\\b/i.test(raw))return raw;const n=Number(raw.replace(/[,\\s]/g,""));if(!Number.isFinite(n)||n<=0)return raw;if(n>=10000000)return "₹"+(n/10000000).toLocaleString("en-IN",{maximumFractionDigits:2})+" Crore";if(n>=100000)return "₹"+(n/100000).toLocaleString("en-IN",{maximumFractionDigits:2})+" Lakh";return "₹"+n.toLocaleString("en-IN")};
  const homeCard=p=>{
   const title=safe(p.title||"Property"),image=String(p.image||"").trim(),location=safe(p.location||"Location on request"),description=safe(p.description||p.desc||"");
   const beds=Number(p.bedrooms)||0,type=safe(p.type||p.propertyType||p.property_type||"Residential");
   const visual=image?'<div class="home-property-visual"><span class="visual-brand">KEYDHAN PROPERTY</span><img loading="lazy" src="'+safe(image)+'" alt="'+title+'" onerror="this.remove()"></div>':'<div class="home-property-visual home-property-placeholder"><span class="visual-brand">KEYDHAN PROPERTY</span><svg class="home-house-icon" viewBox="0 0 64 64" fill="none" aria-hidden="true"><path d="M8 29 32 9l24 20M15 25v29h34V25M26 54V37h12v17" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>';
   const price=safe(priceLabel(p.price));
   const pin='<svg viewBox="0 0 24 24" width="16" height="16" fill="none" aria-hidden="true"><path d="M20 10c0 5-8 12-8 12S4 15 4 10a8 8 0 1 1 16 0Z" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="10" r="2.5" stroke="currentColor" stroke-width="1.8"/></svg>';
   return '<article class="card home-property-card">'+visual+'<div class="home-property-body"><h3 class="home-property-title">'+title+'</h3><div class="home-property-price">'+price+'</div><div class="home-property-location">'+pin+'<span>'+location+'</span></div><div class="home-property-tags">'+(beds?'<span class="home-property-detail">'+beds+' BHK</span>':'')+(type?'<span class="home-property-detail">'+type+'</span>':'')+(p.featured?'<span class="home-property-badge">★ Featured</span>':'')+'</div>'+(description?'<p class="home-property-description">'+description+'</p>':'')+'<button type="button" class="home-property-enquire" data-enquire-title="'+title+'" data-enquire-price="'+safe(p.price)+'">Enquire Now <span aria-hidden="true">↗</span></button></div></article>';
  }
  if(grid){
   const status=document.getElementById("featuredStatus"),prev=document.getElementById("featuredPrev"),next=document.getElementById("featuredNext"),dots=document.getElementById("featuredDots");
   const dateValue=p=>{for(const k of ["updatedAt","updated_at","lastUpdated","last_updated","modifiedAt","modified_at","publishedAt","published_at","createdAt","created_at","timestamp"]){const v=p&&p[k];if(v){const n=typeof v==="number"?(v<1e12?v*1000:v):Date.parse(v);if(Number.isFinite(n))return n;}}return 0;};
   const slides=props.filter(p=>String(p.status||"published").toLowerCase()==="published").sort((a,b)=>dateValue(b)-dateValue(a)).slice(0,6);let current=0;
   const render=()=>{grid.innerHTML=slides.length?homeCard(slides[current]):"<p>No properties available right now.</p>";if(status)status.textContent=slides.length?"Showing latest "+slides.length+" of "+props.length+" published properties":"No published properties yet";if(prev)prev.disabled=current===0;if(next)next.disabled=current>=slides.length-1;if(dots)dots.innerHTML=slides.map((p,i)=>'<button type="button" class="slider-dot'+(i===current?" active":"")+'" data-slide="'+i+'" aria-label="Show property '+(i+1)+'"></button>').join("");};
   render();if(prev)prev.addEventListener("click",()=>{if(current>0){current--;render();}});if(next)next.addEventListener("click",()=>{if(current<slides.length-1){current++;render();}});if(dots)dots.addEventListener("click",e=>{const b=e.target.closest("[data-slide]");if(b){current=Number(b.dataset.slide)||0;render();}});
   let startX=0;grid.addEventListener("touchstart",e=>{startX=e.changedTouches[0].clientX;},{passive:true});grid.addEventListener("touchend",e=>{const dx=e.changedTouches[0].clientX-startX;if(Math.abs(dx)>45){current=Math.max(0,Math.min(slides.length-1,current+(dx<0?1:-1)));render();}},{passive:true});
   grid.addEventListener("click",e=>{const b=e.target.closest("[data-enquire-title]");if(b)enquire(b.dataset.enquireTitle,b.dataset.enquirePrice);});
  }
  const offerGrid=document.querySelector("#offers .grid");const offers=Array.isArray(od.offers)?od.offers:[];if(offerGrid)offerGrid.innerHTML=offers.map(o=>'<div class="card"><h3>'+safe(o.title)+'</h3><p>'+safe(o.lender)+'</p><p>'+safe(o.interestRate)+'</p><p>'+safe(o.description)+'</p></div>').join("");
  if(s.contactEmail){const f=document.querySelector("footer");if(f){const ps=f.querySelectorAll("p");if(ps[0])ps[0].textContent=s.contactEmail;if(ps[1]&&s.contactPhone)ps[1].textContent=s.contactPhone;}}
 }catch(e){console.warn("KeyDhan CMS content not loaded; static page fallback remains.",e)}
})();
