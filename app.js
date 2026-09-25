/* ===========================
   KeyDhan™ V20 Enterprise
   app.js
=========================== */

/* ---------- Hamburger Menu ---------- */

const menuBtn = document.getElementById("menuBtn");
const menu = document.getElementById("menu");

if (menuBtn && menu) {

menuBtn.addEventListener("click", () => {

menu.classList.toggle("show");

});

document.addEventListener("click", (e) => {

if (!menu.contains(e.target) && !menuBtn.contains(e.target)) {

menu.classList.remove("show");

}

});

}

/* ---------- Hidden Admin (5 Click Logo) ---------- */

let adminTap = 0;
let adminTimer;

const adminLogo = document.getElementById("adminLogo");

if (adminLogo) {

adminLogo.addEventListener("click", () => {

adminTap++;

clearTimeout(adminTimer);

adminTimer = setTimeout(() => {

adminTap = 0;

}, 2000);

if (adminTap >= 5) {

window.location.href = "/admin/";

}

});

}

/* ---------- Currency Formatter ---------- */

function money(value) {

return "₹" + Number(value).toLocaleString("en-IN", {

maximumFractionDigits: 2

});

}

/* ---------- EMI Calculator ---------- */

function calc() {

const loan = document.getElementById("loan");
const rate = document.getElementById("rate");
const tenure = document.getElementById("tenure");
const type = document.getElementById("type");

if (!loan || !rate || !tenure || !type) return;

let P = Number(loan.value);
let R = Number(rate.value);
let N = Number(tenure.value);

if (type.value === "y") N *= 12;

if (!P || !R || !N) {

alert("Please fill all fields.");

return;

}

const r = R / 1200;

const EMI =
P * r * Math.pow(1 + r, N) /
(Math.pow(1 + r, N) - 1);

const total = EMI * N;
const interest = total - P;

const flatYear = ((interest / P) / (N / 12)) * 100;
const flatMonth = flatYear / 12;

document.getElementById("emi").innerText = money(EMI);
document.getElementById("interest").innerText = money(interest);
document.getElementById("total").innerText = money(total);
document.getElementById("flatM").innerText = flatMonth.toFixed(2) + "%";
document.getElementById("flatY").innerText = flatYear.toFixed(2) + "%";

document.getElementById("results").style.display = "block";
document.getElementById("chart").style.display = "none";

createAmortisation(P, r, EMI, N);

}

/* ---------- Amortisation ---------- */

function createAmortisation(P, r, EMI, N) {

const rows = document.getElementById("rows");

if (!rows) return;

rows.innerHTML = "";

let balance = P;

for (let i = 1; i <= Math.min(N, 240); i++) {

const interest = balance * r;
const principal = EMI - interest;

balance = Math.max(0, balance - principal);

rows.innerHTML += `
<tr>
<td>${i}</td>
<td>${money(principal)}</td>
<td>${money(interest)}</td>
<td>${money(balance)}</td>
</tr>`;

}

}

/* ---------- Show/Hide Chart ---------- */

function toggleChart() {

const chart = document.getElementById("chart");

if (!chart) return;

chart.style.display =
chart.style.display === "block"
? "none"
: "block";

}

/* ---------- Property Auto Fill ---------- */

function enquire(property, amount) {

const contact = document.getElementById("contact");

if (contact) {

contact.scrollIntoView({

behavior: "smooth"

});

}

const budget = document.getElementById("budget");
const propertyName = document.getElementById("propertyName");
const message = document.getElementById("message");

if (budget) budget.value = amount;
if (propertyName) propertyName.value = property;

if (message) {

message.value =
"I'm interested in " + property + ".";

}

}

/* ---------- Enter Key Support ---------- */

["loan","rate","tenure"].forEach(id => {

const field = document.getElementById(id);

if (field) {

field.addEventListener("keypress", e => {

if (e.key === "Enter") {

calc();

}

});

}

});

/* ---------- Future Admin Ready ---------- */

const KeyDhanAdmin = {

version: "V20",

status: "Ready",

security: "Cloudflare Access + Google Authenticator"

};

console.log("KeyDhan™ V20 Loaded");
