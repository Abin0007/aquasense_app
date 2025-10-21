import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/screens/billing/payment_screen.dart';
import 'package:aquasense/screens/billing/receipt_screen.dart';
import 'package:aquasense/utils/page_transition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BillDetailScreen extends StatelessWidget {
  final BillingInfo bill;
  final UserData userData;
  const BillDetailScreen(
      {super.key, required this.bill, required this.userData});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('billingHistory')
          .doc(bill.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F2027),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final updatedBill = BillingInfo.fromFirestore(snapshot.data!);
        final bool isPaid = updatedBill.status.toLowerCase() == 'paid';
        final double fine = isPaid ? (updatedBill.fineAmount ?? 0.0) : updatedBill.currentFine;
        final double totalAmount = updatedBill.amount + fine;

        return Scaffold(
          backgroundColor: const Color(0xFF0F2027),
          appBar: AppBar(
            title: Text(DateFormat('MMMM yyyy').format(updatedBill.date.toDate())),
            backgroundColor: const Color(0xFF152D4E),
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildAmountHeader(totalAmount, isPaid),
              const SizedBox(height: 30),
              _buildDetailCard(updatedBill, isPaid, fine),
              const SizedBox(height: 40),
              if (isPaid)
                ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('View Receipt'),
                  onPressed: () {
                    Navigator.of(context).push(SlideFadeRoute(
                      page: ReceiptScreen(bill: updatedBill, userData: userData),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                )
              else
                ElevatedButton.icon(
                  icon: const Icon(Icons.payment_outlined),
                  label: Text('Proceed to Pay ₹${totalAmount.toStringAsFixed(2)}'),
                  onPressed: () {
                    Navigator.of(context).push(SlideFadeRoute(
                      page: PaymentScreen(bill: updatedBill, userData: userData),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmountHeader(double totalAmount, bool isPaid) {
    return Center(
      child: Column(
        children: [
          Text(
            isPaid ? 'Amount Paid' : 'Amount Due',
            style: const TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${totalAmount.toStringAsFixed(2)}',
            style: TextStyle(
              color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(BillingInfo bill, bool isPaid, double fine) {
    final dueDate = bill.date.toDate().add(const Duration(days: 10));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildDetailRow('Status', bill.status,
              valueColor: isPaid ? Colors.greenAccent : Colors.orangeAccent),
          const Divider(color: Colors.white24),
          _buildDetailRow('Bill Amount', '₹${bill.amount.toStringAsFixed(2)}'),
          if (fine > 0) ...[
            const Divider(color: Colors.white24),
            _buildDetailRow('Fine', '₹${fine.toStringAsFixed(2)}', valueColor: Colors.redAccent),
          ],
          const Divider(color: Colors.white24),
          _buildDetailRow(
              'Bill Date', DateFormat('d MMMM, yyyy').format(bill.date.toDate())),
          const Divider(color: Colors.white24),
          _buildDetailRow('Due Date', DateFormat('d MMMM, yyyy').format(dueDate)),
          const Divider(color: Colors.white24),
          _buildDetailRow('Water Usage', '${bill.reading} m³'),
          if (isPaid && bill.paymentId != null) ...[
            const Divider(color: Colors.white24),
            _buildDetailRow('Payment ID', bill.paymentId!),
            const Divider(color: Colors.white24),
            if (bill.paidAt != null)
              _buildDetailRow('Paid On',
                  DateFormat('d MMM yyyy, h:mm a').format(bill.paidAt!.toDate())),
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 16)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}