import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { deskSlug, listPublicDesks, type DeskRow } from "@/lib/data/desks";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "項目與路演" };

function kindLabel(d: DeskRow) {
  const k = (d.listing_kind || "project").toLowerCase();
  if (k === "roadshow") return "路演";
  return "項目";
}

export default async function ProjectsPage() {
  const supabase = await createClient();
  if (!supabase) {
    return (
      <p className="rounded-lg border border-dashed p-6 text-sm text-muted-foreground">
        請設定 <code className="rounded bg-muted px-1">NEXT_PUBLIC_SUPABASE_URL</code> 與{" "}
        <code className="rounded bg-muted px-1">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> 後重新整理。
      </p>
    );
  }
  const desks = await listPublicDesks(supabase);

  return (
    <div className="space-y-8">
      <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
        <div>
          <h1 className="text-3xl font-bold">公開項目與路演</h1>
          <p className="mt-2 text-muted-foreground">
            與 DeskerHK 應用共用資料庫中的 <code className="text-xs">desks</code> 招募中項目。
          </p>
        </div>
        <Button asChild>
          <Link href="/projects/new">發佈項目</Link>
        </Button>
      </div>
      {desks.length === 0 ? (
        <p className="text-muted-foreground">目前沒有招募中的項目。成為第一個發佈者。</p>
      ) : (
        <ul className="grid gap-6 md:grid-cols-2">
          {desks.map((d) => {
            const slug = deskSlug(d);
            return (
              <li key={d.id}>
                <Card className="h-full">
                  <CardHeader>
                    <div className="flex flex-wrap items-center gap-2">
                      <Badge variant="secondary">{kindLabel(d)}</Badge>
                      <Badge variant="outline">{d.listing_stage || "—"}</Badge>
                      <Badge variant="muted">{d.location_mode || "online"}</Badge>
                    </div>
                    <CardTitle className="mt-2">{d.name}</CardTitle>
                    <CardDescription className="line-clamp-2">{d.pitch}</CardDescription>
                  </CardHeader>
                  <CardContent className="text-sm text-muted-foreground">
                    <p>
                      <span className="font-medium text-foreground">尋找：</span>
                      {d.expectations || "—"}
                    </p>
                    <p className="mt-2">
                      <span className="font-medium text-foreground">地區／行業：</span>
                      {d.region || "—"} · {(d.industries || []).join("、") || "—"}
                    </p>
                  </CardContent>
                  <CardFooter className="flex gap-2">
                    <Button variant="outline" size="sm" asChild>
                      <Link href={`/projects/${slug}`}>查看詳情</Link>
                    </Button>
                    <Button size="sm" asChild>
                      <Link href={`/projects/${slug}/apply`}>申請加入</Link>
                    </Button>
                  </CardFooter>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
