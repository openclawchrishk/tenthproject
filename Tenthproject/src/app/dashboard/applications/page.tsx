import { createClient } from "@/lib/supabase/server";
import { deskSlug } from "@/lib/data/desks";
import Link from "next/link";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export const metadata = { title: "我的申請" };

export default async function ApplicationsPage() {
  const supabase = await createClient();
  if (!supabase) return null;
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return null;

  const { data: apps } = await supabase
    .from("desk_applications")
    .select("id, desk_id, selected_role, status, created_at")
    .eq("applicant_id", user.id)
    .order("created_at", { ascending: false });

  const deskIds = Array.from(new Set((apps || []).map((a: { desk_id: string }) => a.desk_id)));
  const { data: desks } =
    deskIds.length > 0
      ? await supabase.from("desks").select("id, name, public_link_slug, website_slug").in("id", deskIds)
      : { data: [] as { id: string; name: string; public_link_slug?: string | null; website_slug?: string | null }[] };

  const deskMap = Object.fromEntries((desks || []).map((d) => [d.id, d]));

  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">我報名過的項目</h1>
      {(apps || []).length === 0 ? (
        <p className="text-muted-foreground">尚無申請紀錄。</p>
      ) : (
        <ul className="space-y-4">
          {(apps || []).map((a: { id: string; desk_id: string; selected_role: string; status: string }) => {
            const d = deskMap[a.desk_id];
            const slug = d ? deskSlug(d) : a.desk_id;
            return (
              <li key={a.id}>
                <Card>
                  <CardHeader>
                    <CardTitle className="text-base">{d?.name || "項目"}</CardTitle>
                  </CardHeader>
                  <CardContent className="flex flex-wrap items-center justify-between gap-2 text-sm">
                    <span className="text-muted-foreground">
                      角色：{a.selected_role} · 狀態：{a.status}
                    </span>
                    <Link href={`/projects/${slug}`} className="text-primary underline">
                      查看項目
                    </Link>
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
