-- DeskerHK: wipe all app data for a clean Supabase reset.
-- Run in SQL editor with sufficient privileges. Order respects typical FK chains.
-- Comment out any statement if the table does not exist in your schema.

BEGIN;

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
DELETE FROM invites;
DELETE FROM messages;
DELETE FROM desk_roles;
DELETE FROM desks;
DELETE FROM profiles;
DELETE FROM users;

COMMIT;
