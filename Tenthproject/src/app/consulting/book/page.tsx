import Link from "next/link";
import { submitConsultingLeadAction } from "@/app/actions/leads-redirect";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export const metadata = { title: "預約顧問" };

export default function ConsultingBookPage({ searchParams }: { searchParams: { error?: string; success?: string } }) {
  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div>
        <h1 className="text-3xl font-bold">預約／提交需求</h1>
        <p className="mt-2 text-sm text-muted-foreground">資料寫入 <code className="text-xs">tp_consulting_leads</code>。</p>
      </div>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已收到，我們會盡快聯絡。</p> : null}
      <Card>
        <CardHeader>
          <CardTitle>表單</CardTitle>
        </CardHeader>
        <CardContent>
          <form action={submitConsultingLeadAction} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="name">姓名 *</Label>
              <Input id="name" name="name" required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="email">電郵 *</Label>
              <Input id="email" name="email" type="email" required />
            </div>
            <div className="space-y-2">
              <Label htmlFor="whatsapp">WhatsApp</Label>
              <Input id="whatsapp" name="whatsapp" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="company_name">公司名稱</Label>
              <Input id="company_name" name="company_name" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="role_title">職稱</Label>
              <Input id="role_title" name="role_title" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="problem">想解決的問題 *</Label>
              <Textarea id="problem" name="problem" required rows={4} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="tools">現有工具／技術棧</Label>
              <Input id="tools" name="tools" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="budget">預算區間</Label>
              <Input id="budget" name="budget" placeholder="例：5–15 萬港幣" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="service_interest">感興趣服務</Label>
              <Input id="service_interest" name="service_interest" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="meeting_format">偏好會議形式</Label>
              <Input id="meeting_format" name="meeting_format" placeholder="線上／線下／混合" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="notes">附件說明</Label>
              <Textarea id="notes" name="notes" rows={3} />
            </div>
            <Button type="submit">提交</Button>
            <Button variant="outline" type="button" asChild className="ml-2">
              <Link href="/consulting">返回</Link>
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
