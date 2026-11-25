import sys
from pathlib import Path
import geopandas as gpd
from src.ingest.common import get_study_area, write_raw

def main(area_id):
    area = get_study_area(area_id)
    shp = next(Path("data/raw/hydrorivers").rglob("HydroRIVERS_v10_af.shp"))
    rivers = gpd.read_file(shp, mask=area)   # reads only rivers that touch the study area
    rivers = rivers[["HYRIV_ID", "ORD_STRA", "UPLAND_SKM", "DIS_AV_CMS", "geometry"]]
    rivers.columns = ["hyriv_id", "stream_order", "upland_km2", "avg_discharge_cms", "geometry"]
    write_raw(rivers, "hydrorivers", area_id)

if __name__ == "__main__":
    main(sys.argv[1])