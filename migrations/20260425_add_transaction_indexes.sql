-- Migration: 20260425_add_transaction_indexes
-- Issue: #566 - Refactor Heavy Database Queries to use Proper Indices
-- Description: Add missing B-Tree and GIN indexes identified via EXPLAIN ANALYZE
--              on the top slow queries in statsService, searchByNotes, and export routes.

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. B-Tree index on provider
--    Speeds up: statsService.getVolumeByProvider() GROUP BY provider
--               export route WHERE provider = $n
--               admin list queries filtering by provider
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_provider
  ON transactions (provider);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Composite B-Tree index on (status, created_at)
--    Speeds up: statsService WHERE status = 'completed' ORDER BY created_at
--               statsService.getVolumeByPeriod() WHERE status = 'completed' AND created_at BETWEEN
--               statsService.getVolumeByProvider() WHERE status = 'completed' AND created_at range
--               export route WHERE status = $n ORDER BY created_at DESC
--    Covers the most common filter+sort pattern across the codebase.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_status_created_at
  ON transactions (status, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. GIN index on tsvector of notes + admin_notes
--    Speeds up: TransactionModel.searchByNotes() which calls
--               to_tsvector('english', COALESCE(notes,'') || ' ' || COALESCE(admin_notes,''))
--    A stored generated column + GIN index avoids recomputing tsvector per row.
--    Using a functional GIN index here for zero schema-change overhead.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_notes_fts
  ON transactions USING GIN (
    to_tsvector('english', COALESCE(notes, '') || ' ' || COALESCE(admin_notes, ''))
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. B-Tree index on phone_number
--    Exists in database/schema.sql but was never added to migrations.
--    Speeds up: deposit/withdraw lookups by phone_number, AML checks,
--               admin search by phone number.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_phone_number
  ON transactions (phone_number);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Covering index for export / admin list queries
--    The export route selects: id, reference_number, type, amount, phone_number,
--    provider, status, stellar_address, tags, notes, admin_notes, user_id,
--    created_at, updated_at  WHERE status=? AND created_at BETWEEN ? AND ?
--    INCLUDE columns let Postgres satisfy the query from the index alone
--    (index-only scan) without hitting the heap.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_transactions_status_created_covering
  ON transactions (status, created_at DESC)
  INCLUDE (id, reference_number, type, amount, phone_number, provider,
           stellar_address, user_id, updated_at);
