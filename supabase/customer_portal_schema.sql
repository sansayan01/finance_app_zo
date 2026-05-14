-- =====================================================
-- CUSTOMER PORTAL SCHEMA
-- =====================================================

-- Customer Notifications
CREATE TABLE IF NOT EXISTS public.customer_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'payment_due', 'collection_visit', 'loan_approved', 'savings_update'
    is_read BOOLEAN DEFAULT FALSE,
    data JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    read_at TIMESTAMP WITH TIME ZONE
);

-- Customer Payment Requests
CREATE TABLE IF NOT EXISTS public.customer_payment_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    loan_id UUID REFERENCES public.loans(id),
    amount DECIMAL(12,2) NOT NULL,
    payment_method VARCHAR(50) DEFAULT 'cash',
    status VARCHAR(50) DEFAULT 'pending', -- 'pending', 'approved', 'rejected', 'completed'
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by UUID REFERENCES public.profiles(id),
    notes TEXT,
    org_id UUID REFERENCES public.organizations(id)
);

-- Customer Support Tickets
CREATE TABLE IF NOT EXISTS public.customer_support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    subject VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    status VARCHAR(50) DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'closed'
    priority VARCHAR(50) DEFAULT 'normal', -- 'low', 'normal', 'high', 'urgent'
    assigned_to UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    org_id UUID REFERENCES public.organizations(id)
);

-- Customer Support Messages
CREATE TABLE IF NOT EXISTS public.customer_ticket_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id UUID NOT NULL REFERENCES public.customer_support_tickets(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES public.profiles(id),
    message TEXT NOT NULL,
    attachments JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customer Feedback
CREATE TABLE IF NOT EXISTS public.customer_feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'complaint', 'suggestion', 'appreciation', 'other'
    subject VARCHAR(255),
    message TEXT NOT NULL,
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    status VARCHAR(50) DEFAULT 'new',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    org_id UUID REFERENCES public.organizations(id)
);

-- Customer App Sessions (for analytics)
CREATE TABLE IF NOT EXISTS public.customer_app_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    logout_at TIMESTAMP WITH TIME ZONE,
    device_info JSONB DEFAULT '{}',
    app_version VARCHAR(50),
    org_id UUID REFERENCES public.organizations(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_customer_notifications_customer ON public.customer_notifications(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_payment_requests_customer ON public.customer_payment_requests(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_support_tickets_customer ON public.customer_support_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_feedback_customer ON public.customer_feedback(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_app_sessions_customer ON public.customer_app_sessions(customer_id);

-- RLS Policies
ALTER TABLE public.customer_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_payment_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_support_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_ticket_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customer_app_sessions ENABLE ROW LEVEL SECURITY;

-- Customers can only see their own data
CREATE POLICY "customers_own_notifications" ON public.customer_notifications
    FOR ALL USING (customer_id = auth.uid());

CREATE POLICY "customers_own_payment_requests" ON public.customer_payment_requests
    FOR ALL USING (customer_id = auth.uid());

CREATE POLICY "customers_own_tickets" ON public.customer_support_tickets
    FOR ALL USING (customer_id = auth.uid() OR org_id IN (SELECT org_id FROM public.profiles WHERE id = auth.uid()));

CREATE POLICY "customers_own_ticket_messages" ON public.customer_ticket_messages
    FOR ALL USING (ticket_id IN (SELECT id FROM public.customer_support_tickets WHERE customer_id = auth.uid()));

CREATE POLICY "customers_own_feedback" ON public.customer_feedback
    FOR ALL USING (customer_id = auth.uid());
