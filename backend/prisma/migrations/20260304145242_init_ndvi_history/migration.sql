-- CreateTable
CREATE TABLE "plot_ndvi_history" (
    "id" TEXT NOT NULL,
    "plot_id" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "mean" DOUBLE PRECISION NOT NULL,
    "max" DOUBLE PRECISION NOT NULL,
    "min" DOUBLE PRECISION NOT NULL,
    "cloud_cover" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "plot_ndvi_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "plot_ndvi_history_plot_id_date_idx" ON "plot_ndvi_history"("plot_id", "date");

-- CreateIndex
CREATE UNIQUE INDEX "plot_ndvi_history_plot_id_date_key" ON "plot_ndvi_history"("plot_id", "date");

-- AddForeignKey
ALTER TABLE "plot_ndvi_history" ADD CONSTRAINT "plot_ndvi_history_plot_id_fkey" FOREIGN KEY ("plot_id") REFERENCES "plots"("id") ON DELETE CASCADE ON UPDATE CASCADE;
