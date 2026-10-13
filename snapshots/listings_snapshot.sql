{% snapshot listings_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='LISTING_ID',
      strategy='timestamp',
      updated_at='CREATED_AT',
      hard_deletes='invalidate',
    )
}}

-- SCD2 history of listings. Listings deleted at the source (Fivetran soft delete) are left out,
-- so the snapshot closes their current version (hard_deletes='invalidate').
SELECT * EXCLUDE (IS_DELETED, _FIVETRAN_SYNCED)
FROM {{ ref('silver_listings') }}
WHERE NOT IS_DELETED

{% endsnapshot %}
