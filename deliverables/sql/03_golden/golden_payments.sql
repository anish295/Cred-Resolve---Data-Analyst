-- ==========================================================================
-- LAYER 3: GOLDEN — Payments
-- Purpose : Final analytical payments table.
--           Only SUCCESS payments. Joined to account metadata.
--           This is the SINGLE SOURCE OF TRUTH for all recovery metrics.
-- Primary Key: payment_id (unique after dedup)
-- ==========================================================================

CREATE OR REPLACE TABLE golden_payments AS
SELECT
    p.payment_id,
    p.account_id,
    p.borrower_id,
    p.event_at,
    DATE_TRUNC('month', p.event_at)             AS payment_month,
    strftime(p.event_at, '%Y-%m')               AS payment_month_str,
    p.payment_reference,
    p.amount,
    p.payment_method,
    p.provider_id,
    -- Account context (join key: account_id)
    a.loan_type,
    a.dpd,
    CASE
        WHEN a.dpd BETWEEN 0  AND 30  THEN '0-30'
        WHEN a.dpd BETWEEN 31 AND 60  THEN '31-60'
        WHEN a.dpd BETWEEN 61 AND 90  THEN '61-90'
        WHEN a.dpd BETWEEN 91 AND 180 THEN '91-180'
        ELSE '180+'
    END AS dpd_bucket,
    a.risk_segment,
    a.outstanding_amount,
    a.timezone AS account_timezone,
    a.schema_version
FROM clean_payments p
LEFT JOIN raw_accounts a USING (account_id)
WHERE p.payment_status = 'SUCCESS';

SELECT
    COUNT(*)                                AS total_payments,
    SUM(amount)                             AS total_recovered,
    ROUND(SUM(amount)/1e7, 2)               AS total_recovered_cr,
    COUNT(DISTINCT account_id)              AS unique_accounts,
    MIN(event_at)::DATE                     AS earliest_payment,
    MAX(event_at)::DATE                     AS latest_payment
FROM golden_payments;
