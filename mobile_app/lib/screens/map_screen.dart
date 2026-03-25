import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../message/app_localizations.dart';
import '../services/api_service.dart';
import '../utils/area_formatter.dart';
import '../widgets/map_layers.dart';
import '../models/plot_ndvi_history.dart';
import '../widgets/ndvi_chart_widget.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final List<LatLng> _polygonPoints = [];
  final LatLng _initialCenter = const LatLng(14.3532, 100.5684);
  final MapController _mapController = MapController();
  final ApiService _api = ApiService();

  // Sites & Ponds
  List<dynamic> _sites = [];
  Map<String, dynamic>? _activeSite; // Currently selected site
  List<dynamic> _sitePonds = []; // Ponds for active site

  // Map state
  LatLng? _currentPosition;
  double? _currentHeading;
  bool _isLoadingPonds = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Custom AI Map Layer State
  List<dynamic> _availableMapDates = [];
  String? _selectedMapDate;

  bool _hasConnectionError = false;

  List<dynamic> _availableLayers = [];
  String? _selectedLayerType; // e.g., 'RGB', 'NDVI'
  String? _selectedLayerBaseUrl;
  String? _activePlotId; // For selecting which plot's map layer to show

  @override
  void initState() {
    super.initState();
    _fetchSites();
    _initCompass();
  }

  // ─── Animated Rotation to North ──────────────────────────
  void _animateRotateToNorth() {
    final currentRotation = _mapController.camera.rotation;
    if (currentRotation == 0) return;

    final controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Take shortest path (e.g. -30° instead of 330°)
    double target = 0;
    double diff = target - currentRotation;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    final end = currentRotation + diff;

    final animation = Tween<double>(
      begin: currentRotation,
      end: end,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    animation.addListener(() {
      _mapController.rotate(animation.value);
    });
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });
    controller.forward();
  }

  // ─── Animated Move ───────────────────────────────────────
  void _moveAnimated(LatLng destLocation, double destZoom) {
    // Create some animation
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  // ─── Compass ─────────────────────────────────────────────
  void _initCompass() {
    FlutterCompass.events?.listen((event) {
      if (mounted) {
        setState(() => _currentHeading = event.heading);
      }
    });
  }

  // ─── Fetch Sites ────────────────────────────────────────
  Future<void> _fetchSites() async {
    try {
      if (mounted) setState(() => _hasConnectionError = false);
      
      await _api.init(); // Wait for stored IP configuration
      final sites = await _api.fetchSites();
      
      if (mounted) {
        setState(() => _sites = sites);
        // Auto-load the first site's plots so the map isn't empty on startup
        if (sites.isNotEmpty && _activeSite == null) {
          _selectSite(sites.first, moveCamera: true);
        }
      }
    } catch (e) {
      debugPrint('Initial fetch failed: $e');
      if (mounted) {
        setState(() => _hasConnectionError = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ตรวจสอบการตั้งค่า IP')),
        );
      }
    }
  }

  // ─── Select Site → Load Ponds ───────────────────────────
  Future<void> _selectSite(
    Map<String, dynamic> site, {
    bool moveCamera = true,
  }) async {
    if (mounted) setState(() => _isLoadingPonds = true);

    List<dynamic> ponds = [];
    bool fetchFailed = false;

    try {
      ponds = await _api.fetchPlotsBySite(site['id']);
    } catch (e) {
      debugPrint('Failed to load ponds: $e');
      fetchFailed = true;
    }

    if (!mounted) return;

    setState(() {
      _activeSite = site;
      _sitePonds = ponds;
      _polygonPoints.clear();
      _selectedMapDate = null;
      _selectedLayerType = null;
      _selectedLayerBaseUrl = null;
      _isLoadingPonds = false;
      _searchQuery = '';
      _searchController.clear();
      if (ponds.isNotEmpty) {
        _activePlotId = ponds.first['id'] as String;
      } else {
        _activePlotId = null;
      }
    });

    if (fetchFailed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'ไม่พบข้อมูลแปลง – ตรวจสอบการเชื่อมต่อเซิร์ฟเวอร์',
          ),
          action: SnackBarAction(
            label: 'ลองใหม่',
            onPressed: () => _selectSite(site, moveCamera: moveCamera),
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }

    // Check for available satellite imagery dates (uses active plot's ID)
    if (ponds.isNotEmpty && _activePlotId != null) {
      final plotId = _activePlotId!;
      final dates = await _api.fetchMapDates(plotId);
      if (mounted) setState(() => _availableMapDates = dates);
    } else {
      if (mounted) setState(() => _availableMapDates = []);
    }

    // Zoom to site location or first pond
    if (moveCamera) {
      if (ponds.isNotEmpty) {
        // PRIORITY 1: Fit to all plots in this site
        _fitToPonds(ponds);
      } else {
        // PRIORITY 2: Move to site centroid (only if valid and not a default city coordinate)
        final lat = site['latitude'] != null ? (site['latitude'] as num).toDouble() : 0.0;
        final lng = site['longitude'] != null ? (site['longitude'] as num).toDouble() : 0.0;

        // Skip moving to known default "city" coordinates (Bangkok/Ayutthaya) or (0,0)
        bool isDefaultCity = (lat == 13.7367 && lng == 100.5231) || 
                             (lat == 14.3532 && lng == 100.5684);

        if (lat != 0 && lng != 0 && !isDefaultCity) {
          _mapController.move(LatLng(lat, lng), 15.0);
        }
      }
    }
  }

  // ─── Fit map to show all ponds ──────────────────────────
  void _fitToPonds(List<dynamic> ponds) {
    final allPoints = <LatLng>[];
    for (final pond in ponds) {
      if (pond['geometry'] != null && pond['geometry']['coordinates'] != null) {
        try {
          final coordinates = pond['geometry']['coordinates'] as List<dynamic>;
          if (coordinates.isNotEmpty) {
            final ring = coordinates[0] as List<dynamic>;
            for (final dynamic p in ring) {
              final c = p as List<dynamic>;
              allPoints.add(
                LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              );
            }
          }
        } catch (e) {
          debugPrint('Error in _fitToPonds: $e');
        }
      }
    }
    if (allPoints.isNotEmpty) {
      final bounds = LatLngBounds.fromPoints(allPoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
      );
    }
  }

  // ─── Extract polygon from geometry ──────────────────────
  List<LatLng> _extractPolygon(dynamic geometry) {
    if (geometry == null || geometry['coordinates'] == null) return [];
    try {
      final coordinates = geometry['coordinates'] as List<dynamic>;
      if (coordinates.isEmpty) return [];

      final ring = coordinates[0] as List<dynamic>;
      return ring.map<LatLng>((dynamic point) {
        final p = point as List<dynamic>;
        return LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble());
      }).toList();
    } catch (e) {
      debugPrint('Error extracting polygon: $e');
      debugPrint('Raw geometry: $geometry');
      return [];
    }
  }

  // ─── GPS Location ────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    final t = AppLocalizations.of(context);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.tr('enableGps'))));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      _moveAnimated(_currentPosition!, 17.0);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // ─── Show Pond Details ──────────────────────────────────
  Future<void> _showPondDetails(Map<String, dynamic> pond) async {
    final t = AppLocalizations.of(context);
    final double areaRai = (pond['area_rai'] as num).toDouble();
    final String plotType = pond['plot_type'];
    final bool isAWD = plotType == 'irrigated';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final carbonResult = await _api.calculateCarbon(
      areaRai: areaRai,
      isAWD: isAWD,
    );

    List<PlotNdviHistory> ndviHistory = [];
    try {
      final ndviRaw = await _api.fetchNdviHistory(pond['id']);
      ndviHistory = ndviRaw
          .map((e) => PlotNdviHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch NDVI history: $e');
    }

    if (!mounted) return;
    Navigator.pop(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(pond['plot_name'] ?? t.tr('plotDetail')),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${t.tr('typeLabel')}: $plotType'),
                    Text('${t.tr('areaLabel')}: ${formatThaiArea(areaRai)}'),
                    const SizedBox(height: 10),
                    if (carbonResult != null) ...[
                      const Divider(),
                      Text(
                        t.tr('carbonResult'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${t.tr('gasReduction')}: ${carbonResult['carbon_credit_ton']} tCO₂e',
                      ),
                      Text(
                        '${t.tr('revenue')}: ${carbonResult['revenue_thb_est']} ${t.tr('bahtUnit')}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ] else
                      Text(t.tr('carbonCalcFailed')),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 350,
                      child: NdviChartWidget(
                        history: ndviHistory,
                        onRetry: () async {
                          // Show a small loader or just clear and fetch
                          try {
                            final ndviRaw = await _api.fetchNdviHistory(pond['id']);
                            setDialogState(() {
                              ndviHistory = ndviRaw
                                  .map((e) => PlotNdviHistory.fromJson(e as Map<String, dynamic>))
                                  .toList();
                            });
                          } catch (e) {
                            debugPrint('Retry failed: $e');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text(t.tr('close')),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Site Summary Dialog ────────────────────────────────
  Future<void> _showSiteSummaryDialog() async {
    final t = AppLocalizations.of(context);
    if (_sites.isEmpty) return;

    String? selectedId = _activeSite?['id'] ?? _sites.first['id'];

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              scrollable: true,
              title: Text(t.tr('siteSummary')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedId,
                    decoration: InputDecoration(
                      labelText: t.tr('selectSite'),
                      border: const OutlineInputBorder(),
                    ),
                    items: _sites.map<DropdownMenuItem<String>>((site) {
                      return DropdownMenuItem<String>(
                        value: site['id'],
                        child: Text(site['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedId = value);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (selectedId != null)
                    FutureBuilder<Map<String, dynamic>?>(
                      future: _api.getSiteSummary(selectedId!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (snapshot.hasError || !snapshot.hasData) {
                          return Text(t.tr('error'));
                        }
                        final data = snapshot.data!;
                        return Column(
                          children: [
                            _buildSummaryTile(
                              t.tr('totalPlots'),
                              '${data['totalPlots']} ${t.tr('ponds')}',
                              Icons.grid_on,
                              Colors.blue,
                            ),
                            const Divider(),
                            _buildSummaryTile(
                              t.tr('totalCarbon'),
                              '${data['totalCarbon']} tCO₂e',
                              Icons.cloud,
                              Colors.green,
                            ),
                            const Divider(),
                            _buildSummaryTile(
                              t.tr('totalRevenue'),
                              '${data['totalRevenue']} ${t.tr('bahtUnit')}',
                              Icons.monetization_on,
                              Colors.orange,
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t.tr('close')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        value,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─── Create Site Dialog ─────────────────────────────────
  Future<void> _showCreateSiteDialog() async {
    final t = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final provinceController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.tr('createSite')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: t.tr('siteName'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: provinceController,
              decoration: InputDecoration(labelText: t.tr('province')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(context);
              final center = _mapController.camera.center;
              final site = await _api.createSite(
                name: nameController.text,
                farmId: 'user-123',
                province: provinceController.text.isNotEmpty
                    ? provinceController.text
                    : "Unknown",
                latitude: _currentPosition?.latitude ?? center.latitude,
                longitude: _currentPosition?.longitude ?? center.longitude,
              );
              if (site != null) {
                _fetchSites();
              }
            },
            child: Text(t.tr('save')),
          ),
        ],
      ),
    );
  }

  // ─── Submit Pond (within active Site) ───────────────────
  Future<void> _submitPond() async {
    final t = AppLocalizations.of(context);

    // Helper to format Thai Date
    String formatThaiDate(DateTime date) {
      final year = date.year + 543;
      final month = date.month.toString().padLeft(2, '0');
      final day = date.day.toString().padLeft(2, '0');
      return '$day/$month/$year';
    }

    if (_polygonPoints.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.tr('drawMinPoints'))));
      return;
    }

    final nameController = TextEditingController();
    String plotType = 'irrigated';
    DateTime? startDate;
    DateTime? harvestDate;

    // Initialize selected site
    String? selectedSiteId = _activeSite?['id'];
    if (selectedSiteId == null && _sites.isNotEmpty) {
      selectedSiteId = _sites.first['id'];
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (formCtx) {
        return AlertDialog(
          scrollable: true,
          title: Text(t.tr('savePlot')),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Site Dropdown
                  if (_sites.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedSiteId,
                      decoration: InputDecoration(
                        labelText: t.tr('siteName'),
                        border: const OutlineInputBorder(),
                      ),
                      items: _sites.map<DropdownMenuItem<String>>((site) {
                        return DropdownMenuItem<String>(
                          value: site['id'],
                          child: Text(site['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => selectedSiteId = value);
                      },
                    ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 15),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: t.tr('plotName'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: plotType,
                    decoration: const InputDecoration(
                      labelText: 'ประเภทการทำนา',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'irrigated',
                        child: Text('AWD (สลับเปียก-แห้ง)'),
                      ),
                      DropdownMenuItem(
                        value: 'rainfed',
                        child: Text('ปกติ (น้ำขัง)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => plotType = value!);
                    },
                  ),
                  const SizedBox(height: 15),
                  // Date Pickers
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('th', 'TH'), // Force Thai
                      );
                      if (picked != null) {
                        setState(() => startDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t.tr('startDate'),
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        startDate == null ? '' : formatThaiDate(startDate!),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 120),
                        ),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('th', 'TH'), // Force Thai
                      );
                      if (picked != null) {
                        setState(() => harvestDate = picked);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: t.tr('harvestDate'),
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        harvestDate == null ? '' : formatThaiDate(harvestDate!),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(formCtx),
              child: Text(t.tr('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus();

                if (nameController.text.isEmpty) return;
                if (startDate == null || harvestDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(t.tr('fillAllFields'))),
                  );
                  return;
                }
                if (harvestDate!.isBefore(startDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('วันเก็บเกี่ยวต้องหลังวันเริ่มปลูก'),
                    ),
                  );
                  return;
                }

                showDialog(
                  context: formCtx,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  // AUTO-CREATE SITE if none exists or selected
                  if (selectedSiteId == null) {
                    // Calculate centroid for the site location
                    double latSum = 0;
                    double lngSum = 0;
                    for (var p in _polygonPoints) {
                      latSum += p.latitude;
                      lngSum += p.longitude;
                    }
                    final centroidLat = latSum / _polygonPoints.length;
                    final centroidLng = lngSum / _polygonPoints.length;

                    final newSite = await _api.createSite(
                      name: 'แปลงเกษตรของฉัน',
                      farmId: 'user-123',
                      province: 'ไทย',
                      latitude: centroidLat,
                      longitude: centroidLng,
                    );

                    if (newSite != null) {
                      selectedSiteId = newSite['id'];
                      await _fetchSites(); // Refresh site list in background
                    } else {
                      if (!formCtx.mounted) return;
                      Navigator.pop(formCtx); // Close loading
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('สร้าง Site อัตโนมัติไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อ')),
                      );
                      return;
                    }
                  }

                  final savedPlot = await _api.createPlot(
                    farmId: 'user-123',
                    plotName: nameController.text,
                    plotType: plotType,
                    siteId: selectedSiteId!,
                    coordinates: _polygonPoints
                        .map((p) => {"lat": p.latitude, "lng": p.longitude})
                        .toList(),
                  );

                  if (!formCtx.mounted) return;
                  Navigator.pop(formCtx); // Close loading
                  Navigator.pop(formCtx); // Close form

                  if (savedPlot != null) {
                    final double areaRai = (savedPlot['area_rai'] as num)
                        .toDouble();
                    final bool isAWD = savedPlot['plot_type'] == 'irrigated';

                    final carbonResult = await _api.saveCarbonCalculation(
                      plotId: savedPlot['id'],
                      areaRai: areaRai,
                      isAWD: isAWD,
                      startDate: startDate!,
                      harvestDate: harvestDate!,
                    );

                    if (!mounted) return;

                    if (carbonResult != null) {
                      await showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          title: Text(t.tr('saveSuccess')),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ระยะเวลาปลูก: ${carbonResult['totalDays']} วัน',
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${t.tr('nameLabel')}: ${nameController.text}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${t.tr('areaLabel')}: ${formatThaiArea(areaRai)}',
                              ),
                              const Divider(),
                              Text(
                                t.tr('carbonResult'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${t.tr('gasReduction')}: ${carbonResult['carbon_credit_ton']} tCO₂e',
                              ),
                              Text(
                                '${t.tr('revenue')}: ${carbonResult['revenue_thb_est']} ${t.tr('bahtUnit')}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(t.tr('ok')),
                            ),
                          ],
                        ),
                      );
                    }

                    setState(() => _polygonPoints.clear());
                    // Reload ponds for active site
                    if (_activeSite != null) {
                      _selectSite(_activeSite!, moveCamera: false);
                    }
                    _fetchSites();
                  }
                } catch (e, stacktrace) {
                  debugPrint('PLOT SAVE ERROR: $e\n$stacktrace');
                  if (!formCtx.mounted) return;
                  Navigator.pop(formCtx);

                  showDialog(
                    context: formCtx,
                    builder: (errCtx) => AlertDialog(
                      title: Text(t.tr('errorTitle')),
                      content: Text(
                        '${t.tr('saveError')}: $e\n\n${t.tr('checkServer')}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(errCtx),
                          child: Text(t.tr('close')),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: Text(t.tr('save')),
            ),
          ],
        );
      },
    );
  }

  // ─── Find which pond was tapped ─────────────────────────
  Map<String, dynamic>? _findTappedPond(LatLng tapPoint) {
    for (final pond in _sitePonds) {
      final pts = _extractPolygon(pond['geometry']);
      if (pts.isEmpty) continue;
      if (_isPointInPolygon(tapPoint, pts)) return pond;
    }
    return null;
  }

  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    int j = polygon.length - 1;
    for (int i = 0; i < polygon.length; i++) {
      if ((polygon[i].latitude > point.latitude) !=
              (polygon[j].latitude > point.latitude) &&
          (point.longitude <
              (polygon[j].longitude - polygon[i].longitude) *
                      (point.latitude - polygon[i].latitude) /
                      (polygon[j].latitude - polygon[i].latitude) +
                  polygon[i].longitude)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  // ─── Lat/Long Detection ──────────────────────────────────
  LatLng? _parseLatLng(String input) {
    // Supports: "14.35, 100.56" or "14.35 100.56" or "14.35,100.56"
    final regex = RegExp(r'^\s*(-?\d+\.?\d*)\s*[,\s]\s*(-?\d+\.?\d*)\s*$');
    final match = regex.firstMatch(input);
    if (match == null) return null;
    final lat = double.tryParse(match.group(1)!);
    final lng = double.tryParse(match.group(2)!);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  // ─── Build Drawer ───────────────────────────────────────
  Widget _buildDrawer(AppLocalizations t) {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(t.tr('drawerName')),
            accountEmail: Text(t.tr('drawerEmail')),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.green),
            ),
            decoration: const BoxDecoration(color: Colors.green),
          ),
          // ─── Search Bar ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: t.tr('searchHint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.trim());
              },
            ),
          ),
          // ─── Lat/Long Go-To Button ──────────────────────
          if (_searchQuery.isNotEmpty && _parseLatLng(_searchQuery) != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map, size: 18),
                  label: Text(t.tr('goToLocation')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final latLng = _parseLatLng(_searchQuery)!;
                    Navigator.pop(context);
                    _moveAnimated(latLng, 16.0);
                  },
                ),
              ),
            ),
          // Active Site indicator
          if (_activeSite != null)
            Container(
              color: Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.green),
                title: Text(
                  _activeSite!['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${_sitePonds.length} ${t.tr('ponds')}'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _activeSite = null;
                      _sitePonds = [];
                      _availableMapDates = [];
                      _selectedMapDate = null;
                      _selectedLayerType = null;
                      _selectedLayerBaseUrl = null;
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              ),
            ),
          if (_activeSite != null) const Divider(height: 1),

          // Content: Sites list or Ponds list
          Expanded(
            child: _activeSite == null
                ? _buildSitesList(t)
                : _buildPondsList(t),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: Text(t.tr('configServer')),
            onTap: _showConfigServerDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildSitesList(AppLocalizations t) {
    if (_hasConnectionError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('เซิร์ฟเวอร์ตอบสนองผิดพลาด\nโปรดตรวจสอบ IP'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchSites,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองเชื่อมต่อใหม่'),
            ),
          ],
        ),
      );
    }

    if (_sites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.tr('noSites')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close Drawer
                _showCreateSiteDialog();
              },
              icon: const Icon(Icons.add),
              label: Text(t.tr('createSite')),
            ),
          ],
        ),
      );
    }

    final query = _searchQuery.toLowerCase();
    final filteredSites = query.isEmpty
        ? _sites
        : _sites.where((site) {
            final name = (site['name'] ?? '').toString().toLowerCase();
            final province = (site['province'] ?? '').toString().toLowerCase();
            return name.contains(query) || province.contains(query);
          }).toList();

    if (filteredSites.isEmpty) {
      return Center(child: Text(t.tr('noSearchResults')));
    }

    return ListView.builder(
      itemCount: filteredSites.length + (query.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (query.isEmpty && index == filteredSites.length) {
          return ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: Text(t.tr('createSite')),
            onTap: () {
              Navigator.pop(context);
              _showCreateSiteDialog();
            },
          );
        }
        final site = filteredSites[index];
        final plotCount = (site['plots'] as List?)?.length ?? 0;
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.green),
          title: Text(site['name'] ?? ''),
          subtitle: Text(
            '${site['province'] ?? ''} · $plotCount ${t.tr('ponds')}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(context);
            _selectSite(site);
          },
        );
      },
    );
  }

  Widget _buildPondsList(AppLocalizations t) {
    if (_sitePonds.isEmpty) {
      return Center(child: Text(t.tr('noPlots')));
    }

    final query = _searchQuery.toLowerCase();
    final filteredPonds = query.isEmpty
        ? _sitePonds
        : _sitePonds.where((pond) {
            final name = (pond['plot_name'] ?? '').toString().toLowerCase();
            final type = (pond['plot_type'] ?? '').toString().toLowerCase();
            return name.contains(query) || type.contains(query);
          }).toList();

    if (filteredPonds.isEmpty) {
      return Center(child: Text(t.tr('noSearchResults')));
    }

    return ListView.builder(
      itemCount: filteredPonds.length,
      itemBuilder: (context, index) {
        final pond = filteredPonds[index];
        final areaRai = pond['area_rai'] != null
            ? (pond['area_rai'] as num).toDouble()
            : 0.0;
        return ListTile(
          leading: const Icon(Icons.grass, color: Colors.blue),
          title: Text(
            pond['plot_name'] ?? '${t.tr('plotDefault')} #${index + 1}',
          ),
          subtitle: Text('${pond['plot_type']} · ${formatThaiArea(areaRai)}'),
          onTap: () {
            Navigator.pop(context);
            // Zoom to this pond's polygon
            final pts = _extractPolygon(pond['geometry']);
            if (pts.isNotEmpty) {
              final bounds = LatLngBounds.fromPoints(pts);
              _moveAnimated(bounds.center, 16.5);
            }
            _showPondDetails(pond);
          },
        );
      },
    );
  }

  // ─── Build ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _activeSite != null ? _activeSite!['name'] : t.tr('appTitle'),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      drawer: _buildDrawer(t),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                // Check if tapped on a pond polygon
                if (_sitePonds.isNotEmpty) {
                  final tappedPond = _findTappedPond(point);
                  if (tappedPond != null) {
                    _showPondDetails(tappedPond);
                    return;
                  }
                }
                // Otherwise add point to drawing polygon
                setState(() => _polygonPoints.add(point));
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.arcticcarbon.app',
              ),
              // AI Map Layer (RGB / NDVI)
              if (_selectedLayerBaseUrl != null)
                TileLayer(
                  urlTemplate:
                      '${_api.baseUrl}$_selectedLayerBaseUrl/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.arcticcarbon.app.ai',
                ),
              PolygonLayer(
                polygons: [
                  // Site Ponds (blue polygons)
                  for (final pond in _sitePonds)
                    if (_extractPolygon(pond['geometry']).isNotEmpty)
                      Polygon(
                        points: _extractPolygon(pond['geometry']),
                        color: Colors.blue.withValues(alpha: 0.3),
                        borderColor: Colors.blueAccent,
                        borderStrokeWidth: 2,
                        label: pond['plot_name'],
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  // User-drawn polygon (green)
                  if (_polygonPoints.isNotEmpty)
                    Polygon(
                      points: _polygonPoints,
                      color: Colors.green.withValues(alpha: 0.5),
                      borderColor: Colors.green,
                      borderStrokeWidth: 2,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    buildUserLocationMarker(
                      position: _currentPosition!,
                      heading: _currentHeading,
                    ),
                  ...buildPolygonVertexMarkers(_polygonPoints),
                ],
              ),
            ],
          ),
          // ─── Loading overlay while fetching ponds ───────
          if (_isLoadingPonds)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 12),
                      Text(
                        'กำลังโหลดแปลง...',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ─── Top-left: North + GPS ──────────────────────
          Positioned(
            top: 12,
            left: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Add Plot Hint ────────────────────────
                if (_sitePonds.isEmpty && _polygonPoints.isEmpty && !_isLoadingPonds)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'แตะบนแผนที่เพื่อเริ่มวาดแปลง',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                FloatingActionButton.small(
                  heroTag: 'north',
                  onPressed: _animateRotateToNorth,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  child: const Icon(Icons.navigation),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'gps',
                  onPressed: _getCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blue,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'layers',
                  onPressed: () {
                    if (_sitePonds.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('กรุณาสร้างแปลง หรือเลือกแปลงก่อน เพื่อดึงข้อมูลแผนที่ดาวเทียม')),
                      );
                      return;
                    }
                    _showMapLayersDialog();
                  },
                  backgroundColor: _selectedLayerBaseUrl != null
                      ? Colors.blue.shade100
                      : Colors.white,
                  foregroundColor: Colors.blue.shade800,
                  tooltip: 'แผนที่ดาวเทียม (Sentinel-2)',
                  child: const Icon(Icons.layers),
                ),
              ],
            ),
          ),
          // ─── Top-right: Site Summary ────────────────────
          Positioned(
            top: 12,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'summary',
              onPressed: _showSiteSummaryDialog,
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple,
              child: const Icon(Icons.dashboard),
            ),
          ),
          // ─── Bottom save banner (when ≥3 points) ────────
          if (_polygonPoints.length >= 3)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '📍 ${_polygonPoints.length} จุด',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitPond,
                        icon: const Icon(Icons.save),
                        label: Text(t.tr('savePlot')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // ─── Bottom-right: Undo + Clear (only when drawing) ─
      floatingActionButton: _polygonPoints.isNotEmpty
          ? Padding(
              padding: EdgeInsets.only(
                bottom: _polygonPoints.length >= 3 ? 80 : 0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FloatingActionButton(
                    heroTag: 'undo',
                    onPressed: () {
                      setState(() => _polygonPoints.removeLast());
                    },
                    child: const Icon(Icons.undo),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton(
                    heroTag: 'clear',
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    onPressed: () => setState(() => _polygonPoints.clear()),
                    child: const Icon(Icons.clear),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _showConfigServerDialog() async {
    final t = AppLocalizations.of(context);
    final currentIp = _api.baseUrl.replaceAll('http://', '').replaceAll(':3000', '');
    final TextEditingController ipController = TextEditingController(text: currentIp);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t.tr('configServer')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${t.tr('serverIp')}:'),
              const SizedBox(height: 10),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  hintText: t.tr('enterIp'),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.text, // IP addresses contain dots
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(t.tr('close')),
            ),
            ElevatedButton(
              onPressed: () async {
                final newIp = ipController.text.trim();
                if (newIp.isNotEmpty) {
                  await _api.updateHost(newIp);
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(t.tr('ipUpdated'))));
                    Navigator.pop(context); // Close dialog

                    // Refresh data
                    _fetchSites();
                  }
                }
              },
              child: Text(t.tr('save')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showMapLayersDialog() async {
    // Auto-select first plot if none selected
    if (_activePlotId == null && _sitePonds.isNotEmpty) {
      _activePlotId = _sitePonds.first['id'] as String;
    }

    // Always re-fetch dates for the current active plot to ensure dialog is fresh
    if (_activePlotId != null) {
      final dates = await _api.fetchMapDates(_activePlotId!);
      if (mounted) setState(() => _availableMapDates = dates);
    }

    // Auto-select latest date if not set
    if (_selectedMapDate == null && _availableMapDates.isNotEmpty) {
      _selectedMapDate = _availableMapDates.first.toString();
      _selectedLayerType = 'RGB';
      // Fetch layers for this auto-selected date
      if (_activePlotId != null) {
        final layers = await _api.fetchMapLayers(_activePlotId!, _selectedMapDate!);
        if (mounted) setState(() => _availableLayers = layers);
      }
    }
    
    // Auto-select Base URL based on selected layer type
    if (_selectedLayerType != null && _availableLayers.isNotEmpty) {
      final layer = _availableLayers.firstWhere(
        (l) => l['layerType'] == _selectedLayerType,
        orElse: () => null,
      );
      if (layer != null) _selectedLayerBaseUrl = layer['baseUrl'];
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('ดาวเทียม Sentinel-2'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plot context - Simplify if already active
                  if (_activePlotId != null) ...[
                    Text(
                      'แปลง: ${_sitePonds.firstWhere((p) => p['id'] == _activePlotId, orElse: () => {'plot_name': 'Unknown'})['plot_name']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    const Text('เลือกแปลงเกษตร:'),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _activePlotId,
                      hint: const Text('เลือกแปลง'),
                      items: _sitePonds.map<DropdownMenuItem<String>>((pond) {
                        return DropdownMenuItem<String>(
                          value: pond['id'] as String,
                          child: Text(pond['plot_name'] ?? 'แปลงไม่มีชื่อ'),
                        );
                      }).toList(),
                      onChanged: (value) async {
                        if (value == null || value == _activePlotId) return;
                        
                        setModalState(() {
                          _activePlotId = value;
                          _availableMapDates = [];
                          _selectedMapDate = null;
                          _availableLayers = [];
                          _selectedLayerType = null;
                          _selectedLayerBaseUrl = null;
                        });

                        // Fetch dates for newly selected plot
                        final dates = await _api.fetchMapDates(value);
                        if (mounted) {
                          setState(() => _availableMapDates = dates); // Main UI state
                          setModalState(() => _availableMapDates = dates); // Dialog state
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text('วันที่อัปเดตแผนที่ดาวเทียม:'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedMapDate,
                    hint: const Text('เลือกวันที่ (ถ้ามี)'),
                    items: _availableMapDates.map<DropdownMenuItem<String>>((
                      dateStr,
                    ) {
                      return DropdownMenuItem<String>(
                        value: dateStr.toString(),
                        child: Text(dateStr.toString().split('T')[0]),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setModalState(() {
                        _selectedMapDate = value;
                        _selectedLayerType = null;
                        _selectedLayerBaseUrl = null;
                        _availableLayers = [];
                      });
                      if (value != null && _activePlotId != null) {
                        final plotId = _activePlotId!;
                        final layers = await _api.fetchMapLayers(plotId, value);
                        if (mounted) {
                          setModalState(() => _availableLayers = layers);
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('ชนิดแผนที่ (Layer):'),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedLayerType,
                    hint: const Text('ดาวเทียมปกติ (Base)'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('ดาวเทียมปกติ (Base)'),
                      ),
                      ..._availableLayers.map<DropdownMenuItem<String>>((
                        layer,
                      ) {
                        return DropdownMenuItem<String>(
                          value: layer['layerType'],
                          child: Text(layer['layerType']),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        _selectedLayerType = value;
                        if (value == null) {
                          _selectedLayerBaseUrl = null;
                        } else {
                          final layer = _availableLayers.firstWhere(
                            (l) => l['layerType'] == value,
                          );
                          _selectedLayerBaseUrl = layer['baseUrl'];
                        }
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Apply changes to main state so the map re-renders the TileLayer
                    setState(() {});
                  },
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
