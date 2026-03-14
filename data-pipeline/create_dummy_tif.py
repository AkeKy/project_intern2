import numpy as np
import rasterio
from rasterio.transform import from_origin

def create_dummy_tif(filename="dummy_map.tif"):
    # Create a 512x512 dummy image with some gradient
    width = 512
    height = 512
    
    # Generate some dummy data (e.g., 8-bit values 0-255)
    x = np.linspace(0, 255, width)
    y = np.linspace(0, 255, height)
    xv, yv = np.meshgrid(x, y)
    data = (xv**2 + yv**2) / (2 * 255)
    data = data.astype(np.uint8)

    # Define the geotransform
    # Roughly around the coordinates in Thailand (similar to download_s2.py)
    # min_lat: 14.0, min_lon: 100.0
    res = 0.0001
    transform = from_origin(100.0, 14.1, res, res)
    
    # Create the TIF file
    with rasterio.open(
        filename,
        'w',
        driver='GTiff',
        height=height,
        width=width,
        count=1,
        dtype=data.dtype,
        crs='+proj=latlong',
        transform=transform,
    ) as dst:
        dst.write(data, 1)

    print(f"Created dummy TIF: {filename}")

if __name__ == "__main__":
    create_dummy_tif()
