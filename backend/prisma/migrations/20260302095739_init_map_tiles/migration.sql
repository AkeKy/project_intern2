-- CreateEnum
CREATE TYPE "LayerType" AS ENUM ('RGB', 'NDVI');

-- CreateTable
CREATE TABLE "carbon_records" (
    "id" TEXT NOT NULL,
    "plot_id" TEXT NOT NULL,
    "start_date" TIMESTAMP(3) NOT NULL,
    "harvest_date" TIMESTAMP(3) NOT NULL,
    "total_days" INTEGER NOT NULL,
    "carbon_credit_ton" DOUBLE PRECISION NOT NULL,
    "revenue_thb" DOUBLE PRECISION NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "carbon_records_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "map_tile_records" (
    "id" TEXT NOT NULL,
    "farm_id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "layer_type" "LayerType" NOT NULL,
    "min_zoom" INTEGER NOT NULL DEFAULT 10,
    "max_zoom" INTEGER NOT NULL DEFAULT 18,
    "base_url" TEXT NOT NULL,
    "cloud_cover" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "map_tile_records_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "map_tile_records_farm_id_date_idx" ON "map_tile_records"("farm_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "map_tile_records_farm_id_date_layer_type_key" ON "map_tile_records"("farm_id", "date", "layer_type");

-- AddForeignKey
ALTER TABLE "carbon_records" ADD CONSTRAINT "carbon_records_plot_id_fkey" FOREIGN KEY ("plot_id") REFERENCES "plots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
