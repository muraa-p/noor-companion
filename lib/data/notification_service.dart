import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

/// Wraps flutter_local_notifications for the daily Qur'an reminder.
///
/// Fails softly on platforms/emulators where notifications are unavailable.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const int _dailyId = 1001;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      final String? name = await _localTimeZone();
      if (name != null) {
        tz.setLocalLocation(tz.getLocation(name));
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: darwin);
      await _plugin.initialize(settings: settings);

      if (!kIsWeb && isAndroid) {
        final impl = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await impl?.requestNotificationsPermission();
        await impl?.requestExactAlarmsPermission();
      }
      _initialized = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<String?> _localTimeZone() async {
    try {
      if (isAndroid || defaultTargetPlatform == TargetPlatform.iOS) {
        final info = await FlutterTimezone.getLocalTimezone();
        return info.identifier;
      }
    } catch (_) {}
    return null;
  }

  /// Schedules (or replaces) the daily reminder at hour:minute (24h).
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_initialized) return;

    final tzLocation = tz.local;
    final now = tz.TZDateTime.now(tzLocation);
    var scheduled = tz.TZDateTime(
      tzLocation,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Daily Qur\'an reminder',
      channelDescription: 'A gentle reminder to touch the Qur\'an today.',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    );
    const iosDetails = DarwinNotificationDetails(presentAlert: true, presentSound: true);
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      id: _dailyId,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDaily() async {
    await _plugin.cancel(id: _dailyId);
  }

  // ---- Download progress notification ------------------------------------

  static const int _downloadId = 2001;

  /// Shows/updates a download-progress notification so the user can see a
  /// background download's status from any screen (not just the app).
  Future<void> showDownloadProgress(
    int percent, {
    required String title,
  }) async {
    await init();
    if (!_initialized) return;
    final android = AndroidNotificationDetails(
      'downloads',
      'Download progress',
      channelDescription: 'Recitation downloads in progress.',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: percent.clamp(0, 100),
      autoCancel: false,
    );
    final details = NotificationDetails(android: android);
    await _plugin.show(
      id: _downloadId,
      title: 'Downloading… $percent%',
      body: title,
      notificationDetails: details,
    );
  }

  /// Dismisses the download-progress notification and confirms completion.
  Future<void> finishDownload({required String title}) async {
    await init();
    if (!_initialized) return;
    await _plugin.cancel(id: _downloadId);
  }

  /// Canonical daily reminder: a soft nudge to touch the Qur'an and keep the
  /// hasanat streak alive.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) =>
      scheduleDaily(
        hour: hour,
        minute: minute,
        title: 'Time for a little Qur\'an',
        body: 'Open Noor for your ayah of the day. Each letter is hasanat.',
      );
}