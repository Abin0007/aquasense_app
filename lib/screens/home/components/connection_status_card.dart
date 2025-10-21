import 'package:aquasense/models/connection_request_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ConnectionStatusCard extends StatelessWidget {
  final ConnectionRequest request;
  final VoidCallback onTap;

  const ConnectionStatusCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  IconData _getIconForStatus(String status) {
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

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      sliver: SliverToBoxAdapter(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withAlpha(38),
                  Colors.cyan.withAlpha(20),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25.0),
              border: Border.all(color: Colors.cyanAccent.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getIconForStatus(request.currentStatus),
                      color: Colors.cyanAccent,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Connection Status',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  request.currentStatus,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Applied on: ${DateFormat('d MMMM, yyyy').format(request.appliedAt.toDate())}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Tap to view details',
                      style: TextStyle(
                        color: Colors.cyanAccent.withAlpha(200),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.cyanAccent.withAlpha(200),
                      size: 14,
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}