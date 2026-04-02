-- Cached headcount for desks (run once in Supabase SQL Editor).
-- The iOS app calls `DeskRepository.syncDeskMemberCount` after approvals, removals, and desk creation.

BEGIN;

ALTER TABLE public.desks ADD COLUMN IF NOT EXISTS current_member_count INTEGER;

UPDATE public.desks d
SET current_member_count = GREATEST(1, sub.c)
FROM (
    SELECT desk_id, COUNT(*)::int AS c
    FROM public.desk_members
    WHERE status = 'active'
    GROUP BY desk_id
) sub
WHERE d.id = sub.desk_id;

UPDATE public.desks
SET current_member_count = 1
WHERE current_member_count IS NULL;

ALTER TABLE public.desks ALTER COLUMN current_member_count SET DEFAULT 1;

COMMIT;
