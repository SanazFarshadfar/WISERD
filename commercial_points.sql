/*
code snippet to extract items of interest from the full premium addressbase wales
*/

drop table if exists addbase.ab_commercial;
create table addbase.ab_commercial as 
SELECT id,
       field_1 AS "id2",
       field_5 AS "uprn",
       classification,
       xcoord,
       ycoord,
       latitude,
       longitude,
       address,
       postcode,
       St_setsrid(St_makepoint(xcoord::real, ycoord::real), 27700) as "geom"
FROM   addbase.ab_wales
WHERE  classification LIKE 'C%';

create index on addbase.ab_commercial using gist(geom);
create index on addbase.ab_commercial (id);
create index on addbase.ab_commercial (classification);
