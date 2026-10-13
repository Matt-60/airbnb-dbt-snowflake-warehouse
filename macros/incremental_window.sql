{#
    Filter for incremental Silver models, used inside {% if is_incremental() %}.
    Picks up rows Fivetran changed since the last load (_FIVETRAN_SYNCED), with a lookback window
    so late or retried syncs are not skipped. Re-reading is safe: the models MERGE on unique_key.
    Backfill a range:  dbt build --select silver_bookings+ --vars "{backfill_from: '2026-10-01', backfill_to: '2026-10-05'}"
#}
{% macro incremental_window(column='_FIVETRAN_SYNCED', lookback_hours=24) -%}
    {%- if var('backfill_from', none) -%}
        {{ column }} >= '{{ var("backfill_from") }}'::TIMESTAMP_TZ
        AND {{ column }} < '{{ var("backfill_to", "9999-12-31") }}'::TIMESTAMP_TZ
    {%- else -%}
        {{ column }} > (
            SELECT COALESCE(MAX({{ column }}), '1900-01-01'::TIMESTAMP_TZ) - INTERVAL '{{ lookback_hours }} hours'
            FROM {{ this }}
        )
    {%- endif -%}
{%- endmacro %}
