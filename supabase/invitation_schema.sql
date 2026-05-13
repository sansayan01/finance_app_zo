-- =====================================================
-- INVITATION SYSTEM
-- MicroFlow Pro - Staff Invitations
-- =====================================================

-- Organization Invitations
CREATE TABLE IF NOT EXISTS public.org_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('admin', 'manager', 'fieldStaff', 'accountant')),
    branch_id UUID REFERENCES public.branches(id) ON DELETE SET NULL,
    invited_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    personal_message TEXT,
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'expired', 'revoked')),
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '7 days'),
    accepted_at TIMESTAMP WITH TIME ZONE,
    accepted_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    -- One pending invitation per email per org
    UNIQUE(org_id, email) WHERE status = 'pending'
);

-- Password Reset Tokens
CREATE TABLE IF NOT EXISTS public.password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    used BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '1 hour'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Email Verification Tokens
CREATE TABLE IF NOT EXISTS public.email_verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    verified BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '24 hours'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Magic Links (Passwordless Auth)
CREATE TABLE IF NOT EXISTS public.magic_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL,
    token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    used BOOLEAN DEFAULT false,
    expires_at TIMESTAMP WITH TIME ZONE DEFAULT (now() + interval '15 minutes'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- INDEXES
CREATE INDEX idx_org_invitations_org ON public.org_invitations(org_id);
CREATE INDEX idx_org_invitations_email ON public.org_invitations(email);
CREATE INDEX idx_org_invitations_token ON public.org_invitations(token);
CREATE INDEX idx_org_invitations_status ON public.org_invitations(status);
CREATE INDEX idx_password_reset_tokens_user ON public.password_reset_tokens(user_id);
CREATE INDEX idx_password_reset_tokens_token ON public.password_reset_tokens(token);
CREATE INDEX idx_magic_links_email ON public.magic_links(email);

-- RLS POLICIES
ALTER TABLE public.org_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.password_reset_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.email_verification_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.magic_links ENABLE ROW LEVEL SECURITY;

-- Invitations: Users can view own org's invitations
CREATE POLICY "Users can view own org invitations" ON public.org_invitations
    FOR SELECT USING (org_id = public.get_user_org_id());

-- Invitations: Admins can create invitations
CREATE POLICY "Admins can create invitations" ON public.org_invitations
    FOR INSERT WITH CHECK (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin', 'manager')
    );

-- Invitations: Admins can update invitations
CREATE POLICY "Admins can update invitations" ON public.org_invitations
    FOR UPDATE USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- FUNCTIONS

-- Create invitation
CREATE OR REPLACE FUNCTION public.create_invitation(
    p_org_id UUID,
    p_email TEXT,
    p_role TEXT,
    p_branch_id UUID DEFAULT NULL,
    p_message TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_invitation_id UUID;
    v_inviter_id UUID;
BEGIN
    -- Get current user
    SELECT user_id INTO v_inviter_id FROM public.profiles WHERE user_id = auth.uid();
    
    -- Create invitation
    INSERT INTO public.org_invitations (
        org_id, email, role, branch_id, invited_by, personal_message
    ) VALUES (
        p_org_id, p_email, p_role, p_branch_id, v_inviter_id, p_message
    ) RETURNING id INTO v_invitation_id;
    
    RETURN v_invitation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Accept invitation
CREATE OR REPLACE FUNCTION public.accept_invitation(
    p_token TEXT,
    p_full_name TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_invitation RECORD;
    v_user_id UUID;
    v_org_id UUID;
    v_result JSONB;
BEGIN
    -- Get invitation
    SELECT * INTO v_invitation
    FROM public.org_invitations
    WHERE token = p_token AND status = 'pending' AND expires_at > now();
    
    IF NOT FOUND THEN
        RETURN jsonb_build_object('error', 'Invalid or expired invitation');
    END IF;
    
    -- Check if user exists
    SELECT id INTO v_user_id FROM auth.users WHERE email = v_invitation.email;
    
    IF v_user_id IS NULL THEN
        -- User doesn't exist, return info for signup
        RETURN jsonb_build_object(
            'action', 'signup',
            'email', v_invitation.email,
            'org_id', v_invitation.org_id,
            'role', v_invitation.role,
            'branch_id', v_invitation.branch_id
        );
    END IF;
    
    -- User exists, update profile
    UPDATE public.profiles SET
        org_id = v_invitation.org_id,
        role = v_invitation.role,
        branch_id = v_invitation.branch_id,
        full_name = COALESCE(p_full_name, full_name)
    WHERE user_id = v_user_id;
    
    -- Mark invitation as accepted
    UPDATE public.org_invitations SET
        status = 'accepted',
        accepted_at = now(),
        accepted_by = v_user_id
    WHERE id = v_invitation.id;
    
    RETURN jsonb_build_object(
        'action', 'login',
        'user_id', v_user_id,
        'org_id', v_invitation.org_id,
        'role', v_invitation.role
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Revoke invitation
CREATE OR REPLACE FUNCTION public.revoke_invitation(p_invitation_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.org_invitations SET status = 'revoked'
    WHERE id = p_invitation_id AND org_id = public.get_user_org_id();
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Resend invitation
CREATE OR REPLACE FUNCTION public.resend_invitation(p_invitation_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE public.org_invitations SET
        token = encode(gen_random_bytes(32), 'hex'),
        expires_at = now() + interval '7 days',
        status = 'pending'
    WHERE id = p_invitation_id 
      AND org_id = public.get_user_org_id()
      AND status IN ('pending', 'expired');
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Cleanup expired invitations (run via cron)
CREATE OR REPLACE FUNCTION public.cleanup_expired_invitations()
RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER;
BEGIN
    UPDATE public.org_invitations
    SET status = 'expired'
    WHERE status = 'pending' AND expires_at < now();
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    -- Also cleanup old tokens
    DELETE FROM public.password_reset_tokens WHERE expires_at < now();
    DELETE FROM public.magic_links WHERE expires_at < now();
    DELETE FROM public.email_verification_tokens WHERE expires_at < now();
    
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- TRIGGER: Auto-cleanup on insert
CREATE OR REPLACE FUNCTION public.handle_new_invitation()
RETURNS TRIGGER AS $$
BEGIN
    -- Revoke any existing pending invitations for same email
    UPDATE public.org_invitations SET status = 'revoked'
    WHERE org_id = NEW.org_id 
      AND email = NEW.email 
      AND status = 'pending' 
      AND id != NEW.id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_invitation_created
    BEFORE INSERT ON public.org_invitations
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_invitation();

-- =====================================================
-- END OF INVITATION SYSTEM
-- =====================================================
