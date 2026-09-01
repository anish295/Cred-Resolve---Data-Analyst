-- ==========================================================================
-- LAYER 2: CLEAN — Call Dispositions
-- Purpose : Use the standardised disposition_std column from staging.
--           Ensures PROMISE_TO_PAY (legacy) and PTP (v1/v2) are counted
--           as the same event across the full time series.
-- ==========================================================================

CREATE OR REPLACE TABLE clean_dispositions AS
SELECT
    disposition_id,
    account_id,
    borrower_id,
    event_at,
    call_id,
    agent_id,
    disposition_std      AS disposition_code,   -- standardised
    disposition_version,
    flag_legacy_ptp,
    'std_promise_to_pay_to_ptp' AS cleaning_rule
FROM stg_call_dispositions
WHERE NOT flag_bad_ts;

SELECT
    disposition_code, COUNT(*) AS cnt
FROM clean_dispositions
GROUP BY disposition_code
ORDER BY cnt DESC;
