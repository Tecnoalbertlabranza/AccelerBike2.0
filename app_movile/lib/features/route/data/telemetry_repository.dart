import 'model/telemetry.dart';

// interfaz base para cualquier fuente de telemetria (gps, ble, simulada...)
abstract class TelemetryRepository {
  Stream<Telemetry> get telemetryStream;
  void dispose();
}
