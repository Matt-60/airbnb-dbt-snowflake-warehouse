{{ config(
    materialized='table'
) }}

SELECT
    b.BOOKING_ID,
    l.LISTING_KEY,
    h.HOST_KEY,
    b.BOOKING_DATE,
    b.NIGHTS_BOOKED,
    b.BOOKING_AMOUNT,
    b.CLEANING_FEE,
    b.SERVICE_FEE,
    b.TOTAL_AMOUNT,
    b.TOTAL_BOOKING_AMOUNT,
    b.BOOKING_STATUS,
    b.CREATED_AT,
    CURRENT_TIMESTAMP() AS FACT_LOADED_AT

FROM {{ ref('silver_obt') }} b

LEFT JOIN {{ ref('dim_listings') }} l
    ON b.LISTING_ID = l.LISTING_ID
    AND L.IS_CURRENT = 'FALSE'
    --AND b.BOOKING_DATE BETWEEN l.VALID_FROM AND l.VALID_TO 
-- DimListings is modeled as SCD2; however, the historical date range join (BOOKING_DATE BETWEEN VALID_FROM AND VALID_TO) is not applied here because the synthetic dataset does not provide complete historical alignment between booking dates and listing versions.

LEFT JOIN {{ ref('dim_hosts') }} h
    ON b.HOST_ID = h.HOST_ID