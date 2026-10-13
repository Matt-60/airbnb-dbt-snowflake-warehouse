{{ config(severity='warn') }}

-- Suspiciously low booking amounts in the source (warning only).
SELECT 1
FROM {{ source('fivetran', 'bookings') }}
WHERE BOOKING_AMOUNT <= 50
  AND NOT _FIVETRAN_DELETED
