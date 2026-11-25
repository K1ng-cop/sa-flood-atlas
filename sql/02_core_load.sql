-- Run: sudo -u postgres psql -d flood_risk -v area=ethekwini -f sql/02_core_load.sql

CREATE TABLE IF NOT EXISTS core.road (
    road_id        bigserial PRIMARY KEY,
    study_area_id  text NOT NULL REFERENCES core.study_area,
    osm_id         text,
    highway_class  text,
    name           text,
    length_m       numeric(12, 1),
    geom           geometry(MultiLineString, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.river (
    river_id       bigserial PRIMARY KEY,
    study_area_id  text NOT NULL REFERENCES core.study_area,
    source         text NOT NULL,          -- 'hydrorivers' or 'osm'
    waterway       text,
    name           text,
    stream_order   integer,
    geom           geometry(MultiLineString, 4326) NOT NULL
);

CREATE TABLE IF NOT EXISTS core.building (
    building_id    bigserial PRIMARY KEY,
    study_area_id  text NOT NULL REFERENCES core.study_area,
    plus_code      text,
    area_m2        numeric(10, 1),
    confidence     numeric(4, 3),
    geom           geometry(MultiPolygon, 4326) NOT NULL
);

-- Roads
DELETE FROM core.road WHERE study_area_id = :'area';
WITH c AS (
    SELECT r.osmid, r.highway, r.name, s.study_area_id,
           CASE WHEN ST_Within(r.geom, s.geom) THEN r.geom
                ELSE ST_CollectionExtract(ST_Intersection(r.geom, s.geom), 2) END AS g
    FROM raw.osm_roads r
    JOIN core.study_area s USING (study_area_id)
    WHERE r.study_area_id = :'area' AND ST_Intersects(r.geom, s.geom)
)
INSERT INTO core.road (study_area_id, osm_id, highway_class, name, length_m, geom)
SELECT study_area_id, osmid, split_part(highway, ',', 1), name,
       ST_Length(g::geography), ST_Multi(g)
FROM c WHERE NOT ST_IsEmpty(g);

-- Rivers: HydroRIVERS (main rivers) + OSM (small streams and drains)
DELETE FROM core.river WHERE study_area_id = :'area';
INSERT INTO core.river (study_area_id, source, waterway, name, stream_order, geom)
SELECT h.study_area_id, 'hydrorivers', 'river', NULL, h.stream_order,
       ST_Multi(ST_CollectionExtract(ST_Intersection(h.geom, s.geom), 2))
FROM raw.hydrorivers h JOIN core.study_area s USING (study_area_id)
WHERE h.study_area_id = :'area' AND ST_Intersects(h.geom, s.geom);

INSERT INTO core.river (study_area_id, source, waterway, name, stream_order, geom)
SELECT w.study_area_id, 'osm', w.waterway, w.name, NULL,
       ST_Multi(ST_CollectionExtract(ST_Intersection(w.geom, s.geom), 2))
FROM raw.osm_waterways w JOIN core.study_area s USING (study_area_id)
WHERE w.study_area_id = :'area' AND ST_Intersects(w.geom, s.geom);

DELETE FROM core.river WHERE ST_IsEmpty(geom);

-- Buildings: confidence 0.75+ gives cleaner footprints
DELETE FROM core.building WHERE study_area_id = :'area';
INSERT INTO core.building (study_area_id, plus_code, area_m2, confidence, geom)
SELECT study_area_id, full_plus_code, area_in_meters, confidence,
       ST_Multi(ST_CollectionExtract(ST_MakeValid(geom), 3))
FROM raw.open_buildings
WHERE study_area_id = :'area' AND confidence >= 0.75;

-- Spatial indexes
CREATE INDEX IF NOT EXISTS road_geom_idx     ON core.road     USING gist (geom);
CREATE INDEX IF NOT EXISTS river_geom_idx    ON core.river    USING gist (geom);
CREATE INDEX IF NOT EXISTS building_geom_idx ON core.building USING gist (geom);
CREATE INDEX IF NOT EXISTS road_area_idx     ON core.road (study_area_id);
CREATE INDEX IF NOT EXISTS river_area_idx    ON core.river (study_area_id);
CREATE INDEX IF NOT EXISTS building_area_idx ON core.building (study_area_id);

ANALYZE core.road; ANALYZE core.river; ANALYZE core.building;