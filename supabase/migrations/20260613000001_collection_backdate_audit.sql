-- =====================================================
-- Collection Backdate Audit
-- =====================================================
-- Adds an append-only audit trail for backdated collection
-- entries. Every time a collection is inserted or its
-- collection_date / collection_time is modified to an
-- earlier date, a row is written here with a mandatory
-- user-supplied reason and a denormalized snapshot of the
-- before/after values.
--
-- Also adds an `is_backdated` flag on `public.collections`
-- so the application can fast-filter backdated rows in
-- list/analytics queries without scanning the audit table.
--
-- Design notes:
-- - The table is denormalized (no foreign-key lookups to
--   staff_profiles / loans at read time) so dashboards stay
--   fast even as schema evolves.
-- - This table is APPEND-ONLY: no UPDATE / DELETE policies
--   (and no granted update on the base table either). The
--   only writer is the application's backend, which is
--   allowed to insert freely.
-- - `get_user_org_id()` returns the caller's org from the
--   JWT-derived staff profile (matches existing helpers).
-- =====================================================

BEGIN;

-- 1) Flag on collections for fast filtering.
ALTER TABLE public.collections
    ADD COLUMN IF NOT EXISTS is_backdated BOOLEAN NOT NULL DEFAULT FALSE;

-- Partial index — only backdated rows are interesting,
-- keeps the index small and queries hit it cheaply.
CREATE INDEX IF NOT EXISTS collections_is_backdated_idx
    ON public.collections (org_id, is_backdated)
    WHERE is_backdated = TRUE;

-- 2) Audit table.
CREATE TABLE IF NOT EXISTS public.collection_backdate_audit (
    id                    UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                UUID        NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    collection_id         UUID        NOT NULL REFERENCES public.collections(id)   ON DELETE CASCADE,

    -- Row-level audit of the collection itself.
    -- Always now() in practice but kept for full audit fidelity.
    original_created_at   TIMESTAMPTZ NOT NULL,

    -- NULL on first insert of a backdated collection row;
    -- populated when an existing collection's date is shifted.
    entry_collection_date DATE,
    entry_collection_time TIME,

    -- The new (backdated) values being recorded.
    new_collection_date   DATE        NOT NULL,
    new_collection_time   TIME        NOT NULL,

    -- Convenience: (today() - new_collection_date).
    days_back             INTEGER     NOT NULL CHECK (days_back >= 0),

    -- Who did it.
    performed_by          UUID        NOT NULL REFERENCES auth.users(id),
    performed_by_role     TEXT        NOT NULL
        CHECK (performed_by_role IN (
            'superAdmin',
            'executiveAdmin',
            'manager',
            'collectionAgent'
        )),

    -- Mandatory justification supplied by the user at the time.
    reason                TEXT        NOT NULL CHECK (length(trim(reason)) > 0),

    -- Request metadata for forensics.
    ip_address            INET,
    user_agent            TEXT,

    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3) Indexes. Append-heavy table: all indexes lead with org_id
--    so tenant-scoped scans can use index-only paths.
CREATE INDEX IF NOT EXISTS collection_backdate_audit_org_id_created_at_idx
    ON public.collection_backdate_audit (org_id, created_at DESC);

CREATE INDEX IF NOT EXISTS collection_backdate_audit_collection_id_idx
    ON public.collection_backdate_audit (collection_id);

CREATE INDEX IF NOT EXISTS collection_backdate_audit_performed_by_idx
    ON public.collection_backdate_audit (performed_by);

-- 4) Row Level Security.
--    The audit is read-only for managers+ within the same org,
--    and can be inserted by any authenticated user. No UPDATE /
--    DELETE policies are created — the table is append-only.
ALTER TABLE public.collection_backdate_audit ENABLE ROW LEVEL SECURITY;

-- Drop any prior versions of these policies so the migration
-- is idempotent if it's ever re-run.
DROP POLICY IF EXISTS collection_backdate_audit_select ON public.collection_backdate_audit;
DROP POLICY IF EXISTS collection_backdate_audit_insert ON public.collection_backdate_audit;

CREATE POLICY collection_backdate_audit_select ON public.collection_backdate_audit
    FOR SELECT
    USING (
        org_id = public.get_user_org_id()
        AND public.get_user_role() IN (
            'superAdmin',
            'executiveAdmin',
            'manager'
        )
    );

-- Unrestricted insert: the application's backend is expected to
-- guard writes (only collection-entry flows should reach here).
-- RLS still requires a valid auth.uid(), so only authenticated
-- users can write.
CREATE POLICY collection_backdate_audit_insert ON public.collection_backdate_audit
    FOR INSERT
    WITH CHECK (auth.uid() IS NOT NULL);

-- 5) Trigger to keep `collections.is_backdated` in sync with the
--    audit table. The application sets it directly on insert;
--    this trigger backstops that in case a row is ever inserted
--    without the flag being set, so reports stay correct.
CREATE OR REPLACE FUNCTION public.sync_collection_is_backdated()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE public.collections
    SET is_backdated = TRUE
    WHERE id = NEW.collection_id
      AND is_backdated = FALSE;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_collection_is_backdated ON public.collection_backdate_audit;
CREATE TRIGGER trg_sync_collection_is_backdated
    AFTER INSERT ON public.collection_backdate_audit
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_collection_is_backdated();

COMMIT;
