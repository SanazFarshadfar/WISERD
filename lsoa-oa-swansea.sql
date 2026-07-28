SELECT
sw.postcode AS postcode,
post.lsoa21,
--oa.lsoa21cd AS lsoa21,
--oa.oa21cd AS oa21,
sw.total AS population
FROM swansea.postcode_2021_swansea sw
LEFT JOIN addbase.pcds_all post
ON trim(upper(post.postcode)) = trim(upper(sw.postcode))
--LEFT JOIN swansea.oas_2021_swansea oa
--ON trim(upper(oa.lsoa21cd)) = trim(upper(post.lsoa21))
