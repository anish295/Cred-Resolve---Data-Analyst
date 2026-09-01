# Collections Analytics — SQL Repository

## Engine
DuckDB (reads CSVs directly — no database server required)

## Setup
```bash
pip install duckdb
# Run from the deliverables/ directory
duckdb -c ".read sql/00_raw/raw_views.sql"
```

## Layer Architecture

```
00_raw/           Views over raw CSVs. Zero transformation.
01_staging/       Type casting, null flags, quality annotations.
02_clean/         Dedup, entity resolution, code standardisation.
03_golden/        Final trusted analytical tables (primary keys enforced).
04_metrics/       All 9 metric definitions (contact rate, RPC, PTP, recovery rate...).
05_analytical/    Forensics, statistical investigation, DiD, investment ROI.
```

## Cleaning Decisions

| Table | Issue | Rule | Rows Removed |
|---|---|---|---|
| payments | Duplicate payment_reference | Keep first SUCCESS, else earliest | ~4,678 |
| calls | Full-row duplicates | DROP DUPLICATES | ~1,271 |
| whatsapp_events | Full-row duplicates | DROP DUPLICATES | ~600 |
| borrowers | Full-row duplicates | DROP DUPLICATES | ~600 |
| agents | Multiple agent_ids per employee | Keep latest updated_at per employee_code | ~29,000 rows → ~1,000 |
| call_dispositions | PROMISE_TO_PAY vs PTP schema mismatch | Map PROMISE_TO_PAY → PTP | 0 rows removed, codes unified |

## Key Metric Definitions

| Metric | Definition | Verified Value | Why |
|---|---|---|---|
| Recovery Rate | SUCCESS payments (golden) / outstanding_amount | ₹111.27 Cr Jan–Jul | Outstanding is the true denominator |
| Call Connect Rate | ANSWERED calls / total calls placed | **19.9%** | Call-level efficiency; benchmarks dialer and vendor |
| Account Contact Rate | Accounts reached (ANSWERED >30s) / accounts targeted per month | **~40.9% avg** | Account-level; use for campaign effectiveness |
| RPC Rate | RPC dispositions / ANSWERED calls | — | Confirms borrower (not household) engagement |
| PTP Rate | Accounts with PTP / accounts with RPC | — | Standardised codes required |
| PTP Kept Rate | PTPs KEPT / (total PTPs excl PENDING) | **33.0%** | Exclude PENDING from denominator |
| Recovery/Agent-hr | INR recovered / agent-hours | ₹14,580/hr | Efficiency over volume |
| Channel Conversion | Accounts paying within 7d of touchpoint / accounts touched | — | Payment must come AFTER touchpoint |
| Cost per ₹ Recovered | Channel cost / Channel ₹ recovered | — | Enables channel-level ROI |

> **Note on contact rate:** Two definitions exist. "Call connect rate" (19.9%) measures dialer efficiency. "Account contact rate" (~40.9% monthly) measures how many targeted borrowers were actually reached. Both are valid — the definition must be stated when reporting.

## Forensics Queries
- `05_analytical/forensics_duplicate_payments.sql` — Quantifies INR inflation from dup references
- `05_analytical/forensics_attribution_errors.sql` — Finds calls timestamped AFTER payment
- `05_analytical/forensics_timezone.sql` — Measures DNC compliance risk from TZ mixing
- `05_analytical/forensics_agent_identity.sql` — Quantifies productivity distortion
- `05_analytical/forensics_denominator.sql` — Tests survivorship bias in recovery rate
- `05_analytical/analysis_11pct_claim.sql` — Raw vs golden MoM comparison; verdict on 11% claim
- `05_analytical/counterfactual_did.sql` — Difference-in-Differences analysis
- `05_analytical/investment_recommendation.sql` — ROI comparison for all 6 investment options
