-- ==========================================================================
-- LAYER 5: ANALYTICAL — Forensics C: Timezone Problems
-- Question: Are calls being classified into the wrong hour/day?
-- Method  : Compare call_hour_local vs call_hour_utc_corrected distribution.
--           Count calls that shift in/out of working hours (9am-8pm) and
--           do-not-call windows (<9am, >9pm).
-- ==========================================================================

SELECT
    timezone,
    COUNT(*)                                AS total_calls,
    SUM(CASE WHEN call_hour_local < 9  THEN 1 ELSE 0 END) AS calls_before_9am_raw,
    SUM(CASE WHEN call_hour_utc_corrected < 9  THEN 1 ELSE 0 END) AS calls_before_9am_corrected,
    SUM(CASE WHEN call_hour_local > 21 THEN 1 ELSE 0 END) AS calls_after_9pm_raw,
    SUM(CASE WHEN call_hour_utc_corrected > 21 THEN 1 ELSE 0 END) AS calls_after_9pm_corrected,
    -- Calls that MOVE into DNC window after correction (compliance risk)
    SUM(CASE WHEN call_hour_local >= 9
              AND call_hour_utc_corrected < 9  THEN 1 ELSE 0 END) AS newly_in_dnc_early,
    SUM(CASE WHEN call_hour_local <= 21
              AND call_hour_utc_corrected > 21 THEN 1 ELSE 0 END) AS newly_in_dnc_late
FROM clean_calls
GROUP BY timezone
ORDER BY total_calls DESC;

-- Hour-by-hour shift
SELECT
    call_hour_local            AS hour_raw,
    call_hour_utc_corrected    AS hour_corrected,
    COUNT(*)                   AS call_count
FROM clean_calls
GROUP BY call_hour_local, call_hour_utc_corrected
ORDER BY call_hour_local, call_hour_utc_corrected;
