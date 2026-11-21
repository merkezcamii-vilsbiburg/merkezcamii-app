import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'data.dart';
import 'prayer.dart';

final FlutterLocalNotificationsPlugin fln = FlutterLocalNotificationsPlugin();

const _gold = Color(0xFFE3BF72);

const androidFirebase = FirebaseOptions(
  apiKey: 'AIzaSyClcpHPpGBnSdhRWhOhlYnt-lSlSHmJtdQ',
  appId: '1:1070684966272:android:fdd4e167c1147d0e774565',
  messagingSenderId: '1070684966272',
  projectId: 'merkezcamii',
  storageBucket: 'merkezcamii.firebasestorage.app',
);

/// Ezan-Einstellungen: pro Vakit "ezan" | "bildirim" | "kapali"
class EzanSettings {
  static const keys = ['imsak', 'ogle', 'ikindi', 'aksam', 'yatsi'];
  static const labels = {'imsak': 'Sabah', 'ogle': 'Öğle', 'ikindi': 'İkindi', 'aksam': 'Akşam', 'yatsi': 'Yatsı'};

  static String mode(SharedPreferences p, String k) => p.getString('mode_$k') ?? 'ezan';
  static bool cuma(SharedPreferences p) => p.getBool('cuma') ?? true;
  static bool silentToo(SharedPreferences p) => p.getBool('silentToo') ?? false;
}

// Kanäle (Android): Ezan mit eigenem Ton, normal oder als Alarm (auch im Lautlos-Modus)
AndroidNotificationChannel _ezanChannel(bool sabah, bool alarm) => AndroidNotificationChannel(
      'ezan_${sabah ? 'sabah' : 'normal'}_${alarm ? 'alarm' : 'std'}',
      sabah ? 'Sabah ezanı' : 'Ezan',
      description: alarm ? 'Sessiz modda da çalar' : 'Vakit girince ezan okunur',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound(sabah ? 'ezan_sabah' : 'ezan'),
      playSound: true,
      audioAttributesUsage: alarm ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
    );

const _chCami = AndroidNotificationChannel('cami_duyurulari', 'Cami duyuruları',
    description: 'Merkez Camii duyuruları', importance: Importance.high);
const _chLokal = AndroidNotificationChannel('genclik_lokal', 'Gençlik / Lokal',
    description: 'Gençlik duyuruları ve lokal maçları', importance: Importance.high);
const _chVakit = AndroidNotificationChannel('vakit_bildirimi', 'Vakit bildirimi',
    description: 'Ezan yerine sadece bildirim', importance: Importance.high);
const _chCuma = AndroidNotificationChannel('cuma', 'Cuma hatırlatması',
    description: 'Cuma namazından önce hatırlatma', importance: Importance.high);

Future<void> initNotifications(void Function(int tab) onOpenTab) async {
  tzdata.initializeTimeZones();
  const init = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_cami'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );
  await fln.initialize(init, onDidReceiveNotificationResponse: (r) {
    final t = int.tryParse(r.payload ?? '');
    if (t != null) onOpenTab(t);
  });
  final launch = await fln.getNotificationAppLaunchDetails();
  final p = int.tryParse(launch?.notificationResponse?.payload ?? '');
  if (launch?.didNotificationLaunchApp == true && p != null) onOpenTab(p);

  final android = fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (android != null) {
    for (final c in [_chCami, _chLokal, _chVakit, _chCuma]) {
      await android.createNotificationChannel(c);
    }
    for (final s in [true, false]) {
      for (final a in [true, false]) {
        await android.createNotificationChannel(_ezanChannel(s, a));
      }
    }
  }
}

Future<void> requestPermissions() async {
  final android = fln.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.requestNotificationsPermission();
  final ios = fln.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  await ios?.requestPermissions(alert: true, badge: true, sound: true);
}

// ---------------------------------------------------------------- Ezan planen

/// Plant Ezan/Bildirim/Cuma für die nächsten Tage (iOS max. 64 → 6 Tage).
Future<void> scheduleEzans() async {
  final p = await SharedPreferences.getInstance();
  await fln.cancelAll();
  final days = Platform.isIOS ? 6 : 10;
  final now = DateTime.now().toUtc();
  final today = Prayer.nowBerlin();
  final silentToo = EzanSettings.silentToo(p);
  var id = 1000;
  for (var d = 0; d < days; d++) {
    final day = tz.TZDateTime(Prayer.berlin, today.year, today.month, today.day).add(Duration(days: d));
    final t = Prayer.compute(day.year, day.month, day.day);
    for (final k in EzanSettings.keys) {
      final mode = EzanSettings.mode(p, k);
      final when = t[k]!;
      id++;
      if (mode == 'kapali' || !when.isAfter(now.add(const Duration(seconds: 10)))) continue;
      final name = EzanSettings.labels[k]!;
      final sabah = k == 'imsak';
      NotificationDetails details;
      if (mode == 'ezan') {
        final ch = _ezanChannel(sabah, silentToo);
        details = NotificationDetails(
          android: AndroidNotificationDetails(ch.id, ch.name,
              channelDescription: ch.description,
              importance: Importance.max,
              priority: Priority.high,
              category: AndroidNotificationCategory.alarm,
              sound: ch.sound,
              audioAttributesUsage: ch.audioAttributesUsage,
              largeIcon: const DrawableResourceAndroidBitmap('notif_cami'),
              color: _gold,
              actions: const [AndroidNotificationAction('stop', 'Ezanı durdur', cancelNotification: true)]),
          iOS: DarwinNotificationDetails(
              sound: sabah ? 'ezan_sabah.caf' : 'ezan.caf',
              interruptionLevel: silentToo ? InterruptionLevel.timeSensitive : InterruptionLevel.active),
        );
      } else {
        details = NotificationDetails(
          android: AndroidNotificationDetails(_chVakit.id, _chVakit.name,
              importance: Importance.high,
              priority: Priority.high,
              largeIcon: const DrawableResourceAndroidBitmap('notif_cami'),
              color: _gold),
          iOS: const DarwinNotificationDetails(),
        );
      }
      await _zoned(id, '$name ${mode == 'ezan' ? 'ezanı' : 'vakti'}', '$name vakti girdi · Merkez Camii Vilsbiburg',
          when, details);
    }
    if (EzanSettings.cuma(p) && day.weekday == DateTime.friday) {
      final ogle = t['ogle']!;
      final when = ogle.subtract(const Duration(minutes: 45));
      if (when.isAfter(now)) {
        await _zoned(
          900 + d,
          'Bugün Cuma 🕌',
          'Cuma namazı ${Prayer.hm(ogle)}\'de. Hayırlı Cumalar!',
          when,
          NotificationDetails(
            android: AndroidNotificationDetails(_chCuma.id, _chCuma.name,
                importance: Importance.high,
                priority: Priority.high,
                largeIcon: const DrawableResourceAndroidBitmap('notif_cami'),
                color: _gold),
            iOS: const DarwinNotificationDetails(),
          ),
        );
      }
    }
  }
}

Future<void> _zoned(int id, String title, String body, DateTime utc, NotificationDetails details) async {
  final at = tz.TZDateTime.from(utc, Prayer.berlin);
  try {
    await fln.zonedSchedule(id, title, body, at, details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, payload: '0');
  } catch (_) {
    try {
      await fln.zonedSchedule(id, title, body, at, details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: '0');
    } catch (_) {}
  }
}

// ---------------------------------------------------------------- Push (FCM)

Future<void> showPush(Map<String, dynamic> d) async {
  final kind = (d['kind'] ?? '').toString();
  if (kind.isEmpty) return;
  final isCami = kind == 'cami';
  final title = (d['title'] ?? '').toString().isEmpty ? (isCami ? 'Merkez Camii' : 'Gençlik Kolları') : d['title'].toString();
  final body = (d['body'] ?? '').toString();
  StyleInformation style = BigTextStyleInformation(body);
  final photo = (d['photo'] ?? '').toString();
  if (photo.isNotEmpty) {
    try {
      final r = await http.get(Uri.parse(photo)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) {
        style = BigPictureStyleInformation(ByteArrayAndroidBitmap(r.bodyBytes), summaryText: body);
      }
    } catch (_) {}
  }
  final ch = isCami ? _chCami : _chLokal;
  await fln.show(
    DateTime.now().millisecondsSinceEpoch % 100000000,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(ch.id, ch.name,
          importance: Importance.high,
          priority: Priority.high,
          icon: isCami ? 'ic_stat_cami' : 'ic_stat_lokal',
          largeIcon: DrawableResourceAndroidBitmap(isCami ? 'notif_cami' : 'notif_lokal'),
          color: _gold,
          styleInformation: style),
      iOS: const DarwinNotificationDetails(),
    ),
    payload: isCami ? '1' : '2',
  );
}

@pragma('vm:entry-point')
Future<void> firebaseBackground(RemoteMessage msg) async {
  try {
    await Firebase.initializeApp(options: androidFirebase);
  } catch (_) {}
  await fln.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_stat_cami')));
  await showPush(msg.data);
}

Future<void> initPush() async {
  // iOS: Push wird aktiviert, sobald das Apple-Konto und die Firebase-iOS-App eingerichtet sind.
  if (!Platform.isAndroid) return;
  try {
    await Firebase.initializeApp(options: androidFirebase);
    FirebaseMessaging.onBackgroundMessage(firebaseBackground);
    FirebaseMessaging.onMessage.listen((m) => showPush(m.data));
    await FirebaseMessaging.instance.subscribeToTopic('cami');
    await FirebaseMessaging.instance.subscribeToTopic('lokal');
  } catch (e) {
    debugPrint('push: $e');
  }
}

/// Wird nach Änderungen der Duyurular im Vordergrund genutzt (nichts zu tun – Platzhalter für iOS-Badges).
void unusedRef() => AppState.i;
