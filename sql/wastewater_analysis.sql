-- ============================================================
-- Explainable Short-Horizon N2O Forecasting
-- Wastewater Treatment Process Monitoring
--
-- SQL workflow for the Avedøre WWTP dataset
--
-- Execution:
--   Run this script with the `sql/` directory as the
--   working directory.
--
--   The raw dataset is therefore referenced as:
--       ../data/raw/aved_raw.csv
--
-- Quality convention:
--   quality = 0 -> Good
--   quality != 0 -> Not used
--
-- The raw dataset is intentionally excluded from GitHub.
-- ============================================================


-- ============================================================
-- 1. Register the raw dataset
-- ============================================================

CREATE OR REPLACE VIEW wastewater_raw AS
SELECT *
FROM read_csv_auto(
    '../data/raw/aved_raw.csv',
    header = true,
    ignore_errors = false
);


-- ============================================================
-- 2. Quality-aware hourly N2O aggregation
-- ============================================================

CREATE OR REPLACE TABLE n2o_hourly AS

WITH quality_filtered AS (

    SELECT
        CAST(time AS TIMESTAMP) AS timestamp,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.N2O value" AS DOUBLE
        ) AS n2o_value,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.N2O quality" AS INTEGER
        ) AS n2o_quality

    FROM wastewater_raw
)

SELECT
    date_trunc('hour', timestamp) AS hour_start,

    AVG(n2o_value) AS n2o_mean,

    COUNT(n2o_value) AS n2o_valid_count

FROM quality_filtered

WHERE n2o_quality = 0
  AND n2o_value IS NOT NULL

GROUP BY 1

ORDER BY 1;


-- ============================================================
-- 3. Hourly N2O coverage
-- ============================================================

CREATE OR REPLACE TABLE n2o_hourly_coverage AS

WITH hourly_observations AS (

    SELECT
        date_trunc(
            'hour',
            CAST(time AS TIMESTAMP)
        ) AS hour_start,

        COUNT(*) AS raw_observed_rows

    FROM wastewater_raw

    GROUP BY 1
),

valid_n2o AS (

    SELECT
        date_trunc(
            'hour',
            CAST(time AS TIMESTAMP)
        ) AS hour_start,

        COUNT(*) AS n2o_valid_count

    FROM wastewater_raw

    WHERE TRY_CAST(
        "BIOLOGY.LINE 3 TANK 1.N2O quality" AS INTEGER
    ) = 0

    AND TRY_CAST(
        "BIOLOGY.LINE 3 TANK 1.N2O value" AS DOUBLE
    ) IS NOT NULL

    GROUP BY 1
)

SELECT
    h.hour_start,

    h.raw_observed_rows,

    COALESCE(
        n.n2o_valid_count,
        0
    ) AS n2o_valid_count,

    COALESCE(
        n.n2o_valid_count,
        0
    ) * 1.0
    / NULLIF(h.raw_observed_rows, 0)
    AS n2o_coverage

FROM hourly_observations h

LEFT JOIN valid_n2o n
    ON h.hour_start = n.hour_start

ORDER BY h.hour_start;


-- ============================================================
-- 4. Quality-aware hourly process table
--
-- This produces the main hourly process variables used
-- for downstream statistical analysis and modelling.
-- ============================================================

CREATE OR REPLACE TABLE hourly_process AS

WITH quality_filtered AS (

    SELECT
        date_trunc(
            'hour',
            CAST(time AS TIMESTAMP)
        ) AS hour_start,


        -- N2O
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.N2O value" AS DOUBLE
        ) AS n2o,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.N2O quality" AS INTEGER
        ) AS n2o_quality,


        -- NH4
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.NH4 value" AS DOUBLE
        ) AS nh4,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.NH4 quality" AS INTEGER
        ) AS nh4_quality,


        -- NO3
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.NO3 value" AS DOUBLE
        ) AS no3,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.NO3 quality" AS INTEGER
        ) AS no3_quality,


        -- Dissolved oxygen
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.O2 value" AS DOUBLE
        ) AS do_value,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.O2 quality" AS INTEGER
        ) AS do_quality,


        -- DO setpoint
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.O2.SETPOINT value" AS DOUBLE
        ) AS do_setpoint,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.O2.SETPOINT quality" AS INTEGER
        ) AS do_setpoint_quality,


        -- Airflow
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.Q.AIRFLOW value" AS DOUBLE
        ) AS airflow,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.Q.AIRFLOW quality" AS INTEGER
        ) AS airflow_quality,


        -- Suspended solids
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.SS value" AS DOUBLE
        ) AS suspended_solids,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.SS quality" AS INTEGER
        ) AS ss_quality,


        -- Temperature
        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.TEMPERATURE value" AS DOUBLE
        ) AS temperature,

        TRY_CAST(
            "BIOLOGY.LINE 3 TANK 1.TEMPERATURE quality" AS INTEGER
        ) AS temperature_quality,


        -- Influent flow
        TRY_CAST(
            "INLET.Q value" AS DOUBLE
        ) AS inlet_flow,

        TRY_CAST(
            "INLET.Q quality" AS INTEGER
        ) AS inlet_flow_quality

    FROM wastewater_raw
)

SELECT

    hour_start,


    -- N2O
    AVG(n2o)
        FILTER (WHERE n2o_quality = 0)
        AS t1_n2o,

    COUNT(n2o)
        FILTER (WHERE n2o_quality = 0)
        AS t1_n2o_valid_count,


    -- NH4
    AVG(nh4)
        FILTER (WHERE nh4_quality = 0)
        AS t1_nh4,

    COUNT(nh4)
        FILTER (WHERE nh4_quality = 0)
        AS t1_nh4_valid_count,


    -- NO3
    AVG(no3)
        FILTER (WHERE no3_quality = 0)
        AS t1_no3,

    COUNT(no3)
        FILTER (WHERE no3_quality = 0)
        AS t1_no3_valid_count,


    -- Dissolved oxygen
    AVG(do_value)
        FILTER (WHERE do_quality = 0)
        AS t1_do,

    COUNT(do_value)
        FILTER (WHERE do_quality = 0)
        AS t1_do_valid_count,


    -- DO setpoint
    AVG(do_setpoint)
        FILTER (WHERE do_setpoint_quality = 0)
        AS t1_do_setpoint,

    COUNT(do_setpoint)
        FILTER (WHERE do_setpoint_quality = 0)
        AS t1_do_setpoint_valid_count,


    -- Airflow
    AVG(airflow)
        FILTER (WHERE airflow_quality = 0)
        AS t1_airflow_est,

    COUNT(airflow)
        FILTER (WHERE airflow_quality = 0)
        AS t1_airflow_valid_count,


    -- Suspended solids
    AVG(suspended_solids)
        FILTER (WHERE ss_quality = 0)
        AS t1_ss,

    COUNT(suspended_solids)
        FILTER (WHERE ss_quality = 0)
        AS t1_ss_valid_count,


    -- Temperature
    AVG(temperature)
        FILTER (WHERE temperature_quality = 0)
        AS t1_temp,

    COUNT(temperature)
        FILTER (WHERE temperature_quality = 0)
        AS t1_temp_valid_count,


    -- Influent flow
    AVG(inlet_flow)
        FILTER (WHERE inlet_flow_quality = 0)
        AS inlet_flow,

    COUNT(inlet_flow)
        FILTER (WHERE inlet_flow_quality = 0)
        AS inlet_flow_valid_count

FROM quality_filtered

GROUP BY hour_start

ORDER BY hour_start;


-- ============================================================
-- 5. Basic SQL validation
-- ============================================================

SELECT
    COUNT(*) AS hourly_rows,
    MIN(hour_start) AS first_hour,
    MAX(hour_start) AS last_hour
FROM hourly_process;


-- ============================================================
-- 6. N2O coverage summary
-- ============================================================

SELECT
    COUNT(*) AS total_hours,

    AVG(n2o_coverage) AS mean_n2o_coverage,

    MEDIAN(n2o_coverage) AS median_n2o_coverage,

    SUM(
        CASE
            WHEN n2o_coverage >= 0.50 THEN 1
            ELSE 0
        END
    ) AS hours_with_at_least_50pct_n2o_coverage

FROM n2o_hourly_coverage;