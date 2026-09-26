/* ==========================================
   KeyDhan™ V20.6 Enterprise
   Cloudflare Worker Backend
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
        version: "V20.6",
        status: "Online"
      });
    }

    /* -----------------------------
       Lead API
    ------------------------------ */

    if (url.pathname === "/api/lead" && request.method === "POST") {
      return await saveLead(request);
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
       Login API (GET + POST)
    ------------------------------ */

    if (url.pathname === "/api/login") {

      // Browser Test
      if (request.method === "GET") {
        return json({
          success: true,
          endpoint: "/api/login",
          methods: ["POST"],
          message: "Login API is working."
        });
      }

      // Actual Login
      if (request.method === "POST") {

        const body = await request.json().catch(() => ({}));

        const username = body.username || body.email || "";
        const password = body.password || "";

        if (
          username === "keydhan2@gmail.com" &&
          password === "#$Bharat@2018"
        ) {
          return json({
            success: true,
            token: "KD_ADMIN_TOKEN",
            user: {
              name: "Dev",
              email: "keydhan2@gmail.com",
              role: "Admin"
            }
          });
        }

        return json({
          success: false,
          message: "Invalid username or password."
        }, 401);
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
       Not Found
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

async function saveLead(request) {

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
