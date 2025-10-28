// test/role_utils_test.dart

import 'package:flutter/material.dart'; // Needed for Icons and Colors
import 'package:flutter_test/flutter_test.dart';

// Assume these functions were extracted to a utility file or class
IconData getIconForRole(String role) {
  switch (role) {
    case 'supervisor':
      return Icons.supervisor_account_outlined;
    default: // citizen
      return Icons.person_outline;
  }
}

Color getColorForRole(String role) {
  switch (role) {
    case 'supervisor':
      return Colors.purpleAccent;
    default: // citizen
      return Colors.cyanAccent;
  }
}


void main() {
  group('Role Utility Functions', () {

    group('getIconForRole', () {
      test('should return supervisor icon for supervisor role', () {
        expect(getIconForRole('supervisor'), Icons.supervisor_account_outlined);
      });

      test('should return person icon for citizen role', () {
        expect(getIconForRole('citizen'), Icons.person_outline);
      });

      test('should return person icon for unknown/default role', () {
        expect(getIconForRole('admin'), Icons.person_outline); // Assuming default case covers this
        expect(getIconForRole(''), Icons.person_outline);
      });
    });

    group('getColorForRole', () {
      test('should return purple accent for supervisor role', () {
        expect(getColorForRole('supervisor'), Colors.purpleAccent);
      });

      test('should return cyan accent for citizen role', () {
        expect(getColorForRole('citizen'), Colors.cyanAccent);
      });

      test('should return cyan accent for unknown/default role', () {
        expect(getColorForRole('admin'), Colors.cyanAccent); // Assuming default case
        expect(getColorForRole(''), Colors.cyanAccent);
      });
    });

  });
}