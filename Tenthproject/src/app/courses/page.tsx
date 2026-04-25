import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "Vibe Coding 課程" };

export default function CoursesPage() {
  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Vibe Coding 課程</h1>
        <p className="mt-3 max-w-2xl text-muted-foreground">
          以 Cursor、Supabase、Vercel、Stripe 建立真實產品；重點不是語法，而是可收款上線。適合 founders、operators、轉職者與 builders。
        </p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>Vibe Coding — 實戰產品營</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4 text-sm text-muted-foreground">
          <p>課程付款頁僅在 Webinar 後向合適學員發放連結；此處提供課程大綱預覽。</p>
          <ul className="list-inside list-decimal space-y-1">
            <li>Week 1：想法與產品定位</li>
            <li>Week 2：MVP 與 Auth</li>
            <li>Week 3：付款與資料</li>
            <li>Week 4：上線與變現</li>
          </ul>
          <Button asChild>
            <Link href="/courses/vibe-coding">查看課程詳情</Link>
          </Button>
        </CardContent>
      </Card>
    </div>
  );
}
