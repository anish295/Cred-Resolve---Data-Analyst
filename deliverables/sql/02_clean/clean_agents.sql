-- ==========================================================================
-- LAYER 2: CLEAN — Agents (Entity Resolution)
-- Purpose : Collapse multiple agent_id rows per employee to one canonical row.
--           Rule: keep the row with the most recent updated_at.
--           Rationale: one employee may have IDs across multiple vendor systems.
--           The canonical ID is used for all downstream productivity metrics.
-- ==========================================================================

CREATE OR REPLACE TABLE clean_agents AS
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY employee_code
            ORDER BY updated_at DESC NULLS LAST
        ) AS rn
    FROM stg_agents
)
SELECT
    agent_id AS canonical_agent_id,
    employee_code,
    agent_name,
    vendor_id,
    team,
    status,
    joined_at,
    updated_at,
    agent_id_count AS total_raw_ids,
    'entity_resolution_by_employee_code' AS cleaning_rule
FROM ranked
WHERE rn = 1;

SELECT
    (SELECT COUNT(*) FROM raw_agents)   AS raw_rows,
    (SELECT COUNT(*) FROM clean_agents) AS canonical_agents,
    (SELECT COUNT(DISTINCT employee_code) FROM raw_agents) AS unique_employees;
