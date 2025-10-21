import 'package:aquasense/models/water_tank_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TankLevelCard extends StatelessWidget {
  final WaterTank tank;
  final VoidCallback onUpdate; // Callback for update action

  const TankLevelCard({super.key, required this.tank, required this.onUpdate});

  Color _getColorForLevel(int level) {
    if (level < 20) return Colors.redAccent;
    if (level < 50) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForLevel(tank.level);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tank.tankName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              // UPDATE BUTTON
              OutlinedButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white30),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Last updated: ${DateFormat('d MMM, h:mm a').format(tank.lastUpdated.toDate())}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: tank.level / 100.0,
                    minHeight: 12,
                    backgroundColor: Colors.grey.withAlpha(50),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${tank.level}%',
                style: TextStyle(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}