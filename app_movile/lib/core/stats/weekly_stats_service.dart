import 'package:shared_preferences/shared_preferences.dart';

// Claves de shared_preferences para las estadisticas semanales
const _kWeeklyDistance  = 'weekly_distance';
const _kWeeklyTime      = 'weekly_time';
const _kWeeklyCalories  = 'weekly_calories';
const _kLastRideDate    = 'last_ride_date';

class WeeklyStatsService {
  // singleton
  WeeklyStatsService._internal();
  static final WeeklyStatsService instance = WeeklyStatsService._internal();

  // reseteo semanal - llama esto al arrancar la app
  // compara el numero de semana ISO del last_ride_date con el actual
  Future<void> checkAndResetIfNewWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final lastStr = prefs.getString(_kLastRideDate);

    if (lastStr == null) return; // primera vez, no hay nada que resetear

    final lastDate = DateTime.tryParse(lastStr);
    if (lastDate == null) return;

    final now = DateTime.now();

    // numero de semana ISO: lunes como primer dia
    final lastWeek = _isoWeekNumber(lastDate);
    final nowWeek  = _isoWeekNumber(now);

    // si cambiamos de semana (o de año), resetea contadores
    if (lastDate.year != now.year || lastWeek != nowWeek) {
      await prefs.setDouble(_kWeeklyDistance, 0.0);
      await prefs.setInt(_kWeeklyTime,        0);
      await prefs.setDouble(_kWeeklyCalories, 0.0);
    }
  }

  // acumula los datos de un viaje terminado
  // durationSeconds: duracion del viaje en segundos
  // distanceKm: distancia recorrida
  // weightKg: peso del usuario (default 70 si no se ha guardado)
  Future<void> addTrip({
    required double distanceKm,
    required int durationSeconds,
    required double weightKg,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    // calculo de calorias: MET ciclismo moderado = 6.8
    // formula: calorias = MET x peso(kg) x tiempo(h)
    final hours    = durationSeconds / 3600.0;
    final calories = 6.8 * weightKg * hours;

    // acumula sobre lo anterior
    final prevDist = prefs.getDouble(_kWeeklyDistance) ?? 0.0;
    final prevTime = prefs.getInt(_kWeeklyTime)        ?? 0;
    final prevCal  = prefs.getDouble(_kWeeklyCalories) ?? 0.0;

    await prefs.setDouble(_kWeeklyDistance, prevDist + distanceKm);
    await prefs.setInt(_kWeeklyTime,        prevTime + durationSeconds);
    await prefs.setDouble(_kWeeklyCalories, prevCal  + calories);

    // guarda fecha del ultimo viaje para el reseteo semanal
    await prefs.setString(_kLastRideDate, DateTime.now().toIso8601String());
  }

  // lee las estadisticas actuales de la semana
  Future<WeeklyStats> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WeeklyStats(
      distanceKm:      prefs.getDouble(_kWeeklyDistance) ?? 0.0,
      durationSeconds: prefs.getInt(_kWeeklyTime)        ?? 0,
      calories:        prefs.getDouble(_kWeeklyCalories) ?? 0.0,
    );
  }

  // numero de semana ISO 8601 (semana empieza el lunes)
  int _isoWeekNumber(DateTime date) {
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays;
    final weekday   = date.weekday; // 1=lunes, 7=domingo
    return ((dayOfYear - weekday + 10) / 7).floor();
  }
}

// modelo simple para transportar los datos
class WeeklyStats {
  final double distanceKm;
  final int durationSeconds;
  final double calories;

  const WeeklyStats({
    required this.distanceKm,
    required this.durationSeconds,
    required this.calories,
  });

  // formato HH:MM para mostrar en la UI
  String get formattedTime {
    final h = (durationSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
