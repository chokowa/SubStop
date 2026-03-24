import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/subscription.dart';

enum SnoozeType {
  oneHour,
  tonight,
  tomorrow,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  bool get _notificationsUnsupported => !kIsWeb && Platform.isWindows;

  Future<void> init() async {
    if (_notificationsUnsupported || _isInitialized) return;

    tz_data.initializeTimeZones();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    _isInitialized = true;
  }

  Future<void> scheduleDeadlineNotification(Subscription sub) async {
    if (_notificationsUnsupported) return;

    // 既存のこのサブスクに関連する通知をすべてキャンセル（古いID体系も含め広めにクリア）
    // NOTE: 個別IDを特定して消すのが理想ですが、一旦 hashCode ベースで全消去
    await cancelNotification(sub.id); 

    if (sub.notificationDays.isEmpty || sub.isCancelled) return;

    for (final daysBefore in sub.notificationDays) {
      final deadline = sub.deadlineDate;
      final reminderDateTime = DateTime(
        deadline.year,
        deadline.month,
        deadline.day,
        sub.notificationTime.hour,
        sub.notificationTime.minute,
      ).subtract(Duration(days: daysBefore));

      final scheduledDate = tz.TZDateTime.from(reminderDateTime, tz.local);

      // 過去の時間はスキップ
      if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) continue;

      final notificationId = sub.id.hashCode + daysBefore; // 日数ごとにユニークなID

      String body = '';
      if (daysBefore == 0) {
        body = '本日が解約締切日です！';
      } else {
        body = '解約締切まであと $daysBefore 日です。';
      }

      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'substop_deadline_channel',
          '解約アラート',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: notificationId,
        title: sub.name,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: sub.id,
      );
    }
  }

  Future<void> snoozeNotification(Subscription sub, SnoozeType type) async {
    if (_notificationsUnsupported) return;

    final notificationId = sub.id.hashCode;
    await flutterLocalNotificationsPlugin.cancel(id: notificationId);

    final now = tz.TZDateTime.now(tz.local);
    late tz.TZDateTime snoozedDate;

    switch (type) {
      case SnoozeType.oneHour:
        snoozedDate = now.add(const Duration(hours: 1));
        break;
      case SnoozeType.tonight:
        snoozedDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
        if (snoozedDate.isBefore(now)) {
          snoozedDate = snoozedDate.add(const Duration(days: 1));
        }
        break;
      case SnoozeType.tomorrow:
        snoozedDate =
            tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, 9);
        break;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'substop_snooze_channel',
        'スヌーズ通知',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: notificationId,
      title: 'スヌーズ通知',
      body: '後で再通知します。',
      scheduledDate: snoozedDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: sub.id,
    );
  }

  Future<void> cancelNotification(String id) async {
    if (_notificationsUnsupported) return;
    await flutterLocalNotificationsPlugin.cancel(id: id.hashCode);
  }
}
