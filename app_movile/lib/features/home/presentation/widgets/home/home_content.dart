import 'package:app_movile/features/home/presentation/widgets/home/metric_card.dart';
import 'package:flutter/material.dart';

Widget welcomeMessage(BuildContext context) {
  return const Text(
    'GPS listo. Sal a pedalear cuando quieras.',
    style: TextStyle(
      fontSize: 16,
      color: Colors.white70,
      height: 1.4,
    ),
  );
}

Widget metrics(BuildContext context, String weeklyDistance, String weeklyTime, String weeklyCalories) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // titulo de la seccion semanal
      const Text(
        'ESTA SEMANA',
        style: TextStyle(
          color: Color(0xFF00E676),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: MetricCard(
              title: 'Distancia',
              value: weeklyDistance,
              unit: 'km',
              icon: Icons.route,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MetricCard(
              title: 'Tiempo',
              value: weeklyTime,
              unit: 'HH:MM',
              icon: Icons.timer_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      MetricCard(
        title: 'Calorías quemadas',
        value: weeklyCalories,
        unit: 'kcal',
        icon: Icons.local_fire_department_outlined,
      ),
      const SizedBox(height: 16),
    ],
  );
}

Widget startTravel(BuildContext context){
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF00E676)),
      color: const Color(0xFF1A1A1A),
    ),
    child: Row(
      children: [
        const Icon(Icons.explore_outlined, color: Color(0xFF00E676), size: 28),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
              '¿Te gustaría empezar\nun Recorrido?',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Hoy es un excelente día para salir a pedalear.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
