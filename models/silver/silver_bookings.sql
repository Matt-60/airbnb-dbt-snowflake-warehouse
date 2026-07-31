{{ config(materialized='incremental', unique_key='BOOKING_ID') }}

WITH source_data AS (

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
    FROM {{ ref('bronze_bookings') }}

    {% if is_incremental() %}
    WHERE CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

deduped AS (

    SELECT *
    FROM source_data
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY BOOKING_ID
        ORDER BY CREATED_AT DESC
    ) = 1

)

SELECT * FROM deduped