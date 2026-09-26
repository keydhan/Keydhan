/* ==========================================
   KeyDhan™ V21 Enterprise
   admin/property-form.js
========================================== */

const API_BASE = "https://admin-api.keydhan.com/api";

/* ---------- Save Property ---------- */

async function saveProperty() {

  const title = document.getElementById("title").value.trim();
  const price = document.getElementById("price").value.trim();
  const location = document.getElementById("location").value.trim();
  const bhk = document.getElementById("bhk").value.trim();
  const description = document.getElementById("description").value.trim();
  const featured = document.getElementById("featured").checked;
  const image = document.getElementById("image").value.trim();

  const property = {
    title,
    price,
    location,
    bhk,
    description,
    image,
    featured
  };

  try {

    const res = await fetch(`${API_BASE}/properties`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify(property)
    });

    const data = await res.json();

    if (!res.ok) {
      throw new Error(data.message || "Failed");
    }

    alert("Property saved successfully.");

    document.getElementById("propertyForm").reset();

    loadProperties();

  } catch (err) {

    alert("Error: " + err.message);

  }

}

/* ---------- Load Properties ---------- */

async function loadProperties() {

  const list = document.getElementById("propertyList");

  if (!list) return;

  list.innerHTML = "<p>Loading...</p>";

  try {

    const res = await fetch(`${API_BASE}/properties`);

    const properties = await res.json();

    list.innerHTML = "";

    properties.forEach(p => {

      list.innerHTML += `
        <div style="background:#071323;padding:18px;border-radius:18px;margin-bottom:15px">

          <h3>${p.title}</h3>

          <p><strong>Price:</strong> ${p.price}</p>

          <p><strong>Location:</strong> ${p.location}</p>

          <p><strong>BHK:</strong> ${p.bhk || "-"}</p>

          <p>${p.description || ""}</p>

          ${p.image ? `<img src="${p.image}" style="width:100%;max-width:260px;border-radius:12px;margin:10px 0;">` : ""}

          <button onclick="deleteProperty(${p.id})">
            Delete
          </button>

        </div>
      `;

    });

  } catch (err) {

    list.innerHTML = "<p>Unable to load properties.</p>";

  }

}

/* ---------- Delete Property ---------- */

async function deleteProperty(id) {

  if (!confirm("Delete this property?")) return;

  try {

    const res = await fetch(`${API_BASE}/properties/${id}`, {
      method: "DELETE"
    });

    if (!res.ok) throw new Error();

    loadProperties();

  } catch (err) {

    alert("Delete failed.");

  }

}

/* ---------- Auto Load ---------- */

document.addEventListener("DOMContentLoaded", loadProperties);
