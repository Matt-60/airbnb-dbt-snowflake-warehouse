{% snapshot listings_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='LISTING_ID',
      strategy='timestamp',
      updated_at='CREATED_AT',
    )
}}

SELECT
    *
FROM {{ ref('silver_listings') }}

{% endsnapshot %}