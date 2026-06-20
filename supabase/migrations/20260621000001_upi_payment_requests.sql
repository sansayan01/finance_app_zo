-- UPI Payment Requests: customer-initiated payments pending staff/admin confirmation
create table if not exists public.upi_payment_requests (
  id              uuid primary key default gen_random_uuid(),
  org_id          uuid not null references public.organizations(id) on delete cascade,
  customer_id     uuid not null references auth.users(id) on delete cascade,
  member_id       uuid references public.members(id),
  loan_id         uuid references public.loans(id),
  savings_plan_id uuid references public.savings_plans(id),
  emi_schedule_id uuid references public.emi_schedule(id),
  amount          numeric(12,2) not null check (amount > 0),
  upi_vpa         text not null,
  transaction_ref text,
  status          text not null default 'pending'
                  check (status in ('pending', 'confirmed', 'rejected')),
  confirmed_by    uuid references auth.users(id),
  confirmed_at    timestamptz,
  rejection_reason text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Indexes
create index if not exists upi_payment_requests_org_status_idx
  on public.upi_payment_requests (org_id, status);
create index if not exists upi_payment_requests_customer_idx
  on public.upi_payment_requests (customer_id, created_at desc);
create index if not exists upi_payment_requests_pending_idx
  on public.upi_payment_requests (org_id, status, created_at desc)
  where status = 'pending';

-- RLS
alter table public.upi_payment_requests enable row level security;

-- Customers can view their own requests
create policy upi_req_select_own on public.upi_payment_requests
  for select using (customer_id = auth.uid());

-- Org staff/admin/manager can view all org requests
create policy upi_req_select_org on public.upi_payment_requests
  for select using (
    org_id = public.get_user_org_id()
    and public.get_user_role() in ('executiveAdmin', 'manager', 'collectionAgent')
  );

-- Customers can insert their own requests
create policy upi_req_insert_own on public.upi_payment_requests
  for insert with check (customer_id = auth.uid());

-- Org staff/admin/manager can update (confirm/reject) org requests
create policy upi_req_update_org on public.upi_payment_requests
  for update using (
    org_id = public.get_user_org_id()
    and public.get_user_role() in ('executiveAdmin', 'manager', 'collectionAgent')
  );
