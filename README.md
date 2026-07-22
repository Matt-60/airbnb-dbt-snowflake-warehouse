# Airbnb Analytics Data Warehouse

## Overview

This project demonstrates the design and implementation of an end-to-end cloud data warehouse solution for Airbnb booking analytics.

The goal of this project was to transform raw Airbnb data into a structured analytical data warehouse using a modern ELT approach. The project follows a medallion architecture, applies dimensional modeling principles, implements data quality checks, and prepares analytics-ready datasets for BI reporting.

---

## 🎯 Business Goal

An Airbnb-style business needs to understand which listings and hosts drive revenue, how pricing changes over time, and how booking behavior evolves — while trusting that historical changes to a listing's price or attributes aren't silently overwritten. This warehouse delivers that: a clean, tested Gold layer (`FactBookings`, `DimListings`, `DimHosts`) that supports both current-state reporting and historical trend analysis (via SCD Type 2 on listings), ready to plug into a BI tool for revenue, occupancy, and host performance analysis.

---

## Project Objectives

The main objectives of this project:

- Build an end-to-end data warehouse solution
- Implement Bronze, Silver, and Gold layers
- Transform raw data into clean analytical datasets
- Design a star schema optimized for reporting
- Implement Slowly Changing Dimension Type 2 (SCD2)
- Apply data quality tests using dbt
- Create documented and reusable data models

---

# Architecture

The project follows a medallion architecture:

```text
Source Data
     |
     v
Bronze Layer
     |
     v
Silver Layer
     |
     v
Gold Layer
     |
     v
BI / Analytics
```

---

# Technology Stack

| Technology | Purpose |
|------------|---------|
| Snowflake | Cloud data warehouse |
| dbt Cloud (Fusion) | Data transformation and modeling |
| SQL | Data transformations |
| Jinja | Dynamic SQL generation |
| dbt Tests | Data quality validation |
| Git | Version control |
| Power BI | Data visualization |

---

# Data Warehouse Layers

## Bronze Layer

The Bronze layer stores raw source data.

### Purpose

- Preserve original source structure
- Store ingested data
- Provide foundation for downstream transformations

### Characteristics

- Minimal transformations
- Source-aligned tables
- Metadata columns for data tracking

---

# Silver Layer

The Silver layer contains cleaned and standardized datasets.

### Transformations

- Data type standardization
- Data cleaning
- Business logic implementation
- Derived columns creation
- Data enrichment

## Silver Models

### silver_bookings

Contains booking-level information.

**Grain:**

```text
1 row = 1 booking
```

---

### silver_listings

Contains Airbnb listing information:

- Property details
- Location attributes
- Pricing information

---

### silver_hosts

Contains host information:

- Host attributes
- Superhost status
- Response metrics

---

### silver_obt

One Big Table combining booking, listing, and host information.

Purpose:

- Simplify analytical transformations
- Provide a prepared source for Gold models

**Grain:**

```text
1 row = 1 booking
```

---

# Gold Layer

The Gold layer contains analytical models designed using a star schema.

## Dimension Tables

## DimHosts

Stores host attributes.

Type:

```text
SCD Type 1
```

---

## DimListings

Stores listing attributes.

Type:

```text
SCD Type 2
```

Historical changes are tracked using dbt snapshots.

Example:

| LISTING_ID | VALID_FROM | VALID_TO | PRICE_PER_NIGHT |
|------------|------------|----------|-----------------|
| 100 | 2025-01-01 | 2025-06-01 | 120 |
| 100 | 2025-06-01 | 9999-12-31 | 150 |

---

## DimDate

Date dimension used for time-based analysis.

---

# Fact Table

## FactBookings

Central transactional fact table.

**Grain:**

```text
1 row = 1 booking
```

### Measures

- Booking amount
- Cleaning fee
- Service fee
- Total amount
- Number of nights

### Foreign Keys

- Listing Key
- Host Key

---

# Data Quality

Data quality validation is implemented using dbt tests.

## Source Tests

Implemented checks:

- Primary key uniqueness
- Not null validation
- Accepted values validation

---

## Model Tests

Implemented checks:

- Fact table grain validation
- Dimension relationship checks
- Value range validation

Example:

```text
FactBookings.HOST_KEY
          |
          v
DimHosts.HOST_KEY
```

---

# dbt Implementation

## Models

Models are organized into:

```text
Bronze
Silver
Gold
```

---

## Snapshots

dbt snapshots are used to implement SCD Type 2.

Snapshots preserve historical versions of records when dimension attributes change.

---

## Documentation

dbt YAML files contain:

- Model descriptions
- Column descriptions
- Data quality tests
- Model metadata

---

# Project Structure

```text
airbnb-data-warehouse/

├── models/
│
│   ├── bronze/
│
│   ├── silver/
│   │   ├── silver_bookings.sql
│   │   ├── silver_hosts.sql
│   │   ├── silver_listings.sql
│   │   └── silver_obt.sql
│
│   └── gold/
│       ├── dim_hosts.sql
│       ├── dim_listings.sql
│       └── fact_bookings.sql
│
├── snapshots/
│   └── listings_snapshot.sql
│
├── tests/
│
├── macros/
│
└── dbt_project.yml
```

---

# Key Design Decisions

## Star Schema

A star schema was chosen because it provides:

- Simple analytical queries
- Better BI performance
- Clear separation between facts and dimensions
- Easier reporting

---

## Silver OBT Layer

An OBT layer was created in Silver as an intermediate transformation layer.

Benefits:

- Simplifies downstream transformations
- Centralizes business logic
- Provides a reusable source for analytical models

---

## SCD2 for Listings

Listings were modeled as SCD Type 2 because attributes such as price and property details can change over time.

Historical versions are preserved to support time-based analysis.

---

# Future Improvements

Possible improvements:

- Implement incremental processing across all layers
- Add automated data freshness monitoring
- Add CI/CD pipeline for dbt
- Connect Gold models directly to Power BI
- Add business KPI dashboards

---

# Summary

This project demonstrates a complete data warehouse development lifecycle:

1. Raw data ingestion
2. Data transformation with dbt
3. Dimensional modeling
4. Data quality validation
5. Documentation
6. Analytics-ready data delivery

The final solution provides a scalable foundation for Airbnb booking analytics and business intelligence reporting.
