-- Tenthproject.com web layer — extends DeskerHK Supabase (same database).
-- Run in Supabase SQL Editor after backup. Safe to re-run (IF NOT EXISTS).

BEGIN;

-- Public listing fields for desks (iOS ignores unknown JSON keys; Swift Codable ignores extra columns in API responses if not in model — PostgREST returns all columns; iOS Desk decoder may need update if strict. These are additive nullable columns.)
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS website_slug TEXT UNIQUE;
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS listing_kind TEXT DEFAULT 'project';
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS listing_stage TEXT;
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS location_mode TEXT DEFAULT 'online';
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS founder_whatsapp TEXT;
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS deck_url TEXT;
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS listing_visibility TEXT DEFAULT 'public';
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS target_date DATE;
ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS role_types_summary TEXT;

ALTER TABLE public.desk_applications ADD COLUMN IF NOT EXISTS web_extra JSONB DEFAULT '{}'::jsonb;

CREATE TABLE IF NOT EXISTS public.tp_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    summary TEXT,
    body TEXT,
    starts_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tp_event_registrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES public.tp_events(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    whatsapp TEXT,
    interest_tags TEXT[] DEFAULT '{}',
    learn_about TEXT,
    hear_about TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tp_consulting_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    whatsapp TEXT,
    company_name TEXT,
    role_title TEXT,
    problem TEXT,
    tools TEXT,
    budget TEXT,
    service_interest TEXT,
    meeting_format TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tp_investor_leads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    whatsapp TEXT,
    investor_type TEXT,
    preferred_sectors TEXT[] DEFAULT '{}',
    preferred_stage TEXT,
    ticket_range TEXT,
    roadshow_interest BOOLEAN DEFAULT false,
    deal_flow_opt_in BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tp_course_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    course_slug TEXT NOT NULL,
    stripe_checkout_session_id TEXT,
    amount INTEGER,
    currency TEXT DEFAULT 'hkd',
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tp_data_room_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.tp_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_consulting_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_investor_leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_course_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tp_data_room_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "tp_events read all" ON public.tp_events;
CREATE POLICY "tp_events read all" ON public.tp_events FOR SELECT USING (true);

DROP POLICY IF EXISTS "tp_event_reg insert" ON public.tp_event_registrations;
CREATE POLICY "tp_event_reg insert" ON public.tp_event_registrations FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "tp_consulting insert" ON public.tp_consulting_leads;
CREATE POLICY "tp_consulting insert" ON public.tp_consulting_leads FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "tp_investor insert" ON public.tp_investor_leads;
CREATE POLICY "tp_investor insert" ON public.tp_investor_leads FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "tp_course_purchases own" ON public.tp_course_purchases;
DROP POLICY IF EXISTS "tp_course_purchases insert own" ON public.tp_course_purchases;
CREATE POLICY "tp_course_purchases own" ON public.tp_course_purchases FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "tp_course_purchases insert own" ON public.tp_course_purchases FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "tp_dataroom notes read members" ON public.tp_data_room_notes;
DROP POLICY IF EXISTS "tp_dataroom notes insert members" ON public.tp_data_room_notes;
CREATE POLICY "tp_dataroom notes read members" ON public.tp_data_room_notes FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.desk_members dm WHERE dm.desk_id = tp_data_room_notes.desk_id AND dm.user_id = auth.uid() AND dm.status = 'active')
    OR EXISTS (SELECT 1 FROM public.desks d WHERE d.id = tp_data_room_notes.desk_id AND d.founder_id = auth.uid())
);
CREATE POLICY "tp_dataroom notes insert members" ON public.tp_data_room_notes FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.desk_members dm WHERE dm.desk_id = tp_data_room_notes.desk_id AND dm.user_id = auth.uid() AND dm.status = 'active')
    OR EXISTS (SELECT 1 FROM public.desks d WHERE d.id = tp_data_room_notes.desk_id AND d.founder_id = auth.uid())
);

COMMIT;
