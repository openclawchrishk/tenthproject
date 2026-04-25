"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

/** Approve application: mark active + add desk_member (same semantics as DeskerHK app). */
export async function admitApplicantAction(applicationId: string) {
  const supabase = await createClient();
  if (!supabase) return { ok: false as const, error: "缺少 Supabase。" };
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false as const, error: "請先登入。" };

  const { data: app, error: e1 } = await supabase
    .from("desk_applications")
    .select("id, desk_id, applicant_id, status")
    .eq("id", applicationId)
    .single();
  if (e1 || !app) return { ok: false as const, error: "找不到申請。" };
  if (app.status !== "pending") {
    return { ok: false as const, error: "此申請已處理。" };
  }

  const { data: desk } = await supabase.from("desks").select("founder_id").eq("id", app.desk_id).single();
  if (!desk || desk.founder_id !== user.id) {
    return { ok: false as const, error: "只有創辦人可審批。" };
  }

  const { error: e2 } = await supabase.from("desk_members").insert({
    desk_id: app.desk_id,
    user_id: app.applicant_id,
    status: "active",
  });
  if (e2 && !String(e2.message).toLowerCase().includes("duplicate")) {
    return { ok: false as const, error: e2.message };
  }

  const { error: e3 } = await supabase.from("desk_applications").update({ status: "active" }).eq("id", applicationId);
  if (e3) return { ok: false as const, error: e3.message };

  revalidatePath("/dashboard/projects");
  revalidatePath(`/projects/${app.desk_id}`);
  return { ok: true as const };
}

export async function admitApplicantFormAction(formData: FormData) {
  const id = String(formData.get("application_id") ?? "");
  const deskId = String(formData.get("desk_id") ?? "");
  const r = await admitApplicantAction(id);
  if (!r.ok) redirect(`/dashboard/projects/${deskId}?error=${encodeURIComponent(r.error)}`);
  redirect(`/dashboard/projects/${deskId}?success=1`);
}

export async function rejectApplicantFormAction(formData: FormData) {
  const id = String(formData.get("application_id") ?? "");
  const deskId = String(formData.get("desk_id") ?? "");
  const r = await rejectApplicantAction(id);
  if (!r.ok) redirect(`/dashboard/projects/${deskId}?error=${encodeURIComponent(r.error)}`);
  redirect(`/dashboard/projects/${deskId}?success=1`);
}

export async function rejectApplicantAction(applicationId: string) {
  const supabase = await createClient();
  if (!supabase) return { ok: false as const, error: "缺少 Supabase。" };
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { ok: false as const, error: "請先登入。" };

  const { data: app } = await supabase.from("desk_applications").select("desk_id").eq("id", applicationId).single();
  if (!app) return { ok: false as const, error: "找不到申請。" };
  const { data: desk } = await supabase.from("desks").select("founder_id").eq("id", app.desk_id).single();
  if (!desk || desk.founder_id !== user.id) {
    return { ok: false as const, error: "只有創辦人可審批。" };
  }
  const { error } = await supabase.from("desk_applications").update({ status: "rejected" }).eq("id", applicationId);
  if (error) return { ok: false as const, error: error.message };
  revalidatePath("/dashboard/projects");
  return { ok: true as const };
}
