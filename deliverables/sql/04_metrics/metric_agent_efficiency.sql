-- ==========================================================================
-- LAYER 4: METRICS - Agent Efficiency
-- Definitions:
--   Recovery per agent-hour = INR recovered / agent-hours logged
-- ==========================================================================

CREATE OR REPLACE VIEW metric_agent_efficiency AS
WITH agent_hours AS (
    SELECT
        canonical_employee_code,
        session_month AS month,
        SUM(hours_worked) AS hours_worked
    FROM golden_agent_sessions
    GROUP BY canonical_employee_code, session_month
),
-- Last answered call per payment (correct attribution)
last_call_per_payment AS (
    SELECT
        gp.payment_id,
        gp.event_at AS payment_at,
        gp.amount,
        gc.canonical_employee_code,
        strftime(gp.event_at, '%Y-%m') AS month,
        ROW_NUMBER() OVER (
            PARTITION BY gp.payment_id
            ORDER BY gc.event_at DESC
        ) AS rn
    FROM golden_payments gp
    JOIN golden_calls gc
      ON gp.account_id = gc.account_id
     AND gc.event_at <= gp.event_at
     AND gc.call_status = 'ANSWERED'
),
agent_recovery AS (
    SELECT
        canonical_employee_code,
        month,
        SUM(amount) AS amount_recovered
    FROM last_call_per_payment
    WHERE rn = 1
    GROUP BY canonical_employee_code, month
)
SELECT
    h.month,
    h.canonical_employee_code,
    ROUND(h.hours_worked, 2)                                              AS hours_worked,
    ROUND(COALESCE(r.amount_recovered, 0), 2)                            AS amount_recovered,
    ROUND(COALESCE(r.amount_recovered, 0) / NULLIF(h.hours_worked, 0), 0) AS recovery_per_hour
FROM agent_hours h
LEFT JOIN agent_recovery r USING (canonical_employee_code, month)
ORDER BY h.month, recovery_per_hour DESC NULLS LAST;

-- Monthly aggregate
SELECT
    month,
    COUNT(DISTINCT canonical_employee_code) AS active_agents,
    ROUND(SUM(hours_worked), 0)              AS total_agent_hours,
    ROUND(SUM(amount_recovered) / 1e7, 2)   AS total_recovered_cr,
    ROUND(SUM(amount_recovered) / NULLIF(SUM(hours_worked), 0), 0) AS recovery_per_agent_hour
FROM metric_agent_efficiency
GROUP BY month
ORDER BY month;
