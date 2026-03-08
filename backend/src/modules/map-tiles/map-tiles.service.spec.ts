import { Test, TestingModule } from '@nestjs/testing';
import { MapTilesService } from './map-tiles.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CopernicusService } from './copernicus.service';

describe('MapTilesService', () => {
  let service: MapTilesService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MapTilesService,
        {
          provide: PrismaService,
          useValue: {},
        },
        {
          provide: CopernicusService,
          useValue: {},
        },
      ],
    }).compile();

    service = module.get<MapTilesService>(MapTilesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
