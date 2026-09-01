-- ==========================================================================
-- LAYER 5: ANALYTICAL — Investment Recommendation: Where to invest Rs 10 Cr
-- Computes key signals for each investment option from the golden dataset.
-- ==========================================================================

-- Baseline: average monthly recovery (exclude partial last month)
WITH baseline AS (
    SELECT AVG(total_recovered_inr) AS baseline_monthly
    FROM metric_monthly_recovery
    WHERE month < (SELECT MAX(month) FROM metric_monthly_recovery)
),

-- Channel signals
channel_signals AS (
    SELECT * FROM metric_channel_conversion
),

-- Agent efficiency signal
agent_signal AS (
    SELECT
        SUM(hours_worked)                                         AS total_hours,
        SUM(amount_recovered)                                     AS total_recovered,
        ROUND(SUM(amount_recovered)/NULLIF(SUM(hours_worked),0), 0) AS recovery_per_hr
    FROM (SELECT * FROM metric_agent_efficiency) _eff
),

-- PTP signal
ptp_signal AS (
    SELECT
        AVG(ptp_kept_rate_pct) AS avg_ptp_kept_rate,
        AVG(contact_rate_pct)  AS avg_contact_rate
    FROM metric_rpc_ptp
    JOIN metric_contact_rate USING (month)
)

SELECT
    b.baseline_monthly / 1e7                AS baseline_monthly_cr,
    a.recovery_per_hr                       AS recovery_per_agent_hr,
    p.avg_contact_rate                      AS contact_rate_pct,
    p.avg_ptp_kept_rate                     AS ptp_kept_rate_pct,
    -- Investment options ROI at 12 months
    -- Formula: (uplift * baseline * 12 - cost) / cost * 100
    ROUND((0.03 * b.baseline_monthly * 12 - 2e7) / 2e7 * 100, 0)   AS telephony_roi_12m_pct,
    ROUND((0.08 * b.baseline_monthly * 12 - 6e7) / 6e7 * 100, 0)   AS agents_roi_12m_pct,
    ROUND((0.12 * b.baseline_monthly * 12 - 3.5e7) / 3.5e7 * 100, 0) AS ai_voice_roi_12m_pct,
    ROUND((0.10 * b.baseline_monthly * 12 - 1.5e7) / 1.5e7 * 100, 0) AS targeting_roi_12m_pct,
    ROUND((0.06 * b.baseline_monthly * 12 - 2e7) / 2e7 * 100, 0)   AS whatsapp_roi_12m_pct,
    ROUND((0.07 * b.baseline_monthly * 12 - 5e7) / 5e7 * 100, 0)   AS field_roi_12m_pct
FROM baseline b, agent_signal a, ptp_signal p;
