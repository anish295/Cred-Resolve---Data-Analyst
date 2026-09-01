-- ==========================================================================
-- LAYER 2: CLEAN — Borrowers
-- Purpose : Remove full-row duplicates.
-- ==========================================================================

CREATE OR REPLACE TABLE clean_borrowers AS
SELECT DISTINCT *,
    'dedup_fullrow' AS cleaning_rule
FROM raw_borrowers;

SELECT
    (SELECT COUNT(*) FROM raw_borrowers)   AS raw_rows,
    (SELECT COUNT(*) FROM clean_borrowers) AS clean_rows;
