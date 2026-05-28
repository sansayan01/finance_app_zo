import { z } from 'zod';

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------

export const PublicEnvSchema = z.object({
  NEXT_PUBLIC_SITE_URL: z.string().url(),
  NEXT_PUBLIC_APP_SIGN_IN_URL: z.string().url(),
  NEXT_PUBLIC_DEMO_BOOKING_URL: z.string().url(),
  NEXT_PUBLIC_PLAUSIBLE_DOMAIN: z.string().min(1).optional(),
});

export const ServerEnvSchema = z.object({
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
});

// ---------------------------------------------------------------------------
// Internal readers
// ---------------------------------------------------------------------------

function readPublic() {
  // Reference each var explicitly so Next.js inlines them at build time.
  const result = PublicEnvSchema.safeParse({
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL,
    NEXT_PUBLIC_APP_SIGN_IN_URL: process.env.NEXT_PUBLIC_APP_SIGN_IN_URL,
    NEXT_PUBLIC_DEMO_BOOKING_URL: process.env.NEXT_PUBLIC_DEMO_BOOKING_URL,
    NEXT_PUBLIC_PLAUSIBLE_DOMAIN: process.env.NEXT_PUBLIC_PLAUSIBLE_DOMAIN,
  });

  if (!result.success) {
    const missing = result.error.issues.map((i) => i.path.join('.')).join(', ');
    throw new Error(`Missing or invalid public env: ${missing}`);
  }

  return result.data;
}

function readServer() {
  const result = ServerEnvSchema.safeParse({
    SUPABASE_URL: process.env.SUPABASE_URL,
    SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY,
  });

  if (!result.success) {
    const missing = result.error.issues.map((i) => i.path.join('.')).join(', ');
    throw new Error(`Missing or invalid server env: ${missing}`);
  }

  return result.data;
}

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

export type PublicEnv = z.infer<typeof PublicEnvSchema>;
export type ServerEnv = z.infer<typeof ServerEnvSchema>;

/**
 * Eagerly-validated public environment variables (available in both server and
 * client bundles). Server variables are accessed lazily via `env.server` so
 * they are only evaluated on the server side.
 */
export const env: PublicEnv & { readonly server: ServerEnv } = {
  ...readPublic(),
  get server() {
    return readServer();
  },
};

/**
 * Assertion helper for use inside Server Actions and Route Handlers.
 * Throws with a descriptive message naming the missing variable on failure.
 */
export function assertServerEnv(): ServerEnv {
  return readServer();
}
