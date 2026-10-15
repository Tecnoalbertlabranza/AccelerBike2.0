import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'telemetry_repository.dart';
import 'model/telemetry.dart';

// Maneja permisos de ubicacion en tiempo de ejecucion
class GpsPermissionManager {

  Future<bool> requestPermissions() async {
    // verifica que el gps del sistema este activo
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // pide permiso al usuario
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  Future<bool> hasPermissions() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }
}

// Implementacion GPS de TelemetryRepository
// Emite velocidad en km/h y acumula distancia recorrida
class GpsTelemetryRepository implements TelemetryRepository {
  final GpsPermissionManager _permissionManager;
  final LocationSettings _locationSettings;

  final _controller = StreamController<Telemetry>.broadcast();
  StreamSubscription<Position>? _positionSub;

  // ultima posicion conocida para calcular tramos
  Position? _lastPosition;
  double _accumulatedDistanceKm = 0.0;

  GpsTelemetryRepository({
    GpsPermissionManager? permissionManager,
    LocationSettings? locationSettings,
  })  : _permissionManager = permissionManager ?? GpsPermissionManager(),
        _locationSettings = locationSettings ?? _defaultLocationSettings();

  // configuracion de gps de alta frecuencia y precision (estilo Strava)
  static LocationSettings _defaultLocationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(milliseconds: 500),
      );
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        activityType: ActivityType.fitness,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );
  }

  // llama esto antes de suscribirte al stream
  Future<void> initialize() async {
    final granted = await _permissionManager.requestPermissions();
    if (!granted) return;

    // emite posicion inicial si esta disponible
    try {
      final initial = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
      _handlePosition(initial);
    } catch (_) {}

    // inicia stream de posicion gps
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_handlePosition, onError: _handleError);
  }

  // calculo de dist con geolocator + conversion m/s a km/h
  void _handlePosition(Position position) {
    double meters = 0.0;
    if (_lastPosition != null) {
      // distancia en metros entre la pos anterior y la actual
      meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // acumula convirtiendo a km
      _accumulatedDistanceKm += meters / 1000.0;
    }

    // calculo y conversion de velocidad en km/h
    double speedKmh = 0.0;
    if (position.speed > 0) {
      // velocidad directa por efecto doppler del sensor gps
      speedKmh = position.speed * 3.6;
    } else if (_lastPosition != null && meters > 0) {
      // respaldo: calculo por delta de distancia y tiempo si speed no esta disponible
      final elapsedMs = position.timestamp.difference(_lastPosition!.timestamp).inMilliseconds;
      if (elapsedMs > 0) {
        speedKmh = (meters / (elapsedMs / 1000.0)) * 3.6;
      }
    }

    _lastPosition = position;

    _controller.add(Telemetry(
      speedKmh: speedKmh.clamp(0.0, double.infinity),
      distanceKm: _accumulatedDistanceKm,
      latitude: position.latitude,
      longitude: position.longitude,
    ));
  }

  // errores del gps no deben cerrar el stream
  void _handleError(Object error) {}

  // reinicia contadores sin destruir el objeto
  void resetDistance() {
    _accumulatedDistanceKm = 0.0;
    _lastPosition = null;
  }

  // posicion actual conocida
  Position? get lastPosition => _lastPosition;

  @override
  Stream<Telemetry> get telemetryStream => _controller.stream;

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller.close();
  }
}
