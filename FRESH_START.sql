-- ============================================================
-- DeskerHK: Delete ALL data for fresh start
-- Run this in Supabase SQL Editor
-- Order matters for foreign key constraints
-- ============================================================
BEGIN;

-- Delete in correct order (children before parents)

DELETE FROM desk_messages;
DELETE FROM direct_messages;
DELETE FROM notifications;
DELETE FROM desk_applications;
DELETE FROM desk_members;
DELETE FROM reports;
DELETE FROM blocked_users;
DELETE FROM referrals;
DELETE FROM connection_invites;
DELETE FROM connections;
DELETE FROM conversations;
DELETE FROM desk_roles;
DELETE FROM desks;
DELETE FROM profiles;  -- if profiles table exists separately
DELETE FROM users;     -- this will cascade to auth.users if CASCADE is set

COMMIT;

-- If you also want to reset auth.users (DANGER - deletes all accounts):
-- BEGIN;
-- DELETE FROM auth.users;
-- COMMIT;
