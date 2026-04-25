import Link from "next/link";
import { notFound } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { Button } from "@/components/ui/button";

type Props = { params: { slug: string } };

export default async function EventDetailPage({ params }: Props) {
  const supabase = await createClient();
  if (!supabase) notFound();
  const { data: e } = await supabase.from("tp_events").select("*").eq("slug", params.slug).maybeSingle();
  if (!e) notFound();

  return (
    <div className="mx-auto max-w-2xl space-y-6">
      <h1 className="text-3xl font-bold">{e.title}</h1>
      <p className="text-muted-foreground">{e.starts_at || "日期待定"}</p>
      <div className="prose prose-sm max-w-none text-muted-foreground">
        <p>{e.summary}</p>
        <p>{e.body}</p>
      </div>
      <Button asChild>
        <Link href={`/events/${params.slug}/register`}>立即報名</Link>
      </Button>
    </div>
  );
}
