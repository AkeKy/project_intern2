# Sentinel-2 Map Tile Server Integration Guide

This document outlines the architecture and integration process for the Sentinel-2 Map Tile Server module, designed to provide high-resolution (S2DR) NDVI and RGB map tiles to the main application.

## 🏗️ Architecture Overview

The system consists of three main decoupled components:

1.  **Data Processing Pipeline (`data-pipeline/`)**
    - **Role:** Takes raw `.tif` files (e.g., from Google Earth Engine or Colab S2DR4 models) and processes them into XYZ Map Tiles (`.png`).
    - **Tech Stack:** Python 3, GDAL (via Docker `ghcr.io/osgeo/gdal`).
    - **Integration Point:** Submits HTTP `POST` requests to the Backend API to register the generated tiles.

2.  **Backend Tile Server (`backend/`)**
    - **Role:** Hosts the generated XYZ tiles as static files and manages the metadata (which farm has which dates and layer types) via a database.
    - **Tech Stack:** NestJS, Prisma ORM, PostgreSQL.
    - **Integration Points:**
      - `GET /map-tiles/:farmId/dates` -> Returns available dates for a farm.
      - `GET /map-tiles/:farmId/:date/layers` -> Returns available layers (e.g., NDVI, RGB) and their base URLs.
      - Static File Hosting at `/static/tiles/...`

3.  **Mobile Client (`mobile_app/`)**
    - **Role:** Consumes the Backend API to discover available maps and uses the base URLs to render the tiles on an interactive map.
    - **Tech Stack:** Flutter, `flutter_map` package.

---

## 🚀 How to Integrate into the Main App

When migrating this module into the main enterprise application, follow these steps:

### Phase 1: Database Migration (Backend)

You need to add the `MapTileRecord` table to your main application's database schema.

1.  Copy the `MapTileRecord` model and `LayerType` enum from this project's `prisma/schema.prisma` into your main `schema.prisma`.
2.  Run `npx prisma format` and `npx prisma migrate dev --name add_map_tiles` in your main project.
3.  Run `npx prisma generate`.

### Phase 2: Backend Module Integration (NestJS)

1.  Copy the entire `src/modules/map-tiles/` directory into your main NestJS project's `src/modules/` folder.
2.  Import `MapTilesModule` into your main `app.module.ts`.
3.  **Crucial:** Ensure your main NestJS application is configured to serve static files. In your main `app.module.ts`, adapt the `ServeStaticModule` configuration to point to where the tiles will be stored (e.g., a shared `public` directory or an AWS S3 bucket proxy).

    ```typescript
    import { ServeStaticModule } from '@nestjs/serve-static';
    import { join } from 'path';

    @Module({
      imports: [
        ServeStaticModule.forRoot({
          rootPath: join(__dirname, '..', 'public'), // Path to tiles
          serveRoot: '/static',
        }),
        MapTilesModule,
        // ... other modules
      ]
    })
    ```

### Phase 3: Data Pipeline Setup

The data pipeline can run anywhere (a cron job server, a cloud function, or the same server as the backend), as long as it has Python and Docker installed.

1.  Copy the `data-pipeline/generate_tiles.py` script.
2.  Ensure the server running this script has Docker installed (`osgeo/gdal` image is required).
3.  When running the script, pass the correct `--api-url` pointing to your main backend's `/map-tiles` endpoint and `--public-dir` pointing to the storage location.

    ```bash
    python generate_tiles.py \
      --tif /path/to/S2DR4_NDVI.tif \
      --farm-id "FARM_001" \
      --date "2026-03-02" \
      --layer-type "NDVI" \
      --api-url "https://api.your-main-app.com" \
      --public-dir "/var/www/main-app/public"
    ```

### Phase 4: Frontend/Mobile Integration (Flutter)

1.  Ensure your main Flutter app has the `flutter_map` dependency installed.
2.  Create a service in your Flutter app to call the new backend endpoints (`/map-tiles/...`).
3.  Use the returned `baseUrl` to configure a `TileLayer` in your `FlutterMap` widget.

    ```dart
    TileLayer(
      urlTemplate: "https://api.your-main-app.com$baseUrl/{z}/{x}/{y}.png",
    )
    ```

---

## 🛠️ Maintenance & Scale

- **Storage:** As the number of farms grows, storing tiles on the backend VM's local disk will become unmanageable. The `ServeStaticModule` should eventually be replaced by uploading the generated `XYZ` directories directly to AWS S3, Google Cloud Storage, or an edge CDN. The backend's `baseUrl` would then point to the CDN instead of `/static/`.
- **Pipeline Automation:** The python pipeline is currently triggered manually per TIF file. For production, this should be wrapped in an event-driven flow (e.g., an AWS Lambda function that triggers when a new TIF is dropped into an S3 bucket).
