import sys
from pathlib import Path
import geopandas as gpd
import osmnx as ox
import yaml
from shapely.geometry import MultiPolygon
from sqlalchemy import text
from src.db.connection import get_engine

ROOT = Path(__file__).resolve().parents[2]

def main(area_id):
    settings = yaml.safe_load(open(ROOT / "config" / "settings.yaml"))
    area = settings["study_areas"][area_id]

    # 1. Get the boundary from OpenStreetMap
    geom = ox.geocode_to_gdf(area["osm_query"]).to_crs(4326).geometry.union_all()
    if geom.geom_type == "Polygon":
        geom = MultiPolygon([geom])

    # 2. Measure area in metres (UTM), not degrees
    area_km2 = gpd.GeoSeries([geom], crs=4326).to_crs(area["utm_epsg"]).area.iloc[0] / 1e6

    gdf = gpd.GeoDataFrame({
        "study_area_id": [area_id], "name": [area["name"]],
        "province": [area["province"]], "utm_epsg": [area["utm_epsg"]],
        "area_km2": [round(area_km2, 2)],
    }, geometry=[geom], crs=4326).rename_geometry("geom")

    # 3. Replace this area's row in PostGIS
    with get_engine().begin() as conn:
        conn.execute(text("DELETE FROM core.study_area WHERE study_area_id = :id"), {"id": area_id})
        gdf.to_postgis("study_area", conn, schema="core", if_exists="append", index=False)

    print(f"Loaded {area['name']}: {area_km2:,.0f} km2")

if __name__ == "__main__":
    main(sys.argv[1])
