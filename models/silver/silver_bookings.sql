{{ config(materialized='incremental',
   unique_key='BOOKING_ID')  }}

SELECT
    BOOKING_ID,
    LISTING_ID,
    CAST(BOOKING_DATE AS DATE) AS BOOKING_DATE,
    NIGHTS_BOOKED,
    BOOKING_AMOUNT,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} AS TOTAL_BOOKING_AMOUNT,
    CLEANING_FEE,
    SERVICE_FEE,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} + CLEANING_FEE + SERVICE_FEE AS TOTAL_AMOUNT,
    {{ init_cap('BOOKING_STATUS') }} AS BOOKING_STATUS,
    CREATED_AT
FROM
    {{ ref('bronze_bookings') }}
