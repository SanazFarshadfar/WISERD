/*
===============================================================================
Accessible Employment by Public Transport for All Postcodes
===============================================================================

Purpose
-------
This query estimates the number of jobs accessible by public transport from
each postcode.

For every postcode available in addbase.pcd_ops, the query:

1. Identifies the bus journeys that can be accessed from that postcode.
2. Uses ingr1_sig_id to identify all reachable downstream bus stops.
3. Retains only egress stops where the bus arrives between 08:00 and 08:45.
4. Links each reachable egress stop to commercial sites included in the
   400-metre network-walking matrix.
5. Removes duplicate commercial sites that may be reachable through multiple
   journeys, routes, or bus stops.
6. Links each commercial site to its LSOA.
7. Assigns the estimated average number of jobs per commercial site for that
   LSOA.
8. Sums the estimated jobs to calculate total accessible employment for each
   origin postcode.

Methodology
-----------
The employment estimate is based on the avgperjob field in
swansea.lsoa_job_counts.

This assumes that the total employment within each LSOA is distributed evenly
across the commercial sites located within that LSOA. Therefore, the output is
an estimated accessibility measure rather than an exact count of jobs at each
individual commercial site.

Time interpretation
-------------------
The time filter is applied to addbase.egrx_a.egr_arr.

This represents the time at which the bus arrives at the destination or egress
bus stop. It does not include the additional walking time from the egress stop
to the commercial site.

Walking-distance interpretation
-------------------------------
The table addbase.od_abcomm_stop_400_nwd already represents commercial sites
reachable within a maximum 400-metre network walk from an egress bus stop.
Therefore, an additional nwd <= 400 filter is not required.

Output
------
The query returns one row for every postcode in addbase.pcd_ops, including
postcodes with no accessible commercial sites.

Output fields:

postcode
    Origin postcode.

accessible_commercial_sites
    Number of unique commercial sites reachable from the postcode.

sites_with_job_estimate
    Number of accessible commercial sites successfully linked to an LSOA job
    estimate.

sites_without_job_estimate
    Number of accessible commercial sites for which no avgperjob value was
    found.

estimated_accessible_jobs
    Sum of the estimated jobs assigned to all accessible commercial sites.

Tables used
-----------
addbase.pcd_ops
    Bus journeys accessible from each origin postcode.

addbase.egrx_a
    Reachable egress stops and arrival times for each tracked bus journey.

addbase.od_abcomm_stop_400_nwd
    Commercial sites located within a maximum 400-metre network walk of each
    egress bus stop.

addbase.new_ab_commercial
    Commercial-site details, including commercial-site ID and LSOA code.

swansea.lsoa_job_counts
    LSOA employment data and average estimated jobs per commercial site.
===============================================================================
*/


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
