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
loanType:document.getElementById("loanType").value,
amount:document.getElementById("budget").value,
city:document.getElementById("city").value,
message:document.getElementById("message").value

};

try{

const res=await fetch("/api/lead",{

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
