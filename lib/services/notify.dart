import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Alerts {
  static final plugin = FlutterLocalNotificationsPlugin();
  static var ready = false;
  static var _permissionAsked = false;

  static Future<void> init() async {
    if (kIsWeb || ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
      } catch (_) {}
      // 启动时不弹通知权限，避免挡住登录页自动拉同步地址。
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      ready = true;
    } catch (_) {}
  }

  static Future<void> _ensurePermission() async {
    if (!ready || _permissionAsked || kIsWeb) return;
    _permissionAsked = true;
    try {
      await plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  static Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (!ready || !when.isAfter(DateTime.now())) return;
    await _ensurePermission();
    try {
      await plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'cami_alarm',
            '到点提醒',
            channelDescription: '作业倒计时和番茄钟',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'alarm',
      );
    } catch (_) {}
  }

  static Future<void> cancel(int id) async {
    if (!ready) return;
    try {
      await plugin.cancel(id: id);
    } catch (_) {}
  }
}
