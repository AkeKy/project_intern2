import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateSiteDto } from './dto/create-site.dto';

@Injectable()
export class SitesService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateSiteDto) {
    return await this.prisma.site.create({
      data: {
        name: dto.name,
        province: dto.province,
        latitude: dto.latitude,
        longitude: dto.longitude,
        farmId: dto.farmId,
      },
    });
  }

  async findAll(farmId?: string) {
    const where = farmId ? { farmId } : {};
    return await this.prisma.site.findMany({
      where,
      include: {
        plots: {
          select: { id: true, plotName: true, areaRai: true, plotType: true },
        },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: string) {
    return await this.prisma.site.findUnique({
      where: { id },
      include: {
        plots: {
          select: { id: true, plotName: true, areaRai: true, plotType: true },
        },
      },
    });
  }
}
