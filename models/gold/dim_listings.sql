{{ config(
    materialized='table'
) }}

SELECT

    {{ dbt_utils.generate_surrogate_key([
        'LISTING_ID',
        'DBT_VALID_FROM'
    ]) }} AS LISTING_KEY,
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
    DBT_VALID_FROM AS VALID_FROM,
    DBT_VALID_TO AS VALID_TO,
    CASE
        WHEN DBT_VALID_TO IS NULL THEN TRUE
        ELSE FALSE
    END AS IS_CURRENT

FROM {{ ref('listings_snapshot') }}