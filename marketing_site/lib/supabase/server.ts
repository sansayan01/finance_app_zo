import { createClient } from '@supabase/supabase-js';
import { assertServerEnv } from '@/lib/env';
import type { Database } from '@/lib/supabase/types';

/**
 * Returns a typed Supabase client authenticated with the service-role key.
 *
 * This module MUST only be imported from server components, route handlers,
 * or server actions — never from client components.
 */
export function getSupabaseServerClient() {
  const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = assertServerEnv();
  return createClient<Database>(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}
