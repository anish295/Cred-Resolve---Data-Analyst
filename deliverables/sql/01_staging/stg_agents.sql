-- ==========================================================================
-- LAYER 1: STAGING — Agents
-- Purpose : Type cast, flag rows where agent_id appears multiple times
--           for the same employee_code (identity fragmentation).
-- ==========================================================================

CREATE OR REPLACE VIEW stg_agents AS
WITH typed AS (
    SELECT
        agent_id,
        employee_code,
        agent_name,
        vendor_id,
        team,
        UPPER(TRIM(status))              AS status,
        TRY_CAST(joined_at  AS TIMESTAMP) AS joined_at,
        TRY_CAST(updated_at AS TIMESTAMP) AS updated_at
    FROM raw_agents
),
id_counts AS (
    SELECT employee_code, COUNT(DISTINCT agent_id) AS agent_id_count
    FROM typed GROUP BY employee_code
)
SELECT
    t.*,
    ic.agent_id_count,
    CASE WHEN ic.agent_id_count > 1 THEN true ELSE false END AS flag_multi_id
FROM typed t
JOIN id_counts ic USING (employee_code);

-- Identity problem summary
SELECT
    COUNT(*)                        AS total_rows,
    COUNT(DISTINCT employee_code)   AS unique_employees,
    COUNT(DISTINCT agent_id)        AS unique_agent_ids,
    SUM(flag_multi_id::INT)         AS rows_with_multi_id,
    MAX(agent_id_count)             AS max_ids_per_employee
FROM stg_agents;
