-- ==========================================================================
-- LAYER 1: STAGING — Call Dispositions
-- Purpose : Type cast + flag mixed schema versions.
--           'PROMISE_TO_PAY' (legacy) and 'PTP' (v1/v2) are the same concept.
-- ==========================================================================

CREATE OR REPLACE VIEW stg_call_dispositions AS
SELECT
    disposition_id,
    account_id,
    borrower_id,
    TRY_CAST(event_at AS TIMESTAMP) AS event_at,
    call_id,
    agent_id,
    disposition_code,
    disposition_version,
    -- Standardise PTP across schema versions
    CASE
        WHEN disposition_code = 'PROMISE_TO_PAY' THEN 'PTP'
        ELSE disposition_code
    END AS disposition_std,
    -- Flag legacy records that need remapping
    CASE WHEN disposition_code = 'PROMISE_TO_PAY' THEN true ELSE false END AS flag_legacy_ptp,
    CASE WHEN TRY_CAST(event_at AS TIMESTAMP) IS NULL THEN true ELSE false END AS flag_bad_ts
FROM raw_call_dispositions;

-- Schema version usage
SELECT
    disposition_version,
    COUNT(*)                AS total_rows,
    SUM(flag_legacy_ptp::INT) AS legacy_ptp_rows
FROM stg_call_dispositions
GROUP BY disposition_version
ORDER BY disposition_version;
