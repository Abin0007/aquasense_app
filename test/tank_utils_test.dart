// test/tank_utils_test.dart (or your general utils test file)

import 'package:flutter/material.dart'; // Needed for Colors
import 'package:flutter_test/flutter_test.dart';

// Extracted logic for testing
Color getColorForLevel(int level) {
  if (level <= 20) return Colors.red.shade400;
  if (level < 40) return Colors.amber.shade400;
  return const Color(0xFF38B6FF); // Using const Color for direct comparison
}

void main() {
  group('TankLevelCard Utils - getColorForLevel', () {

    test('should return red accent for levels <= 20', () {
      expect(getColorForLevel(0), Colors.red.shade400);
      expect(getColorForLevel(15), Colors.red.shade400);
      expect(getColorForLevel(20), Colors.red.shade400);
    });

    test('should return amber accent for levels between 21 and 39', () {
      expect(getColorForLevel(21), Colors.amber.shade400);
      expect(getColorForLevel(30), Colors.amber.shade400);
      expect(getColorForLevel(39), Colors.amber.shade400);
    });

    test('should return blue (custom) for levels >= 40', () {
      expect(getColorForLevel(40), const Color(0xFF38B6FF));
      expect(getColorForLevel(75), const Color(0xFF38B6FF));
      expect(getColorForLevel(100), const Color(0xFF38B6FF));
    });

    test('should handle edge cases like negative (treat as <=20)', () {
      // Assuming negative levels shouldn't happen but testing defensively
      expect(getColorForLevel(-10), Colors.red.shade400);
    });

  });
}