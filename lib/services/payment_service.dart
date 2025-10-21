import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';


class PaymentService {
  late Razorpay _razorpay;

  // Razorpay API Key - Replace with your actual key from the Razorpay dashboard
  // For testing purposes, you can use a test key.
  static const String _apiKey = 'rzp_test_RDvImXtNoxU5Kr';

  PaymentService({
    required Function(PaymentSuccessResponse) onPaymentSuccess,
    required Function(PaymentFailureResponse) onPaymentFailure,
    required Function(ExternalWalletResponse) onExternalWallet,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (response) => onPaymentSuccess(response!));
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (response) => onPaymentFailure(response!));
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (response) => onExternalWallet(response!));
  }

  void openCheckout({
    required double amount,
    required String description,
    required String userEmail,
    required String userPhone,
    required String userName,
  }) {
    // Amount should be in the smallest currency unit (e.g., paise for INR)
    final amountInPaise = (amount * 100).toInt();

    var options = {
      'key': _apiKey,
      'amount': amountInPaise,
      'name': 'AquaSense Water Supply',
      'description': description,
      'prefill': {
        'contact': userPhone,
        'email': userEmail,
        'name': userName,
      },
      'external': {
        'wallets': ['paytm']
      }
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay checkout: $e');
    }
  }

  void dispose() {
    _razorpay.clear();
  }
}
