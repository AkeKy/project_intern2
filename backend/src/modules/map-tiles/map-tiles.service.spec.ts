import { Test, TestingModule } from '@nestjs/testing';
import { MapTilesService } from './map-tiles.service';

describe('MapTilesService', () => {
  let service: MapTilesService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [MapTilesService],
    }).compile();

    service = module.get<MapTilesService>(MapTilesService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
