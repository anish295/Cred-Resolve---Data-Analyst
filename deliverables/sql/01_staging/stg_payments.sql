-- ==========================================================================
-- LAYER 1: STAGING — Payments
-- Purpose : Cast columns to correct types, flag nulls, no dedup yet.
--           Every raw row is preserved with quality flags attached.
-- ==========================================================================

CREATE OR REPLACE VIEW stg_payments AS
WITH typed AS (
    SELECT
        payment_id,
        account_id,
        borrower_id,
        TRY_CAST(event_at        AS TIMESTAMP) AS event_at,
        payment_reference,
        TRY_CAST(amount          AS DOUBLE)    AS amount,
        UPPER(TRIM(payment_status))            AS payment_status,
        UPPER(TRIM(payment_method))            AS payment_method,
        provider_id
    FROM raw_payments
)
SELECT
    *,
    -- Quality flags
    CASE WHEN payment_id        IS NULL THEN true ELSE false END AS flag_null_payment_id,
    CASE WHEN payment_reference IS NULL THEN true ELSE false END AS flag_null_reference,
    CASE WHEN event_at          IS NULL THEN true ELSE false END AS flag_bad_timestamp,
    CASE WHEN amount IS NULL OR amount <= 0 THEN true ELSE false END AS flag_bad_amount,
    CASE WHEN payment_status NOT IN ('SUCCESS','FAILED','PENDING','REVERSED')
         THEN true ELSE false END AS flag_unknown_status
FROM typed;

-- Quality summary
SELECT
    COUNT(*)                               AS total_rows,
    SUM(flag_null_payment_id::INT)         AS null_payment_ids,
    SUM(flag_null_reference::INT)          AS null_references,
    SUM(flag_bad_timestamp::INT)           AS bad_timestamps,
    SUM(flag_bad_amount::INT)              AS bad_amounts,
    SUM(flag_unknown_status::INT)          AS unknown_statuses
FROM stg_payments;
