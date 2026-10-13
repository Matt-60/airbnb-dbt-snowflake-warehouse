# Airbnb Analytics Data Warehouse

An end-to-end cloud data warehouse for Airbnb booking analytics — raw data transformed into a tested, analytics-ready model using a modern **ELT approach with Azure, Snowflake and dbt**.

`Azure Data Lake Gen2` · `Snowflake` · `dbt` · `SQL` · `Medallion Architecture` · `Star Schema` · `SCD Type 2` · `Power BI`

---

## 🎯 Business Goal

An Airbnb-style business needs to understand which listings and hosts drive revenue, how pricing changes over time, and how booking behavior evolves — while trusting that historical changes to a listing's price or attributes aren't silently overwritten. This warehouse delivers that: a clean, tested Gold layer (`FactBookings`, `DimListings`, `DimHosts`) supporting both current-state reporting and historical trend analysis (via SCD Type 2), ready to plug into a BI tool for revenue, occupancy, and host performance analysis.

## 🏗️ Architecture

```
Azure Data Lake Gen2 → Staging (Snowflake, snapshot) → Bronze → Silver → Gold → BI / Analytics
```

| Layer | Purpose |
|---|---|
| **Staging** | Snowflake external stage over ADLS Gen2, loaded as a full **snapshot** (`TRUNCATE` + `COPY INTO ... FORCE = TRUE`) — mirrors the current state of the source, no history kept here |
| **Bronze** | Raw, historized data — dbt incremental model, `incremental_strategy='append'`, filtered by a `created_at` watermark against staging. Preserves every change over time as an append-only log |
| **Silver** | Cleaned & standardized, deduplicated models (`silver_bookings`, `silver_listings`, `silver_hosts`) plus `silver_obt` — a One Big Table combining all three, grain = 1 booking |
| **Gold** | Star schema built from Silver OBT: `FactBookings` + `DimListings`, `DimHosts`, `DimDate` |

<b>🔍 DBT lineage graph</b>

<img width="1242" height="296" alt="image" src="https://github.com/user-attachments/assets/118a752e-c6f5-42eb-9ab5-c7f06b5a0cc1" />


## 🔄 Ingestion — Azure Data Lake Gen2 → Snowflake

Data lands in an Azure Storage container and is pulled into Snowflake through a native storage integration (no keys stored in Snowflake, authenticated via Azure AD). Staging tables are loaded as a **full snapshot on every run** (`TRUNCATE` + `COPY INTO ... FORCE = TRUE`), automated hourly via a Snowflake `TASK`.

<details>
<summary><b>💻 Storage integration & COPY INTO SQL (click to expand)</b></summary>

```sql
CREATE OR REPLACE STORAGE INTEGRATION azureconn
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    AZURE_TENANT_ID = '<tenant_id>'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = ('azure://<account>.blob.core.windows.net/source');
```

An external stage points at the container, and staging tables are loaded as a full snapshot on every run:

```sql
TRUNCATE TABLE STAGING.BOOKINGS;

COPY INTO STAGING.BOOKINGS
FROM @azure_stage/raw/
FILES = ('bookings.csv')
FORCE = TRUE
ON_ERROR = 'CONTINUE';
```

</details>

**Why `FORCE = TRUE`:** Snowflake tracks per-table file load history (name + checksum) for ~64 days. Without `FORCE`, a file already recorded as loaded gets silently skipped, even after the table is truncated. Snowflake dedupes by file **checksum**, not just name — if the source file is overwritten with changed rows, the checksum changes and the file *is* reloaded automatically.

**Why snapshot instead of append at the staging level:** loading directly with append duplicates every unchanged row on every reload (since Snowflake reloads the whole file when its checksum changes, not just the delta rows). Truncating staging each run keeps it as a clean mirror of the source; history is instead owned explicitly by the Bronze layer.

📄 Full script (storage integration, file format, stage, staging tables, stored procedure + scheduled `TASK`): [`azure_snowflake_ingestion.sql`](./sql/azure_snowflake_ingestion.sql)

## 🥉 Bronze — Historized Append Layer

Bronze reads from the staging snapshot and appends only rows new since the last run, using `created_at` as a watermark (the source bumps `created_at` on update as well as insert, so it doubles as a change-detection column). This is intentionally append-only: the same business key can appear multiple times over time, each row representing a version — Bronze is the audit trail / changelog, not a queryable current state.

<details>
<summary><b>💻 Bronze incremental model SQL (click to expand)</b></summary>

```sql
{{ config(materialized='incremental', incremental_strategy='append') }}

select *, current_timestamp() as _loaded_at
from {{ source('staging', 'bookings') }}
{% if is_incremental() %}
where created_at > (select coalesce(max(created_at), '1900-01-01'::timestamp_ntz) from {{ this }})
{% endif %}
```

</details>

## 🥈 Silver — Deduplication + Point-in-Time Merge

Because Bronze can hold multiple versions of the same key, any model that does an incremental `MERGE` (via `unique_key`) against Bronze must first collapse to a single row per key, or Snowflake raises `100090 (42P18): Duplicate row detected during DML action`.

<details>
<summary><b>💻 Silver dedup + merge SQL (click to expand)</b></summary>

```sql
{{ config(materialized='incremental', unique_key='booking_id') }}

with source_data as (
    select * from {{ ref('bronze_bookings') }}
    {% if is_incremental() %}
    where created_at > (select coalesce(max(created_at), '1900-01-01'::timestamp_ntz) from {{ this }})
    {% endif %}
),
deduped as (
    select * from source_data
    qualify row_number() over (partition by booking_id order by created_at desc) = 1
)
select * from deduped
```

</details>

The `qualify row_number()` dedup is required regardless of whether the model is incremental — a full `ref()` to Bronze without any date filter still pulls the entire historized log, which will contain duplicate keys for anything ever updated.

## ⭐ Gold Layer — Star Schema

| Table | Type | Notes |
|---|---|---|
| `FactBookings` | Fact | Grain: 1 row = 1 booking. Measures: booking amount, cleaning fee, service fee, total amount, nights. FKs: Listing Key, Host Key |
| `DimListings` | Dimension — **SCD Type 2** | Historical price/attribute changes tracked via a dbt snapshot (`listings_snapshot`) |
| `DimHosts` | Dimension — SCD Type 1 | Host attributes, superhost status, response metrics |
| `DimDate` | Dimension | Time-based analysis |

**SCD2 example (`DimListings`):**

| LISTING_ID | VALID_FROM | VALID_TO | PRICE_PER_NIGHT |
|---|---|---|---|
| 100 | 2025-01-01 | 2025-06-01 | 120 |
| 100 | 2025-06-01 | 9999-12-31 | 150 |

**Join fanout gotcha:** `FactBookings` joins to `DimListings` on `listing_id`. Because `DimListings` is SCD2, any listing with a price/attribute change has **two** rows (closed + current). A join on `listing_id` alone silently duplicates every booking tied to that listing. Since the synthetic dataset doesn't have reliable historical alignment between booking dates and listing versions, the fix is to join only against the current version:

```sql
LEFT JOIN {{ ref('dim_listings') }} l
    ON b.LISTING_ID = l.LISTING_ID
    AND l.VALID_TO IS NULL   -- current version only
```

Whenever `DimListings` is joined anywhere downstream, this current-version filter (or a genuine point-in-time date range join, if the source data supports it) must be applied — otherwise fact tables silently inflate.

## ✅ Data Quality (dbt tests)

Uniqueness tests differ by layer, since "unique" means something different at each stage:

| Layer | What to test | Why |
|---|---|---|
| Staging | `unique` on the natural key (`booking_id`, `host_id`, `listing_id`) | Staging is a snapshot — exactly one row per key is expected per load |
| Bronze | `unique_combination_of_columns: [id, created_at]` — **not** `unique` on the id alone | Bronze intentionally holds multiple versions per key over time; a plain uniqueness test on the id would fail on every legitimate update. Testing `(id, created_at)` catches real duplicate-ingestion bugs instead |
| Silver / Gold | `unique` on the primary key | These layers are deduplicated/merged to a single current row per key — a failure here means the dedup or MERGE logic broke |

Additional checks: not-null validation, accepted values, fact table grain validation, dimension relationship checks (`FactBookings.HOST_KEY → DimHosts.HOST_KEY`), value range validation.

## 🧠 Key Design Decisions

- **Snapshot ingestion, historized Bronze** — Snowflake `COPY INTO` works at file granularity, not row-level diff, so ingestion is treated as a full snapshot (truncate + reload) rather than a naive append; history is deliberately pushed downstream into Bronze, which is designed for it
- **Star schema** — simpler queries, better BI performance, clear fact/dimension separation
- **Silver OBT layer** — centralizes business logic once, reused as a single source for all Gold models instead of repeating joins
- **SCD Type 2 for listings** — price and property details change over time; historical versions are preserved to support trend analysis (SCD1 would silently overwrite them)
- **Explicit dedup before every MERGE** — any model with `unique_key` against a historized source needs a `qualify row_number()` step; Snowflake's `MERGE` has no built-in tolerance for duplicate source keys

## 🐛 Debugging Notes (real issues hit while building this)

- **File reload ≠ row-level diff.** Changing 1 record + adding 1 record in a 200-row source file caused the *entire* 201-row file to reload (Snowflake dedupes by file checksum, not row content) — this is what pushed the design toward snapshot + watermark rather than naive append at ingestion.
- **`100090: Duplicate row detected during DML action`** — hit when a Silver model did `MERGE` (via `unique_key`) against a Bronze source containing two versions of the same key. Fixed with `qualify row_number() over (partition by <key> order by created_at desc) = 1` before the merge.
- **Fact table row count inflated by exactly the number of bookings tied to an updated listing** (5001 expected, 5011 actual) — traced to `FactBookings` joining `DimListings` (SCD2) on `listing_id` only, matching both the closed and current version. Fixed by adding `AND l.VALID_TO IS NULL` to the join.

<details>
<summary><b>🛠️ Tech stack, project structure & future improvements (click to expand)</b></summary>

**Technology Stack**

| Technology | Purpose |
|---|---|
| Azure Data Lake Storage Gen2 | Raw source file landing zone |
| Snowflake | Cloud data warehouse, storage integration, external stage, tasks |
| dbt Cloud (Fusion) | Data transformation and modeling |
| SQL / Jinja | Transformations, dynamic SQL |
| dbt Tests | Data quality validation |
| Git | Version control |
| Power BI | Data visualization |

**Project Structure**

```
airbnb-data-warehouse/
├── sql/
│   └── azure_snowflake_ingestion.sql   -- storage integration, stage, staging tables, task
├── models/
│   ├── staging/
│   ├── bronze/
│   ├── silver/
│   │   ├── silver_bookings.sql
│   │   ├── silver_hosts.sql
│   │   ├── silver_listings.sql
│   │   └── silver_obt.sql
│   └── gold/
│       ├── dim_hosts.sql
│       ├── dim_listings.sql
│       └── fact_bookings.sql
├── snapshots/
│   └── listings_snapshot.sql
├── tests/
├── macros/
└── dbt_project.yml
```

**How to run**
1. Set up an Azure Storage container and load source CSVs (`bookings`, `listings`, `hosts`)
2. Run `sql/azure_snowflake_ingestion.sql` in Snowflake to create the storage integration, external stage, staging tables, and the hourly load `TASK`
3. Configure a dbt Cloud (or dbt Core) project pointing at the Snowflake warehouse
4. Run `dbt snapshot` to initialize `listings_snapshot`
5. Run `dbt build` to execute all models (Bronze → Silver → Gold) and tests
6. Connect Power BI to the Gold schema for reporting

**Future Improvements**
- Automated data freshness monitoring on the staging layer
- CI/CD pipeline for dbt
- Direct Power BI connection to Gold models
- Business KPI dashboards
- Point-in-time date-range join for `DimListings` once historical booking/listing-version alignment is available in source data

</details>

---

*Demonstrates a complete data warehouse lifecycle: Azure ingestion → Snowflake snapshot loading → dbt transformation (Bronze/Silver/Gold) → dimensional modeling with SCD2 → data quality validation → documentation → analytics-ready delivery.*
