-- ==========================================================================
-- LAYER 5: ANALYTICAL — Forensics A: Duplicate Payments
-- Question: Are retries or ingestion issues inflating recovery?
-- Method  : Group by payment_reference, flag references with >1 row.
--           Compute the INR inflation from counting dupes as real payments.
-- ==========================================================================

-- 1. Find all duplicate references
WITH ref_counts AS (
    SELECT
        payment_reference,
        COUNT(*)                                        AS occurrence_count,
        COUNT(DISTINCT payment_id)                      AS distinct_payment_ids,
        SUM(CASE WHEN payment_status='SUCCESS' THEN 1 ELSE 0 END) AS success_count,
        SUM(CASE WHEN payment_status='SUCCESS' THEN amount ELSE 0 END) AS success_amount
    FROM raw_payments
    GROUP BY payment_reference
)
SELECT
    (SELECT COUNT(*) FROM raw_payments)          AS raw_total_rows,
    (SELECT COUNT(*) FROM clean_payments)        AS clean_total_rows,
    (SELECT COUNT(*) FROM raw_payments)
     - (SELECT COUNT(*) FROM clean_payments)     AS rows_removed,
    COUNT(*)                                     AS total_references,
    SUM(CASE WHEN occurrence_count > 1 THEN 1 ELSE 0 END) AS duplicate_references,
    SUM(CASE WHEN occurrence_count > 1 THEN occurrence_count ELSE 0 END) AS rows_in_duplicates,
    -- Financial impact
    (SELECT SUM(amount) FROM raw_payments WHERE payment_status='SUCCESS')
     - (SELECT SUM(amount) FROM clean_payments WHERE payment_status='SUCCESS')
        AS inr_inflation_from_dupes,
    ROUND(
        ((SELECT SUM(amount) FROM raw_payments WHERE payment_status='SUCCESS')
         - (SELECT SUM(amount) FROM clean_payments WHERE payment_status='SUCCESS'))
        / NULLIF((SELECT SUM(amount) FROM raw_payments WHERE payment_status='SUCCESS'),0) * 100,
    2) AS inflation_pct
FROM ref_counts;

-- 2. Sample duplicate references
SELECT payment_reference, COUNT(*) AS occurrences,
    STRING_AGG(DISTINCT payment_status, ', ') AS statuses,
    SUM(amount) AS total_amount_if_all_counted
FROM raw_payments
GROUP BY payment_reference
HAVING COUNT(*) > 1
ORDER BY occurrences DESC
LIMIT 20;
