class PlotNdviHistory {
  final String date;
  final double mean;
  final double max;
  final double min;
  final double? cloudCover;

  PlotNdviHistory({
    required this.date,
    required this.mean,
    required this.max,
    required this.min,
    this.cloudCover,
  });

  factory PlotNdviHistory.fromJson(Map<String, dynamic> json) {
    return PlotNdviHistory(
      date: json['date'],
      mean: (json['mean'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      cloudCover: json['cloudCover'] != null
          ? (json['cloudCover'] as num).toDouble()
          : null,
    );
  }
}
