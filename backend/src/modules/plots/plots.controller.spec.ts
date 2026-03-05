import { Test, TestingModule } from '@nestjs/testing';
import { PlotsController } from './plots.controller';
import { PlotsService } from './plots.service';

describe('PlotsController', () => {
  let controller: PlotsController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [PlotsController],
      providers: [PlotsService],
    }).compile();

    controller = module.get<PlotsController>(PlotsController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
