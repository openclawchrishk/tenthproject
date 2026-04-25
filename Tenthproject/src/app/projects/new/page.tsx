import Link from "next/link";
import { createDeskAction } from "@/app/actions/desk";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

export const metadata = { title: "發佈項目" };

export default function NewProjectPage({ searchParams }: { searchParams: { error?: string } }) {
  return (
    <div className="mx-auto max-w-2xl space-y-8">
      {searchParams.error ? (
        <p className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {searchParams.error}
        </p>
      ) : null}
      <div>
        <h1 className="text-3xl font-bold">發佈項目／路演</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          免費建立公開招募列表。需先
          <Link href="/auth/login" className="font-medium text-primary underline">
            登入
          </Link>
          （與 DeskerHK 同一 Supabase Auth）。
        </p>
      </div>
      <Card>
        <CardHeader>
          <CardTitle>項目資料</CardTitle>
          <CardDescription>標示 * 為必填。進階欄位將寫入資料庫擴充欄位（執行 SQL migration 後生效）。</CardDescription>
        </CardHeader>
        <CardContent>
          <form action={createDeskAction} className="space-y-6">
            <div className="space-y-2">
              <Label htmlFor="title">項目／路演標題 *</Label>
              <Input id="title" name="title" required placeholder="例：跨境支付 MVP 招募" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="listing_kind">類型</Label>
              <select
                id="listing_kind"
                name="listing_kind"
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
                defaultValue="project"
              >
                <option value="project">項目 project</option>
                <option value="roadshow">路演 roadshow</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="pitch">一句簡介 *</Label>
              <Input id="pitch" name="pitch" required maxLength={150} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="description">完整描述</Label>
              <Textarea id="description" name="description" rows={5} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="stage">階段</Label>
                <Input id="stage" name="stage" placeholder="idea / MVP / revenue / growth" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="industry">行業（逗號分隔）</Label>
                <Input id="industry" name="industry" placeholder="Fintech, SaaS" />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="expectations">希望找到的人／合作方式</Label>
              <Textarea id="expectations" name="expectations" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="role_types">需要的角色類型</Label>
              <Input id="role_types" name="role_types" placeholder="CTO、市場、投資人關係…" />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="location_mode">形式</Label>
                <select
                  id="location_mode"
                  name="location_mode"
                  className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
                  defaultValue="online"
                >
                  <option value="online">線上</option>
                  <option value="hybrid">混合</option>
                  <option value="physical">實體</option>
                </select>
              </div>
              <div className="space-y-2">
                <Label htmlFor="target_date">目標日期</Label>
                <Input id="target_date" name="target_date" type="date" />
              </div>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <div className="space-y-2">
                <Label htmlFor="founder_whatsapp">創辦人 WhatsApp</Label>
                <Input id="founder_whatsapp" name="founder_whatsapp" />
              </div>
              <div className="space-y-2">
                <Label htmlFor="deck_url">Deck／連結</Label>
                <Input id="deck_url" name="deck_url" type="url" placeholder="https://…" />
              </div>
            </div>
            <div className="space-y-2">
              <Label htmlFor="visibility">可見度</Label>
              <select
                id="visibility"
                name="visibility"
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
                defaultValue="public"
              >
                <option value="public">公開</option>
                <option value="unlisted">不公開列表</option>
                <option value="invite_only">僅邀請</option>
              </select>
            </div>
            <SubmitRow />
          </form>
        </CardContent>
      </Card>
    </div>
  );
}

function SubmitRow() {
  return (
    <div className="flex flex-wrap gap-3">
      <Button type="submit">建立項目</Button>
      <Button variant="outline" type="button" asChild>
        <Link href="/projects">取消</Link>
      </Button>
    </div>
  );
}
