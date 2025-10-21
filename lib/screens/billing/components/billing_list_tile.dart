import 'dart:ui';
import 'package:aquasense/models/billing_info.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillingListTile extends StatelessWidget {
  final BillingInfo bill;

  const BillingListTile({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final bool isPaid = bill.status.toLowerCase() == 'paid';
    final Color statusColor = isPaid ? Colors.greenAccent : Colors.orangeAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              // ✅ FIX: Replaced withOpacity(0.1) with withAlpha(26)
              color: Colors.white.withAlpha(26),
              borderRadius: BorderRadius.circular(20),
              // ✅ FIX: Replaced withOpacity(0.2) with withAlpha(51)
              border: Border.all(color: Colors.white.withAlpha(51)),
            ),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 60,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // As of Sep 4, 2025, using DateFormat for clarity
                        DateFormat('MMMM d, yyyy').format(bill.date.toDate()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reading: ${bill.reading} m³',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${bill.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bill.status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}