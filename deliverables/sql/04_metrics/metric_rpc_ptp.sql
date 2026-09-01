-- ==========================================================================
-- LAYER 4: METRICS — RPC Rate, PTP Rate, PTP Kept Rate
-- Definitions:
--   RPC Rate      = calls with RPC disposition / ANSWERED calls (>30s)
--   PTP Rate      = unique accounts with PTP disposition / accounts with RPC
--   PTP Kept Rate = PTPs with status='KEPT' / all PTPs excl. PENDING
-- Why standardised PTP: PROMISE_TO_PAY (legacy) must be counted as PTP
--   or the rate appears to drop when schema migrates — a false signal.
-- ==========================================================================

-- RPC Dispositions (right party contact confirmed)
-- PTP and PAID and REFUSED and DISPUTE confirm borrower engagement
CREATE OR REPLACE VIEW metric_rpc_ptp AS
WITH answered AS (
    SELECT call_id, account_id
    FROM golden_calls
    WHERE call_status = 'ANSWERED' AND duration_sec > 30
),
rpc_calls AS (
    SELECT d.call_id, d.account_id,
        strftime(d.event_at, '%Y-%m') AS month
    FROM clean_dispositions d
    JOIN answered a USING (call_id)
    WHERE d.disposition_code IN ('PTP','PAID','REFUSED','DISPUTE','PTP_BROKEN','CALLBACK')
),
ptp_calls AS (
    SELECT DISTINCT account_id,
        strftime(event_at, '%Y-%m') AS month
    FROM clean_dispositions
    WHERE disposition_code = 'PTP'
),
ptp_stats AS (
    SELECT
        strftime(TRY_CAST(event_at AS TIMESTAMP), '%Y-%m') AS month,
        COUNT(*) AS total_ptps,
        SUM(CASE WHEN status = 'KEPT'     THEN 1 ELSE 0 END) AS ptps_kept,
        SUM(CASE WHEN status = 'BROKEN'   THEN 1 ELSE 0 END) AS ptps_broken,
        SUM(CASE WHEN status = 'CANCELLED'THEN 1 ELSE 0 END) AS ptps_cancelled,
        SUM(CASE WHEN status = 'PENDING'  THEN 1 ELSE 0 END) AS ptps_pending
    FROM raw_promises_to_pay
    GROUP BY 1
),
monthly_answered AS (
    SELECT strftime(event_at, '%Y-%m') AS month, COUNT(*) AS total_answered
    FROM golden_calls WHERE call_status='ANSWERED' AND duration_sec>30
    GROUP BY 1
)
SELECT
    ma.month,
    ma.total_answered,
    COUNT(DISTINCT rc.call_id)                      AS rpc_calls,
    COUNT(DISTINCT pc.account_id)                   AS accounts_with_ptp,
    ROUND(COUNT(DISTINCT rc.call_id) * 100.0 / NULLIF(ma.total_answered,0),2) AS rpc_rate_pct,
    ROUND(COUNT(DISTINCT pc.account_id)*100.0
          / NULLIF(COUNT(DISTINCT rc.account_id),0),2)                         AS ptp_rate_pct,
    ps.ptps_kept,
    ps.total_ptps - ps.ptps_pending AS ptps_eligible,
    ROUND(ps.ptps_kept * 100.0
          / NULLIF(ps.total_ptps - ps.ptps_pending,0),2)                      AS ptp_kept_rate_pct
FROM monthly_answered ma
LEFT JOIN rpc_calls rc USING (month)
LEFT JOIN ptp_calls pc USING (month)
LEFT JOIN ptp_stats ps USING (month)
GROUP BY ma.month, ma.total_answered, ps.ptps_kept, ps.total_ptps, ps.ptps_pending
ORDER BY ma.month;

SELECT * FROM metric_rpc_ptp;
