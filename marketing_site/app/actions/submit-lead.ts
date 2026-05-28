'use server';

import { z } from 'zod';
import { assertServerEnv } from '@/lib/env';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { PRICING_TIERS } from '@/lib/pricing';
import type { LeadSubmissionResult } from '@/lib/supabase/types';

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------

const tierIds = PRICING_TIERS.map((t) => t.id) as [string, ...string[]];

const LeadSubmissionSchema = z.object({
  organizationName: z.string().min(1).max(200),
  contactName: z.string().min(1).max(120),
  email: z.string().email().max(320),
  message: z.string().min(1).max(5000),
  role: z.string().max(100).optional(),
  country: z.string().max(100).optional(),
  mfiSize: z.string().max(100).optional(),
  tierOfInterest: z.enum(tierIds).optional(),
  sourcePage: z.string().max(500).optional(),
  // Honeypot — must be empty
  website: z.string().max(0).optional(),
});

// ---------------------------------------------------------------------------
// Rate limiting (in-memory token bucket)
// ---------------------------------------------------------------------------

const buckets = new Map<string, { tokens: number; last: number }>();
const RATE_LIMIT = 10;
const RATE_WINDOW_MS = 10 * 60 * 1000; // 10 minutes

function checkRateLimit(key: string): boolean {
  const now = Date.now();
  let bucket = buckets.get(key);

  if (!bucket || now - bucket.last > RATE_WINDOW_MS) {
    bucket = { tokens: RATE_LIMIT, last: now };
    buckets.set(key, bucket);
  }

  if (bucket.tokens <= 0) return false;
  bucket.tokens--;
  bucket.last = now;
  return true;
}

// ---------------------------------------------------------------------------
// Server action
// ---------------------------------------------------------------------------

export async function submitLead(
  formData: FormData,
  forwardedFor?: string,
): Promise<LeadSubmissionResult> {
  // Validate env
  assertServerEnv();

  // Parse
  const raw = {
    organizationName: formData.get('organizationName'),
    contactName: formData.get('contactName'),
    email: formData.get('email'),
    message: formData.get('message'),
    role: formData.get('role') || undefined,
    country: formData.get('country') || undefined,
    mfiSize: formData.get('mfiSize') || undefined,
    tierOfInterest: formData.get('tierOfInterest') || undefined,
    sourcePage: formData.get('sourcePage') || undefined,
    website: formData.get('website') || '',
  };

  const parsed = LeadSubmissionSchema.safeParse(raw);
  if (!parsed.success) {
    const fieldErrors: Record<string, string> = {};
    for (const issue of parsed.error.issues) {
      const key = issue.path.join('.');
      if (!fieldErrors[key]) fieldErrors[key] = issue.message;
    }
    return { ok: false, code: 'invalid', fieldErrors };
  }

  // Honeypot check
  if (parsed.data.website) {
    return { ok: false, code: 'rejected' };
  }

  // Rate limit
  const rateLimitKey = forwardedFor ?? 'unknown';
  if (!checkRateLimit(rateLimitKey)) {
    return { ok: false, code: 'rejected' };
  }

  // Insert
  try {
    const supabase = getSupabaseServerClient();
    const { error } = await supabase.from('marketing_leads').insert({
      organization_name: parsed.data.organizationName,
      contact_name: parsed.data.contactName,
      email: parsed.data.email,
      message: parsed.data.message,
      role: parsed.data.role ?? null,
      country: parsed.data.country ?? null,
      mfi_size: parsed.data.mfiSize ?? null,
      tier_of_interest: parsed.data.tierOfInterest ?? null,
      source_page: parsed.data.sourcePage ?? null,
      user_agent: null,
    } as never);

    if (error) {
      console.error('Supabase insert error:', error);
      return { ok: false, code: 'server_error' };
    }

    return { ok: true };
  } catch (err) {
    console.error('submitLead error:', err);
    return { ok: false, code: 'server_error' };
  }
}
