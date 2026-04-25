import type { SupabaseClient } from "@supabase/supabase-js";
import { isUuid } from "@/lib/utils";

export type DeskRow = {
  id: string;
  founder_id: string;
  name: string;
  pitch: string;
  industries: string[] | null;
  region: string | null;
  status: string;
  website_slug?: string | null;
  public_link_slug?: string | null;
  listing_kind?: string | null;
  listing_stage?: string | null;
  location_mode?: string | null;
  expectations?: string | null;
  description?: string | null;
  funding_needs?: string | null;
  deck_url?: string | null;
  created_at?: string;
};

export function deskSlug(d: Pick<DeskRow, "id" | "website_slug" | "public_link_slug">): string {
  const s = (d.website_slug || d.public_link_slug || "").trim();
  if (s) return s;
  return d.id;
}

export async function listPublicDesks(supabase: SupabaseClient): Promise<DeskRow[]> {
  const { data, error } = await supabase
    .from("desks")
    .select("*")
    .in("status", ["recruiting"])
    .order("created_at", { ascending: false })
    .limit(80);
  if (error) {
    console.error("listPublicDesks", error.message);
    return [];
  }
  return (data ?? []) as DeskRow[];
}

export async function getDeskBySlug(supabase: SupabaseClient, slug: string): Promise<DeskRow | null> {
  if (isUuid(slug)) {
    const { data } = await supabase.from("desks").select("*").eq("id", slug).maybeSingle();
    return (data as DeskRow) ?? null;
  }
  const { data: a } = await supabase.from("desks").select("*").eq("website_slug", slug).maybeSingle();
  if (a) return a as DeskRow;
  const { data: b } = await supabase.from("desks").select("*").eq("public_link_slug", slug).maybeSingle();
  return (b as DeskRow) ?? null;
}

export async function userIsDeskMember(
  supabase: SupabaseClient,
  deskId: string,
  userId: string
): Promise<boolean> {
  const { data } = await supabase
    .from("desk_members")
    .select("id")
    .eq("desk_id", deskId)
    .eq("user_id", userId)
    .eq("status", "active")
    .maybeSingle();
  return !!data;
}

export async function userIsFounder(
  supabase: SupabaseClient,
  deskId: string,
  userId: string
): Promise<boolean> {
  const { data } = await supabase.from("desks").select("founder_id").eq("id", deskId).maybeSingle();
  return data?.founder_id === userId;
}
