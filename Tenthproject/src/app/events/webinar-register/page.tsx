import { submitWebinarInterestAction } from "@/app/actions/leads-redirect";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export const metadata = { title: "免費 Webinar 報名" };

export default function WebinarRegisterPage({ searchParams }: { searchParams: { error?: string; success?: string } }) {
  return (
    <div className="mx-auto max-w-xl space-y-8">
      <div>
        <h1 className="text-3xl font-bold">免費報名 Tenthproject Webinar</h1>
        <p className="mt-3 text-muted-foreground">
          先了解我們如何用 AI、vibe coding 與 real-world product thinking 建立可變現工具站。完成 Webinar 後，我們才會向合適對象發送課程付款連結。
        </p>
      </div>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已收到。感謝報名。</p> : null}
      <Card>
        <CardHeader>
          <CardTitle>報名資料</CardTitle>
          <CardDescription>需設定環境變數 NEXT_PUBLIC_WEBINAR_EVENT_ID 指向 tp_events 一筆活動的 UUID。</CardDescription>
        </CardHeader>
        <CardContent>
          <form action={submitWebinarInterestAction} className="space-y-4">
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
              <Label htmlFor="interest_tags">感興趣（逗號分隔）</Label>
              <Input id="interest_tags" name="interest_tags" placeholder="課程, 顧問, 項目, 投資者網絡" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="learn_about">想學習什麼</Label>
              <Textarea id="learn_about" name="learn_about" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="hear_about">如何得知我們</Label>
              <Input id="hear_about" name="hear_about" />
            </div>
            <Button type="submit">提交報名</Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
