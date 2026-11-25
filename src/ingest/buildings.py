import sys
from pathlib import Path
import geopandas as gpd
import pandas as pd
from src.ingest.common import get_study_area, write_raw

COLS = ["latitude", "longitude", "area_in_meters", "confidence", "geometry", "full_plus_code"]

def main(area_id):
    poly = get_study_area(area_id).geometry.iloc[0]
    minx, miny, maxx, maxy = poly.bounds

    parts = []
    for f in Path("data/raw/open_buildings").glob("*.csv.gz"):
        for chunk in pd.read_csv(f, usecols=COLS, chunksize=500_000):
            c = chunk[chunk.latitude.between(miny, maxy)
                      & chunk.longitude.between(minx, maxx)
                      & (chunk.confidence >= 0.65)]
            if len(c):
                parts.append(c)
    df = pd.concat(parts, ignore_index=True)

    # Keep buildings whose centre point falls inside the study area
    pts = gpd.GeoSeries(gpd.points_from_xy(df.longitude, df.latitude), crs=4326)
    df = df[pts.within(poly).values]

    gdf = gpd.GeoDataFrame(
        df.drop(columns=["geometry", "latitude", "longitude"]),
        geometry=gpd.GeoSeries.from_wkt(df["geometry"]), crs=4326,
    )
    write_raw(gdf, "open_buildings", area_id)

if __name__ == "__main__":
    main(sys.argv[1])