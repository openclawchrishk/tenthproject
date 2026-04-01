-- ============================================================
-- DeskerHK — Supplemental schema (Batch L)
-- Run after `SUPABASE_SCHEMA.sql` on existing projects.
-- Adds desk invites, missing RLS DELETE rules, verification note column, indexes.
-- ============================================================

BEGIN;

-- Optional: free-text note with verification applications (app writes via `UserRepository`).
ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS verification_document_note TEXT;

-- ----------------------------------------------------------------
-- Desk invites (`InviteRepository` → `public.invites`)
-- ----------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (desk_id, invitee_id)
);

CREATE INDEX IF NOT EXISTS idx_invites_desk ON public.invites(desk_id);
CREATE INDEX IF NOT EXISTS idx_invites_invitee ON public.invites(invitee_id);
CREATE INDEX IF NOT EXISTS idx_invites_inviter ON public.invites(inviter_id);
CREATE INDEX IF NOT EXISTS idx_invites_status ON public.invites(status);

ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Invites viewable by participants" ON public.invites;
CREATE POLICY "Invites viewable by participants" ON public.invites FOR SELECT USING (
    auth.uid() = inviter_id OR auth.uid() = invitee_id
    OR EXISTS (SELECT 1 FROM public.desks d WHERE d.id = invites.desk_id AND d.founder_id = auth.uid())
);

DROP POLICY IF EXISTS "Founders can send desk invites" ON public.invites;
CREATE POLICY "Founders can send desk invites" ON public.invites FOR INSERT WITH CHECK (
    auth.uid() = inviter_id
    AND EXISTS (SELECT 1 FROM public.desks d WHERE d.id = desk_id AND d.founder_id = auth.uid())
);

DROP POLICY IF EXISTS "Invitee or founder can update invites" ON public.invites;
CREATE POLICY "Invitee or founder can update invites" ON public.invites FOR UPDATE USING (
    auth.uid() = invitee_id
    OR auth.uid() = inviter_id
    OR EXISTS (SELECT 1 FROM public.desks d WHERE d.id = invites.desk_id AND d.founder_id = auth.uid())
);

-- ----------------------------------------------------------------
-- RLS: DELETE policies missing from base schema (client repositories)
-- ----------------------------------------------------------------
DROP POLICY IF EXISTS "Founders can delete own desks" ON public.desks;
CREATE POLICY "Founders can delete own desks" ON public.desks FOR DELETE USING (auth.uid() = founder_id);

DROP POLICY IF EXISTS "Users can delete own connections" ON public.connections;
CREATE POLICY "Users can delete own connections" ON public.connections FOR DELETE USING (
    auth.uid() = user_a_id OR auth.uid() = user_b_id
);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications" ON public.notifications FOR DELETE USING (auth.uid() = user_id);

-- ----------------------------------------------------------------
-- Triggers: `updated_at` on new tables
-- ----------------------------------------------------------------
DROP TRIGGER IF EXISTS invites_updated_at ON public.invites;
CREATE TRIGGER invites_updated_at BEFORE UPDATE ON public.invites
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

COMMIT;

-- ----------------------------------------------------------------
-- Optional: enable Realtime for `invites` (Dashboard > Replication)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.invites;
