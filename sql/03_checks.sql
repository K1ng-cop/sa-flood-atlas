-- Row counts, invalid geometry, size
SELECT 'road' AS layer, count(*) AS rows,
       count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS invalid,
       round(sum(length_m) / 1000) AS total_km_or_m2
FROM core.road WHERE study_area_id = :'area'
UNION ALL
SELECT 'river', count(*), count(*) FILTER (WHERE NOT ST_IsValid(geom)),
       round(sum(ST_Length(geom::geography)) / 1000)
FROM core.river WHERE study_area_id = :'area'
UNION ALL
SELECT 'building', count(*), count(*) FILTER (WHERE NOT ST_IsValid(geom)),
       round(sum(area_m2))
FROM core.building WHERE study_area_id = :'area';

-- Anything outside the study area? Should be 0
SELECT count(*) AS buildings_outside
FROM core.building b JOIN core.study_area s USING (study_area_id)
WHERE b.study_area_id = :'area' AND NOT ST_Intersects(b.geom, s.geom);

-- Every geometry column should be SRID 4326
SELECT f_table_schema, f_table_name, srid
FROM geometry_columns
WHERE f_table_schema IN ('raw', 'core')
ORDER BY 1, 2;