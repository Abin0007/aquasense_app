import 'package:aquasense/models/billing_info.dart';
import 'package:aquasense/services/firestore_service.dart';
import 'package:aquasense/screens/statistics/components/stat_card.dart';
import 'package:aquasense/screens/statistics/components/usage_chart.dart';
import 'package:flutter/material.dart';

class UsageStatisticsScreen extends StatefulWidget {
  const UsageStatisticsScreen({super.key});

  @override
  State<UsageStatisticsScreen> createState() => _UsageStatisticsScreenState();
}

class _UsageStatisticsScreenState extends State<UsageStatisticsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: StreamBuilder<List<BillingInfo>>(
          stream: _firestoreService.getBillingHistoryStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent));
            }
            if (snapshot.hasError) {
              return Center(
                  child: Text('Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent)));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                  child: Text('No usage data available.',
                      style: TextStyle(color: Colors.white70)));
            }

            final history = snapshot.data!;
            return _buildContent(history);
          },
        ),
      ),
    );
  }

  Widget _buildContent(List<BillingInfo> history) {
    if (history.isEmpty) {
      return const Center(
          child: Text('No usage data available.',
              style: TextStyle(color: Colors.white70)));
    }

    // --- MODIFIED LOGIC FOR AVERAGE USAGE ---
    final sortedHistory = List<BillingInfo>.from(history)
      ..sort((a, b) => a.date.compareTo(b.date));

    List<double> consumptionData = [];
    if (sortedHistory.isNotEmpty) {
      consumptionData.add(sortedHistory[0].reading.toDouble());
      for (int i = 1; i < sortedHistory.length; i++) {
        final consumption = sortedHistory[i].reading - sortedHistory[i - 1].reading;
        consumptionData.add(consumption.toDouble());
      }
    }

    final double avgUsage = consumptionData.isEmpty
        ? 0.0
        : consumptionData.reduce((a, b) => a + b) / consumptionData.length;
    // --- END MODIFIED LOGIC ---

    final double highestBill =
    history.map((e) => e.amount).reduce((a, b) => a > b ? a : b);

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          backgroundColor: Colors.transparent,
          expandedHeight: 120.0,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text('Usage Statistics',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monthly Consumption',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Last ${history.length} Months',
                  style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 16),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 300,
                  padding: const EdgeInsets.only(top: 16, right: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(51)),
                  ),
                  child: UsageChart(billingHistory: history),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    StatCard(
                      title: 'Avg. Usage',
                      value: '${avgUsage.toStringAsFixed(1)} m³',
                      icon: Icons.water_drop_outlined,
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 16),
                    StatCard(
                      title: 'Highest Bill',
                      value: '₹${highestBill.toStringAsFixed(2)}',
                      icon: Icons.receipt_long_outlined,
                      color: Colors.orangeAccent,
                    ),
                  ],
                )
              ],
            ),
          ),
        )
      ],
    );
  }
}