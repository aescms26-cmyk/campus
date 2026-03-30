-- Fix Database Schema for User Creation Errors
-- Run this SQL in Supabase Dashboard > SQL Editor > New Query

-- 1. Add missing columns if not exist
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS user_id TEXT UNIQUE,
ADD COLUMN IF NOT EXISTS mobile_no TEXT,
ADD COLUMN IF NOT EXISTS photo_url TEXT,
ADD COLUMN IF NOT EXISTS on_break BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS break_start_time TIMESTAMPTZ,
ADD COLUMN IF NOT EXISTS break_duration_mins INTEGER DEFAULT 30;

-- 2. Fix RLS Policies - Remove conflicting, add proper ones
DROP POLICY IF EXISTS \"Admins can manage all users\" ON public.users;
DROP POLICY IF EXISTS \"Allow all access to users\" ON public.users;
DROP POLICY IF EXISTS \"Team leads can read their counsellors\" ON public.users;
DROP POLICY IF EXISTS \"Users can read their own profile\" ON public.users;

-- Admin full access (checks JWT metadata)
CREATE POLICY \"Admins manage all users\" ON public.users FOR ALL 
USING ((auth.jwt() ->> 'app_metadata' ->> 'provider') IS NULL OR (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin');

-- Users read own profile
CREATE POLICY \"Users read own profile\" ON public.users FOR SELECT 
USING (auth.uid() = id);

-- Team leads read their team
CREATE POLICY \"Team leads read team\" ON public.users FOR SELECT 
USING (team_lead_id = auth.uid());

-- Service role bypass (for API endpoints)
CREATE POLICY \"Service role bypass\" ON public.users FOR ALL 
USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- 3. Ensure realtime replication
ALTER PUBLICATION supabase_realtime ADD TABLE users, enquiries, courses;

-- 4. Seed courses if empty
INSERT INTO public.courses (name, duration, fees, description)
SELECT 'B.Tech. Computer Science', '4 Years', 230000, 'Sample Course'
WHERE NOT EXISTS (SELECT 1 FROM public.courses LIMIT 1)
ON CONFLICT (name) DO NOTHING;

-- Test: Verify admin bootstrap
INSERT INTO public.users (id, user_id, name, email, role) 
VALUES (
  (SELECT id FROM auth.users WHERE email = 'aescms26@gmail.com'),
  '1001',
  'Admin',
  'aescms26@gmail.com',
  'admin'
)
ON CONFLICT (id) DO NOTHING;

-- Success message
SELECT 'Schema fixed! Run npm run dev and login as User ID: 1001, Name: Admin' as message;
