-- ==========================================================================
-- LAYER 2: CLEAN — Calls
-- Purpose : Remove full-row duplicates and compute TZ-corrected hour.
--           event_at remains as local time; we add a UTC-normalised column.
-- ==========================================================================

CREATE OR REPLACE TABLE clean_calls AS
WITH deduped AS (
    SELECT DISTINCT
        call_id, account_id, borrower_id, event_at_local, agent_id,
        campaign_id, direction, vendor_id, call_status, duration_sec,
        timezone, utc_offset_hours
    FROM stg_calls
    WHERE NOT flag_null_call_id
      AND NOT flag_bad_timestamp
),
tz_corrected AS (
    SELECT *,
        -- Hour in local time
        EXTRACT(HOUR FROM event_at_local) AS call_hour_local,
        -- UTC-corrected hour (for cross-timezone comparisons)
        CAST(
            (EXTRACT(HOUR FROM event_at_local) + utc_offset_hours) % 24
        AS INTEGER) AS call_hour_utc_corrected,
        -- Date in local time
        CAST(event_at_local AS DATE) AS call_date_local
    FROM deduped
)
SELECT *, 'dedup_fullrow_tz_annotated' AS cleaning_rule
FROM tz_corrected;

SELECT
    (SELECT COUNT(*) FROM raw_calls)   AS raw_rows,
    (SELECT COUNT(*) FROM clean_calls) AS clean_rows,
    COUNT(DISTINCT timezone)           AS timezones_present
FROM clean_calls;
