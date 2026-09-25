/* ==========================================
   KeyDhan™ V20 Enterprise
   admin/dashboard.js
   Version: V20.3
========================================== */

const Dashboard = {

version: "V20.3",

leads: [

{
id:1,
name:"Rahul Sharma",
mobile:"9876543210",
loan:"Home Loan",
budget:"₹45L",
city:"Faridabad",
status:"New"
},

{
id:2,
name:"Aman Verma",
mobile:"9811111111",
loan:"LAP",
budget:"₹25L",
city:"Gurugram",
status:"Follow-up"
},

{
id:3,
name:"Priya Singh",
mobile:"9899999999",
loan:"Business Loan",
budget:"₹18L",
city:"Noida",
status:"Approved"
}

]

};

/* -----------------------------
   Mobile Sidebar
------------------------------ */

function toggleSidebar(){

const sidebar=document.getElementById("sidebar");

if(sidebar){

sidebar.classList.toggle("show");

}

}

/* -----------------------------
   Render Leads Table
------------------------------ */

function renderLeads(){

const table=document.querySelector("tbody");

if(!table) return;

table.innerHTML="";

Dashboard.leads.forEach(lead=>{

const cls=getStatusClass(lead.status);

table.innerHTML+=`

<tr>

<td>${lead.name}</td>

<td>${lead.loan}</td>

<td>${lead.budget}</td>

<td>
<span class="status ${cls}">
${lead.status}
</span>
</td>

</tr>

`;

});

updateStats();

}

/* -----------------------------
   Status Color
------------------------------ */

function getStatusClass(status){

switch(status){

case "New":

return "new";

case "Follow-up":

return "follow";

case "Approved":

return "closed";

default:

return "new";

}

}

/* -----------------------------
   Dashboard Stats
------------------------------ */

function updateStats(){

const total=Dashboard.leads.length;

const leadCard=document.getElementById("leadCount");

if(leadCard){

animateCounter(leadCard,total);

}

}

/* -----------------------------
   Animated Counter
------------------------------ */

function animateCounter(el,target){

let count=0;

const speed=20;

const timer=setInterval(()=>{

count++;

el.innerText=count;

if(count>=target){

clearInterval(timer);

}

},speed);

}

/* -----------------------------
   Search Leads
------------------------------ */

function searchLeads(keyword){

keyword=keyword.toLowerCase();

const table=document.querySelector("tbody");

table.innerHTML="";

Dashboard.leads
.filter(l=>

l.name.toLowerCase().includes(keyword)||

l.loan.toLowerCase().includes(keyword)||

l.city.toLowerCase().includes(keyword)

)

.forEach(lead=>{

table.innerHTML+=`

<tr>

<td>${lead.name}</td>

<td>${lead.loan}</td>

<td>${lead.budget}</td>

<td>
<span class="status ${getStatusClass(lead.status)}">
${lead.status}
</span>
</td>

</tr>

`;

});

}

/* -----------------------------
   Add Demo Lead
------------------------------ */

function addDemoLead(){

Dashboard.leads.unshift({

id:Date.now(),

name:"New Customer",

mobile:"9000000000",

loan:"Home Loan",

budget:"₹30L",

city:"Delhi",

status:"New"

});

renderLeads();

showToast("New lead added.");

}

/* -----------------------------
   Export CSV
------------------------------ */

function exportCSV(){

let csv="Name,Mobile,Loan,Budget,City,Status\n";

Dashboard.leads.forEach(l=>{

csv+=`${l.name},${l.mobile},${l.loan},${l.budget},${l.city},${l.status}\n`;

});

const blob=new Blob([csv],{

type:"text/csv"

});

const url=URL.createObjectURL(blob);

const a=document.createElement("a");

a.href=url;

a.download="KeyDhan_Leads.csv";

a.click();

URL.revokeObjectURL(url);

showToast("CSV downloaded.");

}

/* -----------------------------
   Toast
------------------------------ */

function showToast(msg){

const old=document.getElementById("toast");

if(old) old.remove();

const toast=document.createElement("div");

toast.id="toast";

toast.innerText=msg;

toast.style.cssText=`

position:fixed;
bottom:25px;
right:25px;
background:#D4AF37;
color:#111;
padding:14px 20px;
border-radius:12px;
font-weight:700;
box-shadow:0 10px 30px rgba(0,0,0,.35);
z-index:9999;
`;

document.body.appendChild(toast);

setTimeout(()=>{

toast.remove();

},2500);

}

/* -----------------------------
   Clock
------------------------------ */

function startClock(){

const top=document.querySelector(".admin-info small");

if(!top) return;

setInterval(()=>{

const now=new Date();

top.innerText=

"KeyDhan™ Admin • "+

now.toLocaleTimeString();

},1000);

}

/* -----------------------------
   Auto Logout
------------------------------ */

let idleTimer;

function resetIdle(){

clearTimeout(idleTimer);

idleTimer=setTimeout(()=>{

alert("Session expired.");

window.location.href="index.html";

},15*60*1000);

}

["click","keypress","mousemove","touchstart"].forEach(e=>{

document.addEventListener(e,resetIdle);

});

/* -----------------------------
   Theme Loader
------------------------------ */

function loadDashboard(){

renderLeads();

startClock();

resetIdle();

console.log("KeyDhan™ Dashboard Loaded");

}

/* -----------------------------
   Future APIs
------------------------------ */

const API={

googleSheets:false,

cloudflare:false,

whatsapp:false,

analytics:false

};

/* -----------------------------
   Start
------------------------------ */

document.addEventListener("DOMContentLoaded",loadDashboard);
