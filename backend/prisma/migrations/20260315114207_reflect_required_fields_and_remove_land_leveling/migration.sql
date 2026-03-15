/*
  Warnings:

  - You are about to drop the column `land_leveling` on the `plots` table. All the data in the column will be lost.
  - Made the column `cloud_cover` on table `plot_ndvi_history` required. This step will fail if there are existing NULL values in that column.
  - Made the column `geometry` on table `plots` required. This step will fail if there are existing NULL values in that column.
  - Made the column `area_ha` on table `plots` required. This step will fail if there are existing NULL values in that column.
  - Made the column `area_rai` on table `plots` required. This step will fail if there are existing NULL values in that column.
  - Made the column `irrigation_source` on table `plots` required. This step will fail if there are existing NULL values in that column.
  - Made the column `site_id` on table `plots` required. This step will fail if there are existing NULL values in that column.
  - Made the column `province` on table `sites` required. This step will fail if there are existing NULL values in that column.
  - Made the column `latitude` on table `sites` required. This step will fail if there are existing NULL values in that column.
  - Made the column `longitude` on table `sites` required. This step will fail if there are existing NULL values in that column.

*/
-- DropForeignKey
ALTER TABLE "plots" DROP CONSTRAINT "plots_site_id_fkey";

-- AlterTable
ALTER TABLE "plot_ndvi_history" ALTER COLUMN "cloud_cover" SET NOT NULL;

-- AlterTable
ALTER TABLE "plots" DROP COLUMN "land_leveling",
ALTER COLUMN "geometry" SET NOT NULL,
ALTER COLUMN "area_ha" SET NOT NULL,
ALTER COLUMN "area_rai" SET NOT NULL,
ALTER COLUMN "irrigation_source" SET NOT NULL,
ALTER COLUMN "site_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "sites" ALTER COLUMN "province" SET NOT NULL,
ALTER COLUMN "latitude" SET NOT NULL,
ALTER COLUMN "longitude" SET NOT NULL;

-- AddForeignKey
ALTER TABLE "plots" ADD CONSTRAINT "plots_site_id_fkey" FOREIGN KEY ("site_id") REFERENCES "sites"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
