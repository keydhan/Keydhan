/* ==========================================
   KeyDhan™ V22
   admin/property-form.js
   Cloudflare Worker + KV Connected
========================================== */

const API = "https://admin-api.keydhan.com/api/properties";

/* ---------- Render Properties ---------- */

async function render() {
  const table = document.getElementById("propertyTable");
  if (!table) return;

  table.innerHTML = `<tr><td colspan="3">Loading...</td></tr>`;

  try {
    const res = await fetch(API);
    const data = await res.json();

    table.innerHTML = "";

    if (!data.length) {
      table.innerHTML = `<tr><td colspan="3">No Property Found</td></tr>`;
      return;
    }

    data.forEach(p => {
      table.innerHTML += `
        <tr>
          <td>${p.title || "-"}</td>
          <td>${p.location || "-"}</td>
          <td>${p.price || "-"}</td>
        </tr>`;
    });

  } catch (err) {
    table.innerHTML = `<tr><td colspan="3">API Connection Failed</td></tr>`;
    console.error(err);
  }
}

/* ---------- Save Property ---------- */

const btn = document.getElementById("saveBtn");

if (btn) {
  btn.onclick = async () => {

    const property = {
      title: document.getElementById("title").value.trim(),
      location: document.getElementById("location").value.trim(),
      price: document.getElementById("price").value.trim(),
      image: document.getElementById("image").value.trim(),
      desc: document.getElementById("desc").value.trim(),
      featured: false
    };

    if (!property.title || !property.location || !property.price) {
      alert("Title, Location aur Price required hain.");
      return;
    }

    btn.disabled = true;
    btn.innerText = "Saving...";

    try {

      const res = await fetch(API, {
        method: "POST",
        headers: {
          "Content-Type": "application/json"
        },
        body: JSON.stringify(property)
      });

      const result = await res.json();

      if (!result.success) throw new Error("Save failed");

      document.getElementById("title").value = "";
      document.getElementById("location").value = "";
      document.getElementById("price").value = "";
      document.getElementById("image").value = "";
      document.getElementById("desc").value = "";

      await render();

      showToast("Property Live Successfully!");

    } catch (err) {
      console.error(err);
      alert("Property save nahi hui.");
    }

    btn.disabled = false;
    btn.innerText = "Save Property";

  };
}

/* ---------- Toast ---------- */

function showToast(msg) {

  const old = document.getElementById("toast");
  if (old) old.remove();

  const toast = document.createElement("div");
  toast.id = "toast";
  toast.innerText = msg;

  toast.style.cssText = `
    position:fixed;
    right:25px;
    bottom:25px;
    background:#D4AF37;
    color:#111;
    padding:14px 22px;
    border-radius:12px;
    font-weight:700;
    z-index:9999;
    box-shadow:0 10px 25px rgba(0,0,0,.35);
  `;

  document.body.appendChild(toast);

  setTimeout(() => toast.remove(), 2500);
}

/* ---------- Load ---------- */

document.addEventListener("DOMContentLoaded", render);
