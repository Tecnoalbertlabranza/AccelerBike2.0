import 'dart:async';

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
        _locationSettings = locationSettings ??
            const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            );

  // llama esto antes de suscribirte al stream
  Future<void> initialize() async {
    final granted = await _permissionManager.requestPermissions();
    if (!granted) return;

    // inicia stream de posicion gps
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_handlePosition, onError: _handleError);
  }

  // calculo de dist con geolocator + conversion m/s a km/h
  void _handlePosition(Position position) {
    if (_lastPosition != null) {
      // distancia en metros entre la pos anterior y la actual
      final meters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      // acumula convirtiendo a km
      _accumulatedDistanceKm += meters / 1000.0;
    }

    _lastPosition = position;

    // geolocator da speed en m/s → km/h
    final speedKmh = (position.speed * 3.6).clamp(0.0, double.infinity);

    _controller.add(Telemetry(
      speedKmh: speedKmh,
      distanceKm: _accumulatedDistanceKm,
    ));
  }

  // errores del gps no deben cerrar el stream
  void _handleError(Object error) {}

  // reinicia contadores sin destruir el objeto
  void resetDistance() {
    _accumulatedDistanceKm = 0.0;
    _lastPosition = null;
  }

  @override
  Stream<Telemetry> get telemetryStream => _controller.stream;

  @override
  void dispose() {
    _positionSub?.cancel();
    _controller.close();
  }
}
