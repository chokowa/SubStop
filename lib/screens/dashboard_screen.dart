import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';
import '../models/subscription.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../widgets/subscription_card.dart';
import '../utils/app_colors.dart';
import '../utils/app_icons.dart';
import '../widgets/subscription_icon.dart';
import 'analytics_screen.dart';
import 'add_subscription_screen.dart';
import 'history_screen.dart';
import 'notification_settings_screen.dart';
import 'exchange_rate_settings_screen.dart';
import '../services/exchange_rate_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Subscription>> _subscriptionList;

  String _selectedCategory = 'すべて';
  String _selectedPaymentMethod = 'すべて';
  String _sortOrder = 'next_billing_date';
  bool _isTimelineMode = false;

  bool _isStatsExpanded = false; // 統計詳細の展開状態
  bool _includeCancelled = true;
  bool _includeTrial = false; // 名称変更
  Map<String, double> _rates = {};

  List<String> _categories = [];
  List<String> _paymentMethods = ['すべて'];
  final Set<String> _pendingDeleteIds = {}; // 削除保留中のID
  final Map<String, Timer> _pendingDeleteTimers = {}; // 各タイマー管理

  @override
  void initState() {
    super.initState();
    _loadCategories(); // カテゴリリストをロード
    _subscriptionList = _loadInitialData();
  }

  Future<List<Subscription>> _loadInitialData() async {
    final list = await DatabaseHelper.instance.readAllSubscriptions();
    _rates = await ExchangeRateService().getRates();
    _updatePaymentMethods(list);
    return _applyFiltersAndSort(list);
  }

  void _updatePaymentMethods(List<Subscription> list) {
    final methods = list.map((e) => e.paymentMethod).where((e) => e.isNotEmpty).toSet().toList();
    setState(() {
      _paymentMethods = ['すべて', ...methods];
    });
  }

  Future<List<Subscription>> _refreshList() async {
    final list = await DatabaseHelper.instance.readAllSubscriptions();
    _updatePaymentMethods(list);
    return _applyFiltersAndSort(list);
  }

  List<Subscription> _applyFiltersAndSort(List<Subscription> list) {
    // アーカイブされていないアクティブなもの、または削除保留中のもの
    var filtered = list.where((sub) => !sub.isArchived || _pendingDeleteIds.contains(sub.id)).toList();
    
    // かつ、期限切れ(expired)のものも、保留中でなければ除外
    filtered = filtered.where((sub) => sub.computedStatus != 'expired' || _pendingDeleteIds.contains(sub.id)).toList();

    if (_selectedCategory != 'すべて') {
      filtered = filtered.where((sub) => sub.category == _selectedCategory).toList();
    }
    if (_selectedPaymentMethod != 'すべて') {
      filtered = filtered.where((sub) => sub.paymentMethod == _selectedPaymentMethod).toList();
    }

    if (_sortOrder == 'price_desc') {
      filtered.sort((a, b) {
        final aRate = _rates[a.currency] ?? 1.0;
        final bRate = _rates[b.currency] ?? 1.0;
        return (b.price * bRate).compareTo(a.price * aRate);
      });
    } else if (_sortOrder == 'price_asc') {
      filtered.sort((a, b) {
        final aRate = _rates[a.currency] ?? 1.0;
        final bRate = _rates[b.currency] ?? 1.0;
        return (a.price * aRate).compareTo(b.price * bRate);
      });
    } else if (_isTimelineMode || _sortOrder == 'next_billing_date') {
      filtered.sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));
    }

    return filtered;
  }

  double _calculateMonthlyBurnRate(List<Subscription> subs) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return subs.fold(0.0, (sum, item) {
      // 1. 有効期間の重複チェック
      final start = item.startDate ?? DateTime(2000);
      if (start.isAfter(currentMonthEnd)) return sum; // まだ始まっていない

      if (item.isCancelled) {
        if (!_includeCancelled) return sum; 
        final end = item.nextBillingDate; 
        if (end.isBefore(currentMonthStart)) return sum; // 今月より前に終了
      }

      // 2. トライアル判定
      bool isInTrial = false;
      if (item.billingType == 'trial_days' && item.startDate != null) {
        final trialEnd = item.startDate!.add(Duration(days: item.trialDays));
        if (now.isBefore(trialEnd)) {
          isInTrial = true;
        }
      }

      // 3. コスト加算
      if (isInTrial && !_includeTrial) {
        return sum; 
      }

      // 為替換算
      double priceInJPY = item.averageMonthlyPrice;
      if (item.currency != 'JPY') {
        final rate = _rates[item.currency] ?? 1.0;
        priceInJPY *= rate;
      }

      return sum + priceInJPY;
    });
  }

  Future<void> _toggleCancelStatus(Subscription sub) async {
    final newValue = !sub.isCancelled;
    sub.isCancelled = newValue;
    
    await DatabaseHelper.instance.updateSubscription(sub);

    // 解約状態に連動してバックグラウンドの通知タスクも制御
    if (newValue) {
      await NotificationService().cancelNotification(sub.id);
    } else {
      // 復活させたなら再スケジュール
      await NotificationService().scheduleDeadlineNotification(sub);
    }

    setState(() {
      _subscriptionList = _refreshList();
    });
  }

  Future<void> _loadCategories() async {
    final list = await DatabaseHelper.instance.readAllCategories();
    setState(() {
      _categories = ['すべて', ...list];
    });
  }

  Future<void> _deleteSubscription(Subscription sub) async {
    // すでにタイマーがあればキャンセル（再スワイプ対策）
    _pendingDeleteTimers[sub.id]?.cancel();

    setState(() {
      sub.isArchived = true;
      _pendingDeleteIds.add(sub.id);
    });
    
    await DatabaseHelper.instance.updateSubscription(sub);

    // 通知は一旦解除
    await NotificationService().cancelNotification(sub.id);

    // 4秒後に確定
    _pendingDeleteTimers[sub.id] = Timer(const Duration(seconds: 4), () async {
      if (mounted) {
        setState(() {
          _pendingDeleteIds.remove(sub.id);
          _pendingDeleteTimers.remove(sub.id);
          _subscriptionList = _refreshList();
        });
      }
      // データベースの状態はすでに isArchived=true なので、
      // ここで追加のDB操作は不要。
    });
  }

  Future<void> _undoDelete(Subscription sub) async {
    _pendingDeleteTimers[sub.id]?.cancel();
    _pendingDeleteTimers.remove(sub.id);
    
    sub.isArchived = false;
    await DatabaseHelper.instance.updateSubscription(sub);
    await NotificationService().scheduleDeadlineNotification(sub);

    setState(() {
      _pendingDeleteIds.remove(sub.id);
      _subscriptionList = _refreshList();
    });
  }

  Future<void> _toggleArchiveStatus(Subscription sub) async {
    await _deleteSubscription(sub);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('SubStop'),
        actions: [
          IconButton(
            icon: Icon(_isTimelineMode ? Icons.list : Icons.timeline),
            onPressed: () => setState(() { 
              _isTimelineMode = !_isTimelineMode; 
              _subscriptionList = _refreshList(); 
            }),
            tooltip: _isTimelineMode ? 'リスト表示' : 'タイムライン表示',
          ),
          IconButton(
            icon: const Icon(Icons.currency_exchange),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExchangeRateSettingsScreen())).then((val) { 
              if (val == true) setState(() { _subscriptionList = _refreshList(); }); 
            }),
            tooltip: '為替・通貨設定',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsScreen())).then((_) => setState(() { _subscriptionList = _refreshList(); })),
            tooltip: '通知の管理',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())).then((_) => setState(() { _subscriptionList = _refreshList(); })),
            tooltip: '過去のサブスク',
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())).then((_) => setState(() { _subscriptionList = _refreshList(); })),
          ),
        ],
      ),
      body: FutureBuilder<List<Subscription>>(
        future: _subscriptionList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
             return Center(child: Text('データを読み込めませんでした', style: TextStyle(color: AppColors.danger)));
          }

          final subscriptions = snapshot.data ?? [];
          final burnRate = _calculateMonthlyBurnRate(subscriptions);

          return SafeArea(
            child: Column(
              children: [
                // 統計ウィジェット (Gaming Style: Expandable Panel)
                GestureDetector(
                  onTap: () => setState(() => _isStatsExpanded = !_isStatsExpanded),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1E), // 深いグレー（モックに準拠）
                      borderRadius: BorderRadius.circular(28),
                      // border: Border.all(color: Colors.white.withOpacity(0.05), width: 1), // 控えめなエッジ
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL MONTHLY COST',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            AnimatedRotation(
                              duration: const Duration(milliseconds: 300),
                              turns: _isStatsExpanded ? 0.5 : 0,
                              child: Icon(Icons.keyboard_arrow_down, color: Colors.white.withOpacity(0.3), size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '¥${NumberFormat('#,###').format(burnRate.round())}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 52,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        // 展開される詳細設定
                        AnimatedCrossFade(
                          firstChild: const SizedBox(height: 0),
                          secondChild: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Divider(color: Colors.white10),
                              ),
                              Text(
                                'CALCULATION SETTINGS',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildGamingOptionRow(
                                '今月解約済サブスクを',
                                _includeCancelled,
                                (val) => setState(() => _includeCancelled = val),
                              ),
                              const SizedBox(height: 16),
                              _buildGamingOptionRow(
                                'トライアル期間のコストを',
                                _includeTrial,
                                (val) => setState(() => _includeTrial = val),
                              ),
                            ],
                          ),
                          crossFadeState: _isStatsExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 300),
                        ),
                      ],
                    ),
                  ),
                ),

                // フィルター行
                SizedBox(
                  height: 52,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildCompactFilter(
                          _selectedCategory == 'すべて' ? 'カテゴリ' : _selectedCategory,
                          _categories,
                          (val) => setState(() { _selectedCategory = val!; _subscriptionList = _refreshList(); }),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          _selectedPaymentMethod == 'すべて' ? '支払い' : _selectedPaymentMethod,
                          _paymentMethods,
                          (val) => setState(() { _selectedPaymentMethod = val!; _subscriptionList = _refreshList(); }),
                        ),
                        const SizedBox(width: 8),
                        _buildCompactFilter(
                          _sortOrder == 'next_billing_date' ? '支払日が近い' : (_sortOrder == 'price_desc' ? '高い順' : '安い順'),
                          ['支払日が近い', '高い順', '安い順'],
                          (val) {
                            if (val == '支払日が近い') _sortOrder = 'next_billing_date';
                            else if (val == '高い順') _sortOrder = 'price_desc';
                            else _sortOrder = 'price_asc';
                            setState(() { _subscriptionList = _refreshList(); });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator())
                      : subscriptions.isEmpty
                          ? Center(child: Text('サブスクがありません', style: TextStyle(color: AppColors.textSub(context), fontSize: 16)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: subscriptions.length,
                              itemBuilder: (context, index) {
                                final sub = subscriptions[index];
                                
                                bool showSeparator = false;
                                if (_isTimelineMode && index == 0) showSeparator = true;
                                if (_isTimelineMode && index > 0) {
                                  final prevSub = subscriptions[index - 1];
                                  if (prevSub.nextBillingDate.month != sub.nextBillingDate.month) showSeparator = true;
                                }

                                return Column(
                                  key: ValueKey('${sub.id}_column'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (showSeparator)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        child: Row(
                                          children: [
                                            Text(
                                              DateFormat('MMMM yyyy').format(sub.nextBillingDate),
                                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 13),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(child: Divider(thickness: 1, color: Colors.blueAccent, height: 1)),
                                          ],
                                        ),
                                      ),
                                    if (_pendingDeleteIds.contains(sub.id))
                                      Container(
                                        key: Key('pending_${sub.id}'),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.card(context).withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '「${sub.name}」を削除しました',
                                                    style: TextStyle(color: AppColors.textMain(context), fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  const Text(
                                                    '履歴からいつでも復元できます',
                                                    style: TextStyle(color: Colors.grey, fontSize: 11),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _undoDelete(sub),
                                              child: const Text('元に戻す', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Dismissible(
                                        key: Key(sub.id),
                                        background: _buildSwipeAction(Alignment.centerLeft, AppColors.safe, sub.isCancelled ? Icons.undo : Icons.check),
                                        secondaryBackground: _buildSwipeAction(Alignment.centerRight, AppColors.danger, Icons.delete),
                                        confirmDismiss: (direction) async {
                                          if (direction == DismissDirection.startToEnd) { 
                                            await _toggleCancelStatus(sub); 
                                            return false; 
                                          }
                                          return true; 
                                        },
                                        onDismissed: (direction) { if (direction == DismissDirection.endToStart) _deleteSubscription(sub); },
                                        child: SubscriptionCard(
                                          subscription: sub,
                                          rates: _rates,
                                          onTap: () => _showSubscriptionDetail(sub),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_sub_fab',
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddSubscriptionScreen()),
          ).then((value) {
            if (value == true) setState(() { _subscriptionList = _refreshList(); });
          });
        },
        child: const Icon(Icons.add, size: 32),
      ),
    );
  }

  void _showSubscriptionDetail(Subscription sub) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
          child: Column(
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60, height: 60,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(color: Color(sub.iconColorValue).withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
                            child: SubscriptionIcon(
                              iconName: sub.iconName,
                              colorValue: sub.iconColorValue,
                              size: 32,
                              padding: 8,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sub.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textMain(context))),
                                Text(sub.category, style: TextStyle(fontSize: 13, color: AppColors.textSub(context), fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () { 
                              Navigator.pop(context); 
                              Navigator.push(context, MaterialPageRoute(builder: (_) => AddSubscriptionScreen(existingSubscription: sub)))
                                .then((v) { if (v == true) setState(() { _subscriptionList = _refreshList(); }); }); 
                            },
                            icon: Icon(Icons.edit_outlined, color: AppColors.primary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.06), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('料金プラン', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSub(context), letterSpacing: 1.0)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_getCurrencySymbol(sub.currency)}${_formatCurrency(sub.price, sub.currency)} / ${sub.cycle == 'yearly' ? '年' : '月'}', 
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textMain(context))
                                ),
                                if (sub.currency != 'JPY')
                                  Text(
                                    '約 ¥${NumberFormat('#,###').format((sub.price * (_rates[sub.currency] ?? 1.0)).round())}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                              ],
                            ),
                            if (sub.cycle == 'yearly')
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('月額換算', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSub(context), letterSpacing: 1.0)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getCurrencySymbol(sub.currency)}${_formatCurrency(sub.averageMonthlyPrice, sub.currency)}', 
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)
                                  ),
                                  if (sub.currency != 'JPY')
                                    Text(
                                      '約 ¥${NumberFormat('#,###').format((sub.averageMonthlyPrice * (_rates[sub.currency] ?? 1.0)).round())}',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      _buildDetailItem('次回支払日', DateFormat('yyyy/MM/dd').format(sub.nextBillingDate), Icons.event_available_outlined),
                      _buildDetailItem('解約猶予日', DateFormat('yyyy/MM/dd').format(sub.deadlineDate), Icons.notifications_active_outlined, highlight: true),
                      
                      // 通知設定の表示と編集ボタン
                      _buildDetailItem(
                        '通知設定',
                        '${sub.notificationDays.isEmpty ? "なし" : sub.notificationDays.map((d) => d == 0 ? "当日" : "${d}日前").join(", ")} / ${sub.formatNotificationTime()}',
                        Icons.alarm_on_outlined,
                        onTap: () async {
                          // 通知設定を編集するための簡易的な処理
                          // 本来はAddSubscriptionScreenと同様のUIが良いが、ここでは時間の変更のみデモ的に実装
                          final newTime = await showTimePicker(
                            context: context,
                            initialTime: sub.notificationTime,
                          );
                          if (newTime != null) {
                            final newSub = sub;
                            final newNotifyType = Subscription.createNotifyTypeJson(sub.notificationDays, newTime);
                            // プロパティを直接書き換える（SubscriptionモデルがImmutableでない前提、またはコピー作成）
                            // 実際には updateSubscription を呼ぶ
                            final updatedSub = Subscription.fromMap(sub.toMap()..['notify_type'] = newNotifyType);
                            await DatabaseHelper.instance.updateSubscription(updatedSub);
                            await NotificationService().scheduleDeadlineNotification(updatedSub);
                            if (mounted) {
                              setState(() { _subscriptionList = _refreshList(); });
                              Navigator.pop(context); // 一旦閉じて更新を促す
                              _showSubscriptionDetail(updatedSub); // 再表示
                            }
                          }
                        },
                      ),

                      _buildDetailItem('支払い方法', sub.paymentMethod.isEmpty ? '未設定' : sub.paymentMethod, Icons.credit_card_outlined),
                      if (sub.memo.isNotEmpty)
                        _buildDetailItem('メモ', sub.memo, Icons.notes_outlined),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () { Navigator.pop(context); _toggleCancelStatus(sub); },
                              icon: Icon(sub.isCancelled ? Icons.play_arrow : Icons.stop, color: sub.isCancelled ? AppColors.safe : AppColors.danger, size: 18),
                              label: Text(sub.isCancelled ? '復活' : '解約', style: TextStyle(color: sub.isCancelled ? AppColors.safe : AppColors.danger, fontWeight: FontWeight.w900)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: (sub.isCancelled ? AppColors.safe : AppColors.danger).withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () { Navigator.pop(context); _toggleArchiveStatus(sub); },
                              icon: const Icon(Icons.archive_outlined, color: Colors.grey, size: 18),
                              label: const Text('履歴へ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w900)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Colors.grey.withOpacity(0.08),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, IconData icon, {bool highlight = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 18, color: highlight ? AppColors.warning : AppColors.textSub(context)),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textSub(context), letterSpacing: 0.5)),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: highlight ? AppColors.warning : AppColors.textMain(context))),
              ],
            ),
            if (onTap != null) ...[
              const Spacer(),
              Icon(Icons.chevron_right, size: 16, color: AppColors.textSub(context).withOpacity(0.3)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGamingOptionRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        _buildGamingSegmentControl(value, onChanged),
      ],
    );
  }

  Widget _buildGamingSegmentControl(bool value, ValueChanged<bool> onChanged) {
    return Container(
      width: 140,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          // 含めない
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: !value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '含めない',
                  style: TextStyle(
                    color: !value ? Colors.white : Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          // 含める
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: value ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '含める',
                  style: TextStyle(
                    color: value ? Colors.white : Colors.white.withOpacity(0.3),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilter(String label, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(label) ? label : null,
          hint: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMain(context))),
          icon: const Icon(Icons.keyboard_arrow_down, size: 14),
          dropdownColor: AppColors.card(context),
          items: items.map((sub) {
            final bool isCategory = _categories.contains(sub) && sub != 'すべて';
            return DropdownMenuItem(
              value: sub,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCategory) ...[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.getCategoryColor(sub),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(sub, style: const TextStyle(fontSize: 12)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildSwipeAction(Alignment alignment, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(icon, color: Colors.white),
    );
  }

  String _formatCurrency(double value, String currency) {
    if (currency == 'JPY') {
      return NumberFormat('#,###').format(value.round());
    } else {
      return NumberFormat('#,##0.00').format(value);
    }
  }

  String _getCurrencySymbol(String currency) {
    switch (currency) {
      case 'USD': return r'$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return '¥';
    }
  }
}
