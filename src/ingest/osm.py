import geopandas as gpd
from sqlalchemy import text
from src.db.connection import get_engine

def get_study_area(area_id):
    sql = "SELECT study_area_id, utm_epsg, geom FROM core.study_area WHERE study_area_id = %(id)s"
    return gpd.read_postgis(sql, get_engine(), params={"id": area_id}, geom_col="geom")

def write_raw(gdf, table, area_id):
    gdf = gdf.to_crs(4326).copy()
    gdf["study_area_id"] = area_id
    if gdf.geometry.name != "geom":
        gdf = gdf.rename_geometry("geom")
    with get_engine().begin() as conn:
        if conn.execute(text("SELECT to_regclass(:t)"), {"t": f"raw.{table}"}).scalar():
            conn.execute(text(f"DELETE FROM raw.{table} WHERE study_area_id = :id"), {"id": area_id})
        gdf.to_postgis(table, conn, schema="raw", if_exists="append", index=False)
    print(f"raw.{table}: {len(gdf):,} rows for {area_id}")
