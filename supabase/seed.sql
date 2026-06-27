-- =====================================================
-- MICROFLOW PRO - SEED DATA
-- Minimal test data for local development
-- =====================================================

-- Platform settings
INSERT INTO public.platform_settings (key, value, description)
VALUES ('chatbot_config', '{"enabled": true, "model": "llama-3.1-70b"}', 'Chatbot configuration for AI assistant')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, description = EXCLUDED.description;
