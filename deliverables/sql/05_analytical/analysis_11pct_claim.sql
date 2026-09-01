-- ==========================================================================
-- LAYER 5: ANALYTICAL — Is the 11% MoM Improvement Real?
-- This query builds our independent assessment of the claim.
-- ==========================================================================

WITH monthly AS (
    SELECT * FROM metric_monthly_recovery
),
-- Compare raw (inflated) vs clean (golden) recovery
raw_monthly AS (
    SELECT
        strftime(TRY_CAST(event_at AS TIMESTAMP), '%Y-%m') AS month,
        SUM(CASE WHEN payment_status='SUCCESS' THEN amount ELSE 0 END) AS raw_recovered
    FROM raw_payments
    GROUP BY 1
)
SELECT
    m.month,
    ROUND(rm.raw_recovered / 1e7, 2)           AS raw_recovered_cr,
    ROUND(m.total_recovered_cr, 2)             AS golden_recovered_cr,
    ROUND((rm.raw_recovered - m.total_recovered_inr)/1e7, 2) AS inflation_cr,
    m.mom_pct_change                           AS golden_mom_pct,
    m.meets_11pct_claim                        AS raw_claim_met,
    CASE
        WHEN m.mom_pct_change >= 11 THEN 'YES — genuine'
        WHEN rm.raw_recovered / 1e7 - m.total_recovered_cr > 0.5
             AND m.mom_pct_change >= 8
             THEN 'PARTIALLY — inflated by dupes'
        ELSE 'NO — overstated'
    END AS verdict
FROM monthly m
JOIN raw_monthly rm USING (month)
ORDER BY m.month;
