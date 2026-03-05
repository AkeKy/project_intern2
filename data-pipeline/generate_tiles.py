import os
import sys
import argparse
import subprocess
import requests

def main():
    parser = argparse.ArgumentParser(description="Generate XYZ tiles from TIF and register to backend.")
    parser.add_argument("--tif", required=True, help="Path to input TIF file")
    parser.add_argument("--farm-id", required=True, help="Farm ID")
    parser.add_argument("--date", required=True, help="Date in YYYY-MM-DD format")
    parser.add_argument("--layer-type", required=True, choices=["RGB", "NDVI"], help="Layer type")
    parser.add_argument("--api-url", default="http://localhost:3000", help="Base URL of backend API")
    parser.add_argument("--public-dir", default="../backend/public", help="Path to backend public directory")
    
    args = parser.parse_args()

    # Determine absolute paths
    tif_abs = os.path.abspath(args.tif)
    public_abs = os.path.abspath(args.public_dir)

    if not os.path.exists(tif_abs):
        print(f"Error: Input TIF file not found: {tif_abs}")
        sys.exit(1)

    # Output directory for tiles
    tile_rel_path = f"tiles/{args.farm_id}/{args.date}/{args.layer_type.upper()}"
    output_dir = os.path.join(public_abs, tile_rel_path)
    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating tiles from {tif_abs} to {output_dir}")

    # Use Docker to run gdal2tiles
    # Mount the input directory and output directory
    input_dir = os.path.dirname(tif_abs)
    input_filename = os.path.basename(tif_abs)

    docker_cmd = [
        "docker", "run", "--rm",
        "-v", f"{input_dir}:/input:ro",
        "-v", f"{output_dir}:/output:rw",
        "ghcr.io/osgeo/gdal:ubuntu-small-latest",
        "gdal2tiles.py",
        "-p", "mercator",
        "-z", "15-20",  # Zoom levels
        "-w", "none",   # No web viewer
        f"/input/{input_filename}",
        "/output"
    ]

    print(f"Running command: {' '.join(docker_cmd)}")
    result = subprocess.run(docker_cmd)

    if result.returncode != 0:
        print("Error: gdal2tiles failed.")
        sys.exit(result.returncode)

    print("Tiles generated successfully.")

    # Register to backend
    api_endpoint = f"{args.api_url}/map-tiles"
    base_url = f"/static/{tile_rel_path}"

    payload = {
        "farmId": args.farm_id,
        "date": args.date + "T00:00:00Z", # Ensure ISO format
        "layerType": args.layer_type.upper(),
        "minZoom": 15,
        "maxZoom": 20,
        "baseUrl": base_url,
    }

    try:
        print(f"Registering tile to API: {api_endpoint}")
        response = requests.post(api_endpoint, json=payload)
        response.raise_for_status()
        print("Successfully registered map tile record.")
    except requests.exceptions.RequestException as e:
        print(f"Error registering to backend: {e}")
        if response is not None:
            print(f"Server response: {response.text}")
        sys.exit(1)

if __name__ == "__main__":
    main()
