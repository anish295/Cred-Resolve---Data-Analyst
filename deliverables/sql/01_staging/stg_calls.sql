-- ==========================================================================
-- LAYER 1: STAGING — Calls
-- Purpose : Type casting + timezone offset annotation.
--           NOTE: event_at is stored as local time per the 'timezone' column.
--           We annotate the UTC offset here; conversion happens in clean layer.
-- ==========================================================================

CREATE OR REPLACE VIEW stg_calls AS
WITH typed AS (
    SELECT
        call_id,
        account_id,
        borrower_id,
        TRY_CAST(event_at  AS TIMESTAMP) AS event_at_local,
        agent_id,
        campaign_id,
        UPPER(TRIM(direction))           AS direction,
        vendor_id,
        UPPER(TRIM(call_status))         AS call_status,
        TRY_CAST(duration_sec AS INTEGER) AS duration_sec,
        timezone
    FROM raw_calls
)
SELECT
    *,
    -- Map timezone string to UTC offset hours
    CASE timezone
        WHEN 'UTC'          THEN 0.0
        WHEN 'Asia/Kolkata' THEN 5.5
        WHEN 'Asia/Dubai'   THEN 4.0
        ELSE NULL
    END AS utc_offset_hours,
    -- Quality flags
    CASE WHEN call_id    IS NULL THEN true ELSE false END AS flag_null_call_id,
    CASE WHEN event_at_local IS NULL THEN true ELSE false END AS flag_bad_timestamp,
    CASE WHEN timezone IS NULL
          OR timezone NOT IN ('UTC','Asia/Kolkata','Asia/Dubai')
         THEN true ELSE false END AS flag_unknown_tz,
    CASE WHEN duration_sec < 0 THEN true ELSE false END AS flag_negative_duration
FROM typed;

SELECT
    COUNT(*)                             AS total_rows,
    SUM(flag_bad_timestamp::INT)         AS bad_timestamps,
    SUM(flag_unknown_tz::INT)            AS unknown_timezones,
    SUM(flag_negative_duration::INT)     AS negative_durations,
    COUNT(DISTINCT timezone)             AS distinct_timezones
FROM stg_calls;
