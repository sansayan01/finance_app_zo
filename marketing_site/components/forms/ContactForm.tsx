'use client';

import { useState, useTransition } from 'react';
import { useSearchParams } from 'next/navigation';
import { submitLead } from '@/app/actions/submit-lead';
import { PRICING_TIERS } from '@/lib/pricing';
import type { LeadSubmissionResult } from '@/lib/supabase/types';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select } from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { FieldError } from '@/components/ui/field-error';
import { Card } from '@/components/ui/card';

type FormState = 'idle' | 'submitting' | 'success' | 'error';

import type { TierOfInterest } from '@/lib/supabase/types';

const tierIds = PRICING_TIERS.map((t) => t.id) as readonly string[];

export function ContactForm({ sourcePage = '/contact' }: { sourcePage?: string }) {
  const searchParams = useSearchParams();
  const tierParam = searchParams.get('tier');
  const validTier: TierOfInterest | '' = tierParam && (tierIds as readonly string[]).includes(tierParam) ? (tierParam as TierOfInterest) : '';

  const [state, setState] = useState<FormState>('idle');
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});
  const [isPending, startTransition] = useTransition();

  // Preserve values on error
  const [formValues, setFormValues] = useState({
    organizationName: '',
    contactName: '',
    email: '',
    message: '',
    role: '',
    country: '',
    mfiSize: '',
    tierOfInterest: validTier,
  });

  function updateField(name: string, value: string) {
    setFormValues((prev) => ({ ...prev, [name]: value }));
    if (fieldErrors[name]) {
      setFieldErrors((prev) => {
        const next = { ...prev };
        delete next[name];
        return next;
      });
    }
  }

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setState('submitting');
    setFieldErrors({});

    const form = e.currentTarget;
    const fd = new FormData(form);

    startTransition(() => {
      void (async () => {
        const result: LeadSubmissionResult = await submitLead(fd);
        if (result.ok) {
          setState('success');
          setFormValues({
            organizationName: '',
            contactName: '',
            email: '',
            message: '',
            role: '',
            country: '',
            mfiSize: '',
            tierOfInterest: '',
          });
        } else if (result.code === 'invalid' && result.fieldErrors) {
          setState('idle');
          setFieldErrors(result.fieldErrors);
        } else {
          setState('error');
        }
      })();
    });
  }

  if (state === 'success') {
    return (
      <Card variant="glass" className="text-center">
        <svg aria-hidden className="mx-auto h-12 w-12 text-indigo" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <h3 className="mt-4 font-display text-xl font-bold text-text">Thank you!</h3>
        <p className="mt-2 text-sm text-text-muted">
          We&apos;ve received your message and will be in touch shortly.
        </p>
      </Card>
    );
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-4">
      {/* Honeypot */}
      <input
        type="text"
        name="website"
        tabIndex={-1}
        aria-hidden
        autoComplete="off"
        className="absolute left-[-9999px]"
      />

      <input type="hidden" name="sourcePage" value={sourcePage} />

      <div>
        <Label htmlFor="organizationName">Organization Name *</Label>
        <Input
          id="organizationName"
          name="organizationName"
          required
          value={formValues.organizationName}
          onChange={(e) => updateField('organizationName', e.target.value)}
          aria-invalid={!!fieldErrors.organizationName}
          aria-describedby={fieldErrors.organizationName ? 'err-organizationName' : undefined}
        />
        {fieldErrors.organizationName && (
          <FieldError id="err-organizationName">{fieldErrors.organizationName}</FieldError>
        )}
      </div>

      <div>
        <Label htmlFor="contactName">Contact Name *</Label>
        <Input
          id="contactName"
          name="contactName"
          required
          value={formValues.contactName}
          onChange={(e) => updateField('contactName', e.target.value)}
          aria-invalid={!!fieldErrors.contactName}
          aria-describedby={fieldErrors.contactName ? 'err-contactName' : undefined}
        />
        {fieldErrors.contactName && (
          <FieldError id="err-contactName">{fieldErrors.contactName}</FieldError>
        )}
      </div>

      <div>
        <Label htmlFor="email">Email *</Label>
        <Input
          id="email"
          name="email"
          type="email"
          required
          value={formValues.email}
          onChange={(e) => updateField('email', e.target.value)}
          aria-invalid={!!fieldErrors.email}
          aria-describedby={fieldErrors.email ? 'err-email' : undefined}
        />
        {fieldErrors.email && (
          <FieldError id="err-email">{fieldErrors.email}</FieldError>
        )}
      </div>

      <div>
        <Label htmlFor="message">Message *</Label>
        <Textarea
          id="message"
          name="message"
          required
          rows={4}
          value={formValues.message}
          onChange={(e) => updateField('message', e.target.value)}
          aria-invalid={!!fieldErrors.message}
          aria-describedby={fieldErrors.message ? 'err-message' : undefined}
        />
        {fieldErrors.message && (
          <FieldError id="err-message">{fieldErrors.message}</FieldError>
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="role">Role</Label>
          <Select id="role" name="role" value={formValues.role} onChange={(e) => updateField('role', e.target.value)}>
            <option value="">Select role</option>
            <option value="executive_admin">Executive Admin</option>
            <option value="branch_manager">Branch Manager</option>
            <option value="staff">Staff / Agent</option>
            <option value="other">Other</option>
          </Select>
        </div>
        <div>
          <Label htmlFor="country">Country</Label>
          <Input id="country" name="country" value={formValues.country} onChange={(e) => updateField('country', e.target.value)} />
        </div>
      </div>

      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor="mfiSize">MFI Size</Label>
          <Select id="mfiSize" name="mfiSize" value={formValues.mfiSize} onChange={(e) => updateField('mfiSize', e.target.value)}>
            <option value="">Select size</option>
            <option value="1-10">1-10 staff</option>
            <option value="11-50">11-50 staff</option>
            <option value="51-200">51-200 staff</option>
            <option value="200+">200+ staff</option>
          </Select>
        </div>
        <div>
          <Label htmlFor="tierOfInterest">Tier of Interest</Label>
          <Select id="tierOfInterest" name="tierOfInterest" value={formValues.tierOfInterest} onChange={(e) => updateField('tierOfInterest', e.target.value)}>
            <option value="">Select tier</option>
            {PRICING_TIERS.map((t) => (
              <option key={t.id} value={t.id}>{t.name}</option>
            ))}
          </Select>
        </div>
      </div>

      {state === 'error' && (
        <Card className="border-red-200 bg-red-50 text-sm text-red-700 dark:border-red-900 dark:bg-red-950 dark:text-red-300">
          Something went wrong. Please try again.
          <Button type="button" variant="ghost" size="sm" onClick={() => setState('idle')} className="ml-2">
            Retry
          </Button>
        </Card>
      )}

      <Button type="submit" disabled={isPending || state === 'submitting'} className="w-full">
        {isPending || state === 'submitting' ? 'Sending…' : 'Send Message'}
      </Button>
    </form>
  );
}
