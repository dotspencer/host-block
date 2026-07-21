// HostBlock license-decrement Worker.
//
// The macOS app calls this when a user removes their license, to free the "uses"
// slot the key consumed at activation (so the same key can be re-added on the same
// device). The Gumroad *seller access token* lives only here as a Worker secret and
// never ships inside the distributed app.
//
// Endpoint: POST /  { "license_key": "XXXX-..." }  ->  { "success": true, ... }
//
// Config:
//   var    GUMROAD_PRODUCT_ID   (wrangler.toml; same public id the app uses)
//   secret GUMROAD_ACCESS_TOKEN (wrangler secret put GUMROAD_ACCESS_TOKEN)

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") return withCORS(new Response(null, { status: 204 }));
    if (request.method !== "POST") return withCORS(json({ success: false, error: "method_not_allowed" }, 405));

    const productId = env.GUMROAD_PRODUCT_ID;
    const token = env.GUMROAD_ACCESS_TOKEN;
    if (!productId || !token) return withCORS(json({ success: false, error: "server_not_configured" }, 500));

    let body;
    try {
      body = await request.json();
    } catch {
      return withCORS(json({ success: false, error: "bad_json" }, 400));
    }
    const licenseKey = (body?.license_key || "").trim();
    if (!licenseKey) return withCORS(json({ success: false, error: "missing_license_key" }, 400));

    // 1) Verify the key is real and belongs to this product before touching anything.
    //    This is the public endpoint (no token) and does NOT increment the count.
    //    It's the abuse guard: a bare public URL shouldn't decrement arbitrary strings.
    const verify = await gumroad("https://api.gumroad.com/v2/licenses/verify", "POST", {
      product_id: productId,
      license_key: licenseKey,
      increment_uses_count: "false",
    });
    if (!verify || verify.success !== true) {
      return withCORS(json({ success: false, error: "invalid_license" }, 404));
    }
    // Already at zero — nothing to free, treat as success (idempotent).
    if ((verify.uses ?? 0) <= 0) {
      return withCORS(json({ success: true, uses: 0, decremented: false }));
    }

    // 2) Decrement (authenticated; the token stays server-side).
    const dec = await gumroad("https://api.gumroad.com/v2/licenses/decrement_uses_count", "PUT", {
      access_token: token,
      product_id: productId,
      license_key: licenseKey,
    });
    if (!dec || dec.success !== true) {
      return withCORS(json({ success: false, error: "decrement_failed" }, 502));
    }
    return withCORS(json({ success: true, uses: dec.uses, decremented: true }));
  },
};

async function gumroad(url, method, fields) {
  try {
    const resp = await fetch(url, {
      method,
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams(fields),
    });
    return await resp.json();
  } catch {
    return null;
  }
}

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// CORS is harmless for the native app (which isn't a browser) but lets you test
// the endpoint from a browser console during setup.
function withCORS(resp) {
  resp.headers.set("Access-Control-Allow-Origin", "*");
  resp.headers.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  resp.headers.set("Access-Control-Allow-Headers", "Content-Type");
  return resp;
}
