import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  final bool isWakelockActive;

  const StatusBanner({
    super.key,
    required this.isWakelockActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: const Color(0xFF13151A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wb_incandescent_outlined,
            color: isWakelockActive ? const Color(0xFF00E676) : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'WAKELOCK ${isWakelockActive ? "ACTIVE" : "INACTIVE"}',
            style: TextStyle(
              color: isWakelockActive ? const Color(0xFF00E676) : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          // fuente de datos: gps
          const Icon(Icons.gps_fixed, color: Color(0xFF00E676), size: 16),
          const SizedBox(width: 8),
          const Text(
            'GPS ACTIVO',
            style: TextStyle(
              color: Color(0xFF00E676),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
