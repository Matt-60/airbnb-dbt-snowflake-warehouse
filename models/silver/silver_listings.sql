{{ config(materialized='incremental', unique_key='LISTING_ID') }}

WITH source_data AS (

    SELECT 
        LISTING_ID,
        HOST_ID,
        PROPERTY_TYPE,
        {{ init_cap('ROOM_TYPE') }} AS ROOM_TYPE,
        CITY,
        COUNTRY,
        ACCOMMODATES,
        BEDROOMS,
        BATHROOMS,
        PRICE_PER_NIGHT,
        {{ tag('CAST(PRICE_PER_NIGHT AS INT)') }} AS PRICE_PER_NIGHT_TAG,
        CREATED_AT
    FROM {{ ref('bronze_listings') }}

    {% if is_incremental() %}
    WHERE CREATED_AT > (SELECT COALESCE(MAX(CREATED_AT), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

deduped AS (

    SELECT *
    FROM source_data
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY LISTING_ID
        ORDER BY CREATED_AT DESC
    ) = 1

)

SELECT * FROM deduped
    