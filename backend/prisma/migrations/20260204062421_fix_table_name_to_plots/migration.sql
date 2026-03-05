/*
  Warnings:

  - You are about to drop the `User` table. If the table is not empty, all the data it contains will be lost.

*/
-- DropTable
DROP TABLE "User";

-- CreateTable
CREATE TABLE "plots" (
    "id" TEXT NOT NULL,
    "farm_id" TEXT NOT NULL,
    "plot_name" TEXT NOT NULL,
    "geometry" geometry(Polygon, 4326),
    "area_ha" DOUBLE PRECISION,
    "area_rai" DOUBLE PRECISION,
    "plot_type" TEXT NOT NULL,
    "irrigation_source" TEXT,
    "land_leveling" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "plots_pkey" PRIMARY KEY ("id")
);
