import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import { deskSlug } from "@/lib/data/desks";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

export const metadata = { title: "我的項目" };

export default async function DashboardProjectsPage() {
  const supabase = await createClient();
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: desks } = await supabase.from("desks").select("*").eq("founder_id", user.id).order("created_at", { ascending: false });

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-4">
        <h1 className="text-2xl font-bold">我發佈的項目</h1>
        <Button asChild size="sm">
          <Link href="/projects/new">新增項目</Link>
        </Button>
      </div>
      {(desks || []).length === 0 ? (
        <p className="text-muted-foreground">尚未發佈項目。</p>
      ) : (
        <ul className="space-y-4">
          {(desks || []).map((d: { id: string; name: string; public_link_slug?: string | null; website_slug?: string | null; status: string }) => {
            const slug = deskSlug(d);
            return (
              <li key={d.id}>
                <Card>
                  <CardHeader className="flex flex-row items-center justify-between space-y-0">
                    <CardTitle className="text-base">{d.name}</CardTitle>
                    <span className="text-xs text-muted-foreground">{d.status}</span>
                  </CardHeader>
                  <CardContent className="flex flex-wrap gap-2">
                    <Button variant="outline" size="sm" asChild>
                      <Link href={`/projects/${slug}`}>公開頁</Link>
                    </Button>
                    <Button size="sm" asChild>
                      <Link href={`/dashboard/projects/${d.id}`}>審批申請</Link>
                    </Button>
                  </CardContent>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
