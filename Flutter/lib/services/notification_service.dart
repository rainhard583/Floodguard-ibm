import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Sistem notifikasi lokal FloodGuard.
///
/// Dipakai untuk alert penting yang sudah diketahui aplikasi. Ini bukan FCM
/// push dari server; untuk push saat aplikasi benar-benar mati, tambahkan
/// Firebase Cloud Messaging di tahap berikutnya.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'floodguard_alerts_v2';
  static const String _channelName = 'Peringatan FloodGuard';
  static const String _channelDescription =
      'Peringatan banjir, cuaca, dan kondisi penting FloodGuard.';

  bool _initialized = false;
  final Set<String> _shownKeys = <String>{};

  Future<void> initialize() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> showAlert({
    required String key,
    required String title,
    required String body,
    bool important = true,
  }) async {
    await initialize();
    if (_shownKeys.contains(key)) return;
    _shownKeys.add(key);

    final details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: important ? Importance.high : Importance.defaultImportance,
      priority: important ? Priority.high : Priority.defaultPriority,
      category: AndroidNotificationCategory.alarm,
      icon: '@mipmap/ic_launcher',
      ticker: title,
      styleInformation: BigTextStyleInformation(body),
      autoCancel: true,
      onlyAlertOnce: true,
    );

    await _plugin.show(
      id: key.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
      payload: 'notifications',
    );
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
