import Link from "next/link";
import { notFound } from "next/navigation";
import { applyToDeskAction } from "@/app/actions/desk";
import { createClient } from "@/lib/supabase/server";
import { deskSlug, getDeskBySlug } from "@/lib/data/desks";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

type Props = { params: { slug: string }; searchParams: { error?: string; success?: string } };

export default async function ApplyPage({ params, searchParams }: Props) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const desk = await getDeskBySlug(supabase, params.slug);
  if (!desk) notFound();
  const { data: roles } = await supabase.from("desk_roles").select("id, title").eq("desk_id", desk.id);
  const slug = deskSlug(desk);

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <div>
        <h1 className="text-2xl font-bold">申請加入：{desk.name}</h1>
        <p className="mt-2 text-sm text-muted-foreground">
          需登入 Supabase 帳戶。申請寫入 <code className="text-xs">desk_applications</code>，創辦人可於後台審批。
        </p>
      </div>
      {searchParams.error ? (
        <p className="rounded-md border border-destructive/40 bg-destructive/10 px-3 py-2 text-sm text-destructive">
          {searchParams.error}
        </p>
      ) : null}
      {searchParams.success ? (
        <p className="rounded-md border border-secondary/40 bg-secondary/10 px-3 py-2 text-sm">申請已送出。</p>
      ) : null}
      <Card>
        <CardHeader>
          <CardTitle>申請表</CardTitle>
          <CardDescription>請完整填寫，方便創辦人評估。</CardDescription>
        </CardHeader>
        <CardContent>
          <form action={applyToDeskAction} className="space-y-4">
            <input type="hidden" name="desk_id" value={desk.id} />
            <input type="hidden" name="return_slug" value={slug} />
            <div className="space-y-2">
              <Label htmlFor="selected_role">申請角色 *</Label>
              <select
                id="selected_role"
                name="selected_role"
                required
                className="flex h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
                defaultValue=""
              >
                <option value="" disabled>
                  請選擇
                </option>
                {(roles || []).map((r: { id: string; title: string }) => (
                  <option key={r.id} value={r.title}>
                    {r.title}
                  </option>
                ))}
                {(roles || []).length === 0 ? <option value="成員">成員（綜合）</option> : null}
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="statement">自我介紹與動機 *</Label>
              <Textarea id="statement" name="statement" required rows={4} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="whatsapp">WhatsApp</Label>
              <Input id="whatsapp" name="whatsapp" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="background">背景／經驗</Label>
              <Textarea id="background" name="background" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="why_join">為何想加入此項目</Label>
              <Textarea id="why_join" name="why_join" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="value_bring">可帶來的價值</Label>
              <Textarea id="value_bring" name="value_bring" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="portfolio_url">Portfolio／LinkedIn／網站</Label>
              <Input id="portfolio_url" name="portfolio_url" type="url" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="availability">可配合時間</Label>
              <Input id="availability" name="availability" />
            </div>
            <div className="flex gap-2">
              <Button type="submit">送出申請</Button>
              <Button variant="outline" type="button" asChild>
                <Link href={`/projects/${slug}`}>返回</Link>
              </Button>
            </div>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
