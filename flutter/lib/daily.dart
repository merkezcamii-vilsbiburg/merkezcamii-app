import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'prayer.dart';
import 'theme.dart';

/// Günün Ayeti / Hadisi – feste Liste in assets/daily.json, wechselt jeden Tag.
class DailyItem {
  final String ar, tr, src;
  DailyItem(this.ar, this.tr, this.src);
}

class Daily {
  static List<DailyItem> ayet = [], hadis = [];
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    try {
      final j = jsonDecode(await rootBundle.loadString('assets/daily.json'));
      List<DailyItem> list(String k) =>
          ((j[k] as List?) ?? []).map((x) => DailyItem(x['ar'] ?? '', x['tr'] ?? '', x['src'] ?? '')).toList();
      ayet = list('ayet');
      hadis = list('hadis');
      _loaded = true;
    } catch (_) {}
  }

  static int get _day {
    final b = Prayer.nowBerlin();
    return DateTime.utc(b.year, b.month, b.day).millisecondsSinceEpoch ~/ 86400000;
  }

  static DailyItem? todayAyet() => ayet.isEmpty ? null : ayet[_day % ayet.length];
  static DailyItem? todayHadis() => hadis.isEmpty ? null : hadis[(_day * 7) % hadis.length];
}

class DailyCards extends StatefulWidget {
  const DailyCards({super.key});
  @override
  State<DailyCards> createState() => _DailyCardsState();
}

class _DailyCardsState extends State<DailyCards> {
  @override
  void initState() {
    super.initState();
    Daily.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = Daily.todayAyet(), h = Daily.todayHadis();
    if (a == null && h == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(children: [
        if (a != null) _DailyCard(kicker: 'GÜNÜN AYETİ', item: a),
        if (a != null && h != null) const SizedBox(height: 12),
        if (h != null) _DailyCard(kicker: 'GÜNÜN HADİSİ', item: h),
      ]),
    );
  }
}

class _DailyCard extends StatefulWidget {
  final String kicker;
  final DailyItem item;
  const _DailyCard({required this.kicker, required this.item});
  @override
  State<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<_DailyCard> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final long = it.tr.length > 260 || it.ar.length > 220;
    return GestureDetector(
      onTap: long ? () => setState(() => open = !open) : null,
      child: glassBox(
        r: 22,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 22, height: 1, color: gold.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(widget.kicker, style: manrope(11, w: 700, color: gold, ls: 2.4)),
            ),
            Container(width: 22, height: 1, color: gold.withValues(alpha: 0.5)),
          ]),
          if (it.ar.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                it.ar,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                maxLines: open ? null : 4,
                overflow: open ? null : TextOverflow.ellipsis,
                style: amiri(20).copyWith(height: 1.7),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              it.tr,
              textAlign: TextAlign.center,
              maxLines: open ? null : 6,
              overflow: open ? null : TextOverflow.ellipsis,
              style: manrope(14.5, color: textC.withValues(alpha: 0.85), height: 1.5),
            ),
          ),
          if (long)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(open ? 'Daha az göster ▲' : 'Devamını oku ▼',
                  textAlign: TextAlign.center, style: manrope(12, w: 700, color: gold)),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(it.src, textAlign: TextAlign.center, style: manrope(12, w: 600, color: muted)),
          ),
        ]),
      ),
    );
  }
}
