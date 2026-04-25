import Link from "next/link";
import { notFound } from "next/navigation";
import { submitEventRegistrationAction } from "@/app/actions/leads-redirect";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

type Props = { params: { slug: string }; searchParams: { error?: string; success?: string } };

export default async function EventRegisterPage({ params, searchParams }: Props) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const { data: e } = await supabase.from("tp_events").select("id, title").eq("slug", params.slug).maybeSingle();
  if (!e) notFound();

  return (
    <div className="mx-auto max-w-lg space-y-6">
      <h1 className="text-2xl font-bold">報名：{e.title}</h1>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已收到報名。</p> : null}
      <Card>
        <CardHeader>
          <CardTitle>報名表</CardTitle>
        </CardHeader>
        <CardContent>
          <form action={submitEventRegistrationAction} className="space-y-4">
            <input type="hidden" name="event_id" value={e.id} />
            <input type="hidden" name="event_slug" value={params.slug} />
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
              <Label htmlFor="interest_tags">感興趣方向（逗號分隔）</Label>
              <Input id="interest_tags" name="interest_tags" placeholder="課程, 顧問, 項目…" />
            </div>
            <div className="space-y-2">
              <Label htmlFor="learn_about">想學習／了解</Label>
              <Textarea id="learn_about" name="learn_about" rows={3} />
            </div>
            <div className="space-y-2">
              <Label htmlFor="hear_about">如何得知我們</Label>
              <Input id="hear_about" name="hear_about" />
            </div>
            <Button type="submit">送出</Button>
            <Button variant="outline" type="button" asChild className="ml-2">
              <Link href={`/events/${params.slug}`}>返回</Link>
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
