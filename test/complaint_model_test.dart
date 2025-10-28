// test/complaint_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Adjust the import path based on your project structure
import 'package:aquasense/models/complaint_model.dart';

void main() {
  group('Complaint Model Tests', () {

    // Test data setup
    final timeNow = Timestamp.now();
    final timeEarlier = Timestamp.fromDate(timeNow.toDate().subtract(const Duration(hours: 1)));
    final timeEvenEarlier = Timestamp.fromDate(timeNow.toDate().subtract(const Duration(hours: 2)));

    final historyWithImages = [
      ComplaintStatusUpdate(status: 'Resolved', updatedAt: timeNow, updatedBy: 'sup1', supervisorImageUrl: 'resolved_image_url'),
      ComplaintStatusUpdate(status: 'In Progress', updatedAt: timeEarlier, updatedBy: 'sup1', supervisorImageUrl: 'progress_image_url'),
      ComplaintStatusUpdate(status: 'Submitted', updatedAt: timeEvenEarlier, updatedBy: 'user1'), // No image for submitted
    ];

    final historyNoMatchingImage = [
      ComplaintStatusUpdate(status: 'Resolved', updatedAt: timeNow, updatedBy: 'sup1'), // No image url
      ComplaintStatusUpdate(status: 'In Progress', updatedAt: timeEarlier, updatedBy: 'sup1', supervisorImageUrl: 'progress_image_url'),
      ComplaintStatusUpdate(status: 'Submitted', updatedAt: timeEvenEarlier, updatedBy: 'user1'),
    ];

    final historyEmpty = <ComplaintStatusUpdate>[];


    group('getSupervisorImageForStatus', () {

      test('should return correct image URL when status and image exist', () {
        // Arrange
        final complaint = Complaint(
          id: 'c1', userId: 'u1', type: 'Leakage', description: 'desc', wardId: 'w1', createdAt: timeEvenEarlier,
          statusHistory: historyWithImages, // Key data
        );

        // Act
        final progressImage = complaint.getSupervisorImageForStatus('In Progress');
        final resolvedImage = complaint.getSupervisorImageForStatus('Resolved');

        // Assert
        expect(progressImage, 'progress_image_url');
        expect(resolvedImage, 'resolved_image_url');
      });

      test('should return null if status exists but has no image URL', () {
        // Arrange
        final complaint = Complaint(
          id: 'c2', userId: 'u1', type: 'Leakage', description: 'desc', wardId: 'w1', createdAt: timeEvenEarlier,
          statusHistory: historyNoMatchingImage, // Key data
        );

        // Act
        final resolvedImage = complaint.getSupervisorImageForStatus('Resolved');

        // Assert
        expect(resolvedImage, isNull);
      });

      test('should return null if the status does not exist in history', () {
        // Arrange
        final complaint = Complaint(
          id: 'c3', userId: 'u1', type: 'Leakage', description: 'desc', wardId: 'w1', createdAt: timeEvenEarlier,
          statusHistory: historyWithImages, // Key data
        );

        // Act
        final image = complaint.getSupervisorImageForStatus('Rejected'); // Status not in history

        // Assert
        expect(image, isNull);
      });

      test('should return null if history is empty', () {
        // Arrange
        final complaint = Complaint(
          id: 'c4', userId: 'u1', type: 'Leakage', description: 'desc', wardId: 'w1', createdAt: timeEvenEarlier,
          statusHistory: historyEmpty, // Key data
        );

        // Act
        final image = complaint.getSupervisorImageForStatus('Resolved');

        // Assert
        expect(image, isNull);
      });

      // Optional: Test sorting logic if you relied on it heavily,
      // though the current implementation finds the first match which
      // works because the input list is sorted descending in the factory.
    });
  });
}