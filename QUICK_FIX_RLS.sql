-- QUICK FIX: Add missing INSERT policy for users table
-- Run this in Supabase SQL Editor to fix "New row violates row-level security policy for table users"

-- Check if policy already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'users' AND policyname = 'Users can insert their own profile'
    ) THEN
        CREATE POLICY "Users can insert their own profile" ON public.users 
        FOR INSERT WITH CHECK (auth.uid() = id);
        RAISE NOTICE 'Policy created successfully';
    ELSE
        RAISE NOTICE 'Policy already exists';
    END IF;
END $$;

-- Also ensure RLS is enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Verify
SELECT policyname, cmd FROM pg_policies WHERE tablename = 'users';
