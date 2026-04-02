-- Run in Supabase SQL Editor if Explore shows no desks except "recruiting".
-- Default schema only allowed SELECT on desks where status = 'recruiting', so
-- published desks marked `full` were invisible to other users.
-- This widens read access for discovery while keeping archived private unless you own the desk.

BEGIN;

DROP POLICY IF EXISTS "Recruiting desks are viewable by everyone" ON public.desks;

CREATE POLICY "Desks discoverable or own"
ON public.desks
FOR SELECT
USING (
  status IN ('recruiting', 'full')
  OR founder_id = auth.uid()
);

COMMIT;
