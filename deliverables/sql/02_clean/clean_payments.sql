-- ==========================================================================
-- LAYER 2: CLEAN — Payments
-- Purpose : Deduplicate on payment_reference.
--           Decision: keep the first SUCCESS record per reference;
--           if no SUCCESS exists, keep the earliest record.
--           Rationale: duplicate references are retries or ingestion dupes.
--           Keeping SUCCESS prevents undercounting real recoveries.
-- ==========================================================================

CREATE OR REPLACE TABLE clean_payments AS
WITH staged AS (
    SELECT *,
        CASE payment_status
            WHEN 'SUCCESS'  THEN 0
            WHEN 'PENDING'  THEN 1
            WHEN 'FAILED'   THEN 2
            WHEN 'REVERSED' THEN 3
            ELSE 9
        END AS status_priority
    FROM stg_payments
    WHERE NOT flag_null_payment_id
      AND NOT flag_bad_timestamp
      AND NOT flag_bad_amount
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY payment_reference
            ORDER BY status_priority ASC, event_at ASC
        ) AS rn
    FROM staged
)
SELECT
    payment_id, account_id, borrower_id, event_at,
    payment_reference, amount, payment_status, payment_method, provider_id,
    -- Lineage
    'dedup_on_payment_reference' AS cleaning_rule
FROM ranked
WHERE rn = 1;

-- Cleaning impact
SELECT
    (SELECT COUNT(*) FROM raw_payments)   AS raw_rows,
    (SELECT COUNT(*) FROM clean_payments) AS clean_rows,
    (SELECT COUNT(*) FROM raw_payments)
    - (SELECT COUNT(*) FROM clean_payments) AS rows_removed;
