-- ==========================================================================
-- LAYER 4: METRICS — Monthly Recovery
-- Definition : Total verified SUCCESS payments (golden, deduped)
--              per calendar month.
-- Why this definition: outstanding_amount is the true denominator,
--              not 'accounts targeted'. Rate = recovery / outstanding.
-- ==========================================================================

CREATE OR REPLACE VIEW metric_monthly_recovery AS
WITH monthly AS (
    SELECT
        payment_month_str                    AS month,
        SUM(amount)                          AS total_recovered,
        COUNT(*)                             AS payment_count,
        COUNT(DISTINCT account_id)           AS unique_accounts_paid,
        AVG(amount)                          AS avg_payment_amount
    FROM golden_payments
    GROUP BY payment_month_str
),
with_mom AS (
    SELECT
        month,
        total_recovered,
        payment_count,
        unique_accounts_paid,
        avg_payment_amount,
        LAG(total_recovered) OVER (ORDER BY month) AS prev_month_recovered,
        ROUND(
            (total_recovered - LAG(total_recovered) OVER (ORDER BY month))
            / NULLIF(LAG(total_recovered) OVER (ORDER BY month), 0) * 100,
        2) AS mom_pct_change
    FROM monthly
)
SELECT
    month,
    ROUND(total_recovered, 2)       AS total_recovered_inr,
    ROUND(total_recovered / 1e7, 2) AS total_recovered_cr,
    payment_count,
    unique_accounts_paid,
    ROUND(avg_payment_amount, 2)    AS avg_payment_inr,
    ROUND(mom_pct_change, 2)        AS mom_pct_change,
    -- Flag months with claimed 11% growth
    CASE WHEN mom_pct_change >= 11 THEN 'YES' ELSE 'NO' END AS meets_11pct_claim
FROM with_mom
ORDER BY month;

SELECT * FROM metric_monthly_recovery;
