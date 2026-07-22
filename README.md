# Airbnb Analytics Data Warehouse

An end-to-end cloud data warehouse for Airbnb booking analytics — raw data transformed into a tested, analytics-ready model using a modern **ELT approach with dbt and Snowflake**.

`Snowflake` · `dbt` · `SQL` · `Medallion Architecture` · `Star Schema` · `SCD Type 2` · `Power BI`

---

## 🎯 Business Goal

An Airbnb-style business needs to understand which listings and hosts drive revenue, how pricing changes over time, and how booking behavior evolves — while trusting that historical changes to a listing's price or attributes aren't silently overwritten. This warehouse delivers that: a clean, tested Gold layer (`FactBookings`, `DimListings`, `DimHosts`) supporting both current-state reporting and historical trend analysis (via SCD Type 2), ready to plug into a BI tool for revenue, occupancy, and host performance analysis.

## 🏗️ Architecture

```
Source Data → Bronze → Silver → Gold → BI / Analytics
```

| Layer | Purpose |
|---|---|
| **Bronze** | Raw source data, 1:1, minimal transformations, metadata columns for tracking |
| **Silver** | Cleaned & standardized models (`silver_bookings`, `silver_listings`, `silver_hosts`) plus `silver_obt` — a One Big Table combining all three, grain = 1 booking |
| **Gold** | Star schema built from Silver OBT: `FactBookings` + `DimListings`, `DimHosts`, `DimDate` |

## ⭐ Gold Layer — Star Schema

| Table | Type | Notes |
|---|---|---|
| `FactBookings` | Fact | Grain: 1 row = 1 booking. Measures: booking amount, cleaning fee, service fee, total amount, nights. FKs: Listing Key, Host Key |
| `DimListings` | Dimension — **SCD Type 2** | Historical price/attribute changes tracked via dbt snapshots |
| `DimHosts` | Dimension — SCD Type 1 | Host attributes, superhost status, response metrics |
| `DimDate` | Dimension | Time-based analysis |

**SCD2 example (`DimListings`):**

| LISTING_ID | VALID_FROM | VALID_TO | PRICE_PER_NIGHT |
|---|---|---|---|
| 100 | 2025-01-01 | 2025-06-01 | 120 |
| 100 | 2025-06-01 | 9999-12-31 | 150 |

## ✅ Data Quality (dbt tests)

- **Source tests:** primary key uniqueness, not-null validation, accepted values
- **Model tests:** fact table grain validation, dimension relationship checks (`FactBookings.HOST_KEY → DimHosts.HOST_KEY`), value range validation

## 🧠 Key Design Decisions

- **Star schema** — simpler queries, better BI performance, clear fact/dimension separation
- **Silver OBT layer** — centralizes business logic once, reused as a single source for all Gold models instead of repeating joins
- **SCD Type 2 for listings** — price and property details change over time; historical versions are preserved to support trend analysis (SCD1 would silently overwrite them)

<details>
<summary><b>🛠️ Tech stack, project structure & future improvements (click to expand)</b></summary>

**Technology Stack**

| Technology | Purpose |
|---|---|
| Snowflake | Cloud data warehouse |
| dbt Cloud (Fusion) | Data transformation and modeling |
| SQL / Jinja | Transformations, dynamic SQL |
| dbt Tests | Data quality validation |
| Git | Version control |
| Power BI | Data visualization |

**Project Structure**

```
airbnb-data-warehouse/
├── models/
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

**Future Improvements**
- Incremental processing across all layers
- Automated data freshness monitoring
- CI/CD pipeline for dbt
- Direct Power BI connection to Gold models
- Business KPI dashboards

</details>

---

*Demonstrates a complete data warehouse lifecycle: ingestion → dbt transformation → dimensional modeling → data quality validation → documentation → analytics-ready delivery.*
