SELECT
sw.postcode as postcode,
j.lsoa_code as lsoa21,
oa.oa21cd AS oa21,
sw.total as population
FROM swansea.lsoa_job_counts j
left join  addbase.pcds_all pos on pos.lsoa21 =j.lsoa_code
left join swansea.postcode_2021_swansea sw on sw.postcode=pos.postcode
LEFT JOIN swansea.oas_2021_swansea oa
ON oa.lsoa21cd = pos.lsoa21
