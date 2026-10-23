// OSGARD HORIZON secure Stripe webhook.
// The ONLY path that grants/revokes paid cosmetic entitlements.
// Supabase Function verify_jwt=false is intentional: Stripe has no Supabase JWT.
// Authenticity comes from Stripe-Signature verification over the EXACT raw body.
import Stripe from "npm:stripe@18.5.0";
import { createClient } from "npm:@supabase/supabase-js@2.54.0";

const key = Deno.env.get("STRIPE_SECRET_KEY") || "";
const signingSecret = Deno.env.get("STRIPE_WEBHOOK_SIGNING_SECRET") || "";
const mode = Deno.env.get("STRIPE_MODE") || "live";
const expectedAccount = Deno.env.get("MERCHANT_STRIPE_ACCOUNT_ID") || "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ||
  JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") || "{}").default;
const stripe = key ? new Stripe(key) : null;
const cryptoProvider = Stripe.createSubtleCryptoProvider();

const response = (status: number, message: string) =>
  new Response(JSON.stringify({ message }), { status, headers: { "content-type": "application/json", "cache-control": "no-store" } });

Deno.serve(async (request) => {
  if (request.method !== "POST") return response(405, "Method not allowed");
  if (!stripe || !serviceKey || !supabaseUrl || !signingSecret.startsWith("whsec_") ||
      !/^acct_[A-Za-z0-9]+$/.test(expectedAccount) ||
      !["live", "test"].includes(mode) ||
      !(key.startsWith(mode === "live" ? "sk_live_" : "sk_test_") || key.startsWith(mode === "live" ? "rk_live_" : "rk_test_")))
    return response(503, "Merchant not yet configured");

  const signature = request.headers.get("stripe-signature") || "";
  if (!signature || Number(request.headers.get("content-length") || 0) > 1024 * 1024)
    return response(400, "Missing signature or oversized payload");
  const raw = await request.text();
  if (raw.length > 1024 * 1024) return response(413, "Oversized payload");
  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(raw, signature, signingSecret, undefined, cryptoProvider);
  } catch {
    return response(400, "Invalid Stripe signature");
  }
  if (event.livemode !== (mode === "live"))
    return response(400, "Wrong Stripe mode");
  const db = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  try {
    // Never accept signed events from a different merchant's API key.
    const account = await stripe.accounts.retrieve();
    if (account.id !== expectedAccount || account.country !== "GB")
      return response(503, "Wrong merchant");

    if (event.type === "checkout.session.completed" || event.type === "checkout.session.async_payment_succeeded") {
      const original = event.data.object as Stripe.Checkout.Session;
      if (!original.id?.startsWith("cs_")) return response(400, "Invalid Checkout session");
      const session = await stripe.checkout.sessions.retrieve(original.id, { expand: ["line_items"] });
      if (session.mode !== "payment" || session.payment_status !== "paid" ||
          session.livemode !== (mode === "live"))
        return response(200, "Payment not yet settled; no item granted");

      const orderId = session.metadata?.osgard_order_id ?? "";
      const userId = session.metadata?.osgard_user_id ?? "";
      const sku = session.metadata?.osgard_sku ?? "";
      if (!/^[0-9a-f-]{36}$/i.test(orderId) || !/^[0-9a-f-]{36}$/i.test(userId))
        return response(400, "Missing verified game order metadata");
      const { data: order, error: orderError } = await db.from("omega_store_orders")
        .select("*").eq("id", orderId).single();
      const { data: item, error: itemError } = await db.from("omega_store_catalog")
        .select("*").eq("sku", sku).single();
      if (orderError || itemError || !order || !item)
        return response(500, "Order database lookup failed; Stripe will retry");
      const firstLine = session.line_items?.data?.[0];
      if (order.user_id !== userId || order.sku !== sku ||
          session.client_reference_id !== userId ||
          order.amount_pence !== item.price_pence || order.currency !== item.currency ||
          session.amount_total !== order.amount_pence || session.currency !== order.currency ||
          session.line_items?.data.length !== 1 || firstLine?.quantity !== 1 ||
          firstLine?.price?.id !== item.stripe_price_id ||
          (order.stripe_session_id && order.stripe_session_id !== session.id))
        return response(400, "Paid Checkout does not match catalog/order/owner; fulfillment blocked");
      const paymentIntent = typeof session.payment_intent === "string" ? session.payment_intent : session.payment_intent?.id;
      if (!paymentIntent) return response(500, "Payment intent unavailable");

      // If the checkout-session DB update failed just as a customer paid,
      // recover only using a merchant-signed, re-fetched, price-verified event.
      if (!order.stripe_session_id) {
        const { error: repairError } = await db.from("omega_store_orders")
          .update({ stripe_session_id: session.id }).eq("id", order.id).is("stripe_session_id", null);
        if (repairError) return response(500, "Order recovery failed; Stripe will retry");
      }

      const { data: granted, error: grantError } = await db.rpc("omega_grant_paid_order", {
        p_order_id: order.id,
        p_session_id: session.id,
        p_payment_intent: paymentIntent,
        p_customer_id: typeof session.customer === "string" ? session.customer : session.customer?.id || "",
        p_event_id: event.id
      });
      if (grantError) {
        console.error("Atomic entitlement transaction failed", grantError.code);
        return response(500, "Grant failed; Stripe will retry");
      }
      return response(200, granted ? "Paid cosmetic activated" : "Order already revoked");
    }

    // Only FULL refunds are auto-revoked. Handle partial refunds via merchant policy.
    if (event.type === "charge.refunded" || event.type === "charge.dispute.created") {
      const charge = event.data.object as Stripe.Charge & Stripe.Dispute;
      const intent = typeof charge.payment_intent === "string" ? charge.payment_intent : charge.payment_intent?.id;
      if (!intent) return response(200, "No associated game purchase");
      if (event.type === "charge.refunded" && (charge.amount_refunded || 0) < (charge.amount || 0))
        return response(200, "Partial refund, entitlement unchanged");
      // Stripe can deliver refund/dispute BEFORE checkout.session.completed.
      // Recover order ownership from server-written PaymentIntent metadata, never client text.
      const paymentIntent = await stripe.paymentIntents.retrieve(intent);
      const metadataOrder = paymentIntent.metadata?.osgard_order_id ?? "";
      if (!/^[0-9a-f-]{36}$/i.test(metadataOrder)) return response(200, "Charge unrelated to OSGARD");
      const { data: order, error: queryError } = await db.from("omega_store_orders")
        .select("id,stripe_payment_intent_id").eq("id", metadataOrder).maybeSingle();
      if (queryError) return response(500, "Refund lookup failed; Stripe will retry");
      if (!order) return response(200, "Charge unrelated to OSGARD");
      if (order.stripe_payment_intent_id && order.stripe_payment_intent_id !== intent)
        return response(400, "Refund cannot affect another order");
      const { error: revokeError } = await db.rpc("omega_revoke_paid_order", {
        p_order_id: order.id, p_event_id: event.id,
        p_reason: event.type === "charge.refunded" ? "refunded" : "disputed"
      });
      if (revokeError) return response(500, "Revocation failed; Stripe will retry");
      return response(200, "Purchase revoked after refund/dispute");
    }

    if (event.type === "checkout.session.expired" || event.type === "checkout.session.async_payment_failed") {
      const session = event.data.object as Stripe.Checkout.Session;
      const id = session.metadata?.osgard_order_id;
      if (id && /^[0-9a-f-]{36}$/i.test(id)) {
        const { error } = await db.from("omega_store_orders")
          .update({ status: event.type === "checkout.session.expired" ? "expired" : "cancelled" })
          .eq("id", id).eq("status", "pending");
        if (error) return response(500, "Order cancellation failed; Stripe will retry");
      }
      return response(200, "Unpaid Checkout closed");
    }
    return response(200, "Event ignored");
  } catch (error) {
    console.error("Webhook transient processing exception", error instanceof Error ? error.name : "unknown");
    return response(500, "Temporary webhook error; Stripe should retry");
  }
});
