// test/complaint_utils_test.dart

import 'package:flutter_test/flutter_test.dart';

// Assume this function exists or you copy/paste the logic here for testing
int getStatusPriority(String status) {
  switch (status.toLowerCase()) {
    case 'submitted':
      return 0;
    case 'in progress':
      return 1;
    case 'resolved':
      return 2;
    default:
      return 3; // Handles unknown or other statuses
  }
}

void main() {
  // Group related tests together
  group('Complaint Status Priority', () {

    // Test case 1: Submitted status
    test('should return 0 for Submitted status', () {
      // Arrange: Set up the input
      const status = 'Submitted';

      // Act: Call the function being tested
      final priority = getStatusPriority(status);

      // Assert: Check if the result is what you expect
      expect(priority, 0);
    });

    // Test case 2: In Progress status (case-insensitive)
    test('should return 1 for In Progress status (case-insensitive)', () {
      // Arrange
      const status = 'in PrOgReSs'; // Test different casing

      // Act
      final priority = getStatusPriority(status);

      // Assert
      expect(priority, 1);
    });

    // Test case 3: Resolved status
    test('should return 2 for Resolved status', () {
      // Arrange
      const status = 'Resolved';

      // Act
      final priority = getStatusPriority(status);

      // Assert
      expect(priority, 2);
    });

    // Test case 4: Unknown status
    test('should return 3 for an unknown status', () {
      // Arrange
      const status = 'Pending Approval'; // An example of a status not explicitly handled

      // Act
      final priority = getStatusPriority(status);

      // Assert
      expect(priority, 3);
    });

    // Test case 5: Empty status string
    test('should return 3 for an empty status string', () {
      // Arrange
      const status = '';

      // Act
      final priority = getStatusPriority(status);

      // Assert
      expect(priority, 3);
    });
  });
}