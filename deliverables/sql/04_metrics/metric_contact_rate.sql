-- ==========================================================================
-- LAYER 4: METRICS — Contact Rate (two complementary definitions)
--
-- Definition A (Account Contact Rate):
--   Unique accounts with >= 1 ANSWERED call (duration > 30s)
--   divided by unique accounts targeted in the same calendar month.
--   Verified value: ~40.9% monthly average (Jan–Jul 2026).
--   Why > 30s: Removes auto-answer/IVR false positives.
--   Why targeted not called: 'called' denominator excludes never-dialled
--   accounts and creates selection bias.
--
-- Definition B (Call Connect Rate):
--   ANSWERED calls / total calls placed (call-level ratio).
--   Verified value: 19.9% (18,146 answered / 91,350 total).
--   This is the figure cited in the executive dashboard and channel analysis.
--   Use this to benchmark dialer efficiency and vendor performance.
--
-- IMPORTANT: Always state which definition is being used when reporting.
-- ==========================================================================

CREATE OR REPLACE VIEW metric_contact_rate AS
WITH monthly_targeted AS (
    SELECT
        strftime(TRY_CAST(target_date AS TIMESTAMP), '%Y-%m') AS month,
        COUNT(DISTINCT account_id) AS accounts_targeted
    FROM raw_daily_targeting
    GROUP BY 1
),
monthly_contacted AS (
    SELECT
        strftime(event_at, '%Y-%m') AS month,
        COUNT(DISTINCT account_id)  AS accounts_contacted
    FROM golden_calls
    WHERE call_status = 'ANSWERED'
      AND duration_sec > 30
    GROUP BY 1
),
-- Call connect rate (call-level)
call_connect AS (
    SELECT
        strftime(event_at, '%Y-%m') AS month,
        COUNT(*)                    AS total_calls,
        SUM(CASE WHEN call_status = 'ANSWERED' THEN 1 ELSE 0 END) AS answered_calls
    FROM golden_calls
    GROUP BY 1
)
SELECT
    t.month,
    t.accounts_targeted,
    COALESCE(c.accounts_contacted, 0)   AS accounts_contacted,
    ROUND(
        COALESCE(c.accounts_contacted, 0) * 100.0 / NULLIF(t.accounts_targeted, 0),
    2) AS account_contact_rate_pct,       -- Definition A: ~40.9% monthly avg
    cc.total_calls,
    cc.answered_calls,
    ROUND(cc.answered_calls * 100.0 / NULLIF(cc.total_calls, 0), 2) AS call_connect_rate_pct  -- Definition B: ~19.9% overall
FROM monthly_targeted t
LEFT JOIN monthly_contacted c  USING (month)
LEFT JOIN call_connect cc      USING (month)
ORDER BY t.month;

SELECT * FROM metric_contact_rate;
