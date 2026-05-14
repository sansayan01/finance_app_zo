import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/branch_manager_providers.dart';

class BranchReportsPage extends ConsumerWidget {
  const BranchReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentUserBranchIdProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Branch Reports'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Collections'),
              Tab(text: 'Loans'),
              Tab(text: 'Members'),
              Tab(text: 'Staff'),
            ],
          ),
        ),
        body: branchId == null
            ? const Center(child: Text('No branch assigned'))
            : TabBarView(
                children: [
                  _CollectionsReport(branchId: branchId),
                  _LoansReport(branchId: branchId),
                  _MembersReport(branchId: branchId),
                  _StaffReport(branchId: branchId),
                ],
              ),
      ),
    );
  }
}

class _CollectionsReport extends ConsumerWidget {
  final String branchId;
  const _CollectionsReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Collection Trend (Last 7 Days)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    spots: [
                      const FlSpot(0, 15000),
                      const FlSpot(1, 18000),
                      const FlSpot(2, 12000),
                      const FlSpot(3, 22000),
                      const FlSpot(4, 19000),
                      const FlSpot(5, 25000),
                      const FlSpot(6, 28000),
                    ],
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),
          _buildSummaryCard(context, 'Today', currencyFormat.format(28000)),
          _buildSummaryCard(context, 'This Week', currencyFormat.format(139000)),
          _buildSummaryCard(context, 'This Month', currencyFormat.format(520000)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LoansReport extends StatelessWidget {
  final String branchId;
  const _LoansReport({required this.branchId});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatCard(context, 'Total Active Loans', '45', Colors.blue),
          _buildStatCard(context, 'Total Disbursed', currencyFormat.format(2500000), Colors.green),
          _buildStatCard(context, 'Outstanding Balance', currencyFormat.format(1800000), Colors.orange),
          _buildStatCard(context, 'Overdue Loans', '8', Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.account_balance, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _MembersReport extends StatelessWidget {
  final String branchId;
  const _MembersReport({required this.branchId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatCard(context, 'Total Members', '256', Colors.blue),
          _buildStatCard(context, 'Active Members', '241', Colors.green),
          _buildStatCard(context, 'New This Month', '15', Colors.purple),
          _buildStatCard(context, 'Pending KYC', '8', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.people, color: color),
        ),
        title: Text(title),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _StaffReport extends ConsumerWidget {
  final String branchId;
  const _StaffReport({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final performanceAsync = ref.watch(
      staffPerformanceProvider((branchId, null, null)),
    );

    return performanceAsync.when(
      data: (performance) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: performance.length,
        itemBuilder: (context, index) {
          final staff = performance[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(staff['name']?[0] ?? '?'),
              ),
              title: Text(staff['name'] ?? 'Unknown'),
              subtitle: Text('Efficiency: ${staff['efficiency'] ?? 0}%'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '₹${staff['collected'] ?? 0}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('Collected', style: TextStyle(fontSize: 10)),
                ],
              ),
            ),
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }
}
