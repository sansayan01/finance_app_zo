-- ==============================================
-- BRAND ASSETS STORAGE BUCKET
-- ==============================================
-- Run this in Supabase SQL Editor to create
-- the brand-assets storage bucket

-- Create storage bucket for brand assets
INSERT INTO storage.buckets (id, name, public)
VALUES ('brand-assets', 'brand-assets', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for brand-assets
CREATE POLICY "Brand assets are publicly readable"
ON storage.objects FOR SELECT
USING (bucket_id = 'brand-assets');

CREATE POLICY "Authenticated users can upload brand assets"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'brand-assets' 
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can update their own org brand assets"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'brand-assets'
  AND auth.role() = 'authenticated'
);

-- ==============================================
-- UPDATE ORGANIZATIONS TABLE FOR BRANDING
-- ==============================================

ALTER TABLE public.organizations
ADD COLUMN IF NOT EXISTS display_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS logo_url TEXT,
ADD COLUMN IF NOT EXISTS brand_color VARCHAR(7) DEFAULT '#1976D2',
ADD COLUMN IF NOT EXISTS brand_secondary_color VARCHAR(7) DEFAULT '#424242',
ADD COLUMN IF NOT EXISTS favicon_url TEXT,
ADD COLUMN IF NOT EXISTS splash_screen_url TEXT;

-- ==============================================
-- BRANDING CONFIGURATION TABLE
-- ==============================================

CREATE TABLE IF NOT EXISTS public.org_branding (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    
    -- App appearance
    primary_color VARCHAR(7) DEFAULT '#1976D2',
    secondary_color VARCHAR(7) DEFAULT '#424242',
    accent_color VARCHAR(7) DEFAULT '#FF5722',
    background_color VARCHAR(7) DEFAULT '#FFFFFF',
    
    -- Assets
    logo_url TEXT,
    logo_dark_url TEXT,
    favicon_url TEXT,
    splash_screen_url TEXT,
    app_icon_url TEXT,
    
    -- Typography
    font_family VARCHAR(100) DEFAULT 'Roboto',
    heading_font VARCHAR(100),
    
    -- Customization flags
    use_custom_branding BOOLEAN DEFAULT false,
    show_powered_by BOOLEAN DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    UNIQUE(org_id)
);

-- Enable RLS
ALTER TABLE public.org_branding ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view their org branding"
ON public.org_branding FOR SELECT
USING (
    org_id IN (
        SELECT org_id FROM public.profiles 
        WHERE user_id = auth.uid()
    )
);

CREATE POLICY "Org admins can manage branding"
ON public.org_branding FOR ALL
USING (
    org_id IN (
        SELECT org_id FROM public.profiles 
        WHERE user_id = auth.uid() 
        AND role IN ('superAdmin', 'executiveAdmin')
    )
);

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_org_branding_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER org_branding_updated_at
BEFORE UPDATE ON public.org_branding
FOR EACH ROW
EXECUTE FUNCTION update_org_branding_updated_at();

-- ==============================================
-- INDEXES
-- ==============================================

CREATE INDEX IF NOT EXISTS idx_org_branding_org_id 
ON public.org_branding(org_id);

-- ==============================================
-- GRANT PERMISSIONS
-- ==============================================

GRANT ALL ON public.org_branding TO authenticated;
GRANT ALL ON public.org_branding TO service_role;
GRANT SELECT ON public.org_branding TO anon;
