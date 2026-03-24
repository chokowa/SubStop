import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database_helper.dart';
import '../models/subscription.dart';
import '../utils/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => AnalyticsScreenState();
}

class AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<List<Subscription>> _subscriptionList;

  @override
  void initState() {
    super.initState();
    _subscriptionList = DatabaseHelper.instance.readAllSubscriptions();
  }

  Future<void> _refresh() async {
    setState(() {
      _subscriptionList = DatabaseHelper.instance.readAllSubscriptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('支出分析'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Subscription>>(
          future: _subscriptionList,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  '分析データの読み込みに失敗しました',
                  style: TextStyle(color: AppColors.textSub(context)),
                ),
              );
            }

            final subs = (snapshot.data ?? [])
                .where((s) => !s.isCancelled && !s.isArchived)
                .toList();

            if (subs.isEmpty) {
              return ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Text(
                        '分析できるサブスクがありません',
                        style: TextStyle(color: AppColors.textSub(context)),
                      ),
                    ),
                  ),
                ],
              );
            }

            final categoryTotals = <String, double>{};
            var totalSpend = 0.0;
            final rates = DatabaseHelper.instance.exchangeRates;

            for (final sub in subs) {
              final rate = rates[sub.currency] ?? 1.0;
              final monthlyPrice = sub.averageMonthlyPrice * rate;
              categoryTotals[sub.category] =
                  (categoryTotals[sub.category] ?? 0.0) + monthlyPrice;
              totalSpend += monthlyPrice;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTotalCard(totalSpend, context),
                const SizedBox(height: 24),
                Text(
                  'カテゴリ別の月額比率',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain(context),
                  ),
                ),
                const SizedBox(height: 16),
                _buildPieChart(categoryTotals, totalSpend),
                const SizedBox(height: 32),
                Text(
                  'カテゴリ別の詳細',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textMain(context),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCategoryList(categoryTotals, totalSpend, context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTotalCard(double total, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            '月額合計（円換算）',
            style: TextStyle(
              color: AppColors.textSub(context),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${NumberFormat('#,###').format(total.round())}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> categoryTotals, double total) {
    if (total == 0) return const SizedBox.shrink();

    final sections = <PieChartSectionData>[];
    categoryTotals.forEach((category, value) {
      sections.add(
        PieChartSectionData(
          value: value,
          title: '${((value / total) * 100).toStringAsFixed(0)}%',
          color: AppColors.getCategoryColor(category),
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    Map<String, double> categoryTotals,
    double total,
    BuildContext context,
  ) {
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: sortedEntries.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.getCategoryColor(entry.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.key,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                '¥${NumberFormat('#,###').format(entry.value.round())}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 8),
              Text(
                '(${((entry.value / total) * 100).toStringAsFixed(1)}%)',
                style: TextStyle(
                  color: AppColors.textSub(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
