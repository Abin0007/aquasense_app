import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MyQrCodeScreen extends StatelessWidget {
  const MyQrCodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0F2027),
      appBar: AppBar(
        title: const Text('My Meter QR Code'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (userId != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: QrImageView(
                    data: userId,
                    version: QrVersions.auto,
                    size: 250.0,
                  ),
                )
              else
                const Text(
                  'Could not generate QR code. User not logged in.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              const SizedBox(height: 24),
              Text(
                'Present this code to the supervisor for meter reading.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

