import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../database/database_helper.dart';
import '../services/notification_service.dart';
import '../utils/app_colors.dart';
import '../widgets/subscription_icon.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  List<Subscription> _activeSubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubs();
  }

  Future<void> _loadSubs() async {
    final list = await DatabaseHelper.instance.readAllSubscriptions();
    setState(() {
      _activeSubs = list.where((s) => s.computedStatus == 'active').toList();
      _activeSubs.sort((a, b) => a.deadlineDate.compareTo(b.deadlineDate));
      _isLoading = false;
    });
  }

  // 一括設定用のステート
  final List<int> _bulkDays = [1];
  TimeOfDay _bulkTime = const TimeOfDay(hour: 9, minute: 0);

  Future<void> _applyBulkSettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知の一括設定', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('現在のアクティブな全サブスクリプションの通知設定を上書きしますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('上書きする'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    
    final notifyTypeJson = Subscription.createNotifyTypeJson(_bulkDays, _bulkTime);
    
    for (final sub in _activeSubs) {
      final updatedSub = Subscription.fromMap(sub.toMap()..['notify_type'] = notifyTypeJson);
      await DatabaseHelper.instance.updateSubscription(updatedSub);
      await NotificationService().scheduleDeadlineNotification(updatedSub);
    }
    
    await _loadSubs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('すべての通知設定を更新しました')));
    }
  }

  Future<void> _toggleNotification(Subscription sub, bool value) async {
    // ONにする場合は、現在の一括設定用デフォルト値を使用
    final notifyType = value 
      ? Subscription.createNotifyTypeJson(_bulkDays, _bulkTime)
      : 'none';

    final updatedSub = Subscription.fromMap(sub.toMap()..['notify_type'] = notifyType);
    
    await DatabaseHelper.instance.updateSubscription(updatedSub);
    
    if (value) {
      await NotificationService().scheduleDeadlineNotification(updatedSub);
    } else {
      await NotificationService().cancelNotification(updatedSub.id);
    }
    
    setState(() {
      final idx = _activeSubs.indexWhere((s) => s.id == sub.id);
      if (idx != -1) {
        _activeSubs[idx] = updatedSub;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? '$sub.nameの通知をONにしました' : '$sub.nameの通知をOFFにしました'),
          duration: const Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
       return Scaffold(
         backgroundColor: AppColors.background(context),
         appBar: AppBar(title: const Text('通知の設定', style: TextStyle(fontWeight: FontWeight.bold))),
         body: const Center(child: CircularProgressIndicator()),
       );
    }
    
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('通知の設定', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _activeSubs.isEmpty
          ? Center(
              child: Text('管理するアクティブなサブスクがありません', 
                style: TextStyle(color: AppColors.textSub(context))
              )
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 一括設定ヘッダー
                Card(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('一括設定', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                        const SizedBox(height: 16),
                        const Text('通知タイミング', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [0, 1, 3, 7].map((days) {
                            final isSelected = _bulkDays.contains(days);
                            return FilterChip(
                              label: Text(days == 0 ? '当日' : '$days日前', style: const TextStyle(fontSize: 11)),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _bulkDays.add(days);
                                  } else {
                                    _bulkDays.remove(days);
                                  }
                                });
                              },
                              selectedColor: AppColors.primary.withValues(alpha: 0.2),
                              checkmarkColor: AppColors.primary,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('通知時刻', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(context: context, initialTime: _bulkTime);
                                    if (picked != null) setState(() => _bulkTime = picked);
                                  },
                                  child: Text(
                                    '${_bulkTime.hour.toString().padLeft(2, '0')}:${_bulkTime.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton(
                              onPressed: _applyBulkSettings,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: const Text('全適用', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('個別設定', style: TextStyle(color: AppColors.textSub(context), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                ...List.generate(_activeSubs.length, (index) {
                  final sub = _activeSubs[index];
                  final isEnabled = sub.notifyType != 'none';
                  
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final deadline = DateTime(sub.deadlineDate.year, sub.deadlineDate.month, sub.deadlineDate.day);
                  final diffDays = deadline.difference(today).inDays;
                  final serviceColor = Color(sub.iconColorValue);

                  return Card(
                    color: AppColors.card(context),
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isEnabled ? serviceColor.withValues(alpha: 0.3) : Colors.transparent, width: 1.0),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Text(sub.name, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textMain(context))),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'デッドライン: ${DateFormat('MM/dd').format(sub.deadlineDate)} (あと$diffDays日)',
                            style: TextStyle(color: AppColors.textSub(context), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          if (isEnabled)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '通知: ${sub.notificationDays.map((d) => d == 0 ? "当日" : "${d}日前").join(", ")} / ${sub.formatNotificationTime()}',
                                style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900),
                              ),
                            ),
                        ],
                      ),
                      value: isEnabled,
                      onChanged: (val) => _toggleNotification(sub, val),
                      secondary: Container(
                        width: 44,
                        height: 44,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: serviceColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SubscriptionIcon(
                          iconName: sub.iconName,
                          colorValue: sub.iconColorValue,
                          size: 24,
                          padding: 4,
                        ),
                      ),
                    ),
                  );
                }),
          ],
        ),
    );
  }
}
