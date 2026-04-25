"use server";

import { redirect } from "next/navigation";
import { submitConsultingLead, submitContactInquiry, submitEventRegistration, submitInvestorLead, submitWebinarInterest } from "@/app/actions/leads";

export async function submitConsultingLeadAction(formData: FormData) {
  const r = await submitConsultingLead(formData);
  if (!r.ok) redirect(`/consulting/book?error=${encodeURIComponent(r.error)}`);
  redirect("/consulting/book?success=1");
}

export async function submitInvestorLeadAction(formData: FormData) {
  const r = await submitInvestorLead(formData);
  if (!r.ok) redirect(`/investors?error=${encodeURIComponent(r.error)}`);
  redirect("/investors?success=1");
}

export async function submitEventRegistrationAction(formData: FormData) {
  const slug = String(formData.get("event_slug") ?? "").trim();
  const r = await submitEventRegistration(formData);
  if (!r.ok) {
    redirect(slug ? `/events/${slug}/register?error=${encodeURIComponent(r.error)}` : `/events?error=${encodeURIComponent(r.error)}`);
  }
  redirect(slug ? `/events/${slug}/register?success=1` : "/events?success=1");
}

export async function submitWebinarInterestAction(formData: FormData) {
  const r = await submitWebinarInterest(formData);
  if (!r.ok) redirect(`/events/webinar-register?error=${encodeURIComponent(r.error)}`);
  redirect("/events/webinar-register?success=1");
}

export async function submitContactInquiryAction(formData: FormData) {
  const r = await submitContactInquiry(formData);
  if (!r.ok) redirect(`/contact?error=${encodeURIComponent(r.error)}`);
  redirect("/contact?success=1");
}
