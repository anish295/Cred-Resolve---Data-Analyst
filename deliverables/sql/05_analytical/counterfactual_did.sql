-- ==========================================================================
-- LAYER 5: ANALYTICAL - Counterfactual: Difference-in-Differences
-- ==========================================================================

-- Step 1: Build treatment and control groups
CREATE OR REPLACE TABLE _did_groups AS
WITH treatment_accounts AS (
    SELECT DISTINCT dt.account_id, 'treatment' AS grp
    FROM raw_daily_targeting dt
    JOIN raw_campaigns c USING (campaign_id)
    WHERE c.strategy_version = 'v2'
),
control_accounts AS (
    SELECT DISTINCT dt.account_id, 'control' AS grp
    FROM raw_daily_targeting dt
    JOIN raw_campaigns c USING (campaign_id)
    WHERE c.strategy_version != 'v2'
      AND dt.account_id NOT IN (SELECT account_id FROM treatment_accounts)
)
SELECT * FROM treatment_accounts
UNION ALL SELECT * FROM control_accounts;

-- Step 2: Monthly recovery per group
CREATE OR REPLACE TABLE _did_monthly AS
SELECT
    g.grp,
    gp.payment_month_str   AS month,
    SUM(gp.amount)         AS recovered
FROM golden_payments gp
JOIN _did_groups g ON gp.account_id = g.account_id
GROUP BY g.grp, gp.payment_month_str
ORDER BY grp, month;

-- Step 3: Pivot
CREATE OR REPLACE TABLE _did_pivoted AS
SELECT
    month,
    SUM(CASE WHEN grp='treatment' THEN recovered ELSE 0 END) AS treatment_recovered,
    SUM(CASE WHEN grp='control'   THEN recovered ELSE 0 END) AS control_recovered
FROM _did_monthly
GROUP BY month
ORDER BY month;

-- Step 4: Label pre/post
CREATE OR REPLACE TABLE _did_labelled AS
WITH change_month AS (
    SELECT MIN(strftime(TRY_CAST(start_at AS TIMESTAMP), '%Y-%m')) AS change_mth
    FROM raw_campaigns WHERE strategy_version = 'v2'
)
SELECT p.*, cm.change_mth,
    CASE WHEN p.month < cm.change_mth THEN 'PRE' ELSE 'POST' END AS period
FROM _did_pivoted p, change_month cm;

-- Step 5: DiD estimate
WITH agg AS (
    SELECT period,
        AVG(treatment_recovered) AS avg_treat,
        AVG(control_recovered)   AS avg_ctrl
    FROM _did_labelled
    GROUP BY period
)
SELECT
    post.avg_treat - pre.avg_treat                                    AS treatment_change,
    post.avg_ctrl  - pre.avg_ctrl                                     AS control_change,
    (post.avg_treat - pre.avg_treat) - (post.avg_ctrl - pre.avg_ctrl) AS did_estimate,
    ROUND(((post.avg_treat - pre.avg_treat) - (post.avg_ctrl - pre.avg_ctrl))
          / NULLIF(pre.avg_treat, 0) * 100, 2)                        AS did_pct_of_pre
FROM agg pre, agg post
WHERE pre.period = 'PRE' AND post.period = 'POST';

-- Time series for plotting
SELECT month, treatment_recovered, control_recovered FROM _did_pivoted ORDER BY month;
