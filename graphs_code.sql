SELECT j.lsoa_code as lsoa,
sw.postcode as postcode,
j.total_jobs as total_job, 
sw.total as population,
w.data_values as wimd_rank,
n.neet_proxy_percentage as neet_proxy_percentage
FROM swansea.lsoa_job_counts j
left join  addbase.pcds_all pos on pos.lsoa21 =j.lsoa_code
left join swansea.postcode_2021_swansea sw on sw.postcode=pos.postcode
left join swansea.wimd w on w.area_code=j.lsoa_code
left join swansea.neet n on n.lsoa_code=pos.lsoa21
