import { Test, TestingModule } from '@nestjs/testing';
import { MapTilesController } from './map-tiles.controller';
import { MapTilesService } from './map-tiles.service';

describe('MapTilesController', () => {
  let controller: MapTilesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [MapTilesController],
      providers: [
        {
          provide: MapTilesService,
          useValue: {},
        },
      ],
    }).compile();

    controller = module.get<MapTilesController>(MapTilesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
