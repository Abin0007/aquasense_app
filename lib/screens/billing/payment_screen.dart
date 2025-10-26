import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/models/user_data.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/services/payment_service.dart';
import 'package:aquasense/utils/helper_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentScreen extends StatefulWidget {
  final BillingInfo bill;
  final UserData userData;

  const PaymentScreen({super.key, required this.bill, required this.userData});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late PaymentService _paymentService;
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _paymentService = PaymentService(
      onPaymentSuccess: _handlePaymentSuccess,
      onPaymentFailure: _handlePaymentError,
      onExternalWallet: _handleExternalWallet,
    );
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint("Payment Successful: ${response.paymentId}");
    setState(() => _isLoading = true);
    final paymentId = response.paymentId ?? 'N/A';
    _firestoreService.updateBillStatus(widget.bill.id, paymentId).then((_) {
      // FIX: Check if the widget is still mounted before showing the dialog.
      if (mounted) {
        _showSuccessDialog();
      }
    }).catchError((error) {
      if (mounted) {
        HelperFunctions.showError(context, "Payment successful, but failed to update bill status.");
        setState(() => _isLoading = false);
      }
    });
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint("Payment Failed: ${response.code} - ${response.message}");
    HelperFunctions.showError(context, "Payment Failed: ${response.message}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
    HelperFunctions.showSnackBar(context, "Redirecting to ${response.walletName}...", color: Colors.blue);
  }

  void _initiatePayment() {
    _paymentService.openCheckout(
      amount: widget.bill.amount,
      description: 'Bill for ${DateFormat('MMMM yyyy').format(widget.bill.date.toDate())}',
      userEmail: widget.userData.email,
      userPhone: widget.userData.phoneNumber ?? '',
      userName: widget.userData.name,
    );
  }

  void _showSuccessDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C5364),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/animations/success_checkmark.json', repeat: false, height: 100),
            const SizedBox(height: 16),
            const Text("Payment Successful!", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Your bill has been marked as paid.", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              navigator.pop(); // Close dialog
              navigator.pop(); // Go back from payment screen
            },
            child: const Text("OK", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: const Color(0xFF152D4E),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bill Summary',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            _buildSummaryCard(),
            const Spacer(),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _initiatePayment,
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay with Razorpay'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: Colors.black,
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _buildDetailRow('Bill For:', DateFormat('MMMM yyyy').format(widget.bill.date.toDate())),
          const Divider(color: Colors.white24, height: 32),
          _buildDetailRow('Water Usage:', '${widget.bill.reading} m³'),
          const SizedBox(height: 16),
          _buildDetailRow('Due Date:', DateFormat('d MMM, yyyy').format(widget.bill.date.toDate().add(const Duration(days: 15)))),
          const Divider(color: Colors.white24, height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${widget.bill.amount.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}