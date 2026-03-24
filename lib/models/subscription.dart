import 'dart:convert';
import 'package:flutter/material.dart';

import '../utils/app_constants.dart';

class Subscription {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String cycle;
  final DateTime nextBillingDate;
  final String cancellationRule;
  final int offsetDays;
  final String category;
  final String notifyType; // JSON string or legacy string
  final String paymentMethod;
  final String iconName;
  final int iconColorValue;
  final String billingType;
  final int trialDays;
  final DateTime? startDate;
  final String memo;
  bool isCancelled;
  bool isArchived;

  // 拡張された通知設定
  late List<int> notificationDays; // [0, 1, 3] etc. (days before deadline)
  late TimeOfDay notificationTime; // (hour, minute)

  Subscription({
    required this.id,
    required this.name,
    required this.price,
    this.currency = 'JPY',
    required this.cycle,
    required this.nextBillingDate,
    required this.cancellationRule,
    this.offsetDays = 0,
    required this.category,
    this.notifyType = '{"days":[1],"time":"09:00"}', // Default as JSON
    this.paymentMethod = '',
    this.iconName = 'generic',
    this.iconColorValue = 0xFF4C6FFF,
    this.billingType = 'relative',
    this.trialDays = 31,
    this.startDate,
    this.memo = '',
    this.isCancelled = false,
    this.isArchived = false,
  }) {
    _parseNotifyType();
  }

  void _parseNotifyType() {
    try {
      if (notifyType.startsWith('{')) {
        final Map<String, dynamic> data = jsonDecode(notifyType);
        notificationDays = List<int>.from(data['days'] ?? [1]);
        final timeStr = data['time'] as String? ?? '09:00';
        final parts = timeStr.split(':');
        notificationTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } else {
        // レガシー対応
        notificationTime = const TimeOfDay(hour: 9, minute: 0);
        if (notifyType == 'none') {
          notificationDays = [];
        } else if (notifyType == 'on_day') {
          notificationDays = [0];
        } else if (notifyType == '3_days_before') {
          notificationDays = [3];
        } else {
          notificationDays = [1];
        }
      }
    } catch (e) {
      // フォールバック
      notificationDays = [1];
      notificationTime = const TimeOfDay(hour: 9, minute: 0);
    }
  }

  // 通知用ヘルパー：TimeOfDayを文字列(HH:mm)にする
  String formatNotificationTime() {
    final hour = notificationTime.hour.toString().padLeft(2, '0');
    final minute = notificationTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 静的ヘルパー：設定情報のJSON化
  static String createNotifyTypeJson(List<int> days, TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return jsonEncode({
      'days': days,
      'time': '$hour:$minute',
    });
  }

  double get averageMonthlyPrice {
    if (cycle == 'monthly') return price;
    return price / 12.0;
  }

  DateTime get deadlineDate {
    if (cancellationRule == 'typeA') {
      return nextBillingDate.subtract(const Duration(days: 1));
    }
    if (cancellationRule == 'typeB') {
      return nextBillingDate;
    }
    if (cancellationRule == 'typeC') {
      return nextBillingDate.subtract(Duration(days: offsetDays));
    }
    return nextBillingDate;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'cycle': cycle,
      'next_billing_date': nextBillingDate.toIso8601String(),
      'cancellation_rule': cancellationRule,
      'offset_days': offsetDays,
      'category': AppConstants.normalizeCategory(category),
      'notify_type': notifyType,
      'payment_method': paymentMethod,
      'icon_name': iconName,
      'icon_color_value': iconColorValue,
      'is_cancelled': isCancelled ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'billing_type': billingType,
      'trial_days': trialDays,
      'start_date': startDate?.toIso8601String(),
      'memo': memo,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] as String,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'JPY',
      cycle: map['cycle'] as String,
      nextBillingDate: DateTime.parse(map['next_billing_date'] as String),
      cancellationRule: map['cancellation_rule'] as String? ?? 'typeA',
      offsetDays: map['offset_days'] as int? ?? 0,
      category: AppConstants.normalizeCategory(
        map['category'] as String? ?? AppConstants.uncategorized,
      ),
      notifyType: map['notify_type'] as String? ?? '1_day_before',
      paymentMethod: map['payment_method'] as String? ?? '',
      iconName: map['icon_name'] as String? ?? 'generic',
      iconColorValue: _parseColorValue(map['icon_color_value']),
      isCancelled: map['is_cancelled'] == 1,
      isArchived: map['is_archived'] == 1,
      billingType: map['billing_type'] as String? ?? 'relative',
      trialDays: map['trial_days'] as int? ?? 31,
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'] as String)
          : null,
      memo: map['memo'] as String? ?? '',
    );
  }

  static int _parseColorValue(dynamic value) {
    if (value == null) return 0xFF4C6FFF;
    if (value is int) return value;
    if (value is String) {
      if (value.startsWith('0x')) {
        return int.tryParse(value.substring(2), radix: 16) ?? 0xFF4C6FFF;
      }
      return int.tryParse(value) ?? 0xFF4C6FFF;
    }
    return 0xFF4C6FFF;
  }

  double get progress {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    late final DateTime prevDate;
    if (cycle == 'yearly') {
      prevDate = DateTime(
        nextBillingDate.year - 1,
        nextBillingDate.month,
        nextBillingDate.day,
      );
    } else {
      var prevYear = nextBillingDate.year;
      var prevMonth = nextBillingDate.month - 1;
      if (prevMonth <= 0) {
        prevMonth = 12;
        prevYear -= 1;
      }
      prevDate = DateTime(prevYear, prevMonth, nextBillingDate.day);
    }

    final totalDays = nextBillingDate.difference(prevDate).inDays.toDouble();
    if (totalDays <= 0) return 1.0;

    final elapsedDays = today.difference(prevDate).inDays.toDouble();
    if (elapsedDays <= 0) return 0.0;
    if (elapsedDays >= totalDays) return 1.0;

    return elapsedDays / totalDays;
  }

  String get computedStatus {
    final now = DateTime.now();
    if (now.isAfter(nextBillingDate)) {
      return 'expired';
    }
    if (isCancelled) {
      return 'cancelled';
    }
    return 'active';
  }
}
