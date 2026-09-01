-- ==========================================================================
-- LAYER 5: ANALYTICAL — Forensics B: Attribution Errors
-- Question: Are payments being credited to calls that happened AFTER payment?
-- Method  : Join payments to calls on account_id; flag calls timestamped
--           after the payment event. These have no causal link to payment.
-- ==========================================================================

WITH payment_call_pairs AS (
    SELECT
        gp.payment_id,
        gp.account_id,
        gp.event_at                            AS payment_at,
        gp.amount,
        gc.call_id,
        gc.event_at                            AS call_at,
        gc.campaign_id,
        DATEDIFF('hour', gc.event_at, gp.event_at) AS hours_before_payment
    FROM golden_payments gp
    JOIN golden_calls gc ON gp.account_id = gc.account_id
),
flagged AS (
    SELECT *,
        CASE WHEN call_at > payment_at THEN 'POST_PAYMENT_CALL'
             WHEN hours_before_payment <= 168 THEN 'WITHIN_7D'
             ELSE 'OLDER_THAN_7D'
        END AS attribution_flag
    FROM payment_call_pairs
)
SELECT
    attribution_flag,
    COUNT(DISTINCT payment_id)              AS payments_affected,
    ROUND(SUM(amount)/1e7, 2)              AS amount_cr,
    ROUND(COUNT(DISTINCT payment_id)*100.0
          / (SELECT COUNT(*) FROM golden_payments), 2) AS pct_of_all_payments
FROM flagged
GROUP BY attribution_flag
ORDER BY attribution_flag;
