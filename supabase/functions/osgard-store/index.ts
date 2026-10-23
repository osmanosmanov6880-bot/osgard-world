// OSGARD HORIZON — server-only Stripe Checkout. NEVER embed a secret in Godot/Web.
// Deploy with verify_jwt=false: this handler verifies Supabase Auth JWT via getUser().
import Stripe from "npm:stripe@18.5.0";
import { createClient } from "npm:@supabase/supabase-js@2.54.0";

const jsonHeaders = { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" };
const allowedOrigins = (Deno.env.get("STORE_ALLOWED_ORIGINS") ?? "").split(",").map(s=>s.trim()).filter(Boolean);
const originHeaders = (request: Request): HeadersInit => {
  const origin = request.headers.get("origin") ?? "";
  return origin && allowedOrigins.includes(origin) ? { "access-control-allow-origin": origin, "vary": "Origin",
    "access-control-allow-headers": "authorization, content-type, apikey",
    "access-control-allow-methods": "GET, POST, OPTIONS" } : {};
};
const send = (request: Request, status: number, body: unknown): Response =>
  new Response(JSON.stringify(body), { status, headers: { ...jsonHeaders, ...originHeaders(request) } });

const apiKey = () => {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const modern = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}");
  return modern.default as string | undefined;
};

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    const origin = request.headers.get("origin");
    if (!origin || !allowedOrigins.includes(origin)) return new Response(null, { status: 403 });
    return new Response(null, { status: 204, headers: originHeaders(request) });
  }
  const url = new URL(request.url);
  const part = url.pathname.split("/").filter(Boolean).pop() || "";
  if (!["catalog", "checkout", "entitlements"].includes(part)) return send(request, 404, { error: "Not found" });
  if ((part === "checkout" && request.method !== "POST") ||
      (part !== "checkout" && request.method !== "GET")) return send(request, 405, { error: "Method not allowed" });
  const projectUrl = Deno.env.get("SUPABASE_URL") || "";
  const serviceKey = apiKey();
  if (!projectUrl || !serviceKey) return send(request, 503, { error: "Store backend not configured" });

  const db = createClient(projectUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  if (part === "catalog") {
    const { data, error } = await db.from("omega_store_catalog")
      .select("sku,title,description,price_pence,currency,active,stripe_price_id").order("price_pence");
    if (error) return send(request, 503, { error: "Catalog unavailable" });
    // Never expose merchant's secret, internal Stripe account ID or sensitive customer info.
    return send(request, 200, { items: (data ?? []).map(p => ({
      sku: p.sku, title: p.title, description: p.description, amount_pence: p.price_pence,
      currency: p.currency, purchasable: p.active === true && typeof p.stripe_price_id === "string"
    })) });
  }
  const bearer = request.headers.get("authorization") || "";
  if (!bearer.startsWith("Bearer ") || bearer.length < 30) return send(request, 401, { error: "Log in first" });
  const token = bearer.slice(7);
  const { data: userInfo, error: userError } = await db.auth.getUser(token);
  const user = userInfo.user;
  if (userError || !user || !user.email || !user.email_confirmed_at)
    return send(request, 401, { error: "Verified email login required" });

  if (part === "entitlements") {
    const { data, error } = await db.from("omega_store_entitlements")
      .select("sku,granted_at").eq("user_id", user.id).is("revoked_at", null);
    if (error) return send(request, 503, { error: "Entitlements unavailable" });
    return send(request, 200, { items: (data ?? []).map(r => r.sku), checked_at: new Date().toISOString() });
  }

  let body: unknown;
  try {
    if (Number(request.headers.get("content-length") || "0") > 2048) return send(request, 413, { error: "Request too large" });
    body = await request.json();
  } catch { return send(request, 400, { error: "Invalid JSON" }); }
  const sku = (body && typeof body === "object" && "sku" in body) ? (body as { sku: unknown }).sku : null;
  if (typeof sku !== "string" || !/^[a-z][a-z0-9_]{2,50}$/.test(sku))
    return send(request, 400, { error: "Invalid product" });

  const { data: already } = await db.from("omega_store_entitlements")
    .select("sku").eq("user_id", user.id).eq("sku", sku).is("revoked_at", null).maybeSingle();
  if (already) return send(request, 409, { error: "Already owned; refresh game inventory" });
  const { data: item, error: catalogError } = await db.from("omega_store_catalog")
    .select("*").eq("sku", sku).eq("active", true).maybeSingle();
  if (catalogError || !item || !item.stripe_price_id)
    return send(request, 503, { error: "Live product not activated by merchant" });

  // Checkout abuse throttle: one player cannot create unlimited open paid sessions.
  const since = new Date(Date.now() - 15 * 60 * 1000).toISOString();
  const { count, error: rateError } = await db.from("omega_store_orders")
    .select("id", { count: "exact", head: true }).eq("user_id", user.id).gte("created_at", since);
  if (rateError) return send(request, 503, { error: "Store protection unavailable" });
  if ((count ?? 0) >= 4) return send(request, 429, { error: "Too many checkout attempts. Try later." });

  // Fail CLOSED in production. No sandbox secret can ever create a claimed live checkout.
  const mode = Deno.env.get("STRIPE_MODE") || "live";
  const key = Deno.env.get("STRIPE_SECRET_KEY") || "";
  const expectedAccount = Deno.env.get("MERCHANT_STRIPE_ACCOUNT_ID") || "";
  const successUrl = Deno.env.get("STORE_SUCCESS_URL") || "";
  const cancelUrl = Deno.env.get("STORE_CANCEL_URL") || "";
  if (!["live", "test"].includes(mode) || !key.startsWith(mode === "live" ? "sk_live_" : "sk_test_") ||
      !/^acct_[A-Za-z0-9]+$/.test(expectedAccount) ||
      !successUrl.startsWith("https://") || !cancelUrl.startsWith("https://"))
    return send(request, 503, { error: "Merchant live activation incomplete" });

  try {
    const stripe = new Stripe(key);
    const merchant = await stripe.accounts.retrieve();
    if (merchant.id !== expectedAccount || merchant.country !== "GB" || !merchant.charges_enabled || !merchant.payouts_enabled)
      return send(request, 503, { error: "Selected UK merchant cannot accept payouts or account mismatch" });
    const price = await stripe.prices.retrieve(item.stripe_price_id);
    if (!price.active || price.currency !== item.currency || price.unit_amount !== item.price_pence ||
        price.type !== "one_time" || price.livemode !== (mode === "live"))
      return send(request, 503, { error: "Merchant price mismatch — buying disabled" });

    const { data: order, error: insertError } = await db.from("omega_store_orders").insert({
      user_id: user.id, sku: item.sku, amount_pence: item.price_pence, currency: item.currency
    }).select("id").single();
    if (insertError || !order) return send(request, 503, { error: "Order creation failed" });

    let session: Stripe.Checkout.Session;
    try {
      session = await stripe.checkout.sessions.create({
        mode: "payment", payment_method_types: ["card"],
        line_items: [{ price: price.id, quantity: 1 }],
        client_reference_id: user.id, customer_email: user.email,
        metadata: { osgard_order_id: order.id, osgard_sku: sku, osgard_user_id: user.id },
        payment_intent_data: { metadata: { osgard_order_id: order.id } },
        success_url: successUrl, cancel_url: cancelUrl,
        expires_at: Math.floor(Date.now() / 1000) + 1800
      }, { idempotencyKey: "osgard-checkout-" + order.id });
    } catch (error) {
      await db.from("omega_store_orders").update({ status: "cancelled" }).eq("id", order.id);
      console.error("Stripe checkout creation failed:", error instanceof Error ? error.name : "unknown");
      return send(request, 503, { error: "Stripe Checkout unavailable" });
    }
    const { error: storeError } = await db.from("omega_store_orders")
      .update({ stripe_session_id: session.id }).eq("id", order.id);
    if (storeError || !session.url) {
      // Prevent a customer paying for a checkout we cannot reliably fulfill.
      try { await stripe.checkout.sessions.expire(session.id); } catch { /* webhook handles late completion via order metadata */ }
      return send(request, 503, { error: "Cannot safely activate checkout" });
    }
    return send(request, 200, { url: session.url, order_id: order.id });
  } catch (error) {
    console.error("Merchant validation error:", error instanceof Error ? error.name : "unknown");
    return send(request, 503, { error: "Payment setup incomplete; no charge was initiated" });
  }
});
