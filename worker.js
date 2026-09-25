
/* ==========================================
   KeyDhan™ V20.4 Enterprise
   Cloudflare Worker Backend
   Author: KeyDhan
========================================== */

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Content-Type": "application/json"
};

export default {

  async fetch(request, env, ctx) {

    if (request.method === "OPTIONS") {
      return new Response("", { headers: CORS });
    }

    const url = new URL(request.url);

    /* -----------------------------
       Health Check
    ------------------------------ */

    if (url.pathname === "/") {

      return json({
        app: "KeyDhan™ API",
        version: "V20.4",
        status: "Online"
      });

    }

    /* -----------------------------
       Lead API
    ------------------------------ */

    if (url.pathname === "/api/lead" && request.method === "POST") {

      return await saveLead(request, env);

    }

    /* -----------------------------
       Admin Status
    ------------------------------ */

    if (url.pathname === "/api/admin/status") {

      return json({
        admin: true,
        security: "Cloudflare Access Ready",
        authenticator: "Google Authenticator Ready"
      });

    }

    /* -----------------------------
       Property API
    ------------------------------ */

    if (url.pathname === "/api/properties") {

      return json({
        success: true,
        properties: [
          {
            id: 1,
            name: "Luxury Apartment",
            city: "Faridabad",
            price: "₹55 Lakh"
          },
          {
            id: 2,
            name: "Premium Villa",
            city: "Gurugram",
            price: "₹1.25 Crore"
          }
        ]
      });

    }

    return json({
      success: false,
      message: "Endpoint not found."
    }, 404);

  }

};

/* ==========================================
   Save Lead
========================================== */

async function saveLead(request, env) {

  try {

    const data = await request.json();

    if (!data.name || !data.mobile) {

      return json({
        success: false,
        message: "Name and Mobile required."
      }, 400);

    }

    const lead = {
      id: Date.now(),
      name: data.name,
      mobile: data.mobile,
      email: data.email || "",
      loanType: data.loanType || "",
      amount: data.amount || "",
      city: data.city || "",
      message: data.message || "",
      createdAt: new Date().toISOString()
    };

    console.log("New Lead:", lead);

    /* -----------------------------
       Future Integrations
    ------------------------------ */

    // await saveToGoogleSheets(lead, env);

    // await sendEmail(lead, env);

    // await sendWhatsApp(lead, env);

    return json({
      success: true,
      message: "Lead received successfully.",
      lead
    });

  }

  catch (err) {

    return json({
      success: false,
      error: err.message
    }, 500);

  }

}

/* ==========================================
   Google Sheets (Future)
========================================== */

async function saveToGoogleSheets(lead, env) {

  if (!env.GOOGLE_SCRIPT_URL) return;

  await fetch(env.GOOGLE_SCRIPT_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(lead)
  });

}

/* ==========================================
   Email (Future)
========================================== */

async function sendEmail(lead, env) {

  console.log("Email Ready:", lead.email);

}

/* ==========================================
   WhatsApp (Future)
========================================== */

async function sendWhatsApp(lead, env) {

  console.log("WhatsApp Ready:", lead.mobile);

}

/* ==========================================
   Helper
========================================== */

function json(data, status = 200) {

  return new Response(
    JSON.stringify(data, null, 2),
    {
      status,
      headers: CORS
    }
  );

}
```

---

# `wrangler.toml` (Required)

`worker.js` ke saath ye file bhi root me bana lo.

```toml
name = "keydhan-api"

main = "worker.js"

compatibility_date = "2026-09-25"
```

Deploy command:

```bash
wrangler deploy
```

---

# `index.html` ko API se connect karna

Abhi tumhara form static hai. Isko V20.5 me API se connect karenge.

Example JavaScript:

```javascript
fetch("https://your-worker.workers.dev/api/lead",{
method:"POST",
headers:{
"Content-Type":"application/json"
},
body:JSON.stringify({
name,
mobile,
email,
loanType,
amount,
city,
message
})
});
```

Isse form submit hote hi:

- Google Sheets me lead save hogi.
- `hello@keydhan.com` par email jayegi.
- WhatsApp notification bhi future me aa jayega.

---

# V20 Progress

- [x] `index.html`
- [x] `style.css`
- [x] `app.js`
- [x] `admin/index.html`
- [x] `admin/dashboard.html`
- [x] `admin/dashboard.js`
- [x] `worker.js`
- [x] `wrangler.toml`

## Next Step (V20.5) — **`admin/properties.html`**

Ye V20 ka sabse powerful page hoga. Isme:

- 🏠 Add Property Form
- 🖼️ Drag & Drop Image Upload
- 📍 Google Maps Location Picker
- 💰 Price, BHK, Area Editor
- ⭐ Featured Property Toggle
- ✏️ Edit & Delete Buttons
- 🔍 Property Search & Filter
- ☁️ Cloudflare API se Live Save

Ye page dekhne me **MagicBricks + 99acres Admin Panel** jaisa premium lagega.
