---https://open-geography-portalx-ons.hub.arcgis.com/datasets/ons::ons-postcode-directory-february-2025-for-the-uk/about

SELECT ons.pcds as postcode,
ons.oa11,
ons.lsoa11,
ons.oa21,
ons.lsoa21,
sw.total as population
FROM swansea.lsoa_oa_postcode_swansea ons
left join swansea.postcode_2021_swansea sw on sw.postcode=ons.pcds
