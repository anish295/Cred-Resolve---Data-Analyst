-- ==========================================================================
-- LAYER 3: GOLDEN — Account Monthly Snapshot
-- Purpose : Reconstruct the active account population at end of each month.
--           Used as the DENOMINATOR for recovery rate calculations.
--           This prevents survivorship bias from inflating the rate.
-- ==========================================================================

CREATE OR REPLACE TABLE golden_account_snapshot AS
WITH history AS (
    SELECT
        account_id,
        status,
        TRY_CAST(event_at  AS TIMESTAMP) AS event_at,
        strftime(TRY_CAST(event_at AS TIMESTAMP), '%Y-%m') AS snap_month
    FROM raw_account_status_history
    WHERE TRY_CAST(event_at AS TIMESTAMP) IS NOT NULL
),
-- Last known status per account per month
monthly_status AS (
    SELECT DISTINCT ON (account_id, snap_month)
        account_id,
        snap_month,
        status AS end_of_month_status,
        event_at AS status_as_of
    FROM history
    ORDER BY account_id, snap_month, event_at DESC
)
SELECT
    ms.*,
    a.loan_type,
    a.dpd,
    a.risk_segment,
    a.outstanding_amount
FROM monthly_status ms
LEFT JOIN raw_accounts a USING (account_id);

-- Denominator trend
SELECT
    snap_month,
    SUM(CASE WHEN end_of_month_status = 'ACTIVE' THEN 1 ELSE 0 END)           AS active_accounts,
    SUM(CASE WHEN end_of_month_status IN ('CLOSED','SETTLED','WRITTEN_OFF')
             THEN 1 ELSE 0 END)                                                AS closed_accounts
FROM golden_account_snapshot
GROUP BY snap_month
ORDER BY snap_month;
