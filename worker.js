/* ==========================================
   KeyDhan™ V20.5 Enterprise
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
        version: "V20.5",
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
       Admin Login
    ------------------------------ */

    if (url.pathname === "/api/login" && request.method === "POST") {

      try {

        const body = await request.json();

        if (
          body.username === "admin" &&
          body.password === "KeyDhan@2026"
        ) {

          return json({
            success: true,
            token: "keydhan-admin-demo-token",
            user: {
              name: "Dev",
              role: "Administrator"
            }
          });

        }

        return json({
          success: false,
          message: "Invalid username or password."
        }, 401);

      } catch (err) {

        return json({
          success: false,
          message: "Invalid request."
        }, 400);

      }

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
            title: "Luxury Apartment",
            price: "₹55 Lakh",
            location: "Sector 143, Faridabad",
            featured: true,
            image: "/images/luxury-apartment.jpg",
            description: "Modern apartment with premium amenities."
          },
          {
            id: 2,
            title: "Premium Villa",
            price: "₹1.25 Crore",
            location: "Gurugram",
            featured: true,
            image: "/images/premium-villa.jpg",
            description: "Independent luxury villa."
          }
        ]
      });

    }

    /* -----------------------------
       404
    ------------------------------ */

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

    // Future Integrations
    // await saveToGoogleSheets(lead, env);
    // await sendEmail(lead, env);
    // await sendWhatsApp(lead, env);

    return json({
      success: true,
      message: "Lead received successfully.",
      lead
    });

  } catch (err) {

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
