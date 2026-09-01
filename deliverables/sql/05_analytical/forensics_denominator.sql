-- ==========================================================================
-- LAYER 5: ANALYTICAL — Forensics G: Denominator Manipulation
-- Question: Are accounts disappearing from the population used to calculate
--           conversion rate, making the rate look better than it is?
-- Method  : Track active account count month-by-month.
--           Compute recovery RATE with stable vs shrinking denominator.
-- ==========================================================================

-- 1. Account population trend
SELECT
    snap_month,
    SUM(CASE WHEN end_of_month_status = 'ACTIVE' THEN 1 ELSE 0 END)       AS active_eom,
    SUM(CASE WHEN end_of_month_status IN ('CLOSED','SETTLED','WRITTEN_OFF')
             THEN 1 ELSE 0 END)                                            AS closed_eom,
    COUNT(*)                                                               AS total_accounts
FROM golden_account_snapshot
GROUP BY snap_month
ORDER BY snap_month;

-- 2. Recovery rate: using stable (total) vs shrinking (active-only) denominator
WITH monthly_outstanding AS (
    SELECT
        snap_month AS month,
        SUM(outstanding_amount) FILTER (WHERE end_of_month_status = 'ACTIVE') AS active_outstanding,
        SUM(outstanding_amount)                                                 AS total_outstanding
    FROM golden_account_snapshot
    GROUP BY snap_month
),
monthly_recovered AS (
    SELECT payment_month_str AS month, SUM(amount) AS recovered
    FROM golden_payments
    GROUP BY payment_month_str
)
SELECT
    r.month,
    ROUND(r.recovered / 1e7, 2)                                              AS recovered_cr,
    ROUND(r.recovered / NULLIF(o.active_outstanding,  0) * 100, 2)          AS rate_active_denom,
    ROUND(r.recovered / NULLIF(o.total_outstanding,   0) * 100, 2)          AS rate_total_denom,
    ROUND(
        (r.recovered / NULLIF(o.active_outstanding,0))
        - (r.recovered / NULLIF(o.total_outstanding,0)),
    4) * 100                                                                  AS rate_distortion_pp
FROM monthly_recovered r
JOIN monthly_outstanding o USING (month)
ORDER BY r.month;
