{{ config(materialized='incremental', unique_key='LISTING_ID', incremental_strategy='merge') }}

SELECT
    LISTING_ID,
    HOST_ID,
    TRIM(PROPERTY_TYPE)                                 AS PROPERTY_TYPE,
    {{ init_cap('ROOM_TYPE') }}                         AS ROOM_TYPE,
    TRIM(CITY)                                          AS CITY,
    TRIM(COUNTRY)                                       AS COUNTRY,
    ACCOMMODATES,
    BEDROOMS,
    BATHROOMS,
    PRICE_PER_NIGHT,
    {{ tag('CAST(PRICE_PER_NIGHT AS INT)') }}           AS PRICE_PER_NIGHT_TAG,
    CREATED_AT,
    _FIVETRAN_DELETED                                   AS IS_DELETED,
    _FIVETRAN_SYNCED
FROM {{ source('fivetran', 'listings') }}

{% if is_incremental() %}
WHERE {{ incremental_window() }}
{% endif %}
