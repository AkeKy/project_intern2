const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/app.module');
const { PlotsService } = require('./dist/modules/plots/plots.service');

async function bootstrap() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const plotsService = app.get(PlotsService);
  
  const plot = await plotsService.create({
    farmId: 'test-user',
    plotName: 'AgroScriptTest',
    plotType: 'irrigated',
    coordinates: [
      { lat: 14.35, lng: 100.56 },
      { lat: 14.35, lng: 100.57 },
      { lat: 14.36, lng: 100.57 },
      { lat: 14.36, lng: 100.56 }
    ]
  });
  
  console.log('Result:', plot);
  await app.close();
}
bootstrap();
