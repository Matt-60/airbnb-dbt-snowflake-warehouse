{{ config(materialized='table') }}

-- Grain: one row per booking (soft-deleted bookings are excluded in silver_obt).
-- LISTING_KEY points to the listing VERSION valid on the booking date (point-in-time SCD2 join).
SELECT
    b.BOOKING_ID,
    l.LISTING_KEY,
    h.HOST_KEY,
    TO_NUMBER(TO_CHAR(b.BOOKING_DATE, 'YYYYMMDD')) AS DATE_KEY,
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
    ON  b.LISTING_ID = l.LISTING_ID
    AND b.BOOKING_DATE >= l.VALID_FROM
    AND b.BOOKING_DATE <  l.VALID_TO         -- half-open: exactly one version matches
LEFT JOIN {{ ref('dim_hosts') }} h
    ON b.HOST_ID = h.HOST_ID
