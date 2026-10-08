const escapeHtml = (value) => String(value ?? "")
  .replaceAll("&", "&amp;")
  .replaceAll("<", "&lt;")
  .replaceAll(">", "&gt;")
  .replaceAll('"', "&quot;")
  .replaceAll("'", "&#039;");

export default {
  async fetch(request) {
    const url = new URL(request.url);
    if (url.pathname === "/health") {
      return Response.json({ status: "ok" }, {
        headers: { "Cache-Control": "no-store" },
      });
    }

    const email = request.headers.get("CF-Access-Authenticated-User-Email") || "Authenticated user";
    const ray = request.headers.get("CF-Ray") || "not available";
    const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Clientless Access Demo</title>
  <style>
    :root { color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: radial-gradient(circle at top, #1e3a5f 0, #07111f 45%, #030712 100%); color: #e5eefb; }
    main { width: min(760px, calc(100% - 32px)); padding: 42px; border: 1px solid #294665; border-radius: 24px; background: rgba(7,17,31,.88); box-shadow: 0 28px 80px rgba(0,0,0,.45); }
    .eyebrow { color: #7dd3fc; font-weight: 700; letter-spacing: .12em; text-transform: uppercase; font-size: .78rem; }
    h1 { font-size: clamp(2rem, 6vw, 4rem); line-height: 1; margin: 16px 0; }
    p { color: #afc4db; font-size: 1.08rem; line-height: 1.7; }
    .proof { margin-top: 28px; display: grid; gap: 12px; }
    .row { padding: 16px 18px; border-radius: 14px; background: #0d2035; border: 1px solid #1d3b5a; }
    .label { display: block; color: #70d6a6; font-size: .75rem; text-transform: uppercase; letter-spacing: .1em; margin-bottom: 6px; }
    strong { overflow-wrap: anywhere; }
    .badge { display: inline-flex; align-items: center; gap: 8px; margin-top: 24px; padding: 9px 13px; border-radius: 999px; background: #123d2c; color: #8ff0bd; border: 1px solid #28694d; font-weight: 700; }
    .dot { width: 9px; height: 9px; border-radius: 50%; background: #4ade80; box-shadow: 0 0 14px #4ade80; }
  </style>
</head>
<body>
  <main>
    <div class="eyebrow">Cloudflare One · Terraform</div>
    <h1>Clientless Access Demo</h1>
    <p>This page is protected by Cloudflare Access and opens from the App Launcher using only a browser—no WARP client is required.</p>
    <div class="proof">
      <div class="row"><span class="label">Authenticated identity</span><strong>${escapeHtml(email)}</strong></div>
      <div class="row"><span class="label">Protected hostname</span><strong>${escapeHtml(url.hostname)}</strong></div>
      <div class="row"><span class="label">Cloudflare request</span><strong>${escapeHtml(ray)}</strong></div>
    </div>
    <div class="badge"><span class="dot"></span>Verified by Cloudflare Access</div>
  </main>
</body>
</html>`;

    return new Response(html, {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-store",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
      },
    });
  },
};
