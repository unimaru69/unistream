import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const WEBHOOK_SECRET = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Product ID → subscription tier mapping
const PRODUCT_TIER_MAP: Record<string, string> = {
  unistream_basic_monthly: "basic",
  unistream_basic_annual: "basic",
  unistream_premium_monthly: "premium",
  unistream_premium_annual: "premium",
};

const CROSS_PLATFORM_PRODUCTS = new Set([
  "unistream_cross_platform",
]);

Deno.serve(async (req) => {
  // Only accept POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verify webhook secret
  const authHeader = req.headers.get("Authorization");
  if (!WEBHOOK_SECRET || authHeader !== `Bearer ${WEBHOOK_SECRET}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  let body;
  try {
    body = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const event = body?.event;
  if (!event) {
    return new Response("Missing event", { status: 400 });
  }

  const eventType: string = event.type;
  const appUserId: string | undefined = event.app_user_id;
  const productId: string | undefined =
    event.product_id ?? event.product_identifier;
  const expiresAt: string | undefined =
    event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : undefined;
  const store: string | undefined = event.store;

  if (!appUserId) {
    return new Response("Missing app_user_id", { status: 400 });
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  try {
    switch (eventType) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE":
      case "NON_RENEWING_PURCHASE": {
        // Determine tier from product ID
        const tier = productId ? PRODUCT_TIER_MAP[productId] : undefined;
        const isCrossPlatform = productId
          ? CROSS_PLATFORM_PRODUCTS.has(productId)
          : false;

        const updates: Record<string, unknown> = {
          revenuecat_customer_id: appUserId,
          subscription_platform: store ?? "apple",
          subscription_product_id: productId,
          updated_at: new Date().toISOString(),
        };

        if (tier) {
          updates.subscription_tier = tier;
        }
        if (expiresAt) {
          updates.subscription_expires_at = expiresAt;
        }
        if (isCrossPlatform) {
          updates.cross_platform_license = true;
        }

        const { error } = await adminClient
          .from("user_accounts")
          .update(updates)
          .eq("id", appUserId);

        if (error) {
          console.error("Update failed:", error);
          return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
          });
        }
        break;
      }

      case "CANCELLATION":
      case "EXPIRATION": {
        // Check if user still has any active entitlement
        // If not, revert to trial tier
        const { error } = await adminClient
          .from("user_accounts")
          .update({
            subscription_tier: "trial",
            subscription_expires_at: null,
            subscription_product_id: null,
            updated_at: new Date().toISOString(),
          })
          .eq("id", appUserId);

        if (error) {
          console.error("Expiration update failed:", error);
          return new Response(JSON.stringify({ error: error.message }), {
            status: 500,
          });
        }
        break;
      }

      default:
        // Unknown event type — acknowledge but do nothing
        console.log(`Unhandled event type: ${eventType}`);
    }
  } catch (err) {
    console.error("Webhook processing error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500 }
    );
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
