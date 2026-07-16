/*
===============================================================================
Estimate accessible employment from a postcode by bus
===============================================================================

Purpose
-------
Identify the unique commercial sites accessible from a selected postcode by:

1. Walking to an origin bus stop included in the postcode-access table.
2. Taking an available bus journey.
3. Arriving at an egress stop between 08:00 and 09:00.
4. Walking up to 400 metres from the egress stop to a commercial site.

Each accessible commercial site is linked to its LSOA and assigned the
estimated average number of jobs per commercial site in that LSOA.

The estimated job values are then summed to calculate the total employment
accessible from the selected postcode.

Important
---------
The time condition uses ex.egr_arr, representing the time at which the bus
arrives at the destination or egress stop.

The destination walking threshold is already represented by
addbase.od_abcomm_stop_400_nwd. The nwd <= 400 condition is included as an
additional validation check.
===============================================================================
*/

WITH parameters AS (

    SELECT
        'SA1 1AA'::text AS target_postcode,
        TIME '08:00:00' AS arrival_start_time,
        TIME '09:00:00' AS arrival_end_time
),

reachable_commercial_sites AS (

    /*
    Create one record for each unique postcode-commercial-site combination.

    DISTINCT prevents a commercial site from being counted more than once
    when it can be reached through multiple journeys, routes or egress stops.
    */

    SELECT DISTINCT
        po.postcode,
        ab.to_id AS commercial_id

    FROM addbase.pcd_ops_a AS po

    JOIN addbase.egrx_a AS ex
        ON po.ingr1_sig_id = ex.ingr1_sig_id

    JOIN addbase.od_abcomm_stop_400_nwd AS ab
        ON ex.egr_stop = ab.from_id

    CROSS JOIN parameters AS p

    WHERE po.postcode = p.target_postcode
      AND ex.egr_arr >= p.arrival_start_time
      AND ex.egr_arr <= p.arrival_end_time
      AND ab.nwd <= 400
),

accessible_site_jobs AS (

    /*
    Link each accessible commercial site to its LSOA and estimated
    number of jobs.
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
)

SELECT
    postcode,

    COUNT(*) AS accessible_commercial_sites,

    COUNT(estimated_jobs_at_site) AS sites_with_job_estimate,

    COUNT(*) - COUNT(estimated_jobs_at_site)
        AS sites_without_job_estimate,

    ROUND(
        SUM(COALESCE(estimated_jobs_at_site, 0)),
        2
    ) AS estimated_accessible_jobs

FROM accessible_site_jobs

GROUP BY postcode

ORDER BY postcode;
