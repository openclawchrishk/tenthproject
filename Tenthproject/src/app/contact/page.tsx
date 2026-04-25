import { submitContactInquiryAction } from "@/app/actions/leads-redirect";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export const metadata = { title: "聯絡我們" };

export default function ContactPage({ searchParams }: { searchParams: { error?: string; success?: string } }) {
  return (
    <div className="mx-auto max-w-xl space-y-8">
      <div>
        <h1 className="text-3xl font-bold">聯絡我們</h1>
        <p className="mt-2 text-muted-foreground">香港基地 · 繁中／英文溝通</p>
        <ul className="mt-4 space-y-1 text-sm text-muted-foreground">
          <li>Email：hello@tenthproject.com（範例，請替換為實際）</li>
          <li>WhatsApp：請於商務渠道提供</li>
          <li>LinkedIn / Instagram：請替換實際連結</li>
        </ul>
      </div>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已收到查詢。</p> : null}
      <Card>
        <CardHeader>
          <CardTitle>查詢表單</CardTitle>
        </CardHeader>
        <CardContent>
          <form action={submitContactInquiryAction} className="space-y-4">
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
              <Label htmlFor="subject">主旨</Label>
              <Input id="subject" name="subject" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="message">訊息 *</Label>
              <Textarea id="message" name="message" required rows={5} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="phone">備註電話（可選）</Label>
              <Input id="phone" name="phone" />
            </div>
            <Button type="submit">送出</Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
