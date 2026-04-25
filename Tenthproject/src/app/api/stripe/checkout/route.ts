import { NextResponse } from "next/server";
import Stripe from "stripe";
import { createClient } from "@/lib/supabase/server";

export async function POST(req: Request) {
  const secret = process.env.STRIPE_SECRET_KEY;
  const priceId = process.env.STRIPE_COURSE_PRICE_ID;
  if (!secret || !priceId) {
    return NextResponse.json({ error: "Stripe 未設定。" }, { status: 501 });
  }
  const stripe = new Stripe(secret);
  const supabase = await createClient();
  if (!supabase) {
    return NextResponse.json({ error: "Supabase 未設定。" }, { status: 501 });
  }
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user?.email) {
    return NextResponse.json({ error: "請先登入。" }, { status: 401 });
  }
  const { slug } = (await req.json()) as { slug?: string };
  const courseSlug = slug || "vibe-coding";
  const origin = req.headers.get("origin") || process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000";
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    customer_email: user.email,
    line_items: [{ price: priceId, quantity: 1 }],
    success_url: `${origin}/dashboard?purchase=success`,
    cancel_url: `${origin}/courses/${courseSlug}/checkout?cancel=1`,
    metadata: { user_id: user.id, course_slug: courseSlug },
  });
  return NextResponse.json({ url: session.url });
}
