import Link from "next/link";
import { notFound } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

const COURSE = {
  slug: "vibe-coding",
  title: "Vibe Coding 實戰產品營",
  summary: "做出可收款產品，連接支付與資料，帶著信心上線。",
  modules: ["Week 1: idea & positioning", "Week 2: MVP & auth", "Week 3: payments & data", "Week 4: launch & monetisation"],
};

type Props = { params: { slug: string } };

export default function CourseDetailPage({ params }: Props) {
  if (params.slug !== COURSE.slug) notFound();
  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <div>
        <h1 className="text-3xl font-bold">{COURSE.title}</h1>
        <p className="mt-2 text-muted-foreground">{COURSE.summary}</p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>模組</CardTitle>
        </CardHeader>
        <CardContent>
          <ul className="list-inside list-decimal space-y-2 text-sm">
            {COURSE.modules.map((m) => (
              <li key={m}>{m}</li>
            ))}
          </ul>
        </CardContent>
      </Card>
      <Card>
        <CardHeader>
          <CardTitle>常見問題</CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <p>Q：如何購買？ A：完成免費 Webinar 後，我們會向合適學員發送 Stripe Checkout 連結。</p>
          <p>Q：是否錄播？ A：以直播＋實作為主，細節以當期公告為準。</p>
        </CardContent>
      </Card>
      <Button asChild size="lg">
        <Link href={`/courses/${params.slug}/checkout`}>前往結帳（需已登入）</Link>
      </Button>
    </div>
  );
}
