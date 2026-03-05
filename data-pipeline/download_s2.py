import requests
import os
import json
from datetime import datetime, timedelta

# This is a skeleton script for downloading Sentinel-2 L2A data.
# In a real-world scenario, you would use the Copernicus Data Space Ecosystem API (OData)
# or Google Earth Engine API.

COPERNICUS_API_URL = "https://catalogue.dataspace.copernicus.eu/odata/v1/Products"

def search_sentinel2_images(min_lat, min_lon, max_lat, max_lon, start_date, end_date, max_cloud_cover=20):
    """
    Searches the Copernicus Data Space for Sentinel-2 L2A imagery.
    """
    print(f"Searching for images between {start_date} and {end_date}...")
    
    # Constructing a basic OData query for Sentinel-2 L2A within a bounding box
    # Note: Requires proper authentication to download the actual image data.
    
    # Example WKT Bounding Box
    polygon_wkt = f"POLYGON(({min_lon} {min_lat}, {max_lon} {min_lat}, {max_lon} {max_lat}, {min_lon} {max_lat}, {min_lon} {min_lat}))"
    
    filter_query = (
        f"Attributes/OData.CSC.StringAttribute/any(att:att/Name eq 'productType' and att/OData.CSC.StringAttribute/Value eq 'S2MSI2A') and "
        f"OData.CSC.Intersects(area=geography'SRID=4326;{polygon_wkt}') and "
        f"ContentDate/Start ge {start_date}T00:00:00.000Z and ContentDate/Start le {end_date}T23:59:59.999Z and "
        f"Attributes/OData.CSC.DoubleAttribute/any(att:att/Name eq 'cloudCover' and att/OData.CSC.DoubleAttribute/Value le {max_cloud_cover})"
    )
    
    params = {
        "$filter": filter_query,
        "$top": 10,
        "$orderby": "ContentDate/Start desc"
    }

    try:
        response = requests.get(COPERNICUS_API_URL, params=params)
        response.raise_for_status()
        data = response.json()
        
        results = []
        for item in data.get("value", []):
            results.append({
                "id": item["Id"],
                "name": item["Name"],
                "date": item["ContentDate"]["Start"],
                "size": item["ContentLength"]
            })
        return results
        
    except Exception as e:
        print(f"Error searching for images: {e}")
        return []

def download_product(product_id, dest_dir):
    """
    Downloads a Sentinel-2 product by its ID.
    Requires OAuth2 token via Copernicus Data Space.
    """
    print(f"Placeholder: Downloading product {product_id} to {dest_dir}...")
    # NOTE: Actual download requires handling authentication and large file streams.
    # Download URL: https://zipper.dataspace.copernicus.eu/odata/v1/Products({product_id})/$value
    pass


if __name__ == "__main__":
    # Example coordinates roughly around a farm in Thailand
    farm_bbox = {
        "min_lat": 14.0,
        "min_lon": 100.0,
        "max_lat": 14.1,
        "max_lon": 100.1
    }
    
    end_date = datetime.now().strftime("%Y-%m-%d")
    start_date = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
    
    found_images = search_sentinel2_images(**farm_bbox, start_date=start_date, end_date=end_date)
    
    if found_images:
        print(f"Found {len(found_images)} images:")
        for img in found_images:
            print(f"- {img['date']}: {img['name']} (Size: {img['size']} bytes)")
    else:
        print("No images found matching the criteria.")
