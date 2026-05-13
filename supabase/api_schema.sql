-- =====================================================
-- API & WEBHOOKS SYSTEM
-- MicroFlow Pro - Public API for Integrations
-- =====================================================

-- API Keys
CREATE TABLE IF NOT EXISTS public.api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    key_hash TEXT NOT NULL,
    key_prefix TEXT NOT NULL, -- First 8 chars for display
    scopes TEXT[] DEFAULT ARRAY['read']::TEXT[],
    last_used_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    UNIQUE(org_id, name)
);

-- API Rate Limits
CREATE TABLE IF NOT EXISTS public.api_rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    period_start TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Webhooks
CREATE TABLE IF NOT EXISTS public.webhooks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    secret TEXT NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
    events TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    is_active BOOLEAN DEFAULT true,
    last_triggered_at TIMESTAMP WITH TIME ZONE,
    last_response_status INTEGER,
    failure_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Webhook Deliveries
CREATE TABLE IF NOT EXISTS public.webhook_deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    webhook_id UUID REFERENCES public.webhooks(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL,
    response_status INTEGER,
    response_body TEXT,
    delivered_at TIMESTAMP WITH TIME ZONE,
    attempt_count INTEGER DEFAULT 1,
    next_retry_at TIMESTAMP WITH TIME ZONE,
    success BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- API Logs (for debugging and auditing)
CREATE TABLE IF NOT EXISTS public.api_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    api_key_id UUID REFERENCES public.api_keys(id) ON DELETE SET NULL,
    endpoint TEXT NOT NULL,
    method TEXT NOT NULL,
    status_code INTEGER,
    response_time_ms INTEGER,
    ip_address TEXT,
    user_agent TEXT,
    request_body JSONB,
    response_body JSONB,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Integrations (third-party connections)
CREATE TABLE IF NOT EXISTS public.integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('razorpay', 'stripe', 'google_sheets', 'zapier', 'slack', 'whatsapp', 'sms_gateway')),
    name TEXT NOT NULL,
    config JSONB DEFAULT '{}'::jsonb,
    credentials JSONB DEFAULT '{}'::jsonb, -- Encrypted
    is_active BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    sync_status TEXT DEFAULT 'idle',
    sync_error TEXT,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    
    UNIQUE(org_id, type)
);

-- Data Exports
CREATE TABLE IF NOT EXISTS public.data_exports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID REFERENCES public.organizations(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('members', 'loans', 'collections', 'transactions', 'full_backup')),
    format TEXT NOT NULL DEFAULT 'csv' CHECK (format IN ('csv', 'excel', 'json')),
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    file_url TEXT,
    file_size_bytes BIGINT,
    record_count INTEGER,
    filters JSONB DEFAULT '{}'::jsonb,
    error_message TEXT,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    completed_at TIMESTAMP WITH TIME ZONE
);

-- INDEXES
CREATE INDEX idx_api_keys_org ON public.api_keys(org_id);
CREATE INDEX idx_api_keys_prefix ON public.api_keys(key_prefix);
CREATE INDEX idx_api_rate_limits_org_period ON public.api_rate_limits(org_id, period_start);
CREATE INDEX idx_webhooks_org ON public.webhooks(org_id);
CREATE INDEX idx_webhook_deliveries_webhook ON public.webhook_deliveries(webhook_id);
CREATE INDEX idx_api_logs_org ON public.api_logs(org_id);
CREATE INDEX idx_api_logs_created ON public.api_logs(created_at);
CREATE INDEX idx_integrations_org ON public.integrations(org_id);
CREATE INDEX idx_data_exports_org ON public.data_exports(org_id);

-- RLS POLICIES
ALTER TABLE public.api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhooks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhook_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.api_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.integrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.data_exports ENABLE ROW LEVEL SECURITY;

-- API Keys policies
CREATE POLICY "Users can view own org api keys" ON public.api_keys
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Admins can manage api keys" ON public.api_keys
    FOR ALL USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- Webhooks policies
CREATE POLICY "Users can view own org webhooks" ON public.webhooks
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Admins can manage webhooks" ON public.webhooks
    FOR ALL USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- Integrations policies
CREATE POLICY "Users can view own org integrations" ON public.integrations
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Admins can manage integrations" ON public.integrations
    FOR ALL USING (
        org_id = public.get_user_org_id() 
        AND public.get_user_role() IN ('admin', 'superAdmin')
    );

-- Data exports policies
CREATE POLICY "Users can view own org exports" ON public.data_exports
    FOR SELECT USING (org_id = public.get_user_org_id());

CREATE POLICY "Users can create exports" ON public.data_exports
    FOR INSERT WITH CHECK (org_id = public.get_user_org_id());

-- FUNCTIONS

-- Generate API Key
CREATE OR REPLACE FUNCTION public.generate_api_key(
    p_org_id UUID,
    p_name TEXT,
    p_scopes TEXT[] DEFAULT ARRAY['read']::TEXT[],
    p_expires_at TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS TABLE(id UUID, key_prefix TEXT, full_key TEXT) AS $$
DECLARE
    v_key TEXT;
    v_key_hash TEXT;
    v_key_prefix TEXT;
    v_key_id UUID;
BEGIN
    -- Generate random key
    v_key := 'mfp_' || encode(gen_random_bytes(32), 'hex');
    v_key_prefix := substring(v_key, 1, 11);
    v_key_hash := digest(v_key, 'sha256');
    
    -- Insert
    INSERT INTO public.api_keys (org_id, name, key_hash, key_prefix, scopes, expires_at)
    VALUES (p_org_id, p_name, v_key_hash, v_key_prefix, p_scopes, p_expires_at)
    RETURNING api_keys.id INTO v_key_id;
    
    RETURN QUERY SELECT v_key_id, v_key_prefix, v_key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate API Key
CREATE OR REPLACE FUNCTION public.validate_api_key(
    p_key TEXT,
    p_required_scope TEXT DEFAULT 'read'
) RETURNS TABLE(
    valid BOOLEAN,
    org_id UUID,
    key_id UUID,
    scopes TEXT[]
) AS $$
DECLARE
    v_key_hash TEXT;
    v_key_record RECORD;
BEGIN
    v_key_hash := digest(p_key, 'sha256');
    
    SELECT ak.id, ak.org_id, ak.scopes, ak.is_active, ak.expires_at
    INTO v_key_record
    FROM public.api_keys ak
    WHERE ak.key_hash = v_key_hash;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT[];
        RETURN;
    END IF;
    
    IF NOT v_key_record.is_active THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT[];
        RETURN;
    END IF;
    
    IF v_key_record.expires_at IS NOT NULL AND v_key_record.expires_at < now() THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT[];
        RETURN;
    END IF;
    
    IF NOT (p_required_scope = ANY(v_key_record.scopes) OR 'write' = ANY(v_key_record.scopes)) THEN
        RETURN QUERY SELECT false, NULL::UUID, NULL::UUID, NULL::TEXT[];
        RETURN;
    END IF;
    
    -- Update last used
    UPDATE public.api_keys SET last_used_at = now() WHERE id = v_key_record.id;
    
    RETURN QUERY SELECT true, v_key_record.org_id, v_key_record.id, v_key_record.scopes;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger Webhook
CREATE OR REPLACE FUNCTION public.trigger_webhook(
    p_org_id UUID,
    p_event_type TEXT,
    p_payload JSONB
) RETURNS VOID AS $$
DECLARE
    v_webhook RECORD;
BEGIN
    FOR v_webhook IN 
        SELECT * FROM public.webhooks 
        WHERE org_id = p_org_id 
          AND is_active = true 
          AND p_event_type = ANY(events)
    LOOP
        INSERT INTO public.webhook_deliveries (
            webhook_id, event_type, payload
        ) VALUES (
            v_webhook.id, p_event_type, p_payload
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Webhook delivery processor (would be called by Edge Function)
CREATE OR REPLACE FUNCTION public.process_webhook_delivery(
    p_delivery_id UUID,
    p_status INTEGER,
    p_response TEXT
) RETURNS VOID AS $$
BEGIN
    UPDATE public.webhook_deliveries SET
        response_status = p_status,
        response_body = p_response,
        delivered_at = now(),
        success = p_status >= 200 AND p_status < 300,
        attempt_count = attempt_count + 1
    WHERE id = p_delivery_id;
    
    UPDATE public.webhooks SET
        last_triggered_at = now(),
        last_response_status = p_status,
        failure_count = CASE WHEN p_status >= 200 AND p_status < 300 THEN 0 ELSE failure_count + 1 END
    WHERE id = (SELECT webhook_id FROM public.webhook_deliveries WHERE id = p_delivery_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- END OF API & WEBHOOKS SYSTEM
-- =====================================================
