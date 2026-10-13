{{ config(materialized='table') }}

-- SCD Type 2: one row per listing VERSION, valid in the half-open range [VALID_FROM, VALID_TO).
-- The first version of each listing starts in 1900, so bookings made before the listing was first
-- snapshotted still match a version; ranges never overlap, so a point-in-time join matches exactly one row.
SELECT
    {{ dbt_utils.generate_surrogate_key(['LISTING_ID', 'DBT_VALID_FROM']) }} AS LISTING_KEY,
    LISTING_ID,
    HOST_ID,
    PROPERTY_TYPE,
    ROOM_TYPE,
    CITY,
    COUNTRY,
    ACCOMMODATES,
    BEDROOMS,
    BATHROOMS,
    PRICE_PER_NIGHT,
    PRICE_PER_NIGHT_TAG,
    CASE
        WHEN ROW_NUMBER() OVER (PARTITION BY LISTING_ID ORDER BY DBT_VALID_FROM) = 1
            THEN '1900-01-01'::TIMESTAMP_NTZ
        ELSE DBT_VALID_FROM::TIMESTAMP_NTZ
    END                                                         AS VALID_FROM,
    COALESCE(DBT_VALID_TO::TIMESTAMP_NTZ, '9999-12-31'::TIMESTAMP_NTZ) AS VALID_TO,
    DBT_VALID_TO IS NULL                                        AS IS_CURRENT
FROM {{ ref('listings_snapshot') }}
