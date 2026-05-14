-- System Configuration table for app updates and maintenance
CREATE TABLE IF NOT EXISTS public.system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    current_version_android TEXT NOT NULL DEFAULT '1.0.0',
    min_version_android TEXT NOT NULL DEFAULT '1.0.0',
    current_version_ios TEXT NOT NULL DEFAULT '1.0.0',
    min_version_ios TEXT NOT NULL DEFAULT '1.0.0',
    update_url_android TEXT,
    update_url_ios TEXT,
    update_message TEXT DEFAULT 'A new version is available. Please update to continue.',
    is_under_maintenance BOOLEAN DEFAULT false,
    maintenance_message TEXT DEFAULT 'MicroFlow Pro is currently under maintenance. We will be back soon.',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_by UUID REFERENCES auth.users(id)
);

-- Insert default row
INSERT INTO public.system_config (current_version_android, min_version_android, current_version_ios, min_version_ios)
VALUES ('1.0.0', '1.0.0', '1.0.0', '1.0.0')
ON CONFLICT DO NOTHING;

-- RLS Policies
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

-- Everyone can read system config
CREATE POLICY "Allow public read for system_config" 
ON public.system_config FOR SELECT 
USING (true);

-- Only admins can update
CREATE POLICY "Allow admins to update system_config" 
ON public.system_config FOR UPDATE 
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE user_id = auth.uid() 
        AND role = 'superAdmin'
    )
);
