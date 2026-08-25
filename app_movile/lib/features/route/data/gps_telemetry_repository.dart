import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ble_telemetry_repository.dart';
import 'model/telemetry.dart';

// Clase que gestiona los permisos de ubicacion en tiempo de ejecucion
class GpsPermissionManager {

  // Flujo: verifica servicio → solicita permiso → retorna true/false
  Future<bool> requestPermissions() async {

    // Verifica si el GPS del sistema esta activo
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Solicita el permiso de ubicacion precisa al usuario
    final status = await Permission.locationWhenInUse.request();

    // Acepta permiso completo o precision limitada (Android 12+)
    return status.isGranted || status.isLimited;
  }

  // Consulta el estado del permiso sin volver a solicitarlo
  Future<bool> hasPermissions() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted || status.isLimited;
  }
}

// Implementacion GPS de TelemetryRepository
// Lee la velocidad del chip GPS nativo y la emite en km/h
class GpsTelemetryRepository implements TelemetryRepository {
  final GpsPermissionManager _permissionManager;
  final LocationSettings _locationSettings;

  // Stream broadcast: varios listeners pueden suscribirse al mismo tiempo
  final _controller = StreamController<Telemetry>.broadcast();
  StreamSubscription<Position>? _positionSub;

  GpsTelemetryRepository({
    GpsPermissionManager? permissionManager,
    LocationSettings? locationSettings,
  })  : _permissionManager = permissionManager ?? GpsPermissionManager(),
        _locationSettings = locationSettings ??
            const LocationSettings(
              // Precision alta → usa el chip GPS fisico del dispositivo
              accuracy: LocationAccuracy.high,
              // Sin filtro de distancia → actualizacion cada ~1 segundo
              distanceFilter: 0,
            );

  // Llama esto antes de suscribirte al stream
  // Pide permisos y arranca la escucha del GPS
  Future<void> initialize() async {
    final granted = await _permissionManager.requestPermissions();
    if (!granted) return;

    // Inicia el stream de posicion GPS
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings,
    ).listen(_handlePosition, onError: _handleError);
  }

  // Conversion de velocidad: m/s → km/h y emision al stream
  void _handlePosition(Position position) {
    // Geolocator da speed en m/s, multiplicar por 3.6 da km/h
    final speedKmh = (position.speed * 3.6).clamp(0.0, double.infinity);
    _controller.add(Telemetry(speedKmh: speedKmh, distanceKm: 0.0));
  }

  // Errores del GPS: se absorben para no cerrar el stream
  void _handleError(Object error) {}

  @override
  Stream<Telemetry> get telemetryStream => _controller.stream;

  // Cancela la suscripcion y cierra el controller al destruir el objeto
  @override
  void dispose() {
    _positionSub?.cancel();
    _controller.close();
  }
}
