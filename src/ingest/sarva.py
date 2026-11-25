import sys
import geopandas as gpd
from src.ingest.common import get_study_area, write_raw

def main(area_id, path, name):
    gdf = gpd.read_file(path, mask=get_study_area(area_id))
    gdf.columns = [c.lower() for c in gdf.columns]
    write_raw(gdf, f"sarva_{name}", area_id)

if __name__ == "__main__":
    main(*sys.argv[1:4])