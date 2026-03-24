import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../database/database_helper.dart';
import '../widgets/subscription_card.dart';
import '../utils/app_colors.dart';
import '../services/exchange_rate_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Subscription>> _historySubscriptions;
  Map<String, double> _rates = {};

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  Future<void> _refreshList() async {
    _rates = await ExchangeRateService().getRates();
    setState(() {
      _historySubscriptions = DatabaseHelper.instance.readAllSubscriptions().then((list) {
        // アーカイブ済み または 期限切れ(expired)
        var filtered = list.where((sub) => sub.isArchived || sub.computedStatus == 'expired').toList();
        filtered.sort((a, b) => b.nextBillingDate.compareTo(a.nextBillingDate));
        return filtered;
      });
    });
  }

  Future<void> _restoreSubscription(Subscription sub) async {
    sub.isArchived = false;
    sub.isCancelled = false;
    await DatabaseHelper.instance.updateSubscription(sub);
    _refreshList();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('リストに復帰しました。')));
  }

  Future<void> _fullDeleteSubscription(Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('データの完全削除', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('このサブスクの記録をデータベースから完全に消去します。よろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('キャンセル', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('完全に削除', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold))),
        ],
      )
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.deleteSubscription(sub.id);
      _refreshList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('アーカイブ・履歴', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textMain(context),
      ),
      body: FutureBuilder<List<Subscription>>(
        future: _historySubscriptions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          final subs = snapshot.data ?? [];
          if (subs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 64, color: AppColors.textSub(context).withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    '履歴には何もありません', 
                    style: TextStyle(color: AppColors.textSub(context), fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 8),
                  Text('解約済みやアーカイブしたものがここに並びます', style: TextStyle(color: AppColors.textSub(context).withValues(alpha: 0.6), fontSize: 13)),
                ],
              )
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: subs.length,
            itemBuilder: (context, index) {
              final sub = subs[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Opacity(
                      opacity: 0.7,
                      child: SubscriptionCard(
                        subscription: sub,
                        rates: _rates,
                        onTap: () => _showHistoryOptions(sub),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showHistoryOptions(Subscription sub) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: AppColors.card(context), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.refresh, color: AppColors.primary),
              title: const Text('リストに復帰させる', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('再度メイン画面で管理を開始します'),
              onTap: () { Navigator.pop(ctx); _restoreSubscription(sub); },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: AppColors.danger),
              title: const Text('完全に削除', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
              subtitle: const Text('記録をすべて消去します'),
              onTap: () { Navigator.pop(ctx); _fullDeleteSubscription(sub); },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
