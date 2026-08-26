import 'dart:async';
import 'package:app_movile/core/stats/weekly_stats_service.dart';
import 'package:app_movile/features/route/data/gps_telemetry_repository.dart';
import 'package:app_movile/features/route/data/model/telemetry.dart';
import 'package:app_movile/features/route/data/model/trip_summary.dart';
import 'package:app_movile/features/route/data/thingsboard_service.dart';
import 'package:app_movile/features/route/presentation/widgets/route_content.dart';
import 'package:app_movile/core/widgets/top_bar.dart';
import 'package:app_movile/core/widgets/nav_bar.dart';
import 'package:app_movile/core/auth/auth_state_notifier.dart';
import 'package:app_movile/core/network/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    Navigator.pop(context);
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // pasa los datos del stream gps a la ui
                    progressInfo(
                      context,
                      true,
                      _telemetry.distanceKm,
                      _formattedDuration,
                      _telemetry.speedKmh,
                      _maxSpeed,
                    ),
                    const SizedBox(height: 32),
                    buttons(context, onStop: _onStopRide, isLoading: _isFinishing),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
