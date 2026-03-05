import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { SaveCarbonDto } from './dto/save-carbon.dto';

// Constants from IPCC / T-VER methodology (pages 20-21)
const GWP_CH4 = 28;
const GWP_N2O = 265;
const DAYS_IN_SEASON = 120;
const EF_CH4_BASELINE = 1.3; // kg CH4/ha/day
const EF_CH4_AWD = 0.65; // kg CH4/ha/day (50% reduction via AWD)
const EF_N2O = 0.003; // N2O emission factor for flooded rice
const RAI_TO_HA = 6.25;
const THB_PER_TON = 350; // Approximate market price

export interface CarbonCreditResult {
  area_ha: number;
  baseline_emission_kg: number;
  project_emission_kg: number;
  carbon_credit_ton: number;
  revenue_thb_est: number;
}

@Injectable()
export class CarbonService {
  constructor(private prisma: PrismaService) {}

  calculateCarbonCredit(
    areaRai: number,
    isAWD: boolean,
    fertilizerN_kg_ha = 0,
    startDate?: string,
    harvestDate?: string,
  ): CarbonCreditResult & { totalDays: number } {
    const areaHa = areaRai / RAI_TO_HA;

    // Determine days in season
    let daysInSeason = DAYS_IN_SEASON;
    if (startDate && harvestDate) {
      const start = new Date(startDate);
      const end = new Date(harvestDate);
      const diffTime = end.getTime() - start.getTime();
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
      if (diffDays > 0) {
        daysInSeason = diffDays;
      }
    }

    // CH4 (Methane) calculation
    const ch4Baseline = EF_CH4_BASELINE * daysInSeason * areaHa * GWP_CH4;
    const ch4Project = isAWD
      ? EF_CH4_AWD * daysInSeason * areaHa * GWP_CH4
      : ch4Baseline;

    // N2O (Nitrous Oxide) calculation
    const n2oEmission =
      fertilizerN_kg_ha * EF_N2O * (44 / 28) * GWP_N2O * areaHa;

    // Total emissions
    const totalBaseline = ch4Baseline + n2oEmission;
    const totalProject = ch4Project + n2oEmission;
    const reduction = totalBaseline - totalProject;

    return {
      area_ha: parseFloat(areaHa.toFixed(2)),
      baseline_emission_kg: parseFloat(totalBaseline.toFixed(2)),
      project_emission_kg: parseFloat(totalProject.toFixed(2)),
      carbon_credit_ton: parseFloat((reduction / 1000).toFixed(3)),
      revenue_thb_est: parseFloat(
        ((reduction / 1000) * THB_PER_TON).toFixed(2),
      ),
      totalDays: daysInSeason,
    };
  }

  async saveCalculation(dto: SaveCarbonDto) {
    // 1. Calculate
    const result = this.calculateCarbonCredit(
      dto.areaRai,
      dto.isAWD,
      dto.fertilizerN_kg_ha,
      dto.startDate,
      dto.harvestDate,
    );

    // 2. Save to DB
    const record = await this.prisma.carbonRecord.create({
      data: {
        plotId: dto.plotId,
        startDate: new Date(dto.startDate),
        harvestDate: new Date(dto.harvestDate),
        totalDays: result.totalDays,
        carbonCreditTon: result.carbon_credit_ton,
        revenueThb: result.revenue_thb_est,
      },
    });

    return { ...result, recordId: record.id };
  }

  async getSiteSummary(siteId: string) {
    const plots = await this.prisma.plot.findMany({
      where: { siteId },
      include: {
        carbonRecords: {
          orderBy: { createdAt: 'desc' },
          take: 1, // Get latest record only
        },
      },
    });

    let totalCarbon = 0;
    let totalRevenue = 0;
    let totalPlots = 0;

    for (const plot of plots) {
      if (plot.carbonRecords.length > 0) {
        const record = plot.carbonRecords[0];
        totalCarbon += record.carbonCreditTon;
        totalRevenue += record.revenueThb;
        totalPlots++;
      }
    }

    return {
      siteId,
      totalPlots,
      totalCarbon: parseFloat(totalCarbon.toFixed(3)),
      totalRevenue: parseFloat(totalRevenue.toFixed(2)),
    };
  }
}
