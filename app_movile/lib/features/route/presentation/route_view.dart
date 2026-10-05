import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movile/core/auth/auth_state_notifier.dart';
import 'package:app_movile/core/network/supabase_service.dart';
import 'package:app_movile/core/stats/weekly_stats_service.dart';
import 'package:app_movile/core/widgets/nav_bar.dart';
import 'package:app_movile/core/widgets/top_bar.dart';
import 'package:app_movile/features/route/data/gps_telemetry_repository.dart';
import 'package:app_movile/features/route/data/model/telemetry.dart';
import 'package:app_movile/features/route/data/model/trip_summary.dart';
import 'package:app_movile/features/route/data/thingsboard_service.dart';
import 'package:app_movile/features/route/presentation/widgets/route_content.dart';
import 'package:app_movile/features/route/presentation/widgets/status_banner.dart';
import 'package:app_movile/features/route/presentation/widgets/telemetry_card.dart';

class RouteView extends StatefulWidget {
  const RouteView({super.key});

  @override
  State<RouteView> createState() => _RouteViewState();
}

class _RouteViewState extends State<RouteView> {
  int _selectedIndex = 0;

  // conectando repo gps
  late final GpsTelemetryRepository _repo;
  StreamSubscription<Telemetry>? _telemetrySub;
  final ThingsBoardService _thingsBoard = ThingsBoardService();
  Timer? _clockTimer;

  // controlador de camara del mapa
  final MapController _mapController = MapController();
  // trazado de ruta del ciclista
  final List<LatLng> _routePoints = [];
  LatLng? _currentPosition;
  bool _isMapReady = false;

  Telemetry _telemetry = Telemetry.empty();
  double _maxSpeed = 0;
  double _speedSum = 0;
  int _sampleCount = 0;
  bool _isFinishing = false;

  final Stopwatch _stopwatch = Stopwatch()..start();

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // arranca el repo gps y se suscribe al stream
    _repo = GpsTelemetryRepository();
    _repo.initialize().then((_) {
      _telemetrySub = _repo.telemetryStream.listen((data) {
        if (!mounted) return;
        setState(() {
          _telemetry = data;
          if (data.speedKmh > _maxSpeed) _maxSpeed = data.speedKmh;
          _speedSum += data.speedKmh;
          _sampleCount++;

          if (data.latitude != null && data.longitude != null) {
            final newPos = LatLng(data.latitude!, data.longitude!);
            _currentPosition = newPos;

            // guardando coordenadas en la lista para el trazado
            if (_routePoints.isEmpty || _routePoints.last != newPos) {
              _routePoints.add(newPos);
            }

            // centrando camara gps
            if (_isMapReady) {
              _mapController.move(newPos, _mapController.camera.zoom);
            }
          }
        });
      });
    });
  }

  @override
  void dispose() {
    _telemetrySub?.cancel();
    _clockTimer?.cancel();
    // cierra el repo al salir de la vista
    _repo.dispose();
    _mapController.dispose();
    super.dispose();
  }

  String get _formattedDuration {
    final d = _stopwatch.elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  Future<void> _onStopRide() async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);
    _stopwatch.stop();

    final summary = TripSummary(
      maxSpeedKmh: _maxSpeed,
      avgSpeedKmh: _sampleCount == 0 ? 0 : _speedSum / _sampleCount,
      distanceKm: _telemetry.distanceKm,
      durationSeconds: _stopwatch.elapsed.inSeconds,
    );

    // guarda estadisticas locales semanales
    final prefs = await SharedPreferences.getInstance();
    final weightStr = prefs.getString('profile_weight') ?? '70';
    final weight = double.tryParse(weightStr) ?? 70.0;
    await WeeklyStatsService.instance.addTrip(
      distanceKm: summary.distanceKm,
      durationSeconds: summary.durationSeconds,
      weightKg: weight,
    );

    unawaited(
      Future.wait([
        _thingsBoard.sendTripSummary(summary),
        _saveToSupabase(summary),
      ]).then((results) {
        if (!mounted) return;
        if (!results[0] && !results[1]) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Viaje finalizado. Sin conexión para sincronizar.')),
          );
        }
      }).catchError((_) {}),
    );

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<bool> _saveToSupabase(TripSummary summary) async {
    final userId = AuthStateNotifier.instance.userId;
    if (userId == null) return true;
    try {
      await supabaseService.saveTrip(
        userId: userId,
        totalDistance: summary.distanceKm,
        maxSpeed: summary.maxSpeedKmh,
        avgSpeed: summary.avgSpeedKmh,
        duration: summary.durationSeconds,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1115),
      // gps no necesita estado ble, pasamos true para que el topBar no muestre error
      appBar: topBar(context, true),
      body: Stack(
        children: [
          // fondo: mapa ocupando el 100% de la pantalla
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentPosition ?? const LatLng(-33.4489, -70.6693),
                initialZoom: 16.0,
                onMapReady: () {
                  _isMapReady = true;
                  if (_currentPosition != null) {
                    // centrando camara gps
                    _mapController.move(_currentPosition!, 16.0);
                  }
                },
              ),
              children: [
                // capa de openstreetmap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.accelerbike.app',
                ),
                // dibujando ruta del ciclista
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5.0,
                      color: Colors.red,
                    ),
                  ],
                ),
                // marcador de posicion actual del ciclista
                if (_currentPosition != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // banner de estado superior
          const Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: StatusBanner(isWakelockActive: true),
          ),

          // boton flotante para recentrar camara gps
          if (_currentPosition != null)
            Positioned(
              right: 16,
              bottom: 270,
              child: FloatingActionButton.small(
                heroTag: 'recenter_gps_btn',
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: const Color(0xFF00E676),
                onPressed: () {
                  // centrando camara gps
                  _mapController.move(_currentPosition!, _mapController.camera.zoom);
                },
                child: const Icon(Icons.my_location),
              ),
            ),

          // tarjetas de telemetria flotando en la parte inferior
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // tarjeta de velocidad
                  TelemetryCard(
                    title: 'Velocidad',
                    value: _telemetry.speedKmh.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.speed,
                    valueColor: const Color(0xFF00E676),
                    progress: (_telemetry.speedKmh / 60.0).clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 8),
                  // tarjetas de distancia y tiempo
                  Row(
                    children: [
                      Expanded(
                        child: TelemetryCard(
                          title: 'Distancia',
                          value: _telemetry.distanceKm.toStringAsFixed(2),
                          unit: 'km',
                          icon: Icons.route,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TelemetryCard(
                          title: 'Tiempo',
                          value: _formattedDuration,
                          icon: Icons.timer_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // botones de control de ruta
                  buttons(context, onStop: _onStopRide, isLoading: _isFinishing),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
