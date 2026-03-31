-- DeskerHK: complete wipe of all application data in `public` for a clean Supabase reset.
-- Run in the SQL editor with sufficient privileges (e.g. postgres / service role).
-- Order: delete child rows before parent rows (foreign keys). Comment out any line if the table does not exist.

BEGIN;

-- Realtime / messaging leaf tables
DELETE FROM desk_messages;
DELETE FROM direct_messages;

DELETE FROM notifications;

-- Desk workflow
DELETE FROM desk_applications;
DELETE FROM desk_members;

-- Safety / moderation
DELETE FROM reports;
DELETE FROM blocked_users;

DELETE FROM referrals;

-- Social graph
DELETE FROM connection_invites;
DELETE FROM connections;

DELETE FROM conversations;

-- Desk invites (unique desk_id + invitee_id)
DELETE FROM invites;

-- Legacy name (kept if your schema still has it)
DELETE FROM messages;

-- Optional: separate desk_roles table if not embedded in `desks` JSON
DELETE FROM desk_roles;

-- Core entities
DELETE FROM desks;
DELETE FROM profiles;
DELETE FROM users;

COMMIT;

-- -----------------------------------------------------------------------------
-- Optional one-liner reset (PostgreSQL): truncates all listed tables with CASCADE.
-- Use only if you prefer TRUNCATE over DELETE; requires matching table names.
-- -----------------------------------------------------------------------------
-- BEGIN;
-- TRUNCATE TABLE
--   desk_messages,
--   direct_messages,
--   notifications,
--   desk_applications,
--   desk_members,
--   reports,
--   blocked_users,
--   referrals,
--   connection_invites,
--   connections,
--   conversations,
--   invites,
--   messages,
--   desk_roles,
--   desks,
--   profiles,
--   users
-- RESTART IDENTITY CASCADE;
-- COMMIT;

-- -----------------------------------------------------------------------------
-- Auth: deleting app users does NOT remove auth.users. To wipe login identities
-- (destructive), run separately with a role that can access auth schema, e.g.:
-- -----------------------------------------------------------------------------
-- DELETE FROM auth.users;
