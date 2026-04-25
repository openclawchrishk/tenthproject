"use server";

import { createClient, createServiceRoleClient } from "@/lib/supabase/server";

async function insertRow(table: string, row: Record<string, unknown>) {
  const admin = createServiceRoleClient();
  if (admin) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { error } = await (admin as any).from(table).insert(row);
    if (error) return error.message;
    return null;
  }
  const sb = await createClient();
  if (!sb) return "資料庫未設定。";
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const { error } = await (sb as any).from(table).insert(row);
  return error?.message ?? null;
}

export async function submitConsultingLead(formData: FormData) {
  const row = {
    name: String(formData.get("name") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    whatsapp: String(formData.get("whatsapp") ?? "").trim(),
    company_name: String(formData.get("company_name") ?? "").trim(),
    role_title: String(formData.get("role_title") ?? "").trim(),
    problem: String(formData.get("problem") ?? "").trim(),
    tools: String(formData.get("tools") ?? "").trim(),
    budget: String(formData.get("budget") ?? "").trim(),
    service_interest: String(formData.get("service_interest") ?? "").trim(),
    meeting_format: String(formData.get("meeting_format") ?? "").trim(),
    notes: String(formData.get("notes") ?? "").trim(),
  };
  if (!row.name || !row.email) return { ok: false as const, error: "請填寫姓名與電郵。" };
  const err = await insertRow("tp_consulting_leads", row);
  if (err) return { ok: false as const, error: err };
  return { ok: true as const };
}

export async function submitInvestorLead(formData: FormData) {
  const row = {
    name: String(formData.get("name") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    whatsapp: String(formData.get("whatsapp") ?? "").trim(),
    investor_type: String(formData.get("investor_type") ?? "").trim(),
    preferred_sectors: String(formData.get("preferred_sectors") ?? "")
      .split(/[,，]/)
      .map((s) => s.trim())
      .filter(Boolean),
    preferred_stage: String(formData.get("preferred_stage") ?? "").trim(),
    ticket_range: String(formData.get("ticket_range") ?? "").trim(),
    roadshow_interest: String(formData.get("roadshow_interest") ?? "") === "yes",
    deal_flow_opt_in: String(formData.get("deal_flow_opt_in") ?? "") === "yes",
  };
  if (!row.name || !row.email) return { ok: false as const, error: "請填寫姓名與電郵。" };
  const err = await insertRow("tp_investor_leads", row);
  if (err) return { ok: false as const, error: err };
  return { ok: true as const };
}

export async function submitEventRegistration(formData: FormData) {
  const row = {
    event_id: String(formData.get("event_id") ?? "").trim(),
    name: String(formData.get("name") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    whatsapp: String(formData.get("whatsapp") ?? "").trim(),
    interest_tags: String(formData.get("interest_tags") ?? "")
      .split(/[,，]/)
      .map((s) => s.trim())
      .filter(Boolean),
    learn_about: String(formData.get("learn_about") ?? "").trim(),
    hear_about: String(formData.get("hear_about") ?? "").trim(),
  };
  if (!row.event_id || !row.name || !row.email) {
    return { ok: false as const, error: "請填寫活動與聯絡資料。" };
  }
  const err = await insertRow("tp_event_registrations", row);
  if (err) return { ok: false as const, error: err };
  return { ok: true as const };
}

export async function submitWebinarInterest(formData: FormData) {
  const fakeEvent = process.env.NEXT_PUBLIC_WEBINAR_EVENT_ID;
  if (!fakeEvent) {
    return {
      ok: false as const,
      error: "請於環境變數設定 NEXT_PUBLIC_WEBINAR_EVENT_ID（對應 tp_events.id）。",
    };
  }
  const wrapped = new FormData();
  wrapped.set("event_id", fakeEvent);
  for (const [k, v] of Array.from(formData.entries())) {
    if (k !== "event_id") wrapped.set(k, v);
  }
  return submitEventRegistration(wrapped);
}

export async function submitContactInquiry(formData: FormData) {
  const row = {
    name: String(formData.get("name") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    whatsapp: String(formData.get("whatsapp") ?? "").trim(),
    company_name: "—",
    role_title: String(formData.get("subject") ?? "contact").trim(),
    problem: String(formData.get("message") ?? "").trim(),
    tools: "",
    budget: "",
    service_interest: "contact",
    meeting_format: "",
    notes: String(formData.get("phone") ?? "").trim(),
  };
  if (!row.name || !row.email || !row.problem) {
    return { ok: false as const, error: "請填寫姓名、電郵與訊息。" };
  }
  const err = await insertRow("tp_consulting_leads", row);
  if (err) return { ok: false as const, error: err };
  return { ok: true as const };
}
