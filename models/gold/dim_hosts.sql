{{ config(materialized='table') }}

-- SCD Type 1: current host attributes. Hosts deleted at the source stay (IS_DELETED) so historical
-- bookings keep a valid HOST_KEY.
SELECT
    {{ dbt_utils.generate_surrogate_key(['HOST_ID']) }} AS HOST_KEY,
    HOST_ID,
    HOST_NAME,
    HOST_SINCE,
    IS_SUPERHOST,
    RESPONSE_RATE,
    RESPONSE_RATE_QUALITY,
    IS_DELETED
FROM {{ ref('silver_hosts') }}
