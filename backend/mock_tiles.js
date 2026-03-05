const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const farmId = 'user-123';

  console.log(`Creating mock Map Tile Records for Farm ID: ${farmId}`);

  // Mock dates
  const dates = [
    new Date('2026-03-01T00:00:00Z'),
    new Date('2026-02-15T00:00:00Z'),
  ];

  for (const date of dates) {
    // RGB Layer
    await prisma.mapTileRecord.upsert({
      where: {
        farmId_date_layerType: {
          farmId,
          date,
          layerType: 'RGB',
        },
      },
      update: {},
      create: {
        farmId,
        date,
        layerType: 'RGB',
        minZoom: 10,
        maxZoom: 18,
        baseUrl: `/tiles/${farmId}/${date.toISOString().split('T')[0]}/rgb`,
        cloudCover: 5.5,
      },
    });

    // NDVI Layer
    await prisma.mapTileRecord.upsert({
      where: {
        farmId_date_layerType: {
          farmId,
          date,
          layerType: 'NDVI',
        },
      },
      update: {},
      create: {
        farmId,
        date,
        layerType: 'NDVI',
        minZoom: 10,
        maxZoom: 18,
        baseUrl: `/tiles/${farmId}/${date.toISOString().split('T')[0]}/ndvi`,
        cloudCover: 5.5,
      },
    });
  }

  console.log('Successfully created mock map tiles.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
