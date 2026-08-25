import 'model/trip_summary.dart';

class ThingsBoardService {
  // apagado temporalmente - modo offline
  Future<bool> sendTripSummary(TripSummary summary) async {
    // final payload = summary.toThingsBoardPayload();
    // return _client.postTelemetry(payload);
    return true;
  }
}
