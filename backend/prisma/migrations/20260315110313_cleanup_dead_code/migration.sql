/*
  Warnings:

  - You are about to drop the column `polyid` on the `plots` table. All the data in the column will be lost.
  - You are about to drop the `map_tile_records` table. If the table is not empty, all the data it contains will be lost.

*/
-- AlterTable
ALTER TABLE "plots" DROP COLUMN "polyid";

-- DropTable
DROP TABLE "map_tile_records";

-- DropEnum
DROP TYPE "LayerType";
