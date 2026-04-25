"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { slugify } from "@/lib/utils";

export async function createDeskAction(formData: FormData) {
  const supabase = await createClient();
  if (!supabase) redirect(`/projects/new?error=${encodeURIComponent("缺少 Supabase 環境變數。")}`);
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=/projects/new`);

  const title = String(formData.get("title") ?? "").trim();
  const listingKind = String(formData.get("listing_kind") ?? "project");
  const pitch = String(formData.get("pitch") ?? "").trim();
  const description = String(formData.get("description") ?? "").trim();
  const stage = String(formData.get("stage") ?? "").trim();
  const industryRaw = String(formData.get("industry") ?? "").trim();
  const expectations = String(formData.get("expectations") ?? "").trim();
  const locationMode = String(formData.get("location_mode") ?? "online");
  const founderWhatsapp = String(formData.get("founder_whatsapp") ?? "").trim();
  const deckUrl = String(formData.get("deck_url") ?? "").trim();
  const visibility = String(formData.get("visibility") ?? "public");
  const targetDate = String(formData.get("target_date") ?? "").trim() || null;
  const roleTypes = String(formData.get("role_types") ?? "").trim();

  if (!title || !pitch) {
    redirect(`/projects/new?error=${encodeURIComponent("請填寫標題與一句簡介。")}`);
  }

  const industries = industryRaw
    ? industryRaw.split(/[,，]/).map((s) => s.trim()).filter(Boolean)
    : ["General"];

  const base = slugify(title);
  const websiteSlug = `${base}-${user.id.slice(0, 8)}`;

  const row: Record<string, unknown> = {
    founder_id: user.id,
    name: title,
    pitch,
    industries,
    region: "HK",
    languages: [] as string[],
    description: description || null,
    funding_needs: deckUrl || null,
    expectations: expectations || roleTypes || null,
    status: "recruiting",
    member_limit: 6,
    public_link_slug: websiteSlug,
  };

  const extended: Record<string, unknown> = {
    website_slug: websiteSlug,
    listing_kind: listingKind === "roadshow" ? "roadshow" : "project",
    listing_stage: stage || null,
    location_mode: locationMode,
    founder_whatsapp: founderWhatsapp || null,
    deck_url: deckUrl || null,
    listing_visibility: visibility,
    target_date: targetDate,
    role_types_summary: roleTypes || null,
  };

  const ins = await supabase.from("desks").insert(row).select("id, public_link_slug").single();
  const { data, error } = ins;
  if (!error) {
    const { error: e2 } = await supabase.from("desks").update(extended).eq("id", data!.id);
    if (e2) console.warn("desk extended fields skipped:", e2.message);
  }
  if (error) {
    console.error(error);
    redirect(`/projects/new?error=${encodeURIComponent(error.message)}`);
  }
  revalidatePath("/projects");
  const slug = (data?.public_link_slug || data?.id) as string;
  redirect(`/projects/${slug}?created=1`);
}

export async function applyToDeskAction(formData: FormData) {
  const returnSlug = String(formData.get("return_slug") ?? "").trim();
  const back = returnSlug ? `/projects/${returnSlug}/apply` : "/projects";

  const supabase = await createClient();
  if (!supabase) redirect(`${back}?error=${encodeURIComponent("缺少 Supabase 環境變數。")}`);
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) redirect(`/auth/login?next=${encodeURIComponent(back)}`);

  const deskId = String(formData.get("desk_id") ?? "");
  const selectedRole = String(formData.get("selected_role") ?? "").trim();
  const statement = String(formData.get("statement") ?? "").trim();
  if (!deskId || !selectedRole || !statement) {
    redirect(`${back}?error=${encodeURIComponent("請選擇角色並填寫申請說明。")}`);
  }

  const extra = {
    whatsapp: String(formData.get("whatsapp") ?? "").trim(),
    background: String(formData.get("background") ?? "").trim(),
    why_join: String(formData.get("why_join") ?? "").trim(),
    value_bring: String(formData.get("value_bring") ?? "").trim(),
    portfolio_url: String(formData.get("portfolio_url") ?? "").trim(),
    availability: String(formData.get("availability") ?? "").trim(),
  };

  const payload: Record<string, unknown> = {
    desk_id: deskId,
    applicant_id: user.id,
    selected_role: selectedRole,
    statement,
    status: "pending",
    web_extra: extra,
  };

  const { error } = await supabase.from("desk_applications").upsert(payload, {
    onConflict: "desk_id,applicant_id",
  });

  if (error) {
    const noExtra = { ...payload };
    delete noExtra.web_extra;
    const { error: err2 } = await supabase.from("desk_applications").upsert(noExtra, {
      onConflict: "desk_id,applicant_id",
    });
    if (err2) {
      console.error(err2);
      redirect(`${back}?error=${encodeURIComponent(err2.message)}`);
    }
  }
  revalidatePath("/projects");
  revalidatePath("/dashboard/applications");
  redirect(`${back}?success=1`);
}
