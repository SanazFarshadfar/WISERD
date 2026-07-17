WITH parameters AS (

    SELECT
        TIME '08:00:00' AS arrival_start_time,
        TIME '08:45:00' AS arrival_end_time
),

all_postcodes AS (

    /*
    Retain every postcode available in the postcode-to-bus-journey table,
    including postcodes that have no reachable commercial sites within
    the selected arrival-time window.
    */

    SELECT DISTINCT
        BTRIM(postcode::text) AS postcode

    FROM addbase.pcd_ops

    WHERE postcode IS NOT NULL
),

reachable_commercial_sites AS (

    /*
    Identify each unique commercial site reachable from each postcode.

    DISTINCT prevents the same site from being counted multiple times when
    it is accessible through different journeys, routes or egress stops.
    */

    SELECT DISTINCT
        BTRIM(po.postcode::text) AS postcode,
        ab.to_id AS commercial_id

    FROM addbase.pcd_ops AS po

    JOIN addbase.egrx_a AS ex
        ON po.ingr1_sig_id = ex.ingr1_sig_id

    JOIN addbase.od_abcomm_stop_400_nwd AS ab
        ON ex.egr_stop = ab.from_id

    CROSS JOIN parameters AS p

    WHERE ex.egr_arr >= p.arrival_start_time
      AND ex.egr_arr <= p.arrival_end_time
),

accessible_site_jobs AS (

    /*
    Link each accessible commercial site to its LSOA and assign the
    estimated average number of jobs per commercial site.
    */

    SELECT
        r.postcode,
        r.commercial_id,
        BTRIM(c.lsoa_code::text) AS lsoa_code,
        j.avgperjob AS estimated_jobs_at_site

    FROM reachable_commercial_sites AS r

    JOIN addbase.new_ab_commercial AS c
        ON c.id::text = r.commercial_id::text

    LEFT JOIN swansea.lsoa_job_counts AS j
        ON BTRIM(c.lsoa_code::text) = BTRIM(j.lsoa_code::text)
),

postcode_summary AS (

    SELECT
        postcode,

        COUNT(*) AS accessible_commercial_sites,

        COUNT(estimated_jobs_at_site) AS sites_with_job_estimate,

        COUNT(*) - COUNT(estimated_jobs_at_site)
            AS sites_without_job_estimate,

        ROUND(
            SUM(COALESCE(estimated_jobs_at_site, 0))::numeric,
            2
        ) AS estimated_accessible_jobs

    FROM accessible_site_jobs

    GROUP BY postcode
)

SELECT
    p.postcode,

    COALESCE(
        s.accessible_commercial_sites,
        0
    ) AS accessible_commercial_sites,

    COALESCE(
        s.sites_with_job_estimate,
        0
    ) AS sites_with_job_estimate,

    COALESCE(
        s.sites_without_job_estimate,
        0
    ) AS sites_without_job_estimate,

    COALESCE(
        s.estimated_accessible_jobs,
        0
    ) AS estimated_accessible_jobs

FROM all_postcodes AS p

LEFT JOIN postcode_summary AS s
    ON p.postcode = s.postcode

ORDER BY p.postcode;
