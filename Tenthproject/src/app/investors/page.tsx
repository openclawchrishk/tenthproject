import { submitInvestorLeadAction } from "@/app/actions/leads-redirect";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

export const metadata = { title: "投資者網絡" };

export default function InvestorsPage({ searchParams }: { searchParams: { error?: string; success?: string } }) {
  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <div>
        <h1 className="text-3xl font-bold">Join the Tenthproject Investor Network</h1>
        <p className="mt-3 text-muted-foreground">
          我們先建立專業網絡與興趣收集；日後再擴展 deal flow、篩選與私募市場編排。此表寫入{" "}
          <code className="text-xs">tp_investor_leads</code>。
        </p>
      </div>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已收到，多謝。</p> : null}
      <Card>
        <CardHeader>
          <CardTitle>登記興趣</CardTitle>
        </CardHeader>
        <CardContent>
          <form action={submitInvestorLeadAction} className="space-y-4">
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
              <Label htmlFor="investor_type">投資者類型</Label>
              <Input id="investor_type" name="investor_type" placeholder="家族辦公室／天使／機構…" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="preferred_sectors">偏好板塊（逗號分隔）</Label>
              <Input id="preferred_sectors" name="preferred_sectors" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="preferred_stage">偏好階段</Label>
              <Input id="preferred_stage" name="preferred_stage" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="ticket_range">票據規模區間</Label>
              <Input id="ticket_range" name="ticket_range" />
            </div>
            <div className="space-y-2">
              <Label>對路演邀請有興趣？</Label>
              <select name="roadshow_interest" className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm" defaultValue="no">
                <option value="no">否</option>
                <option value="yes">是</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label>願意接收 deal flow 更新？</Label>
              <select name="deal_flow_opt_in" className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm" defaultValue="no">
                <option value="no">否</option>
                <option value="yes">是</option>
              </select>
            </div>
            <Button type="submit">提交</Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
