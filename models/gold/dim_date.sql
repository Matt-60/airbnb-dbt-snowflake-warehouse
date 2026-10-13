{{ config(materialized='table') }}

-- One row per calendar day between the first and last booking date.
WITH bounds AS (
    SELECT MIN(BOOKING_DATE) AS first_day, MAX(BOOKING_DATE) AS last_day
    FROM {{ ref('silver_bookings') }}
),

days AS (
    SELECT DATEADD(day, ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, b.first_day) AS DATE_DAY
    FROM bounds b, TABLE(GENERATOR(ROWCOUNT => 20000))
)

SELECT
    TO_NUMBER(TO_CHAR(d.DATE_DAY, 'YYYYMMDD')) AS DATE_KEY,
    d.DATE_DAY,
    YEAR(d.DATE_DAY)                          AS YEAR,
    QUARTER(d.DATE_DAY)                       AS QUARTER,
    MONTH(d.DATE_DAY)                         AS MONTH,
    MONTHNAME(d.DATE_DAY)                     AS MONTH_NAME,
    DAYOFWEEKISO(d.DATE_DAY)                  AS DAY_OF_WEEK,
    DAYNAME(d.DATE_DAY)                       AS DAY_NAME,
    DAYOFWEEKISO(d.DATE_DAY) IN (6, 7)        AS IS_WEEKEND
FROM days d
CROSS JOIN bounds b
WHERE d.DATE_DAY <= b.last_day
