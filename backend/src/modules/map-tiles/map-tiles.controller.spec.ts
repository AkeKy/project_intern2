import { Test, TestingModule } from '@nestjs/testing';
import { MapTilesController } from './map-tiles.controller';

describe('MapTilesController', () => {
  let controller: MapTilesController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [MapTilesController],
    }).compile();

    controller = module.get<MapTilesController>(MapTilesController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
