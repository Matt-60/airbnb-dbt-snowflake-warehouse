{{ config(materialized='incremental', unique_key='BOOKING_ID', incremental_strategy='merge') }}

-- One row per booking. Fivetran already merges by primary key, so no deduplication is needed;
-- rows deleted at the source are kept with IS_DELETED = TRUE (an incremental MERGE would otherwise
-- never remove them) and filtered out in Gold.
SELECT
    BOOKING_ID,
    LISTING_ID,
    CAST(BOOKING_DATE AS DATE)                                          AS BOOKING_DATE,
    NIGHTS_BOOKED,
    BOOKING_AMOUNT,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }}                AS TOTAL_BOOKING_AMOUNT,
    CLEANING_FEE,
    SERVICE_FEE,
    {{ multiply('NIGHTS_BOOKED', 'BOOKING_AMOUNT', 2) }} + CLEANING_FEE + SERVICE_FEE AS TOTAL_AMOUNT,
    {{ init_cap('BOOKING_STATUS') }}                                    AS BOOKING_STATUS,
    CREATED_AT,
    _FIVETRAN_DELETED                                                   AS IS_DELETED,
    _FIVETRAN_SYNCED
FROM {{ source('fivetran', 'bookings') }}

{% if is_incremental() %}
WHERE {{ incremental_window() }}
{% endif %}
