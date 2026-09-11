# ASG Airlines — End-to-End Data Engineering Case Study

Case study by **Yamini D**. I built a full pipeline that takes messy raw flight, booking, passenger, and payment data and turns it into a clean, analytics-ready dataset with a Power BI dashboard on top.

## Problem I was solving

ASG Airlines collects flight data from its booking platform, scheduling system, and airport logs. The raw data has corrupted flight IDs, inconsistent time formats, missing values, and overnight flights where the arrival date rolls into the next day. I built a pipeline that ingests this data, validates and cleans it, protects passenger PII, and produces a reliable dataset for reporting.

## Architecture

I used a **Bronze → Silver → Gold** structure, with a separate quarantine layer for anything that fails validation:

```
Raw Excel (flights, bookings, passengers, payments)
        │
        ▼
    BRONZE  — raw data, loaded as-is
        │
        ▼
  VALIDATE  — schema checks, missing values, format rules
        │
   ┌────┴────┐
   ▼         ▼
 SILVER   QUARANTINE  — invalid rows tagged with a reason code, not deleted
   │
   ▼
PII MASKING — Aadhaar, phone, email split into a restricted vault
   │
   ▼
  GOLD  — star schema (dim + fact tables), ready for Power BI
```

I quarantine instead of delete because a real airline can't afford to silently lose records — every rejected row is tagged with an `error_reason` and a `pipeline_run_id` so it can be traced and reprocessed later.

## Repo structure

```
├── notebook/
│   └── ASG_Airlines.ipynb          # full pipeline: ingestion → cleaning → gold layer
├── data/
│   ├── UseCase - Airlines.xlsx     # raw source file (bronze)
│   ├── cleaned/                    # gold layer: dim/fact CSVs, ready for Power BI
│   ├── quarantine/                 # rejected rows with reason codes
│   └── pii_vault/                  # restricted — raw PII, not for general access
├── dashboard/
│   └── ASG_Airlines_Dashboard.pbix
└── docs/
    └── ASG_Airlines_Case_Study.docx  # full write-up: assumptions, logic, KPIs
```

## How to run the notebook

1. Clone the repo.
2. Make sure `data/UseCase - Airlines.xlsx` is present (already included here).
3. Open `notebook/ASG_Airlines.ipynb` in Jupyter, VS Code, or Databricks.
4. Run all cells top to bottom. It writes the gold CSVs to `data/cleaned/`.

This was originally built and run on Databricks Community Edition. I've since made all paths relative so it runs the same way locally — no cloud account needed.

## What the pipeline actually does

**Cleaning & validation** — I standardized text fields (airline names, city codes), fixed data types (`aadhaar_id` was silently read as `int64`, which truncates leading zeros — I forced it to string), parsed inconsistent time formats, and removed exact duplicate rows.

**Overnight flight handling** — if arrival time is earlier than departure time and the gap is 12 hours or less, I treat it as a next-day arrival and add a day to it. Anything that still doesn't make sense after that gets quarantined rather than guessed at.

**Surrogate key fix** — `flight_id` values repeat across genuinely different flights (same route number flown on different days), so I generated a composite `flight_key` (`flight_id` + `departure_time`) to uniquely identify each flight before joining bookings to flights.

**PII masking** — Aadhaar ID, phone, and email are hashed (SHA-256) for the analytical layer, and the raw values live only in a separate `pii_vault` table that's excluded from the Power BI-facing gold layer entirely. Only the vault, not just a hash, should sit behind restricted access.

**Data quality scoring** — each source table gets a measurable `valid_record_rate` and `field_completeness` score per pipeline run, so the pipeline reports on its own reliability instead of just producing output silently.

## Results after cleaning

| Table | Raw rows | Quarantined | Clean rows |
|---|---|---|---|
| Flights | 1,020 | 16 | 1,004 |
| Bookings | 1,000 | 3 | 997 |
| Passengers | 1,039 | 144 | 895 |
| Payments | 1,000 | 78 | 922 |

**241 rows** were quarantined in total, each with a specific reason code (invalid Aadhaar format, duplicate passenger ID, missing/negative payment amount, unmatched booking, etc.) — nothing was dropped without a traceable reason.

## Key business KPIs

- **Average flight duration:** 164.5 minutes
- **Busiest route:** BOM–CCU (90 flights), followed by CCU–DEL (72) and MAA–BLR (65)
- **Flights by airline:** IndiGo (249), SpiceJet (235), Air India (233), Vistara (218)
- **Anomaly rate:** 0.1% of flights, flagged using per-route statistical thresholds (mean ± 2 standard deviations) rather than one fixed cutoff for every route
- **Highest revenue route:** BOM–CCU (₹7,00,135)

Full KPI breakdown and the reasoning behind each transformation decision is in `docs/ASG_Airlines_Case_Study.docx`.

## Power BI dashboard

The `.pbix` connects directly to the gold CSVs in `data/cleaned/` as a star schema:

- **Dimensions:** `dim_airline`, `dim_route`, `dim_date`, `dim_passenger`
- **Facts:** `fact_flights`, `fact_bookings`, `fact_payments`
- **Relationships:** each fact table joins to its dimensions on the `*_key` columns (one-to-many, dim → fact)

**Dashboard pages:**
1. **Duration Analysis** — average/median duration, duration distribution, duration by airline
2. **Route Performance** — route-wise traffic, revenue by route, route map
3. **Airline Trends** — flight share by airline, on-time patterns by airline
4. **Delay & Anomaly Insights** — flagged anomalies by route, data quality scorecard

Each page has slicers for airline, route, and date so the view can be filtered interactively. To open it: launch Power BI Desktop, open the `.pbix`, and if prompted, repoint the data source to your local `data/cleaned/` folder path.

## Privacy note

The `pii_vault/` folder contains hashed-but-sensitive fields and is included here only for pipeline completeness. In a real deployment, this folder would sit in a separate, access-controlled storage location — not in a public repo — and only specific authorized roles would be able to query it.

## Tech stack

Python (pandas), Jupyter/Databricks notebook, Power BI Desktop, GitHub.
