// test/connection_status_utils_test.dart (or general utils)

import 'package:flutter/material.dart'; // Needed for Icons
import 'package:flutter_test/flutter_test.dart';

// Extracted logic
IconData getIconForStatus(String status) {
  switch (status.toLowerCase()) {
    case 'application submitted':
      return Icons.file_present_rounded;
    case 'document verification':
      return Icons.document_scanner_outlined;
    case 'site visit scheduled':
      return Icons.location_on_outlined;
    case 'approved':
      return Icons.check_circle_outline;
    case 'completed':
      return Icons.done_all_rounded;
    case 'rejected':
      return Icons.cancel_outlined;
    default:
      return Icons.hourglass_empty_rounded;
  }
}

void main() {
  group('ConnectionStatusCard Utils - getIconForStatus', () {

    test('should return correct icon for each known status (case-insensitive)', () {
      expect(getIconForStatus('Application Submitted'), Icons.file_present_rounded);
      expect(getIconForStatus('document verification'), Icons.document_scanner_outlined);
      expect(getIconForStatus('Site Visit Scheduled'), Icons.location_on_outlined);
      expect(getIconForStatus('approved'), Icons.check_circle_outline);
      expect(getIconForStatus('COMPLETED'), Icons.done_all_rounded);
      expect(getIconForStatus('Rejected'), Icons.cancel_outlined);
    });

    test('should return default hourglass icon for unknown status', () {
      expect(getIconForStatus('Pending Payment'), Icons.hourglass_empty_rounded);
      expect(getIconForStatus(''), Icons.hourglass_empty_rounded);
    });
  });
}