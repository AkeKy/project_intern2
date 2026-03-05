import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
    ),
  )..interceptors.add(LogInterceptor(responseBody: true, requestBody: true));

  String _currentHost = 'http://127.0.0.1:3000'; // Offline ADB Reverse Proxy

  ApiService();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');

    if (savedIp != null && savedIp.isNotEmpty) {
      _currentHost = 'http://$savedIp:3000';
    }
  }

  /// Platform-aware base URL
  String get _host => _currentHost;

  /// Public base URL
  String get baseUrl => _currentHost;

  /// Update the server host IP
  Future<void> updateHost(String newIp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', newIp);
    _currentHost = 'http://$newIp:3000';
  }

  String get plotsUrl => '$_host/plots';
  String get sitesUrl => '$_host/sites';
  String get carbonUrl => '$_host/carbon/calculate';
  String get saveCarbonUrl => '$_host/carbon/save';

  // ─── Sites ────────────────────────────────────────────────

  /// Fetch all sites
  Future<List<dynamic>> fetchSites() async {
    try {
      final response = await _dio.get(sitesUrl);
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching sites: $e');
    }
    return [];
  }

  /// Create a new site
  Future<Map<String, dynamic>?> createSite({
    required String name,
    required String farmId,
    String? province,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _dio.post(
        sitesUrl,
        data: {
          "name": name,
          "farmId": farmId,
          if (province != null) "province": province,
          if (latitude != null) "latitude": latitude,
          if (longitude != null) "longitude": longitude,
        },
      );
      if (response.statusCode == 201) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error creating site: $e');
    }
    return null;
  }

  // ─── Plots ────────────────────────────────────────────────

  /// Fetch all saved plots
  Future<List<dynamic>> fetchPlots() async {
    try {
      final response = await _dio.get(plotsUrl);
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching plots: $e');
    }
    return [];
  }

  /// Fetch plots for a specific site
  Future<List<dynamic>> fetchPlotsBySite(String siteId) async {
    try {
      final response = await _dio.get('$plotsUrl/site/$siteId');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching plots by site: $e');
    }
    return [];
  }

  /// Create a new plot
  Future<Map<String, dynamic>?> createPlot({
    required String farmId,
    required String plotName,
    required String plotType,
    required List<Map<String, double>> coordinates,
    String? siteId,
  }) async {
    final response = await _dio.post(
      plotsUrl,
      data: {
        "farmId": farmId,
        "plotName": plotName,
        "plotType": plotType,
        "coordinates": coordinates,
        if (siteId != null) "siteId": siteId,
      },
    );
    if (response.statusCode == 201) {
      return response.data;
    }
    return null;
  }

  // ─── Carbon ───────────────────────────────────────────────

  /// Calculate carbon credit
  Future<Map<String, dynamic>?> calculateCarbon({
    required double areaRai,
    required bool isAWD,
  }) async {
    try {
      final response = await _dio.post(
        carbonUrl,
        data: {"areaRai": areaRai, "isAWD": isAWD},
      );
      if (response.statusCode == 201) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Carbon calc failed: $e');
    }
    return null;
  }

  /// Save carbon calculation
  Future<Map<String, dynamic>?> saveCarbonCalculation({
    required String plotId,
    required double areaRai,
    required bool isAWD,
    required DateTime startDate,
    required DateTime harvestDate,
  }) async {
    try {
      final response = await _dio.post(
        saveCarbonUrl,
        data: {
          "plotId": plotId,
          "areaRai": areaRai,
          "isAWD": isAWD,
          "startDate": startDate.toIso8601String(),
          "harvestDate": harvestDate.toIso8601String(),
        },
      );
      if (response.statusCode == 201) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Carbon save failed: $e');
    }
    return null;
  }

  /// Get site summary
  Future<Map<String, dynamic>?> getSiteSummary(String siteId) async {
    try {
      final response = await _dio.get('$_host/carbon/summary/$siteId');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching site summary: $e');
    }
    return null;
  }

  // ─── Map Tiles ────────────────────────────────────────────

  /// Get available dates with map tiles for a plot
  Future<List<dynamic>> fetchMapDates(String plotId) async {
    try {
      final response = await _dio.get('$_host/map-tiles/$plotId/dates');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching map dates: $e');
    }
    return [];
  }

  /// Get available map layers for a plot on a specific date
  Future<List<dynamic>> fetchMapLayers(String plotId, String date) async {
    try {
      final response = await _dio.get('$_host/map-tiles/$plotId/$date/layers');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching map layers: $e');
    }
    return [];
  }

  /// Get NDVI historical data for a plot
  Future<List<dynamic>> fetchNdviHistory(String plotId) async {
    try {
      final response = await _dio.get('$_host/plots/$plotId/ndvi-history');
      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching NDVI history: $e');
    }
    return [];
  }
}
