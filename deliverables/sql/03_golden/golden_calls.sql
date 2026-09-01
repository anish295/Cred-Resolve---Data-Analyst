-- ==========================================================================
-- LAYER 3: GOLDEN — Calls
-- Purpose : Clean calls joined to account and canonical agent context.
-- Primary Key: call_id
-- ==========================================================================

CREATE OR REPLACE TABLE golden_calls AS
SELECT
    c.call_id,
    c.account_id,
    c.borrower_id,
    c.event_at_local            AS event_at,
    c.call_date_local           AS call_date,
    c.call_hour_local,
    c.call_hour_utc_corrected,
    c.agent_id,
    -- Map to canonical agent
    ca.employee_code            AS canonical_employee_code,
    ca.team                     AS agent_team,
    ca.vendor_id                AS agent_vendor,
    -- Tenure in months at time of call
    DATEDIFF('month', ca.joined_at, c.event_at_local) AS agent_tenure_months,
    c.campaign_id,
    c.direction,
    c.vendor_id,
    c.call_status,
    c.duration_sec,
    c.timezone,
    -- Derived
    CASE WHEN c.call_status = 'ANSWERED' AND c.duration_sec > 30 THEN true ELSE false END AS is_rpc_eligible,
    -- Account context
    a.loan_type,
    a.dpd,
    a.risk_segment
FROM clean_calls c
LEFT JOIN clean_agents ca ON c.agent_id = ca.canonical_agent_id
LEFT JOIN raw_accounts a  ON c.account_id = a.account_id;

SELECT COUNT(*) AS total_calls,
    SUM(is_rpc_eligible::INT) AS rpc_eligible_calls,
    COUNT(DISTINCT canonical_employee_code) AS distinct_agents
FROM golden_calls;
