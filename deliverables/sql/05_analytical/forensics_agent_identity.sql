-- ==========================================================================
-- LAYER 5: ANALYTICAL — Forensics E: Agent Identity Problems
-- Question: Does the same agent appear under multiple identifiers?
-- Method  : Group raw agents by employee_code; count distinct agent_ids.
--           Show the productivity impact of not resolving identities.
-- ==========================================================================

-- 1. Identity fragmentation summary
SELECT
    COUNT(*)                          AS total_raw_rows,
    COUNT(DISTINCT employee_code)     AS unique_employees,
    COUNT(DISTINCT agent_id)          AS unique_agent_ids,
    COUNT(DISTINCT agent_id)
     - COUNT(DISTINCT employee_code)  AS phantom_extra_ids,
    SUM(CASE WHEN agent_id_count > 1 THEN 1 ELSE 0 END) AS rows_with_multi_id,
    MAX(agent_id_count)               AS max_ids_per_employee
FROM stg_agents;

-- 2. Employees with the most ID fragmentation
SELECT employee_code, agent_name, agent_id_count, team, status
FROM stg_agents
WHERE agent_id_count > 1
QUALIFY ROW_NUMBER() OVER (PARTITION BY employee_code ORDER BY updated_at DESC) = 1
ORDER BY agent_id_count DESC
LIMIT 20;

-- 3. Productivity difference: raw vs canonical
WITH raw_productivity AS (
    SELECT
        agent_id,
        COUNT(DISTINCT call_id) AS calls_made
    FROM raw_calls
    GROUP BY agent_id
),
canonical_productivity AS (
    SELECT
        ca.employee_code,
        COUNT(DISTINCT gc.call_id) AS calls_made
    FROM golden_calls gc
    JOIN clean_agents ca ON gc.canonical_employee_code = ca.employee_code
    GROUP BY ca.employee_code
)
SELECT
    'raw (fragmented)'   AS view,
    ROUND(AVG(calls_made),1) AS avg_calls_per_agent,
    MIN(calls_made)          AS min_calls,
    MAX(calls_made)          AS max_calls
FROM raw_productivity
UNION ALL
SELECT
    'canonical (resolved)',
    ROUND(AVG(calls_made),1),
    MIN(calls_made),
    MAX(calls_made)
FROM canonical_productivity;
