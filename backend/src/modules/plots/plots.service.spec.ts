import { Test, TestingModule } from '@nestjs/testing';
import { PlotsService } from './plots.service';
import { PrismaService } from '../../prisma/prisma.service';
import { CopernicusService } from '../map-tiles/copernicus.service';

describe('PlotsService', () => {
  let service: PlotsService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        PlotsService,
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

    service = module.get<PlotsService>(PlotsService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
