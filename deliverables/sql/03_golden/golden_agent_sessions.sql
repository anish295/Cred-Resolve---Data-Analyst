-- ==========================================================================
-- LAYER 3: GOLDEN — Agent Sessions
-- Purpose : Compute worked hours per session. Cap at 24h per session to
--           remove data entry errors. Join to canonical agent.
-- Primary Key: session_id
-- ==========================================================================

CREATE OR REPLACE TABLE golden_agent_sessions AS
SELECT
    s.session_id,
    s.agent_id,
    ca.employee_code        AS canonical_employee_code,
    ca.team,
    TRY_CAST(s.login_at  AS TIMESTAMP)  AS login_at,
    TRY_CAST(s.logout_at AS TIMESTAMP)  AS logout_at,
    s.channel,
    s.timezone,
    -- Hours worked; cap at 24 to remove outliers
    LEAST(
        DATEDIFF('minute',
            TRY_CAST(s.login_at AS TIMESTAMP),
            TRY_CAST(s.logout_at AS TIMESTAMP)
        ) / 60.0,
        24.0
    ) AS hours_worked,
    strftime(TRY_CAST(s.login_at AS TIMESTAMP), '%Y-%m') AS session_month
FROM raw_agent_sessions s
LEFT JOIN clean_agents ca ON s.agent_id = ca.canonical_agent_id
WHERE TRY_CAST(s.login_at  AS TIMESTAMP) IS NOT NULL
  AND TRY_CAST(s.logout_at AS TIMESTAMP) IS NOT NULL
  AND TRY_CAST(s.logout_at AS TIMESTAMP) > TRY_CAST(s.login_at AS TIMESTAMP);

SELECT
    COUNT(*)            AS sessions,
    SUM(hours_worked)   AS total_agent_hours,
    AVG(hours_worked)   AS avg_session_hours,
    COUNT(DISTINCT canonical_employee_code) AS unique_agents
FROM golden_agent_sessions;
