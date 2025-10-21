import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/supervisor/billing/enter_reading_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanComplete = false;

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_isScanComplete) return;

    final String? scannedUserId = capture.barcodes.first.rawValue;
    if (scannedUserId != null && scannedUserId.isNotEmpty) {
      setState(() => _isScanComplete = true);
      _scannerController.stop();

      // Fetch user data before navigating
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(scannedUserId)
            .get();
        if (doc.exists && mounted) {
          final citizen = UserData.fromFirestore(doc);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => EnterReadingScreen(citizen: citizen),
            ),
          );
        } else {
          // Handle case where user ID from QR is not found
          _showErrorAndRescan('User not found for this QR code.');
        }
      } catch (e) {
        _showErrorAndRescan('Error fetching user data.');
      }
    }
  }

  void _showErrorAndRescan(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      // Reset state to allow another scan
      setState(() {
        _isScanComplete = false;
        _scannerController.start();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Meter QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetection,
          ),
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyanAccent, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const Positioned(
            bottom: 80,
            child: Text(
              'Align QR code within the frame',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}
