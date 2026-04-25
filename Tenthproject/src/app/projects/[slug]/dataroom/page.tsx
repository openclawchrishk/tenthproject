import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { deskSlug, getDeskBySlug, userIsDeskMember, userIsFounder } from "@/lib/data/desks";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

type Props = { params: { slug: string } };

export default async function DataRoomPage({ params }: Props) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const desk = await getDeskBySlug(supabase, params.slug);
  if (!desk) notFound();

  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=/projects/${deskSlug(desk)}/dataroom`);

  const founder = await userIsFounder(supabase, desk.id, user.id);
  const member = await userIsDeskMember(supabase, desk.id, user.id);
  if (!founder && !member) {
    return (
      <div className="mx-auto max-w-lg space-y-4 text-center">
        <h1 className="text-2xl font-bold">資料室權限不足</h1>
        <p className="text-muted-foreground">
          僅限創辦人或已錄取成員（<code className="text-xs">desk_members</code> active）進入。請待創辦人審批申請。
        </p>
        <Link href={`/projects/${deskSlug(desk)}`} className="text-primary underline">
          返回項目頁
        </Link>
      </div>
    );
  }

  const notesRes = await supabase
    .from("tp_data_room_notes")
    .select("id, body, created_at, author_id")
    .eq("desk_id", desk.id)
    .order("created_at", { ascending: false })
    .limit(30);
  const notes = notesRes.error ? [] : notesRes.data || [];

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-3xl font-bold">資料室</h1>
        <p className="text-muted-foreground">{desk.name}</p>
      </div>
      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>項目概覽</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2 text-sm text-muted-foreground">
            <p>{desk.description || "—"}</p>
            <p>Deck／連結：{desk.deck_url || desk.funding_needs || "請與創辦人線下分享"}</p>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>備註與更新</CardTitle>
          </CardHeader>
          <CardContent className="text-sm text-muted-foreground">
            {(notes || []).length === 0 ? (
              <p>尚無留言。執行 SQL migration 後可使用 <code className="text-xs">tp_data_room_notes</code> 記錄更新。</p>
            ) : (
              <ul className="space-y-3">
                {(notes || []).map((n: { id: string; body: string; created_at: string }) => (
                  <li key={n.id} className="rounded-md border p-3">
                    <p>{n.body}</p>
                    <p className="mt-1 text-xs text-muted-foreground">{n.created_at}</p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
