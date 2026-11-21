import 'package:hijri/hijri_calendar.dart';

import 'prayer.dart';

/// Ein besonderer Tag (Kandil-Nacht oder Bayram), lokales Datum in Berlin.
class HolyDay {
  final String key; // regaip, mirac, berat, kadir, mevlid, ramazanBayrami, kurbanBayrami
  final String name;
  final DateTime date; // Datum (lokal, ohne Uhrzeit) des Abends bzw. des Bayram-Tages
  final bool isBayram;
  HolyDay(this.key, this.name, this.date, this.isBayram);
}

/// Islamischer Kalender (Umm-al-Qura), mit optionaler Korrektur durch den Yönetici.
class Islamic {
  /// Korrektur in Tagen für Ramazan/Şevval bzw. Zilhicce (aus Supabase-Einstellungen)
  static int ramazanOffset = 0;
  static int kurbanOffset = 0;

  static DateTime _g(int hy, int hm, int hd) {
    final d = HijriCalendar().hijriToGregorian(hy, hm, hd);
    return DateTime(d.year, d.month, d.day);
  }

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static int hijriYear(DateTime d) => HijriCalendar.fromDate(_day(d)).hYear;

  /// Berechnet Korrekturen aus den Einstellungen ("2027-02-08").
  static void applySettings(String? ramazanStart, String? kurbanDay) {
    ramazanOffset = 0;
    kurbanOffset = 0;
    final now = DateTime.now();
    final r = DateTime.tryParse(ramazanStart ?? '');
    if (r != null) {
      final hy = HijriCalendar.fromDate(r).hYear;
      for (final y in [hy - 1, hy, hy + 1]) {
        final diff = _day(r).difference(_g(y, 9, 1)).inDays;
        if (diff.abs() <= 3) {
          if (now.difference(r).inDays < 60) ramazanOffset = diff;
          break;
        }
      }
    }
    final k = DateTime.tryParse(kurbanDay ?? '');
    if (k != null) {
      final hy = HijriCalendar.fromDate(k).hYear;
      for (final y in [hy - 1, hy, hy + 1]) {
        final diff = _day(k).difference(_g(y, 12, 10)).inDays;
        if (diff.abs() <= 3) {
          if (now.difference(k).inDays < 10) kurbanOffset = diff;
          break;
        }
      }
    }
  }

  static DateTime ramazanStart(int hy) => _g(hy, 9, 1).add(Duration(days: ramazanOffset));
  static DateTime ramazanBayrami(int hy) => _g(hy, 10, 1).add(Duration(days: ramazanOffset));
  static DateTime kurbanBayrami(int hy) => _g(hy, 12, 10).add(Duration(days: kurbanOffset));

  /// Alle besonderen Tage eines Hicri-Jahres.
  static List<HolyDay> daysOf(int hy) {
    final recep1 = _g(hy, 7, 1);
    var firstFriday = recep1;
    while (firstFriday.weekday != DateTime.friday) {
      firstFriday = firstFriday.add(const Duration(days: 1));
    }
    return [
      HolyDay('mevlid', 'Mevlid Kandili', _g(hy, 3, 11), false),
      HolyDay('regaip', 'Regaip Kandili', firstFriday.subtract(const Duration(days: 1)), false),
      HolyDay('mirac', 'Miraç Kandili', _g(hy, 7, 26), false),
      HolyDay('berat', 'Berat Kandili', _g(hy, 8, 14), false),
      HolyDay('kadir', 'Kadir Gecesi', ramazanStart(hy).add(const Duration(days: 25)), false),
      HolyDay('ramazanBayrami', 'Ramazan Bayramı', ramazanBayrami(hy), true),
      HolyDay('kurbanBayrami', 'Kurban Bayramı', kurbanBayrami(hy), true),
    ];
  }

  /// Besondere Tage in den nächsten [days] Tagen (inkl. heute).
  static List<HolyDay> upcoming(int days) {
    final today = _day(DateTime.now());
    final hy = hijriYear(today);
    final all = [...daysOf(hy - 1), ...daysOf(hy), ...daysOf(hy + 1)];
    return all
        .where((h) => !h.date.isBefore(today) && h.date.isBefore(today.add(Duration(days: days))))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Heutiger Ramazan-Tag (1..30) oder null.
  static int? ramazanDay([DateTime? at]) {
    final today = _day(at ?? DateTime.now());
    final hy = hijriYear(today);
    for (final y in [hy - 1, hy, hy + 1]) {
      final s = ramazanStart(y), e = ramazanBayrami(y);
      if (!today.isBefore(s) && today.isBefore(e)) return today.difference(s).inDays + 1;
    }
    return null;
  }

  /// Bayram heute? Liefert (Name, Tag 1..4) oder null.
  static (String, int)? bayramToday() {
    final today = _day(DateTime.now());
    final hy = hijriYear(today);
    for (final y in [hy - 1, hy, hy + 1]) {
      final r = ramazanBayrami(y);
      final rd = today.difference(r).inDays;
      if (rd >= 0 && rd < 3) return ('Ramazan Bayramı', rd + 1);
      final k = kurbanBayrami(y);
      final kd = today.difference(k).inDays;
      if (kd >= 0 && kd < 4) return ('Kurban Bayramı', kd + 1);
    }
    return null;
  }

  /// Kandil heute Abend?
  static HolyDay? kandilTonight() {
    final today = _day(DateTime.now());
    for (final h in upcoming(1)) {
      if (!h.isBayram && h.date == today) return h;
    }
    return null;
  }

  static String fmtDate(DateTime d) => '${d.day} ${Prayer.months[d.month - 1]} ${d.year}';
}
