const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  const plots = await prisma.plot.findMany({ where: { siteId: null } });
  if (plots.length > 0) {
    console.log(
      `Found ${plots.length} orphaned plots. Creating default site...`,
    );
    const site = await prisma.site.create({
      data: {
        name: 'My Farm (Default)',
        farmId: 'user-123',
      },
    });
    console.log(`Created site: ${site.name} (${site.id})`);

    for (const plot of plots) {
      await prisma.plot.update({
        where: { id: plot.id },
        data: { siteId: site.id },
      });
    }
    console.log('Successfully assigned orphaned plots to the new site.');
  } else {
    console.log('No orphaned plots found.');
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
