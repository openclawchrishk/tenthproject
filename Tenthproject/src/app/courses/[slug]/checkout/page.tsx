"use client";

import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function CourseCheckoutPage({ params }: { params: { slug: string } }) {
  const [msg, setMsg] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function pay() {
    setMsg(null);
    setLoading(true);
    try {
      const res = await fetch("/api/stripe/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ slug: params.slug }),
      });
      const data = await res.json();
      if (!res.ok) {
        setMsg(data.error || "無法建立付款工作階段");
        return;
      }
      if (data.url) window.location.href = data.url;
    } catch {
      setMsg("網絡錯誤");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto max-w-lg space-y-6">
      <div>
        <h1 className="text-2xl font-bold">課程結帳</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          此頁建議設為 <code className="text-xs">noindex</code>，只向 Webinar 後的對象分享。需設定{" "}
          <code className="text-xs">STRIPE_SECRET_KEY</code> 與 <code className="text-xs">STRIPE_COURSE_PRICE_ID</code>。
        </p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Stripe Checkout</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          {msg ? <p className="text-sm text-destructive">{msg}</p> : null}
          <Button type="button" disabled={loading} onClick={pay} className="w-full">
            {loading ? "處理中…" : "使用 Stripe 結帳"}
          </Button>
          <Button variant="outline" asChild className="w-full">
            <Link href={`/courses/${params.slug}`}>返回課程頁</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
