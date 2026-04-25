import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { admitApplicantFormAction, rejectApplicantFormAction } from "@/app/actions/founder";
import { createClient } from "@/lib/supabase/server";
import { deskSlug } from "@/lib/data/desks";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

type Props = { params: { id: string }; searchParams: { error?: string; success?: string } };

export default async function FounderApplicantsPage({ params, searchParams }: Props) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect("/auth/login");

  const { data: desk } = await supabase.from("desks").select("*").eq("id", params.id).single();
  if (!desk || desk.founder_id !== user.id) notFound();

  const { data: apps } = await supabase
    .from("desk_applications")
    .select("id, applicant_id, selected_role, statement, status, created_at")
    .eq("desk_id", params.id)
    .order("created_at", { ascending: false });

  const applicantIds = Array.from(new Set((apps || []).map((a: { applicant_id: string }) => a.applicant_id)));
  const { data: users } =
    applicantIds.length > 0
      ? await supabase.from("users").select("id, display_name, username").in("id", applicantIds)
      : { data: [] as { id: string; display_name: string | null; username: string }[] };

  const userMap = Object.fromEntries((users || []).map((u) => [u.id, u]));

  return (
    <div className="space-y-6">
      <div>
        <Link href="/dashboard/projects" className="text-sm text-primary underline">
          ← 返回我的項目
        </Link>
        <h1 className="mt-2 text-2xl font-bold">審批申請 · {desk.name}</h1>
        <p className="text-sm text-muted-foreground">
          公開頁：<Link href={`/projects/${deskSlug(desk)}`} className="underline">{deskSlug(desk)}</Link>
        </p>
      </div>
      {searchParams.error ? <p className="text-sm text-destructive">{searchParams.error}</p> : null}
      {searchParams.success ? <p className="text-sm text-green-700">已更新。</p> : null}
      {(apps || []).length === 0 ? (
        <p className="text-muted-foreground">尚無申請。</p>
      ) : (
        <ul className="space-y-4">
          {(apps || []).map(
            (a: { id: string; applicant_id: string; selected_role: string; statement: string; status: string }) => {
              const u = userMap[a.applicant_id];
              const name = u?.display_name || u?.username || a.applicant_id;
              return (
                <li key={a.id}>
                  <Card>
                    <CardHeader>
                      <CardTitle className="text-base">{name}</CardTitle>
                      <p className="text-xs text-muted-foreground">
                        角色：{a.selected_role} · 狀態：{a.status}
                      </p>
                    </CardHeader>
                    <CardContent className="space-y-3 text-sm">
                      <p className="whitespace-pre-wrap text-muted-foreground">{a.statement}</p>
                      {a.status === "pending" ? (
                        <div className="flex flex-wrap gap-2">
                          <form action={admitApplicantFormAction}>
                            <input type="hidden" name="application_id" value={a.id} />
                            <input type="hidden" name="desk_id" value={params.id} />
                            <Button type="submit" size="sm">
                              批准
                            </Button>
                          </form>
                          <form action={rejectApplicantFormAction}>
                            <input type="hidden" name="application_id" value={a.id} />
                            <input type="hidden" name="desk_id" value={params.id} />
                            <Button type="submit" size="sm" variant="outline">
                              拒絕
                            </Button>
                          </form>
                        </div>
                      ) : null}
                    </CardContent>
                  </Card>
                </li>
              );
            }
          )}
        </ul>
      )}
    </div>
  );
}
