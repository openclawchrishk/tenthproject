import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "後台總覽" };

export default function DashboardHomePage() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">會員後台</h1>
      <p className="text-sm text-muted-foreground">
        與 DeskerHK 共用 Supabase Auth 與資料表。可管理項目、申請、活動與顧問紀錄。
      </p>
      <div className="grid gap-4 sm:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-base">我的項目</CardTitle>
          </CardHeader>
          <CardContent>
            <Link href="/dashboard/projects" className="text-sm text-primary underline">
              前往
            </Link>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle className="text-base">我的申請</CardTitle>
          </CardHeader>
          <CardContent>
            <Link href="/dashboard/applications" className="text-sm text-primary underline">
              前往
            </Link>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
