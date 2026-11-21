import 'dart:math' as m;

import 'package:hijri/hijri_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

/// Gebetszeiten für Vilsbiburg – gleiche Berechnung wie Webseite (Diyanet-Methode).
class Prayer {
  static const lat = 48.4497;
  static const lng = 12.3556;
  static const fajr = 18.0;
  static const isha = 17.0;

  static const keys = ['imsak', 'gunes', 'ogle', 'ikindi', 'aksam', 'yatsi'];
  static const names = {
    'imsak': 'İmsak',
    'gunes': 'Güneş',
    'ogle': 'Öğle',
    'ikindi': 'İkindi',
    'aksam': 'Akşam',
    'yatsi': 'Yatsı',
  };
  static const _temkin = {'imsak': 0, 'gunes': -7, 'ogle': 5, 'ikindi': 4, 'aksam': 7, 'yatsi': 0};

  static tz.Location get berlin => tz.getLocation('Europe/Berlin');

  static double _d2r(double d) => d * m.pi / 180;
  static double _r2d(double r) => r * 180 / m.pi;
  static double _sin(double d) => m.sin(_d2r(d));
  static double _cos(double d) => m.cos(_d2r(d));
  static double _tan(double d) => m.tan(_d2r(d));
  static double _asin(double x) => _r2d(m.asin(x));
  static double _acos(double x) => _r2d(m.acos(x));
  static double _atan2(double y, double x) => _r2d(m.atan2(y, x));
  static double _acot(double x) => _r2d(m.atan(1 / x));
  static double _fix(double a, double b) {
    final r = a - b * (a / b).floorToDouble();
    return r < 0 ? r + b : r;
  }

  static List<double> _sun(double jd) {
    final d = jd - 2451545.0;
    final g = _fix(357.529 + 0.98560028 * d, 360);
    final q = _fix(280.459 + 0.98564736 * d, 360);
    final l = _fix(q + 1.915 * _sin(g) + 0.02 * _sin(2 * g), 360);
    final e = 23.439 - 0.00000036 * d;
    final ra = _fix(_atan2(_cos(e) * _sin(l), _cos(l)) / 15, 24);
    return [_asin(_sin(e) * _sin(l)), q / 15 - ra];
  }

  static double _julian(int year, int month, int day) {
    var y = year, mo = month;
    if (mo <= 2) {
      y -= 1;
      mo += 12;
    }
    final a = (y / 100).floorToDouble();
    final b = 2 - a + (a / 4).floorToDouble();
    return (365.25 * (y + 4716)).floorToDouble() + (30.6001 * (mo + 1)).floorToDouble() + day + b - 1524.5;
  }

  /// Zeiten als UTC-DateTime für das Datum (y,m,d).
  static Map<String, DateTime> compute(int year, int month, int day) {
    final jd = _julian(year, month, day) - lng / (15 * 24);
    double noon(double t) => _fix(12 - _sun(jd + t / 24)[1], 24);
    double at(double angle, double t, bool ccw) {
      final s = _sun(jd + t / 24);
      final v = (-_sin(angle) - _sin(s[0]) * _sin(lat)) / (_cos(s[0]) * _cos(lat));
      final h = _acos(v) / 15;
      final n = noon(t);
      return n + (ccw ? -h : h);
    }

    double asr(double t) {
      final s = _sun(jd + t / 24);
      return at(-_acot(1 + _tan((lat - s[0]).abs())), t, false);
    }

    var t = <String, double>{'imsak': 5, 'gunes': 6, 'ogle': 12, 'ikindi': 13, 'aksam': 18, 'yatsi': 18};
    for (var i = 0; i < 2; i++) {
      t = {
        'imsak': at(fajr, t['imsak']!, true),
        'gunes': at(0.833, t['gunes']!, true),
        'ogle': noon(t['ogle']!),
        'ikindi': asr(t['ikindi']!),
        'aksam': at(0.833, t['aksam']!, false),
        'yatsi': at(isha, t['yatsi']!, false),
      };
    }
    for (final k in keys) {
      t[k] = t[k]! - lng / 15;
    }
    final night = 24 - (t['aksam']! - t['gunes']!);
    final fp = fajr / 60 * night, ip = isha / 60 * night;
    if (t['imsak']!.isNaN || t['gunes']! - t['imsak']! > fp) t['imsak'] = t['gunes']! - fp;
    if (t['yatsi']!.isNaN || t['yatsi']! - t['aksam']! > ip) t['yatsi'] = t['aksam']! + ip;

    final base = DateTime.utc(year, month, day);
    return {
      for (final k in keys) k: base.add(Duration(minutes: (t[k]! * 60 + _temkin[k]!).round())),
    };
  }

  /// Heutiges Datum in Berlin
  static tz.TZDateTime nowBerlin() => tz.TZDateTime.now(berlin);

  static Map<String, DateTime> forBerlinDate(tz.TZDateTime d) => compute(d.year, d.month, d.day);

  static String hm(DateTime utc) {
    final l = tz.TZDateTime.from(utc, berlin);
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  static const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  static const days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  static const hijriMonths = [
    'Muharrem', 'Safer', 'Rebiülevvel', 'Rebiülahir', 'Cemaziyelevvel', 'Cemaziyelahir',
    'Recep', 'Şaban', 'Ramazan', 'Şevval', 'Zilkade', 'Zilhicce'
  ];

  static String miladi(DateTime d) => '${d.day} ${months[d.month - 1]} ${days[d.weekday - 1]}';

  static String hicri(DateTime d) {
    try {
      final h = HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
      return '${h.hDay} ${hijriMonths[h.hMonth - 1]} ${h.hYear}';
    } catch (_) {
      return '';
    }
  }

  static String upperTr(String s) => s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
}
