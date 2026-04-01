-- ============================================================
-- DeskerHK — Complete Supabase PostgreSQL Schema
-- Run this in Supabase SQL Editor to create all tables
-- ============================================================

BEGIN;

-- DROP existing tables first (if recreating)
DROP TABLE IF EXISTS public.desk_messages CASCADE;
DROP TABLE IF EXISTS public.direct_messages CASCADE;
DROP TABLE IF EXISTS public.notifications CASCADE;
DROP TABLE IF EXISTS public.desk_applications CASCADE;
DROP TABLE IF EXISTS public.desk_members CASCADE;
DROP TABLE IF EXISTS public.reports CASCADE;
DROP TABLE IF EXISTS public.blocked_users CASCADE;
DROP TABLE IF EXISTS public.referrals CASCADE;
DROP TABLE IF EXISTS public.connection_invites CASCADE;
DROP TABLE IF EXISTS public.connections CASCADE;
DROP TABLE IF EXISTS public.conversations CASCADE;
DROP TABLE IF EXISTS public.desk_roles CASCADE;
DROP TABLE IF EXISTS public.desks CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ============================================================
-- USERS (extends Supabase auth.users)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    role TEXT DEFAULT 'founder' CHECK (role IN ('founder', 'aspiring_founder', 'investor', 'mentor')),
    region TEXT,
    languages TEXT[] DEFAULT '{}',
    commitment_level TEXT CHECK (commitment_level IN ('fulltime', 'parttime', 'casual')),
    bio_short TEXT,
    bio_long TEXT,
    industries TEXT[] DEFAULT '{}',
    interests TEXT[] DEFAULT '{}',
    skills TEXT[] DEFAULT '{}',
    needs TEXT[] DEFAULT '{}',
    level INTEGER DEFAULT 1 CHECK (level BETWEEN 1 AND 4),
    verification_status TEXT DEFAULT 'none' CHECK (verification_status IN ('none', 'pending', 'verified_investor', 'verified_expert', 'rejected')),
    verification_domain TEXT,
    referral_count INTEGER DEFAULT 0,
    referral_code TEXT UNIQUE,
    invited_by UUID REFERENCES public.users(id),
    public_link_slug TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DESKS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.desks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    founder_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    pitch TEXT NOT NULL,
    industries TEXT[] DEFAULT '{}',
    region TEXT,
    languages TEXT[] DEFAULT '{}',
    description TEXT,
    funding_needs TEXT,
    expectations TEXT,
    status TEXT DEFAULT 'recruiting' CHECK (status IN ('recruiting', 'full', 'archived')),
    member_limit INTEGER DEFAULT 3,
    public_link_slug TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DESK ROLES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.desk_roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    count INTEGER DEFAULT 1,
    skills_description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- DESK APPLICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.desk_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    applicant_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.desk_roles(id) ON DELETE SET NULL,
    statement TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'accepted', 'declined', 'rejected')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (desk_id, applicant_id)
);

-- ============================================================
-- DESK MEMBERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.desk_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES public.desk_roles(id) ON DELETE SET NULL,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'removed')),
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (desk_id, user_id)
);

-- ============================================================
-- DESK MESSAGES (group chat)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.desk_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    desk_id UUID NOT NULL REFERENCES public.desks(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CONNECTIONS (bidirectional)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_a_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_a_id, user_b_id)
);

-- ============================================================
-- CONNECTION INVITES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.connection_invites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inviter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    invitee_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    message TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (inviter_id, invitee_id)
);

-- ============================================================
-- CONVERSATIONS (for DMs)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_a_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    participant_b_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (participant_a_id, participant_b_id)
);

-- ============================================================
-- DIRECT MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    data JSONB DEFAULT '{}',
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- REPORTS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    target_type TEXT NOT NULL CHECK (target_type IN ('user', 'desk', 'message')),
    target_id UUID NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed', 'action_taken')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- BLOCKED USERS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.blocked_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (blocker_id, blocked_id)
);

-- ============================================================
-- REFERRALS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    referrer_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referred_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    referral_code_used TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (referrer_id, referred_id)
);

COMMIT;

-- ============================================================
-- INDEXES
-- ============================================================
BEGIN;

CREATE INDEX IF NOT EXISTS idx_desks_founder ON public.desks(founder_id);
CREATE INDEX IF NOT EXISTS idx_desks_status ON public.desks(status);
CREATE INDEX IF NOT EXISTS idx_desk_roles_desk ON public.desk_roles(desk_id);
CREATE INDEX IF NOT EXISTS idx_desk_applications_desk ON public.desk_applications(desk_id);
CREATE INDEX IF NOT EXISTS idx_desk_applications_applicant ON public.desk_applications(applicant_id);
CREATE INDEX IF NOT EXISTS idx_desk_applications_status ON public.desk_applications(status);
CREATE INDEX IF NOT EXISTS idx_desk_members_desk ON public.desk_members(desk_id);
CREATE INDEX IF NOT EXISTS idx_desk_members_user ON public.desk_members(user_id);
CREATE INDEX IF NOT EXISTS idx_desk_messages_desk_created ON public.desk_messages(desk_id, created_at);
CREATE INDEX IF NOT EXISTS idx_connections_user_a ON public.connections(user_a_id);
CREATE INDEX IF NOT EXISTS idx_connections_user_b ON public.connections(user_b_id);
CREATE INDEX IF NOT EXISTS idx_connection_invites_inviter ON public.connection_invites(inviter_id);
CREATE INDEX IF NOT EXISTS idx_connection_invites_invitee ON public.connection_invites(invitee_id);
CREATE INDEX IF NOT EXISTS idx_connection_invites_status ON public.connection_invites(status);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_a ON public.conversations(participant_a_id);
CREATE INDEX IF NOT EXISTS idx_conversations_participant_b ON public.conversations(participant_b_id);
CREATE INDEX IF NOT EXISTS idx_direct_messages_conversation_created ON public.direct_messages(conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_read ON public.notifications(user_id, read);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON public.notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON public.referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_referred ON public.referrals(referred_id);

COMMIT;

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================
BEGIN;

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.desk_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connection_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

-- USERS policies
CREATE POLICY "Users are viewable by everyone" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING (auth.uid() = id);

-- DESKS policies
CREATE POLICY "Recruiting desks are viewable by everyone" ON public.desks FOR SELECT USING (status = 'recruiting' OR founder_id = auth.uid());
CREATE POLICY "Founders can insert desks" ON public.desks FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "Founders can update own desks" ON public.desks FOR UPDATE USING (auth.uid() = founder_id);

-- DESK ROLES policies
CREATE POLICY "Desk roles are viewable by everyone" ON public.desk_roles FOR SELECT USING (true);
CREATE POLICY "Founders can manage roles for own desks" ON public.desk_roles FOR ALL USING (
    EXISTS (SELECT 1 FROM public.desks WHERE desks.id = desk_roles.desk_id AND desks.founder_id = auth.uid())
);

-- DESK APPLICATIONS policies
CREATE POLICY "Applicants can view own applications" ON public.desk_applications FOR SELECT USING (auth.uid() = applicant_id);
CREATE POLICY "Founders can view applications for own desks" ON public.desk_applications FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.desks WHERE desks.id = desk_applications.desk_id AND desks.founder_id = auth.uid())
);
CREATE POLICY "Anyone can apply" ON public.desk_applications FOR INSERT WITH CHECK (auth.uid() = applicant_id);
CREATE POLICY "Founders can update applications for own desks" ON public.desk_applications FOR UPDATE USING (
    EXISTS (SELECT 1 FROM public.desks WHERE desks.id = desk_applications.desk_id AND desks.founder_id = auth.uid())
);

-- DESK MEMBERS policies
CREATE POLICY "Active members can view desk members" ON public.desk_members FOR SELECT USING (
    status = 'active' AND EXISTS (
        SELECT 1 FROM public.desk_members dm2 
        WHERE dm2.desk_id = desk_members.desk_id 
        AND dm2.user_id = auth.uid() 
        AND dm2.status = 'active'
    )
);
CREATE POLICY "Founders can manage members for own desks" ON public.desk_members FOR ALL USING (
    EXISTS (SELECT 1 FROM public.desks WHERE desks.id = desk_members.desk_id AND desks.founder_id = auth.uid())
);

-- DESK MESSAGES policies
CREATE POLICY "Active members can view desk messages" ON public.desk_messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.desk_members dm2 
        WHERE dm2.desk_id = desk_messages.desk_id 
        AND dm2.user_id = auth.uid() 
        AND dm2.status = 'active'
    )
);
CREATE POLICY "Active members can send desk messages" ON public.desk_messages FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.desk_members dm2 
        WHERE dm2.desk_id = desk_messages.desk_id 
        AND dm2.user_id = auth.uid() 
        AND dm2.status = 'active'
    )
);

-- CONNECTIONS policies
CREATE POLICY "Users can view their connections" ON public.connections FOR SELECT USING (
    auth.uid() = user_a_id OR auth.uid() = user_b_id
);
CREATE POLICY "Users can create connections" ON public.connections FOR INSERT WITH CHECK (
    auth.uid() = user_a_id OR auth.uid() = user_b_id
);

-- CONNECTION INVITES policies
CREATE POLICY "Users can view their own invites" ON public.connection_invites FOR SELECT USING (
    auth.uid() = inviter_id OR auth.uid() = invitee_id
);
CREATE POLICY "Users can send invites" ON public.connection_invites FOR INSERT WITH CHECK (auth.uid() = inviter_id);
CREATE POLICY "Users can update invites they sent or received" ON public.connection_invites FOR UPDATE USING (
    auth.uid() = inviter_id OR auth.uid() = invitee_id
);

-- CONVERSATIONS policies
CREATE POLICY "Users can view their conversations" ON public.conversations FOR SELECT USING (
    auth.uid() = participant_a_id OR auth.uid() = participant_b_id
);

-- DIRECT MESSAGES policies
CREATE POLICY "Users can view messages in their conversations" ON public.direct_messages FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = direct_messages.conversation_id 
        AND (c.participant_a_id = auth.uid() OR c.participant_b_id = auth.uid())
    )
);
CREATE POLICY "Users can send messages in their conversations" ON public.direct_messages FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND EXISTS (
        SELECT 1 FROM public.conversations c 
        WHERE c.id = direct_messages.conversation_id 
        AND (c.participant_a_id = auth.uid() OR c.participant_b_id = auth.uid())
    )
);

-- NOTIFICATIONS policies
CREATE POLICY "Users can view their own notifications" ON public.notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own notifications" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

-- REPORTS policies
CREATE POLICY "Users can create reports" ON public.reports FOR INSERT WITH CHECK (auth.uid() = reporter_id);

-- BLOCKED USERS policies
CREATE POLICY "Users can view their blocked list" ON public.blocked_users FOR SELECT USING (auth.uid() = blocker_id);
CREATE POLICY "Users can block others" ON public.blocked_users FOR INSERT WITH CHECK (auth.uid() = blocker_id);
CREATE POLICY "Users can unblock" ON public.blocked_users FOR DELETE USING (auth.uid() = blocker_id);

-- REFERRALS policies
CREATE POLICY "Users can view their referrals" ON public.referrals FOR SELECT USING (auth.uid() = referrer_id);

COMMIT;

-- ============================================================
-- SUPABASE STORAGE BUCKETS
-- ============================================================
BEGIN;

INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('verification_docs', 'verification_docs', false) ON CONFLICT DO NOTHING;

-- Avatars bucket policies
CREATE POLICY "Anyone can view avatars" ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "Users can upload own avatar" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

-- Verification docs bucket policies
CREATE POLICY "Users can view own verification docs" ON storage.objects FOR SELECT USING (bucket_id = 'verification_docs' AND auth.uid()::text = (storage.foldername(name))[1]);
CREATE POLICY "Users can upload verification docs" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'verification_docs' AND auth.uid()::text = (storage.foldername(name))[1]);

COMMIT;

-- ============================================================
-- REALTIME ENABLEMENT
-- ============================================================
-- Run in Supabase Dashboard > Database > Replication
-- Or uncomment below:
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.desk_messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- View: desks_with_founder (join founder info)
CREATE OR REPLACE VIEW public.desks_with_founder AS
SELECT 
    d.*,
    u.display_name AS founder_name,
    u.avatar_url AS founder_avatar,
    u.verification_status AS founder_verification,
    u.username AS founder_username,
    (SELECT COUNT(*) FROM public.desk_members dm WHERE dm.desk_id = d.id AND dm.status = 'active') AS member_count
FROM public.desks d
JOIN public.users u ON u.id = d.founder_id;

-- View: desk_applications_with_users (join applicant info)
CREATE OR REPLACE VIEW public.desk_applications_with_users AS
SELECT 
    da.*,
    u.display_name AS applicant_name,
    u.avatar_url AS applicant_avatar,
    u.username AS applicant_username,
    dr.title AS role_title
FROM public.desk_applications da
JOIN public.users u ON u.id = da.applicant_id
LEFT JOIN public.desk_roles dr ON dr.id = da.role_id;

-- View: notifications_with_sender (join sender info)
CREATE OR REPLACE VIEW public.notifications_with_data AS
SELECT * FROM public.notifications;

-- ============================================================
-- TRIGGER: updated_at auto-update
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_updated_at BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER desks_updated_at BEFORE UPDATE ON public.desks
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER desk_applications_updated_at BEFORE UPDATE ON public.desk_applications
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER connection_invites_updated_at BEFORE UPDATE ON public.connection_invites
    FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
