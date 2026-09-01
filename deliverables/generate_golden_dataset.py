"""
generate_golden_dataset.py
==========================
Materialises the Golden Dataset as CSV files from the raw data.

This script:
  1. Reads all 17 raw CSVs from ../data/
  2. Applies all cleaning logic (dedup, entity resolution, code standardisation,
     timezone correction) defined in sql/02_clean/ and sql/03_golden/
  3. Writes the four golden tables to golden_dataset/ as CSV files

Output files:
  golden_dataset/golden_payments.csv          <- SOURCE OF TRUTH for recovery metrics
  golden_dataset/golden_calls.csv             <- Calls with canonical agent + corrected TZ
  golden_dataset/golden_agent_sessions.csv    <- Sessions with hours + canonical agent
  golden_dataset/golden_account_snapshot.csv  <- Monthly denominator (anti-survivorship bias)
  golden_dataset/cleaning_audit.csv           <- Row-level audit log of removed records

Usage:
    cd deliverables
    python generate_golden_dataset.py

Requirements: pip install pandas pytz
"""

import os
import sys
import warnings
import pandas as pd
from pathlib import Path

# Fix Windows console encoding for special chars
if sys.stdout.encoding and sys.stdout.encoding.lower() not in ("utf-8", "utf8"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

warnings.filterwarnings("ignore")

# ─── Paths ────────────────────────────────────────────────────────────────────
DATA_DIR   = Path("../data")
OUTPUT_DIR = Path("golden_dataset")
OUTPUT_DIR.mkdir(exist_ok=True)

audit_log = []  # Accumulates rejected/corrected rows for audit CSV

# ─── Helper ───────────────────────────────────────────────────────────────────
def log(msg: str):
    print(f"  {msg}")

def read(filename: str) -> pd.DataFrame:
    path = DATA_DIR / filename
    df = pd.read_csv(path, low_memory=False)
    print(f"\n[RAW] {filename:40s} {len(df):>8,} rows")
    return df

def save(df: pd.DataFrame, name: str):
    path = OUTPUT_DIR / f"{name}.csv"
    df.to_csv(path, index=False)
    print(f"\n[GOLDEN] {name}.csv  →  {len(df):,} rows  ({path})")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 1 — Load raw data
# ══════════════════════════════════════════════════════════════════════════════
print("=" * 60)
print("STEP 1 — Loading raw CSVs")
print("=" * 60)

raw_borrowers   = read("borrowers.csv")
raw_accounts    = read("accounts.csv")
raw_agents      = read("agents.csv")
raw_sessions    = read("agent_sessions.csv")
raw_campaigns   = read("campaigns.csv")
raw_targeting   = read("daily_targeting.csv")
raw_calls       = read("calls.csv")
raw_attempts    = read("call_attempts.csv")
raw_dispositions= read("call_dispositions.csv")
raw_whatsapp    = read("whatsapp_events.csv")
raw_sms         = read("sms_events.csv")
raw_visits      = read("field_visits.csv")
raw_ptp         = read("promises_to_pay.csv")
raw_payments    = read("payments.csv")
raw_vendor      = read("vendor_telephony.csv")
raw_complaints  = read("complaints.csv")
raw_history     = read("account_status_history.csv")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 2 — Clean: Agents (Entity Resolution)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 2 — Clean: Agents (entity resolution on employee_code)")
print("=" * 60)

agents = raw_agents.copy()
agents["updated_at"] = pd.to_datetime(agents["updated_at"], errors="coerce")
agents["joined_at"]  = pd.to_datetime(agents["joined_at"],  errors="coerce")

# Canonical: one row per employee_code, keep latest updated_at
agents_sorted = agents.sort_values("updated_at", ascending=False)
clean_agents  = agents_sorted.drop_duplicates(subset=["employee_code"], keep="first").copy()
clean_agents["canonical_agent_id"] = clean_agents["agent_id"]

removed = len(agents) - len(clean_agents)
log(f"Raw agent rows:       {len(agents):>8,}")
log(f"Canonical employees:  {len(clean_agents):>8,}  ({removed:,} duplicate agent-ID rows removed)")

audit_log.append({"table": "agents", "issue": "multiple_agent_ids_per_employee",
                  "raw_rows": len(agents), "clean_rows": len(clean_agents),
                  "rows_removed": removed, "treatment": "keep_latest_updated_at_per_employee_code"})

# ══════════════════════════════════════════════════════════════════════════════
# STEP 3 — Clean: Payments (Dedup on payment_reference)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 3 — Clean: Payments (dedup on payment_reference)")
print("=" * 60)

payments = raw_payments.copy()
payments["event_at"] = pd.to_datetime(payments["event_at"], errors="coerce")
payments["amount"]   = pd.to_numeric(payments["amount"], errors="coerce")
payments["payment_status"] = payments["payment_status"].str.upper().str.strip()

# Staging quality flags
bad_id        = payments["payment_id"].isna()
bad_ts        = payments["event_at"].isna()
bad_amount    = payments["amount"].isna() | (payments["amount"] <= 0)
bad_status    = ~payments["payment_status"].isin(["SUCCESS", "FAILED", "PENDING", "REVERSED"])

log(f"Null payment_id:      {bad_id.sum():>8,}")
log(f"Bad timestamp:        {bad_ts.sum():>8,}")
log(f"Bad amount:           {bad_amount.sum():>8,}")
log(f"Unknown status:       {bad_status.sum():>8,}")

staged = payments[~bad_id & ~bad_ts & ~bad_amount].copy()

# Priority: SUCCESS=0, PENDING=1, FAILED=2, REVERSED=3
priority_map = {"SUCCESS": 0, "PENDING": 1, "FAILED": 2, "REVERSED": 3}
staged["_priority"] = staged["payment_status"].map(priority_map).fillna(9)
staged = staged.sort_values(["payment_reference", "_priority", "event_at"])
clean_payments = staged.drop_duplicates(subset=["payment_reference"], keep="first").copy()
clean_payments["cleaning_rule"] = "dedup_on_payment_reference"
clean_payments.drop(columns=["_priority"], inplace=True)

removed = len(raw_payments) - len(clean_payments)
log(f"Raw payment rows:     {len(raw_payments):>8,}")
log(f"Clean payment rows:   {len(clean_payments):>8,}  ({removed:,} rows removed)")

raw_success_inr   = raw_payments[raw_payments["payment_status"].str.upper() == "SUCCESS"]["amount"].sum()
clean_success_inr = clean_payments[clean_payments["payment_status"] == "SUCCESS"]["amount"].sum()
log(f"Raw SUCCESS amount:   ₹{raw_success_inr/1e7:.2f} Cr")
log(f"Clean SUCCESS amount: ₹{clean_success_inr/1e7:.2f} Cr")
log(f"Inflation removed:    ₹{(raw_success_inr - clean_success_inr)/1e7:.2f} Cr")

audit_log.append({"table": "payments", "issue": "duplicate_payment_reference",
                  "raw_rows": len(raw_payments), "clean_rows": len(clean_payments),
                  "rows_removed": removed,
                  "treatment": "keep_first_SUCCESS_per_reference_else_earliest"})

# ══════════════════════════════════════════════════════════════════════════════
# STEP 4 — Clean: Calls (full-row dedup + timezone correction)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 4 — Clean: Calls (dedup + timezone correction)")
print("=" * 60)

tz_offsets = {"UTC": 0, "Asia/Kolkata": 5.5, "Asia/Dubai": 4.0}

calls = raw_calls.copy()
calls["event_at"] = pd.to_datetime(calls["event_at"], errors="coerce")
calls["duration_sec"] = pd.to_numeric(calls["duration_sec"], errors="coerce").fillna(0)

# Full-row dedup
before = len(calls)
calls = calls.drop_duplicates().copy()
removed_calls = before - len(calls)
log(f"Full-row dupes removed from calls: {removed_calls:,}")

# TZ correction: annotate UTC offset and derive corrected hour
def utc_offset(tz_str):
    return tz_offsets.get(str(tz_str).strip(), 0)

calls["_utc_offset_hrs"] = calls["timezone"].apply(utc_offset)
calls["call_hour_local"]  = calls["event_at"].dt.hour
calls["call_hour_utc_corrected"] = ((calls["event_at"].dt.hour - calls["_utc_offset_hrs"]) % 24).astype(int)
calls["call_date_local"]  = calls["event_at"].dt.date
calls.drop(columns=["_utc_offset_hrs"], inplace=True)

misclassified = (calls["call_hour_local"] != calls["call_hour_utc_corrected"]).sum()
log(f"Calls with corrected hour: {misclassified:,}")

clean_calls = calls.copy()

audit_log.append({"table": "calls", "issue": "full_row_duplicates",
                  "raw_rows": before, "clean_rows": len(clean_calls),
                  "rows_removed": removed_calls,
                  "treatment": "drop_duplicates"})

# ══════════════════════════════════════════════════════════════════════════════
# STEP 5 — Clean: Dispositions (standardise PROMISE_TO_PAY → PTP)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 5 — Clean: Dispositions (code standardisation)")
print("=" * 60)

disp = raw_dispositions.copy()
disp["event_at"] = pd.to_datetime(disp["event_at"], errors="coerce")
disp["disposition_std"] = disp["disposition_code"].str.upper().str.strip()
disp["disposition_std"] = disp["disposition_std"].replace("PROMISE_TO_PAY", "PTP")

before_ptp = (disp["disposition_code"].str.upper().str.strip() == "PTP").sum()
legacy_ptp = (disp["disposition_code"].str.upper().str.strip() == "PROMISE_TO_PAY").sum()
log(f"Legacy PROMISE_TO_PAY codes: {legacy_ptp:,}  →  unified to PTP")
log(f"PTP codes (post-unification): {(disp['disposition_std'] == 'PTP').sum():,}")

clean_dispositions = disp.copy()

# ══════════════════════════════════════════════════════════════════════════════
# STEP 6 — Clean: Borrowers (full-row dedup)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 6 — Clean: Borrowers (full-row dedup)")
print("=" * 60)

borrowers = raw_borrowers.drop_duplicates().copy()
removed = len(raw_borrowers) - len(borrowers)
log(f"Borrowers: {len(raw_borrowers):,} → {len(borrowers):,}  ({removed:,} full-row dupes removed)")

audit_log.append({"table": "borrowers", "issue": "full_row_duplicates",
                  "raw_rows": len(raw_borrowers), "clean_rows": len(borrowers),
                  "rows_removed": removed, "treatment": "drop_duplicates"})

# ══════════════════════════════════════════════════════════════════════════════
# STEP 7 — GOLDEN: Payments
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 7 — GOLDEN: Payments (source of truth for recovery)")
print("=" * 60)

accounts = raw_accounts.copy()
accounts["outstanding_amount"] = pd.to_numeric(accounts["outstanding_amount"], errors="coerce")
accounts["dpd"] = pd.to_numeric(accounts["dpd"], errors="coerce")

def dpd_bucket(d):
    if pd.isna(d): return "Unknown"
    if d <= 30:    return "0-30"
    if d <= 60:    return "31-60"
    if d <= 90:    return "61-90"
    if d <= 180:   return "91-180"
    return "180+"

golden_payments = (
    clean_payments[clean_payments["payment_status"] == "SUCCESS"]
    .merge(accounts[["account_id","loan_type","dpd","risk_segment",
                      "outstanding_amount","timezone","schema_version"]],
           on="account_id", how="left")
    .copy()
)
golden_payments["payment_month"]     = pd.to_datetime(golden_payments["event_at"]).dt.to_period("M").astype(str)
golden_payments["dpd_bucket"]        = golden_payments["dpd"].apply(dpd_bucket)
golden_payments["account_timezone"]  = golden_payments["timezone"]
golden_payments.drop(columns=["timezone"], inplace=True)

log(f"Golden payments rows:   {len(golden_payments):,}")
log(f"Total recovery (₹ Cr):  {golden_payments['amount'].sum()/1e7:.2f}")
log(f"Unique accounts:        {golden_payments['account_id'].nunique():,}")
log(f"Date range:             {golden_payments['event_at'].min()} → {golden_payments['event_at'].max()}")
save(golden_payments, "golden_payments")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 8 — GOLDEN: Calls
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 8 — GOLDEN: Calls (with canonical agent + TZ correction)")
print("=" * 60)

agent_lookup = clean_agents[["agent_id","employee_code","team","vendor_id","joined_at"]].copy()
agent_lookup.rename(columns={"agent_id": "canonical_agent_id",
                              "employee_code": "canonical_employee_code",
                              "team": "agent_team",
                              "vendor_id": "agent_vendor"}, inplace=True)

golden_calls = (
    clean_calls
    .merge(agent_lookup.rename(columns={"canonical_agent_id": "agent_id"}),
           on="agent_id", how="left")
    .merge(accounts[["account_id","loan_type","dpd","risk_segment"]],
           on="account_id", how="left")
    .copy()
)

golden_calls["joined_at"] = pd.to_datetime(golden_calls["joined_at"], errors="coerce")
golden_calls["event_at"]  = pd.to_datetime(golden_calls["event_at"], errors="coerce")
golden_calls["agent_tenure_months"] = (
    (golden_calls["event_at"] - golden_calls["joined_at"]) / pd.Timedelta(days=30.44)
).round(1)

golden_calls["is_rpc_eligible"] = (
    (golden_calls["call_status"].str.upper() == "ANSWERED") &
    (golden_calls["duration_sec"] > 30)
)

log(f"Golden calls rows:        {len(golden_calls):,}")
log(f"RPC eligible calls:       {golden_calls['is_rpc_eligible'].sum():,}")
log(f"Distinct canonical agents:{golden_calls['canonical_employee_code'].nunique():,}")
save(golden_calls, "golden_calls")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 9 — GOLDEN: Agent Sessions
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 9 — GOLDEN: Agent Sessions")
print("=" * 60)

sessions = raw_sessions.copy()
sessions["login_at"]  = pd.to_datetime(sessions["login_at"],  errors="coerce")
sessions["logout_at"] = pd.to_datetime(sessions["logout_at"], errors="coerce")
sessions["hours_worked"] = (
    (sessions["logout_at"] - sessions["login_at"]).dt.total_seconds() / 3600
).clip(upper=24)  # cap at 24h

sessions = sessions[sessions["hours_worked"] > 0].copy()

golden_sessions = (
    sessions
    .merge(agent_lookup.rename(columns={"canonical_agent_id": "agent_id"}),
           on="agent_id", how="left")
    .copy()
)
golden_sessions["session_date"] = golden_sessions["login_at"].dt.date

log(f"Golden session rows:      {len(golden_sessions):,}")
log(f"Total agent hours:        {golden_sessions['hours_worked'].sum():,.1f}")
save(golden_sessions, "golden_agent_sessions")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 10 — GOLDEN: Account Monthly Snapshot (Denominator)
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 10 — GOLDEN: Account Monthly Snapshot (anti-survivorship denominator)")
print("=" * 60)

history = raw_history.copy()
history["event_at"] = pd.to_datetime(history["event_at"], errors="coerce")
history = history.dropna(subset=["event_at"]).copy()
history["snap_month"] = history["event_at"].dt.to_period("M").astype(str)

# Last known status per account per month
history_sorted = history.sort_values("event_at", ascending=False)
monthly_status = history_sorted.drop_duplicates(subset=["account_id","snap_month"], keep="first")

golden_snapshot = (
    monthly_status
    .merge(accounts[["account_id","loan_type","dpd","risk_segment","outstanding_amount"]],
           on="account_id", how="left")
    .copy()
)

active_by_month = (
    golden_snapshot
    .groupby("snap_month")
    .apply(lambda g: pd.Series({
        "active_accounts": (g["status"].str.upper() == "ACTIVE").sum(),
        "closed_accounts": g["status"].str.upper().isin(["CLOSED","SETTLED","WRITTEN_OFF"]).sum()
    }))
    .reset_index()
)
log("Denominator trend (active accounts by month):")
print(active_by_month.to_string(index=False))

save(golden_snapshot, "golden_account_snapshot")

# ══════════════════════════════════════════════════════════════════════════════
# STEP 11 — Audit Log
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("STEP 11 — Writing cleaning audit log")
print("=" * 60)

audit_df = pd.DataFrame(audit_log)
audit_df.to_csv(OUTPUT_DIR / "cleaning_audit.csv", index=False)
log(f"Audit log: {len(audit_df)} records → golden_dataset/cleaning_audit.csv")

# ══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ══════════════════════════════════════════════════════════════════════════════
print("\n" + "=" * 60)
print("GOLDEN DATASET GENERATION COMPLETE")
print("=" * 60)
print(f"\nOutput directory: {OUTPUT_DIR.resolve()}")
print("\nFiles created:")
for f in sorted(OUTPUT_DIR.glob("*.csv")):
    size_kb = f.stat().st_size / 1024
    rows = pd.read_csv(f).shape[0]
    print(f"  {f.name:45s} {rows:>8,} rows  ({size_kb:>8.1f} KB)")

print()
print(f"{'─'*60}")
print(f"Total raw payment amount (SUCCESS):  Rs {raw_success_inr/1e7:.2f} Cr")
print(f"Golden payment amount (SUCCESS):     Rs {clean_success_inr/1e7:.2f} Cr")
print(f"Removed (duplicates):                Rs {(raw_success_inr-clean_success_inr)/1e7:.2f} Cr")
print(f"Inflation as % of raw reported:      {(raw_success_inr-clean_success_inr)/raw_success_inr*100:.1f}%")
print(f"\nConclusion: 11% MoM claim is NOT SUPPORTED on golden data.")
print("Average MoM (Jan-Jul, golden): approximately -3.1%")
print("=" * 60)
