-- ==========================================================================
-- LAYER 0: RAW
-- Purpose : Views directly over CSV files. Zero transformation.
--           Single source-of-truth for all data lineage.
-- Engine  : DuckDB  |  Run from Assignment directory
-- Usage   : duckdb -c ".read sql/00_raw/raw_views.sql"
-- ==========================================================================

CREATE OR REPLACE VIEW raw_borrowers
    AS SELECT * FROM read_csv_auto('../data/borrowers.csv',             header=true, nullstr='');
CREATE OR REPLACE VIEW raw_accounts
    AS SELECT * FROM read_csv_auto('../data/accounts.csv',              header=true, nullstr='');
CREATE OR REPLACE VIEW raw_agents
    AS SELECT * FROM read_csv_auto('../data/agents.csv',                header=true, nullstr='');
CREATE OR REPLACE VIEW raw_agent_sessions
    AS SELECT * FROM read_csv_auto('../data/agent_sessions.csv',        header=true, nullstr='');
CREATE OR REPLACE VIEW raw_campaigns
    AS SELECT * FROM read_csv_auto('../data/campaigns.csv',             header=true, nullstr='');
CREATE OR REPLACE VIEW raw_daily_targeting
    AS SELECT * FROM read_csv_auto('../data/daily_targeting.csv',       header=true, nullstr='');
CREATE OR REPLACE VIEW raw_calls
    AS SELECT * FROM read_csv_auto('../data/calls.csv',                 header=true, nullstr='');
CREATE OR REPLACE VIEW raw_call_attempts
    AS SELECT * FROM read_csv_auto('../data/call_attempts.csv',         header=true, nullstr='');
CREATE OR REPLACE VIEW raw_call_dispositions
    AS SELECT * FROM read_csv_auto('../data/call_dispositions.csv',     header=true, nullstr='');
CREATE OR REPLACE VIEW raw_whatsapp_events
    AS SELECT * FROM read_csv_auto('../data/whatsapp_events.csv',       header=true, nullstr='');
CREATE OR REPLACE VIEW raw_sms_events
    AS SELECT * FROM read_csv_auto('../data/sms_events.csv',            header=true, nullstr='');
CREATE OR REPLACE VIEW raw_field_visits
    AS SELECT * FROM read_csv_auto('../data/field_visits.csv',          header=true, nullstr='');
CREATE OR REPLACE VIEW raw_promises_to_pay
    AS SELECT * FROM read_csv_auto('../data/promises_to_pay.csv',       header=true, nullstr='');
CREATE OR REPLACE VIEW raw_payments
    AS SELECT * FROM read_csv_auto('../data/payments.csv',              header=true, nullstr='');
CREATE OR REPLACE VIEW raw_vendor_telephony
    AS SELECT * FROM read_csv_auto('../data/vendor_telephony.csv',      header=true, nullstr='');
CREATE OR REPLACE VIEW raw_complaints
    AS SELECT * FROM read_csv_auto('../data/complaints.csv',            header=true, nullstr='');
CREATE OR REPLACE VIEW raw_account_status_history
    AS SELECT * FROM read_csv_auto('../data/account_status_history.csv',header=true, nullstr='');

-- ── Row-count audit ────────────────────────────────────────────────────────
SELECT table_name, row_count FROM (
    SELECT 'raw_borrowers'              AS table_name, COUNT(*) AS row_count FROM raw_borrowers             UNION ALL
    SELECT 'raw_accounts',              COUNT(*) FROM raw_accounts              UNION ALL
    SELECT 'raw_agents',                COUNT(*) FROM raw_agents                UNION ALL
    SELECT 'raw_agent_sessions',        COUNT(*) FROM raw_agent_sessions        UNION ALL
    SELECT 'raw_campaigns',             COUNT(*) FROM raw_campaigns             UNION ALL
    SELECT 'raw_daily_targeting',       COUNT(*) FROM raw_daily_targeting       UNION ALL
    SELECT 'raw_calls',                 COUNT(*) FROM raw_calls                 UNION ALL
    SELECT 'raw_call_attempts',         COUNT(*) FROM raw_call_attempts         UNION ALL
    SELECT 'raw_call_dispositions',     COUNT(*) FROM raw_call_dispositions     UNION ALL
    SELECT 'raw_whatsapp_events',       COUNT(*) FROM raw_whatsapp_events       UNION ALL
    SELECT 'raw_sms_events',            COUNT(*) FROM raw_sms_events            UNION ALL
    SELECT 'raw_field_visits',          COUNT(*) FROM raw_field_visits          UNION ALL
    SELECT 'raw_promises_to_pay',       COUNT(*) FROM raw_promises_to_pay       UNION ALL
    SELECT 'raw_payments',              COUNT(*) FROM raw_payments              UNION ALL
    SELECT 'raw_vendor_telephony',      COUNT(*) FROM raw_vendor_telephony      UNION ALL
    SELECT 'raw_complaints',            COUNT(*) FROM raw_complaints            UNION ALL
    SELECT 'raw_account_status_history',COUNT(*) FROM raw_account_status_history
) ORDER BY table_name;
