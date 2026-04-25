import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "活動與 Webinar" };

type EventRow = { id: string; slug: string; title: string; summary: string | null; starts_at: string | null };

export default async function EventsPage({ searchParams }: { searchParams: { error?: string; success?: string } }) {
  const supabase = await createClient();
  let events: EventRow[] = [];
  if (supabase) {
    const { data, error } = await supabase.from("tp_events").select("*").order("starts_at", { ascending: true });
    if (!error && data) events = data as EventRow[];
  }

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">活動與分享會</h1>
        <p className="mt-2 text-muted-foreground">資料表 <code className="text-xs">tp_events</code>（執行 migration 後顯示）。</p>
        <Button asChild className="mt-4" variant="secondary">
          <Link href="/events/webinar-register">免費報名 Webinar</Link>
        </Button>
      </div>
      {searchParams.error ? (
        <p className="text-sm text-destructive">{searchParams.error}</p>
      ) : null}
      {searchParams.success ? <p className="text-sm text-secondary">報名已記錄。</p> : null}
      {events.length === 0 ? (
        <p className="text-muted-foreground">
          尚未建立活動。請於 Supabase 插入 <code className="text-xs">tp_events</code> 或使用後台工具。
        </p>
      ) : (
        <ul className="grid gap-6 md:grid-cols-2">
          {events.map((e) => (
            <li key={e.id}>
              <Card>
                <CardHeader>
                  <CardTitle>{e.title}</CardTitle>
                  <CardDescription>{e.starts_at || "日期待定"}</CardDescription>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground">{e.summary}</CardContent>
                <CardFooter>
                  <Button asChild variant="outline" size="sm">
                    <Link href={`/events/${e.slug}`}>詳情</Link>
                  </Button>
                  <Button asChild size="sm" className="ml-2">
                    <Link href={`/events/${e.slug}/register`}>報名</Link>
                  </Button>
                </CardFooter>
              </Card>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
