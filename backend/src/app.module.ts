import { Module } from '@nestjs/common';
import { ServeStaticModule } from '@nestjs/serve-static';
import { ConfigModule } from '@nestjs/config';
import { join } from 'path';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { PlotsModule } from './modules/plots/plots.module';
import { CarbonModule } from './modules/carbon/carbon.module';
import { SitesModule } from './modules/sites/sites.module';
import { MapTilesModule } from './modules/map-tiles/map-tiles.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    ServeStaticModule.forRoot({
      rootPath: join(__dirname, '..', 'public'),
      serveRoot: '/static',
    }),
    PrismaModule,
    PlotsModule,
    CarbonModule,
    SitesModule,
    MapTilesModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
