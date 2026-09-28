/* ==========================================
   KeyDhan™ V23 Enterprise
   admin/dashboard.js
========================================== */

// Working Cloudflare Worker API
const API_BASE = "https://polished-band-182e.keydhan2.workers.dev/api";

const Dashboard = {
  version: "V23",
  properties: [],
  leads: []
};

const demoLeads = [
  { name:"Rahul Sharma", loan:"Home Loan", budget:"₹45L", status:"New"},
  { name:"Aman Verma", loan:"LAP", budget:"₹25L", status:"Follow-up"},
  { name:"Priya Singh", loan:"Business Loan", budget:"₹18L", status:"Approved"}
];

/* ---------- Sidebar ---------- */

function toggleSidebar(){
  const sidebar=document.getElementById("sidebar");
  if(sidebar) sidebar.classList.toggle("show");
}

/* ---------- API ---------- */

async function fetchProperties(){

  try{

    const res=await fetch(`${API_BASE}/properties`);

    if(!res.ok) throw new Error();

    Dashboard.properties=await res.json();

    Dashboard.leads=Dashboard.properties.map(p=>({
      name:p.title,
      loan:"Property",
      budget:p.price,
      status:"New"
    }));

  }catch(e){

    console.warn("API unavailable");

    Dashboard.leads=[...demoLeads];

  }

}

/* ---------- Render ---------- */

function renderLeads(){

  const table=document.querySelector("tbody");

  if(!table) return;

  table.innerHTML="";

  Dashboard.leads.forEach(l=>{

    table.innerHTML+=`
      <tr>
        <td>${l.name}</td>
        <td>${l.loan}</td>
        <td>${l.budget}</td>
        <td><span class="status ${getStatus(l.status)}">${l.status}</span></td>
      </tr>
    `;

  });

  updateStats();

}

function getStatus(status){

  switch(status){

    case "Follow-up": return "follow";
    case "Approved": return "closed";
    default:return "new";

  }

}

/* ---------- Dashboard Cards ---------- */

function updateStats(){

  const lead=document.getElementById("leadCount");
  if(lead) lead.innerText=Dashboard.leads.length;

  const property=document.getElementById("propertyCount");
  if(property) property.innerText=Dashboard.properties.length || 32;

}

/* ---------- Toast ---------- */

function showToast(msg){

  const old=document.getElementById("toast");
  if(old) old.remove();

  const t=document.createElement("div");

  t.id="toast";
  t.innerText=msg;

  t.style.cssText=`
    position:fixed;
    right:20px;
    bottom:20px;
    background:#D4AF37;
    color:#111;
    padding:14px 22px;
    border-radius:12px;
    font-weight:700;
    z-index:9999;
  `;

  document.body.appendChild(t);

  setTimeout(()=>t.remove(),2500);

}

/* ---------- Clock ---------- */

function startClock(){

  const top=document.querySelector(".admin-info small");

  if(!top) return;

  setInterval(()=>{

    top.innerText="KeyDhan™ Admin • "+new Date().toLocaleTimeString();

  },1000);

}

/* ---------- Auto Logout ---------- */

let idleTimer;

function resetIdle(){

  clearTimeout(idleTimer);

  idleTimer=setTimeout(()=>{

    localStorage.clear();
    sessionStorage.clear();

    window.location.href="https://keydhan.com/cdn-cgi/access/logout";

  },15*60*1000);

}

["mousemove","click","keypress","touchstart","scroll"].forEach(e=>{

  document.addEventListener(e,resetIdle,{passive:true});

});

/* ---------- Auto Refresh ---------- */

setInterval(async()=>{

  await fetchProperties();
  renderLeads();

},30000);

/* ---------- Load ---------- */

async function loadDashboard(){

  await fetchProperties();

  renderLeads();

  startClock();

  resetIdle();

  console.log("KeyDhan™ Dashboard V23 Connected");

}

document.addEventListener("DOMContentLoaded",loadDashboard);
