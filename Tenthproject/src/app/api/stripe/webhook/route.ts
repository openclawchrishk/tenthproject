import { headers } from "next/headers";
import { NextResponse } from "next/server";
import Stripe from "stripe";
import { createServiceRoleClient } from "@/lib/supabase/server";

export async function POST(req: Request) {
  const secret = process.env.STRIPE_SECRET_KEY;
  const whSecret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret || !whSecret) {
    return NextResponse.json({ error: "not configured" }, { status: 501 });
  }
  const stripe = new Stripe(secret);
  const body = await req.text();
  const sig = (await headers()).get("stripe-signature");
  if (!sig) return NextResponse.json({ error: "no signature" }, { status: 400 });
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, whSecret);
  } catch {
    return NextResponse.json({ error: "invalid signature" }, { status: 400 });
  }
  if (event.type === "checkout.session.completed") {
    const session = event.data.object as Stripe.Checkout.Session;
    const userId = session.metadata?.user_id;
    const courseSlug = session.metadata?.course_slug || "vibe-coding";
    const admin = createServiceRoleClient();
    if (admin && userId) {
      await admin.from("tp_course_purchases").insert({
        user_id: userId,
        course_slug: courseSlug,
        stripe_checkout_session_id: session.id,
        amount: session.amount_total,
        currency: session.currency,
        status: "paid",
      });
    }
  }
  return NextResponse.json({ received: true });
}
