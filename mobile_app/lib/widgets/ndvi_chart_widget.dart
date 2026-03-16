import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/plot_ndvi_history.dart';

class NdviChartWidget extends StatefulWidget {
  final List<PlotNdviHistory> history;
  final VoidCallback? onRetry;

  const NdviChartWidget({super.key, required this.history, this.onRetry});

  @override
  State<NdviChartWidget> createState() => _NdviChartWidgetState();
}

class _NdviChartWidgetState extends State<NdviChartWidget> {
  int _selectedDays = 180;

  @override
  Widget build(BuildContext context) {
    if (widget.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่มีข้อมูล NDVI สำหรับแปลงนี้',
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'ระบบกำลังดึงข้อมูลจากดาวเทียม\nอาจใช้เวลาสักครู่',
              style: TextStyle(color: Colors.white30, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('ลองใหม่อีกครั้ง'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 1. Filter and Sort
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(days: _selectedDays));

    final filteredHistory = widget.history.where((item) {
      return DateTime.parse(item.date).isAfter(cutoffDate);
    }).toList();

    filteredHistory.sort(
      (a, b) => DateTime.parse(a.date).compareTo(DateTime.parse(b.date)),
    );

    if (filteredHistory.isEmpty) {
      return _buildEmptyContent('ไม่มีข้อมูลในช่วง $_selectedDays วันที่เลือก');
    }

    final minDate = DateTime.parse(filteredHistory.first.date);
    final maxDate = DateTime.parse(filteredHistory.last.date);
    final dateRangeSpan = maxDate.difference(minDate).inDays;

    final List<FlSpot> meanSpots = [];
    final List<FlSpot> maxSpots = [];
    final List<FlSpot> minSpots = [];

    for (var stat in filteredHistory) {
      final date = DateTime.parse(stat.date);
      final xValue = date.difference(minDate).inDays.toDouble();
      meanSpots.add(FlSpot(xValue, stat.mean));
      maxSpots.add(FlSpot(xValue, stat.max));
      minSpots.add(FlSpot(xValue, stat.min));
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2130),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Historical',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'NDVI',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildFilterToggle(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendItem('Max', Colors.blue.shade300),
              const SizedBox(width: 12),
              _buildLegendItem('Mean', Colors.greenAccent),
              const SizedBox(width: 12),
              _buildLegendItem('Min', Colors.blue.shade700),
            ],
          ),
          const SizedBox(height: 20),
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
                      const FlLine(color: Colors.white10, strokeWidth: 1),
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
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: (dateRangeSpan / 3).clamp(1, 180).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final date = minDate.add(Duration(days: value.toInt()));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Transform.rotate(
                            angle: -45 * 3.14159 / 180,
                            child: Text(
                              DateFormat('MMM d').format(date),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
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
                  _lineData(minSpots, Colors.blue.shade700, 2),
                  _lineData(maxSpots, Colors.blue.shade300, 2),
                  _lineData(meanSpots, Colors.greenAccent, 3, shaded: true),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.black87,
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
                          '${DateFormat('MMM d').format(date)}\n$prefix${spot.y.toStringAsFixed(3)}',
                          const TextStyle(color: Colors.white, fontSize: 11),
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

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [60, 120, 180].map((days) {
          final isSelected = _selectedDays == days;
          return GestureDetector(
            onTap: () => setState(() => _selectedDays = days),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.greenAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${days}D',
                style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  LineChartBarData _lineData(
    List<FlSpot> spots,
    Color color,
    double width, {
    bool shaded = false,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: shaded,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.2), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildEmptyContent(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, size: 40, color: Colors.white24),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Colors.white30)),
          const SizedBox(height: 10),
          _buildFilterToggle(),
        ],
      ),
    );
  }
}

