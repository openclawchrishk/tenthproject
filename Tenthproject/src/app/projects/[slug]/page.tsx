import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { deskSlug, getDeskBySlug } from "@/lib/data/desks";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

type Props = { params: { slug: string } };

export async function generateMetadata({ params }: Props) {
  const supabase = await createClient();
  if (!supabase) return { title: "項目" };
  const d = await getDeskBySlug(supabase, params.slug);
  return { title: d?.name || "項目" };
}

export default async function ProjectDetailPage({ params, searchParams }: Props & { searchParams: { created?: string } }) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const desk = await getDeskBySlug(supabase, params.slug);
  if (!desk) notFound();

  const { data: roles } = await supabase.from("desk_roles").select("*").eq("desk_id", desk.id);

  return (
    <div className="space-y-8">
      {searchParams.created ? (
        <p className="rounded-lg border border-secondary/40 bg-secondary/10 px-4 py-3 text-sm">項目已建立。</p>
      ) : null}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <div className="flex flex-wrap gap-2">
            <Badge>{desk.listing_kind === "roadshow" ? "路演" : "項目"}</Badge>
            <Badge variant="outline">{desk.status}</Badge>
          </div>
          <h1 className="mt-3 text-3xl font-bold">{desk.name}</h1>
          <p className="mt-2 text-lg text-muted-foreground">{desk.pitch}</p>
        </div>
        <div className="flex shrink-0 flex-col gap-2 sm:items-end">
          <Button asChild>
            <Link href={`/projects/${deskSlug(desk)}/apply`}>申請加入</Link>
          </Button>
          <Button variant="outline" asChild>
            <Link href={`/projects/${deskSlug(desk)}/dataroom`}>資料室</Link>
          </Button>
        </div>
      </div>
      <div className="grid gap-6 lg:grid-cols-3">
        <Card className="lg:col-span-2">
          <CardHeader>
            <CardTitle>項目說明</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4 text-sm leading-relaxed text-muted-foreground">
            <p>{desk.description || "—"}</p>
            <p>
              <span className="font-semibold text-foreground">期望合作：</span>
              {desk.expectations || "—"}
            </p>
            <p>
              <span className="font-semibold text-foreground">資金／資源需求：</span>
              {desk.funding_needs || "—"}
            </p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>開放角色</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3 text-sm">
            {(roles || []).length === 0 ? (
              <p className="text-muted-foreground">創辦人尚未列出細項角色，您仍可在申請表自填可貢獻方向。</p>
            ) : (
              (roles || []).map((r: { id: string; title: string; count: number; skills_description?: string }) => (
                <div key={r.id} className="rounded-lg border p-3">
                  <p className="font-medium">{r.title}</p>
                  <p className="text-muted-foreground">名額：{r.count}</p>
                  {r.skills_description ? <p className="mt-1 text-muted-foreground">{r.skills_description}</p> : null}
                </div>
              ))
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
