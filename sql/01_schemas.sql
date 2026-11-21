CREATE EXTENSION IF NOT EXISTS postgis;

CREATE SCHEMA IF NOT EXISTS raw;        -- layers as downloaded
CREATE SCHEMA IF NOT EXISTS core;       -- cleaned, clipped layers
CREATE SCHEMA IF NOT EXISTS analysis;   -- 30 m grid and model outputs
CREATE SCHEMA IF NOT EXISTS scenario;   -- rainfall scenarios and exposure

CREATE TABLE IF NOT EXISTS core.study_area (
    study_area_id  text PRIMARY KEY,
    name           text NOT NULL,
    province       text NOT NULL,
    utm_epsg       integer NOT NULL,
    area_km2       numeric(10, 2),
    geom           geometry(MultiPolygon, 4326) NOT NULL,
    loaded_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS study_area_geom_idx ON core.study_area USING gist (geom);