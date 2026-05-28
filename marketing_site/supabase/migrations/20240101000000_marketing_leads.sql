-- Migration: marketing_leads table for lead capture
-- Requirements: 6.8, 6.10

-- Enable pgcrypto for gen_random_uuid()
create extension if not exists pgcrypto;

-- Create the marketing_leads table
create table public.marketing_leads (
  id                 uuid primary key default gen_random_uuid(),
  created_at         timestamptz not null default now(),
  organization_name  text not null check (length(organization_name) between 1 and 200),
  contact_name       text not null check (length(contact_name) between 1 and 120),
  email              text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role               text,
  country            text,
  mfi_size           text,
  message            text not null check (length(message) between 1 and 5000),
  tier_of_interest   text check (tier_of_interest in ('starter','growth','enterprise')),
  source_page        text,
  user_agent         text
);

-- Index for querying leads by creation date
create index marketing_leads_created_at_idx on public.marketing_leads (created_at desc);

-- Enable Row Level Security
alter table public.marketing_leads enable row level security;

-- Deny everything by default. Service role bypasses RLS.
revoke all on table public.marketing_leads from anon, authenticated;

-- Explicit policies for clarity / auditability:
create policy "no anon select"
  on public.marketing_leads for select
  to anon, authenticated
  using (false);

create policy "no anon insert"
  on public.marketing_leads for insert
  to anon, authenticated
  with check (false);

-- service_role bypasses RLS by design; the Server Action uses the service-role key,
-- which never reaches the browser.
