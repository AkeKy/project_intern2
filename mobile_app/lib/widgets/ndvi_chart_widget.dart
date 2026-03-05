import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/plot_ndvi_history.dart';

class NdviChartWidget extends StatelessWidget {
  final List<PlotNdviHistory> history;

  const NdviChartWidget({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'No NDVI history available for this plot.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // Sort history by date to ensure proper timeline
    final sortedHistory = List<PlotNdviHistory>.from(
      history,
    )..sort((a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)));

    final minDate = DateTime.parse(sortedHistory.first.date);
    final maxDate = DateTime.parse(sortedHistory.last.date);
    final dateRangeSpan = maxDate.difference(minDate).inDays;

    // We convert Dates to double (days from minDate) for X-axis
    List<FlSpot> meanSpots = [];
    List<FlSpot> maxSpots = [];
    List<FlSpot> minSpots = [];

    for (var stat in sortedHistory) {
      final date = DateTime.parse(stat.date);
      final xValue = date.difference(minDate).inDays.toDouble();
      meanSpots.add(FlSpot(xValue, stat.mean));
      maxSpots.add(FlSpot(xValue, stat.max));
      minSpots.add(FlSpot(xValue, stat.min));
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2130), // Dark premium background
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Historical',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'NDVI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildLegendItem('Max', Colors.blue.shade300),
                  const SizedBox(width: 12),
                  _buildLegendItem('Mean', Colors.greenAccent),
                  const SizedBox(width: 12),
                  _buildLegendItem('Min', Colors.blue.shade700),
                ],
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: -0.5,
                maxY: 1.0,
                minX: 0,
                maxX: dateRangeSpan.toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: false,
                  getDrawingVerticalLine: (value) =>
                      FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 60,
                      interval: dateRangeSpan > 0
                          ? (dateRangeSpan / 4)
                                .clamp(1, dateRangeSpan)
                                .toDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        final date = minDate.add(Duration(days: value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              DateFormat('MMM d, yyyy').format(date),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // MIN Line
                  LineChartBarData(
                    spots: minSpots,
                    isCurved: true,
                    color: Colors.blue.shade700,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // MAX Line
                  LineChartBarData(
                    spots: maxSpots,
                    isCurved: true,
                    color: Colors.blue.shade300,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // MEAN Line
                  LineChartBarData(
                    spots: meanSpots,
                    isCurved: true,
                    color: Colors.greenAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.greenAccent.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => Colors.black87,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = minDate.add(
                          Duration(days: spot.x.toInt()),
                        );
                        String prefix = "";
                        if (spot.barIndex == 0) prefix = "Min: ";
                        if (spot.barIndex == 1) prefix = "Max: ";
                        if (spot.barIndex == 2) prefix = "Mean: ";

                        return LineTooltipItem(
                          DateFormat('MMM d').format(date) +
                              '\n' +
                              prefix +
                              spot.y.toStringAsFixed(3),
                          const TextStyle(color: Colors.white, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
