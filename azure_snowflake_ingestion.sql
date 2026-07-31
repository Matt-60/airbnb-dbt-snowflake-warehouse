/* ==========================================================================
   INGESTION: Azure Data Lake Storage Gen2 -> Snowflake (STAGING)
   Pattern: TRUNCATE + COPY INTO (snapshot), loads the STAGING layer,
   which dbt then reads to build the historized Bronze layer (incremental append).
   ========================================================================== */

USE ROLE SYSADMIN;
USE DATABASE AIRBNB;
USE SCHEMA AIRBNB.STAGING;

/* --------------------------------------------------------------------------
   1) STORAGE INTEGRATION
   Docs: https://docs.snowflake.com/en/user-guide/data-load-azure-config
   -------------------------------------------------------------------------- */

CREATE OR REPLACE STORAGE INTEGRATION azureconn
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    AZURE_TENANT_ID = '<tenant_id>'
    ENABLED = TRUE
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://<storage_account>.blob.core.windows.net/source'
    );

-- After creation: retrieve AZURE_CONSENT_URL / AZURE_MULTI_TENANT_APP_NAME
-- and grant the Snowflake service principal the "Storage Blob Data Reader"
-- role on the Azure storage account (the integration won't work without it).
DESCRIBE INTEGRATION azureconn;

-- Grant usage to roles other than ACCOUNTADMIN/SYSADMIN
GRANT USAGE ON INTEGRATION azureconn TO ROLE SYSADMIN;

/* --------------------------------------------------------------------------
   2) FILE FORMAT
   -------------------------------------------------------------------------- */

CREATE OR REPLACE FILE FORMAT AIRBNB.STAGING.csv_format
    TYPE = CSV
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL = TRUE;

/* --------------------------------------------------------------------------
   3) EXTERNAL STAGE
   -------------------------------------------------------------------------- */

CREATE OR REPLACE STAGE azure_stage
    URL = 'azure://<storage_account>.blob.core.windows.net/source'
    STORAGE_INTEGRATION = azureconn
    FILE_FORMAT = AIRBNB.STAGING.csv_format;

GRANT USAGE ON STAGE azure_stage TO ROLE SYSADMIN;

LIST @azure_stage;

/* --------------------------------------------------------------------------
   4) TARGET STAGING TABLES (snapshot structure matching the source)
   Adjust columns/types to the real schema of the source files.
   -------------------------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS AIRBNB.STAGING.BOOKINGS (
    booking_id     NUMBER,
    listing_id     NUMBER,
    host_id        NUMBER,
    booking_status VARCHAR,
    created_at     TIMESTAMP_NTZ
    -- ... remaining columns per the real bookings.csv schema
);

CREATE TABLE IF NOT EXISTS AIRBNB.STAGING.HOSTS (
    host_id    NUMBER,
    host_name  VARCHAR,
    created_at TIMESTAMP_NTZ
    -- ... remaining columns per the real hosts.csv schema
);

CREATE TABLE IF NOT EXISTS AIRBNB.STAGING.LISTINGS (
    listing_id NUMBER,
    host_id    NUMBER,
    title      VARCHAR,
    created_at TIMESTAMP_NTZ
    -- ... remaining columns per the real listings.csv schema
);

/* --------------------------------------------------------------------------
   5) SNAPSHOT LOAD: TRUNCATE + COPY INTO (FORCE = TRUE)
   FORCE = TRUE is required because Snowflake retains per-table load
   history (~64 days) and would otherwise skip a previously-loaded file,
   even though the table is empty after TRUNCATE.
   -------------------------------------------------------------------------- */

TRUNCATE TABLE AIRBNB.STAGING.BOOKINGS;

COPY INTO AIRBNB.STAGING.BOOKINGS
    FROM @azure_stage/raw/
    FILES = ('bookings.csv')
    FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
    FORCE = TRUE
    ON_ERROR = 'CONTINUE';

TRUNCATE TABLE AIRBNB.STAGING.HOSTS;

COPY INTO AIRBNB.STAGING.HOSTS
    FROM @azure_stage/raw/
    FILES = ('hosts.csv')
    FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
    FORCE = TRUE
    ON_ERROR = 'CONTINUE';

TRUNCATE TABLE AIRBNB.STAGING.LISTINGS;

COPY INTO AIRBNB.STAGING.LISTINGS
    FROM @azure_stage/raw/
    FILES = ('listings.csv')
    FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
    FORCE = TRUE
    ON_ERROR = 'CONTINUE';

-- Quick post-load verification
SELECT 'BOOKINGS' AS tbl, COUNT(*) AS row_count FROM AIRBNB.STAGING.BOOKINGS
UNION ALL
SELECT 'HOSTS', COUNT(*) FROM AIRBNB.STAGING.HOSTS
UNION ALL
SELECT 'LISTINGS', COUNT(*) FROM AIRBNB.STAGING.LISTINGS;

/* --------------------------------------------------------------------------
   6) AUTOMATION: STORED PROCEDURE + TASK (scheduled batch load)
   -------------------------------------------------------------------------- */

CREATE OR REPLACE PROCEDURE AIRBNB.STAGING.SP_LOAD_STAGING_SNAPSHOT()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE AIRBNB.STAGING.BOOKINGS;
    COPY INTO AIRBNB.STAGING.BOOKINGS
        FROM @azure_stage/raw/
        FILES = ('bookings.csv')
        FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
        FORCE = TRUE
        ON_ERROR = 'CONTINUE';

    TRUNCATE TABLE AIRBNB.STAGING.HOSTS;
    COPY INTO AIRBNB.STAGING.HOSTS
        FROM @azure_stage/raw/
        FILES = ('hosts.csv')
        FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
        FORCE = TRUE
        ON_ERROR = 'CONTINUE';

    TRUNCATE TABLE AIRBNB.STAGING.LISTINGS;
    COPY INTO AIRBNB.STAGING.LISTINGS
        FROM @azure_stage/raw/
        FILES = ('listings.csv')
        FILE_FORMAT = (FORMAT_NAME = AIRBNB.STAGING.csv_format)
        FORCE = TRUE
        ON_ERROR = 'CONTINUE';

    RETURN 'OK: staging snapshot loaded at ' || CURRENT_TIMESTAMP()::STRING;
END;
$$;

-- Schedule: hourly, on the hour (adjust CRON as needed)
CREATE OR REPLACE TASK AIRBNB.STAGING.TASK_LOAD_STAGING_SNAPSHOT
    WAREHOUSE = COMPUTE_WH   -- replace with your actual warehouse
    SCHEDULE = 'USING CRON 0 * * * * UTC'
AS
    CALL AIRBNB.STAGING.SP_LOAD_STAGING_SNAPSHOT();

-- Tasks are created suspended by default and must be resumed
ALTER TASK AIRBNB.STAGING.TASK_LOAD_STAGING_SNAPSHOT RESUME;

-- View run history
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
--     TASK_NAME => 'TASK_LOAD_STAGING_SNAPSHOT'
-- ))
-- ORDER BY SCHEDULED_TIME DESC;
