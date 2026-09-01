-- ==========================================================================
-- LAYER 4: METRICS — Channel Conversion Rate
-- Definition : Unique accounts paying within 7 days of a channel touchpoint,
--              divided by unique accounts touched by that channel.
-- Why 7 days: standard attribution window in collections; balances recency
--             and avoiding over-attribution to a single channel.
-- Why payment MUST be after touchpoint: a call after payment has no causal
--             link to the payment (see forensics: attribution errors).
-- ==========================================================================

-- Attribution window in days
-- To change: replace 7 with desired value
CREATE OR REPLACE VIEW metric_channel_conversion AS
WITH touchpoints AS (
    -- CALLS
    SELECT 'CALL'  AS channel, account_id, event_at AS touched_at
    FROM golden_calls WHERE call_status = 'ANSWERED'
    UNION ALL
    -- WHATSAPP
    SELECT 'WHATSAPP', account_id,
        TRY_CAST(event_at AS TIMESTAMP)
    FROM raw_whatsapp_events WHERE event_type = 'SENT'
    UNION ALL
    -- SMS
    SELECT 'SMS', account_id,
        TRY_CAST(event_at AS TIMESTAMP)
    FROM raw_sms_events WHERE event_type = 'SENT'
    UNION ALL
    -- FIELD VISITS
    SELECT 'FIELD', account_id,
        TRY_CAST(event_at AS TIMESTAMP)
    FROM raw_field_visits
),
converted AS (
    SELECT
        t.channel,
        t.account_id,
        t.touched_at,
        p.event_at AS payment_at,
        p.amount
    FROM touchpoints t
    JOIN golden_payments p ON t.account_id = p.account_id
    -- Payment must come AFTER touchpoint and within 7 days
    WHERE p.event_at > t.touched_at
      AND DATEDIFF('day', t.touched_at, p.event_at) <= 7
),
channel_totals AS (
    SELECT channel,
        COUNT(DISTINCT account_id) AS accounts_touched
    FROM touchpoints GROUP BY channel
),
channel_converted AS (
    SELECT channel,
        COUNT(DISTINCT account_id) AS accounts_converted,
        SUM(amount)                AS amount_attributed
    FROM converted GROUP BY channel
)
SELECT
    ct.channel,
    ct.accounts_touched,
    COALESCE(cc.accounts_converted, 0)  AS accounts_converted,
    ROUND(COALESCE(cc.amount_attributed,0)/1e7, 2) AS attributed_recovery_cr,
    ROUND(
        COALESCE(cc.accounts_converted,0) * 100.0 / NULLIF(ct.accounts_touched,0),
    2) AS conversion_rate_pct
FROM channel_totals ct
LEFT JOIN channel_converted cc USING (channel)
ORDER BY conversion_rate_pct DESC NULLS LAST;

SELECT * FROM metric_channel_conversion;
