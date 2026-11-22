import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'brand.dart';
import 'daily.dart';
import 'data.dart';
import 'extras.dart';
import 'notify.dart';
import 'prayer.dart';
import 'prices.dart';
import 'settings.dart';
import 'theme.dart';

AppState get app => AppState.i;

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: manrope(14, w: 600, color: bg)),
      backgroundColor: gold,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
}

class PageList extends StatelessWidget {
  final List<Widget> children;
  const PageList({super.key, required this.children});
  @override
  Widget build(BuildContext context) => ListView(
        padding: EdgeInsets.fromLTRB(18, MediaQuery.of(context).padding.top, 18, 130),
        children: children,
      );
}

Widget sectionHead(String title, String kicker, {double top = 26}) => Padding(
      padding: EdgeInsets.only(top: top, bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Text(title, style: marcellus(26, ls: 1))),
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text(Prayer.upperTr(kicker), style: manrope(11, w: 700, color: gold, ls: 2)),
        ),
      ]),
    );

Widget emptyNote(String t) => Container(
      width: double.infinity,
      decoration: glass(r: 20, elevated: false),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      child: Text(t, textAlign: TextAlign.center, style: manrope(14, color: muted)),
    );

// ================================================================ 1) Vakitler

class VakitlerPage extends StatefulWidget {
  const VakitlerPage({super.key});
  @override
  State<VakitlerPage> createState() => _VakitlerPageState();
}

class _VakitlerPageState extends State<VakitlerPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final b = Prayer.nowBerlin();
    final today = Prayer.forBerlinDate(b);
    final yd = b.subtract(const Duration(days: 1));
    final tm = b.add(const Duration(days: 1));
    final prevYatsi = Prayer.compute(yd.year, yd.month, yd.day)['yatsi']!;
    final tomImsak = Prayer.compute(tm.year, tm.month, tm.day)['imsak']!;
    final keys = Prayer.keys;
    final nextIdx = keys.indexWhere((k) => today[k]!.isAfter(now));
    final curIdx = nextIdx == -1 ? 5 : nextIdx - 1;
    late DateTime nextT, startT;
    late String label;
    if (nextIdx == -1) {
      nextT = tomImsak;
      startT = today['yatsi']!;
      label = 'İmsak · yarın';
    } else {
      nextT = today[keys[nextIdx]]!;
      startT = curIdx >= 0 ? today[keys[curIdx]]! : prevYatsi;
      label = Prayer.names[keys[nextIdx]]!;
    }
    final secs = nextT.difference(now).inSeconds.clamp(0, 999999);
    String two(int v) => v.toString().padLeft(2, '0');
    final clock = '${two(secs ~/ 3600)}:${two(secs % 3600 ~/ 60)}:${two(secs % 60)}';

    return PageList(children: [
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [qiblaIconButton(), gearButton()]),
      ),
      FadeUp(child: Text('بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ', textAlign: TextAlign.center, style: amiri(18))),
      const SizedBox(height: 6),
      const Center(child: FractionallySizedBox(widthFactor: 0.40, child: AnimatedLogo(t: 10000))),
      const SizedBox(height: 8),
      Text('Muslimgemeinde Vilsbiburg e.V.', textAlign: TextAlign.center, style: marcellus(17, ls: 1)),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Camimize hoş geldiniz', textAlign: TextAlign.center, style: manrope(13, color: muted)),
      ),
      const SizedBox(height: 10),
      Center(child: goldDivider()),
      nextHolyDayLine(),
      const SizedBox(height: 14),
      holyBanner(),
      ramazanCard(),
      FadeUp(
        delayMs: 150,
        child: glassBox(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const _PulseDot(),
                  const SizedBox(width: 8),
                  Text('SIRADAKİ VAKİT', style: manrope(11, w: 700, color: gold, ls: 2.4)),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('$label · ${Prayer.hm(nextT)}', style: marcellus(21)),
                ),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, gold],
                  ).createShader(r),
                  child: Text(clock,
                      style: manrope(42, w: 700, color: Colors.white, ls: 1)
                          .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(Prayer.miladi(b), style: manrope(12, color: muted))),
                  Text(Prayer.hicri(b), style: manrope(12, color: muted)),
                ]),
              ]),
            ),
            Container(height: 1, color: line),
            for (var row = 0; row < 2; row++) ...[
              IntrinsicHeight(
                child: Row(children: [
                  for (var col = 0; col < 3; col++) ...[
                    Expanded(child: _cell(keys[row * 3 + col], today, row * 3 + col, curIdx)),
                    if (col < 2) Container(width: 1, color: line),
                  ],
                ]),
              ),
              if (row == 0) Container(height: 1, color: line),
            ],
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text('Vilsbiburg için otomatik hesaplanır · Diyanet takviminden 1–2 dk farklı olabilir',
            textAlign: TextAlign.center, style: manrope(11.5, color: muted)),
      ),
      const DailyCards(),
    ]);
  }

  Widget _cell(String k, Map<String, DateTime> today, int i, int curIdx) {
    final past = i < curIdx || (i == curIdx && k == 'gunes');
    final active = i == curIdx && k != 'gunes';
    return Opacity(
      opacity: past ? 0.42 : 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [gold.withValues(alpha: 0.22), gold.withValues(alpha: 0.06)])
              : null,
          color: active ? null : bg.withValues(alpha: 0.55),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: [
          icon(Ic.prayer[k]!, size: 16, color: gold.withValues(alpha: 0.75)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(Prayer.names[k]!, style: manrope(11.5, w: 600, color: active ? gold : muted)),
          ),
          Text(Prayer.hm(today[k]!), style: manrope(17, w: 700)),
        ]),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 18,
        height: 18,
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => CustomPaint(painter: _DotPainter(c.value)),
        ),
      );
}

class _DotPainter extends CustomPainter {
  final double p;
  _DotPainter(this.p);
  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    canvas.drawCircle(c, 3.5 + p * 6, Paint()..color = gold.withValues(alpha: 0.7 * (1 - p)));
    canvas.drawCircle(c, 3.5, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_DotPainter o) => o.p != p;
}

// ---------- Ezan-Einstellungen ----------

class EzanSettingsCard extends StatefulWidget {
  const EzanSettingsCard({super.key});
  @override
  State<EzanSettingsCard> createState() => _EzanSettingsCardState();
}

class _EzanSettingsCardState extends State<EzanSettingsCard> {
  bool open = false;
  SharedPreferences? p;
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((v) => setState(() => p = v));
  }

  Future<void> _set(String key, Object v) async {
    if (v is String) await p!.setString(key, v);
    if (v is bool) await p!.setBool(key, v);
    setState(() {});
    await scheduleEzans();
  }

  @override
  Widget build(BuildContext context) {
    final p = this.p;
    if (p == null) return const SizedBox.shrink();
    final off = EzanSettings.keys.where((k) => EzanSettings.mode(p, k) != 'ezan').length;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: glassBox(
        r: 22,
        child: Column(children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(children: [
                const Text('🔊', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ezan ve bildirim ayarları', style: manrope(15, w: 700)),
                    Text(off == 0 ? 'Tüm vakitlerde ezan açık' : 'Bazı vakitlerde ezan kapalı',
                        style: manrope(12, color: muted)),
                  ]),
                ),
                Text(open ? '▲' : '▼', style: const TextStyle(fontSize: 13, color: gold)),
              ]),
            ),
          ),
          if (open) ...[
            Container(height: 1, color: line),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(children: [
                for (final k in EzanSettings.keys)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      SizedBox(width: 62, child: Text(EzanSettings.labels[k]!, style: manrope(14, w: 600))),
                      for (final m in const [
                        ['ezan', 'Ezan'],
                        ['bildirim', 'Bildirim'],
                        ['kapali', 'Kapalı']
                      ]) ...[
                        Expanded(child: _modeChip(m[1], EzanSettings.mode(p, k) == m[0], () => _set('mode_$k', m[0]))),
                        if (m[0] != 'kapali') const SizedBox(width: 6),
                      ],
                    ]),
                  ),
                Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 1, color: line),
                _toggle('Cuma hatırlatması', 'Cuma günü öğleden 45 dk önce', EzanSettings.cuma(p),
                    (v) => _set('cuma', v)),
                _toggle('Sessiz modda da ezan oku', 'Kapalıyken telefon sessizdeyse sadece bildirim gelir',
                    EzanSettings.silentToo(p), (v) => _set('silentToo', v)),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Ezan çalarken bildirimdeki "Ezanı durdur" ile susturabilirsiniz.',
                      style: manrope(11.5, color: muted)),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _modeChip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            gradient: on ? goldGradient : null,
            color: on ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? Colors.transparent : line),
          ),
          alignment: Alignment.center,
          child: Text(label, maxLines: 1, style: manrope(12, w: 700, color: on ? bg : muted)),
        ),
      );

  Widget _toggle(String title, String sub, bool on, ValueChanged<bool> onChange) => InkWell(
        onTap: () => onChange(!on),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: manrope(14, w: 600)),
                Text(sub, style: manrope(11.5, color: muted)),
              ]),
            ),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                gradient: on ? goldGradient : null,
                color: on ? null : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(shape: BoxShape.circle, color: on ? bg : textC),
              ),
            ),
          ]),
        ),
      );
}

// ================================================================ Duyurular (gemeinsam)

String whenText(DateTime utc) {
  final l = tz.TZDateTime.from(utc, Prayer.berlin);
  final n = Prayer.nowBerlin();
  final hm = Prayer.hm(utc);
  bool same(tz.TZDateTime a, tz.TZDateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (same(l, n)) return 'Bugün · $hm';
  if (same(l, n.subtract(const Duration(days: 1)))) return 'Dün · $hm';
  return '${l.day} ${Prayer.months[l.month - 1]}, $hm';
}

Widget writeButton(String label, VoidCallback onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(18)),
        alignment: Alignment.center,
        child: Text('＋  $label', style: manrope(17, w: 800, color: bg)),
      ),
    );

List<Widget> annList(String section, {int? limit}) {
  var list = app.list(section);
  if (limit != null && list.length > limit) list = list.sublist(0, limit);
  return [
    if (!app.loaded) emptyNote('Yükleniyor…'),
    if (app.loaded && list.isEmpty) emptyNote(section == 'cami' ? 'Henüz duyuru yok.' : 'Henüz gençlik duyurusu yok.'),
    for (var i = 0; i < list.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FadeUp(delayMs: (i < 4 ? i : 4) * 80, child: AnnCard(a: list[i])),
      ),
  ];
}

/// Kurze Duyuru-Karte: Foto, fetter Titel, 2 Zeilen Text. Antippen öffnet die Duyuru.
class AnnCard extends StatelessWidget {
  final Ann a;
  final VoidCallback? onTap;
  const AnnCard({super.key, required this.a, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap ??
            () {
              app.openAnn = a;
              app.ui();
            },
        child: glassBox(
          r: 20,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (a.photo != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(a.photo!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.white.withValues(alpha: 0.04))),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Prayer.upperTr(whenText(a.createdAt)), style: manrope(10.5, w: 700, color: gold, ls: 1.5)),
                    if (a.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: manrope(17, w: 800)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(a.body,
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: manrope(14, color: muted, height: 1.4)),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                Text('›', style: manrope(26, color: gold.withValues(alpha: 0.8))),
              ]),
            ),
          ]),
        ),
      );
}

/// Ganze Duyuru (Vollbild)
class AnnDetailScreen extends StatefulWidget {
  final Ann a;
  final VoidCallback onClose;
  const AnnDetailScreen({super.key, required this.a, required this.onClose});
  @override
  State<AnnDetailScreen> createState() => _AnnDetailScreenState();
}

class _AnnDetailScreenState extends State<AnnDetailScreen> {
  bool confirm = false;
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onClose();
      },
      child: Material(
        color: bg,
        child: Stack(children: [
          const Positioned.fill(child: BrandBackground()),
          SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
              Row(children: [
                Expanded(
                  child: Text(a.section == 'cami' ? 'Duyuru' : 'Gençlik duyurusu', style: marcellus(22)),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
                    alignment: Alignment.center,
                    child: const Text('✕', style: TextStyle(fontSize: 18, color: textC)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (a.photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.network(a.photo!, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(Prayer.upperTr(whenText(a.createdAt)), style: manrope(11, w: 700, color: gold, ls: 1.6)),
              ),
              if (a.title.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(a.title, style: manrope(22, w: 800))),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SelectableText(a.body, style: manrope(16, color: textC.withValues(alpha: 0.88), height: 1.55)),
              ),
              if (app.isAdmin(a.section))
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            'Yayınlayan: ${a.author ?? '-'}${a.igStatus == null ? '' : '\nInstagram: ${a.igStatus}'}',
                            style: manrope(13, color: muted))),
                    GestureDetector(
                      onTap: () async {
                        if (!confirm) {
                          setState(() => confirm = true);
                          return;
                        }
                        try {
                          await app.delete(a);
                          widget.onClose();
                        } catch (e) {
                          if (context.mounted) toast(context, 'Silinemedi: $e');
                          if (mounted) setState(() => confirm = false);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14), border: Border.all(color: closedRed.withValues(alpha: 0.5))),
                        child: Text(confirm ? 'Emin misiniz? SİL' : 'Sil', style: manrope(14, w: 700, color: closedRed)),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Alle Gençlik-Duyurular (aus der Lokal-Seite geöffnet)
class LokalAnnsScreen extends StatelessWidget {
  final VoidCallback onClose;
  const LokalAnnsScreen({super.key, required this.onClose});
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) onClose();
        },
        child: Material(
          color: bg,
          child: Stack(children: [
            const Positioned.fill(child: BrandBackground()),
            SafeArea(
              child: ListenableBuilder(
                listenable: app,
                builder: (_, __) => ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 40), children: [
                  Row(children: [
                    Expanded(child: Text('Gençlik duyuruları', style: marcellus(24))),
                    GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: line)),
                        alignment: Alignment.center,
                        child: const Text('✕', style: TextStyle(fontSize: 18, color: textC)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (app.isAdmin('lokal')) ...[
                    writeButton('Gençlik duyurusu yaz', () {
                      app.compose = 'lokal';
                      app.ui();
                    }),
                    const SizedBox(height: 14),
                  ],
                  ...annList('lokal'),
                ]),
              ),
            ),
          ]),
        ),
      );
}

// ================================================================ 2) Duyurular

class DuyurularPage extends StatelessWidget {
  const DuyurularPage({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => PageList(children: [
          sectionHead('Duyurular', 'Güncel'),
          if (app.isAdmin('cami')) ...[
            writeButton('Duyuru yaz', () {
              app.compose = 'cami';
              app.ui();
            }),
            const SizedBox(height: 14),
          ],
          ...annList('cami'),
        ]),
      );
}

// ================================================================ 3) Lokal

class LokalPage extends StatefulWidget {
  const LokalPage({super.key});
  @override
  State<LokalPage> createState() => _LokalPageState();
}

class _LokalPageState extends State<LokalPage> {
  String filter = 'all';
  bool showAll = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) => _build(context));

  Widget _build(BuildContext context) {
    final lokalAdmin = app.isAdmin('lokal');
    final shown = app.matches.where((m) {
      final open = app.locks[m.id] == true;
      switch (filter) {
        case 'tr':
          return app.isTurkish(m);
        case 'sl':
          return m.league == 'sl';
        case 'cl':
          return m.league == 'cl';
        case 'open':
          return open;
        default:
          return true;
      }
    }).toList();
    final limited = showAll ? shown : shown.take(12).toList();
    final today = Prayer.nowBerlin();
    final rows = <Widget>[];
    String? last;
    for (final m in limited) {
      final d = tz.TZDateTime.from(m.date, Prayer.berlin);
      final key = '${d.year}-${d.month}-${d.day}';
      if (key != last) {
        last = key;
        final tmw = today.add(const Duration(days: 1));
        String title;
        if (d.year == today.year && d.month == today.month && d.day == today.day) {
          title = 'Bugün';
        } else if (d.year == tmw.year && d.month == tmw.month && d.day == tmw.day) {
          title = 'Yarın';
        } else {
          title = Prayer.miladi(d);
        }
        rows.add(Padding(
          padding: const EdgeInsets.only(left: 4, top: 16, bottom: 8),
          child: Text(Prayer.upperTr(title), style: manrope(11.5, w: 700, color: gold, ls: 2)),
        ));
      }
      final open = app.locks[m.id] == true;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MatchRow(
          m: m,
          open: open,
          onToggle: () async {
            if (lokalAdmin) {
              try {
                await app.setLock(m, !open);
                if (context.mounted) toast(context, !open ? '🔓 Lokal açıldı' : '🔒 Lokal kapatıldı');
              } catch (e) {
                if (context.mounted) toast(context, 'Kaydedilemedi: $e');
              }
            } else {
              toast(context, open ? '🔓 Bu maçta lokal açık – herkesi bekliyoruz!' : '🔒 Lokal bu maç için henüz açık değil');
            }
          },
        ),
      ));
    }

    return PageList(children: [
      FadeUp(
        child: Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(children: [
            FractionallySizedBox(
              widthFactor: 0.88,
              child: AspectRatio(aspectRatio: 992 / 321, child: Image.asset('assets/img/logo_genclik.png')),
            ),
            const SizedBox(height: 16),
            goldDivider(),
          ]),
        ),
      ),
      sectionHead('Gençlik', 'Duyurular', top: 22),
      if (lokalAdmin) ...[
        writeButton('Gençlik duyurusu yaz', () {
          app.compose = 'lokal';
          app.ui();
        }),
        const SizedBox(height: 14),
      ],
      ...annList('lokal', limit: 1),
      if (app.list('lokal').length > 1)
        GestureDetector(
          onTap: () {
            app.showLokalAnns = true;
            app.ui();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: line)),
            alignment: Alignment.center,
            child: Text('Tüm gençlik duyuruları (${app.list('lokal').length}) ›', style: manrope(14, w: 700, color: gold)),
          ),
        ),
      sectionHead('Lokal · Maçlar', 'Süper Lig · ŞL', top: 22),
      _lokalCard(context, lokalAdmin),
      const SizedBox(height: 12),
      const PriceCard(),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(top: 14, bottom: 4),
        child: Row(children: [
          for (final f in const [
            ['all', 'Tümü'],
            ['tr', 'Türk takımları'],
            ['sl', 'Süper Lig'],
            ['cl', 'Şampiyonlar Ligi'],
            ['open', '🔓 Lokal açık']
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(f[1], filter == f[0], () => setState(() {
                    filter = f[0];
                    showAll = false;
                  })),
            ),
        ]),
      ),
      if (app.matchesLoading && app.matches.isEmpty)
        emptyNote('Maçlar yükleniyor…')
      else if (app.matchesError != null && app.matches.isEmpty)
        emptyNote(app.matchesError!)
      else if (shown.isEmpty)
        emptyNote(filter == 'open' ? 'Şu an lokal açık olarak işaretlenmiş maç yok.' : 'Önümüzdeki günlerde maç bulunamadı.'),
      ...rows,
      if (shown.length > limited.length)
        GestureDetector(
          onTap: () => setState(() => showAll = true),
          child: Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), border: Border.all(color: line)),
            alignment: Alignment.center,
            child: Text('Tüm maçları göster (${shown.length})', style: manrope(14, w: 600, color: gold)),
          ),
        ),
    ]);
  }

  /// Genel lokal kilidi – maçlardan bağımsız
  Widget _lokalCard(BuildContext context, bool lokalAdmin) {
    final open = app.lokalOpen;
    final c = open ? openGreen : closedRed;
    final since = app.lokalSince;
    String sub;
    if (since != null) {
      final l = tz.TZDateTime.from(since, Prayer.berlin);
      final n = Prayer.nowBerlin();
      final sameDay = l.year == n.year && l.month == n.month && l.day == n.day;
      sub = sameDay ? '${Prayer.hm(since)}\'den beri' : '${l.day} ${Prayer.months[l.month - 1]}, ${Prayer.hm(since)}\'den beri';
    } else {
      sub = '';
    }
    if (lokalAdmin) sub = sub.isEmpty ? 'Değiştirmek için dokunun' : '$sub · değiştirmek için dokunun';
    return GestureDetector(
      onTap: () async {
        if (!lokalAdmin) {
          toast(context, open ? '🔓 Lokal şu an açık – herkesi bekliyoruz!' : '🔒 Lokal şu an kapalı');
          return;
        }
        try {
          await app.setLokalOpen(!open);
          if (context.mounted) toast(context, !open ? '🔓 Lokal açıldı' : '🔒 Lokal kapatıldı');
        } catch (e) {
          if (context.mounted) toast(context, 'Kaydedilemedi: $e');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.withValues(alpha: 0.16), Colors.white.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.withValues(alpha: 0.5)),
          boxShadow: open ? [BoxShadow(color: openGreen.withValues(alpha: 0.18), blurRadius: 24)] : null,
        ),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.withValues(alpha: 0.55)),
            ),
            alignment: Alignment.center,
            child: icon(open ? Ic.lockOpen : Ic.lockClosed, size: 30, color: c),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(open ? 'Lokal şu an açık' : 'Lokal şu an kapalı', style: marcellus(21)),
              if (sub.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, style: manrope(12.5, color: muted))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: on ? goldGradient : null,
            color: on ? null : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: on ? Colors.transparent : line),
          ),
          child: Text(label, style: manrope(13, w: 600, color: on ? bg : muted)),
        ),
      );
}

class MatchRow extends StatelessWidget {
  final MatchItem m;
  final bool open;
  final VoidCallback onToggle;
  const MatchRow({super.key, required this.m, required this.open, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final sl = m.league == 'sl';
    final tr = app.isTurkish(m);
    Widget timeCol;
    if (m.state == 'in') {
      timeCol = Column(children: [
        Text('CANLI', style: manrope(12, w: 800, color: openGreen)),
        Text(m.clock, style: manrope(12, w: 700)),
      ]);
    } else if (m.state == 'post') {
      timeCol = Text('Bitti', style: manrope(12, w: 700, color: muted));
    } else {
      timeCol = Text(Prayer.hm(m.date), style: manrope(16, w: 700));
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.white.withValues(alpha: 0.07), Colors.white.withValues(alpha: 0.02)]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: open ? openGreen.withValues(alpha: 0.45) : line),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: IntrinsicHeight(
        child: Row(children: [
          SizedBox(
            width: 60,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              timeCol,
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: sl ? const Color(0x2EE31E24) : const Color(0x2E608CFF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(sl ? 'SÜPER LİG' : 'ŞL',
                    style: manrope(9, w: 800, color: sl ? const Color(0xFFFF8A8A) : const Color(0xFFA9C1FF))),
              ),
            ]),
          ),
          Container(width: 1, color: line),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _team(m.home, tr && app.turkishTeams.contains(m.home.id), m.state != 'pre'),
                const SizedBox(height: 6),
                _team(m.away, tr && app.turkishTeams.contains(m.away.id), m.state != 'pre'),
              ]),
            ),
          ),
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 60,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: (open ? openGreen : closedRed).withValues(alpha: open ? 0.16 : 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: (open ? openGreen : closedRed).withValues(alpha: open ? 0.55 : 0.4)),
                    boxShadow: open ? [BoxShadow(color: openGreen.withValues(alpha: 0.35), blurRadius: 16)] : null,
                  ),
                  alignment: Alignment.center,
                  child: icon(open ? Ic.lockOpen : Ic.lockClosed, size: 22, color: open ? openGreen : closedRed),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _team(Team t, bool tr, bool showScore) => Row(children: [
        if (t.logo.isNotEmpty)
          Image.network(t.logo, width: 22, height: 22, errorBuilder: (_, __, ___) => const SizedBox(width: 22))
        else
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: gold.withValues(alpha: 0.12), border: Border.all(color: line)),
            alignment: Alignment.center,
            child: Text(t.name.isEmpty ? '?' : t.name[0], style: manrope(11, w: 700, color: gold)),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(tr ? '${t.name} 🇹🇷' : t.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: manrope(15, w: 600, color: tr ? Colors.white : textC)),
        ),
        if (showScore && t.score != null) Text(t.score!, style: manrope(15, w: 800, color: gold)),
      ]);
}

// ================================================================ 4) Hakkımızda

class HakkimizdaPage extends StatefulWidget {
  const HakkimizdaPage({super.key});
  @override
  State<HakkimizdaPage> createState() => _HakkimizdaPageState();
}

class _HakkimizdaPageState extends State<HakkimizdaPage> {
  int taps = 0;
  DateTime lastTap = DateTime(2000);

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: app, builder: (_, __) => _build(context));

  Widget _build(BuildContext context) {
    final year = Prayer.nowBerlin().year;
    return PageList(children: [
      sectionHead('Hakkımızda', 'Merkez Camii'),
      FadeUp(
        child: glassBox(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(children: [
            GestureDetector(
              onTap: () {
                final now = DateTime.now();
                taps = now.difference(lastTap).inMilliseconds < 1200 ? taps + 1 : 1;
                lastTap = now;
                if (taps >= 5) {
                  taps = 0;
                  app.showAdmin = true;
                  app.ui();
                }
              },
              child: ShaderMask(
                shaderCallback: (r) => goldGradient.createShader(r),
                child: Text('1982', style: marcellus(64, color: Colors.white)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 16),
              child: Text('YILINDAN BERİ HİZMETİNİZDE', style: manrope(11.5, color: muted, ls: 3)),
            ),
            Text(
              'Merkez Camii, Muslimgemeinde Vilsbiburg e.V. çatısı altında Vilsbiburg ve çevresindeki Müslümanlara hizmet vermektedir.',
              textAlign: TextAlign.center,
              style: manrope(15, color: textC.withValues(alpha: 0.82), height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Camimiz beş vakit namaz, Cuma ve bayram namazları, Kuran kursları ve cemaat buluşmaları için herkese açıktır.',
              textAlign: TextAlign.center,
              style: manrope(15, color: textC.withValues(alpha: 0.82), height: 1.5),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: _stat('${year - 1982}', 'yıllık hizmet')),
              const SizedBox(width: 10),
              Expanded(child: _stat('5', 'vakit namaz')),
              const SizedBox(width: 10),
              Expanded(child: _stat('Cuma', '& bayram')),
            ]),
          ]),
        ),
      ),
      donationsCard(context),
      contactCard(),
      const SizedBox(height: 44),
      Text('السَّلَامُ عَلَيْكُمْ', textAlign: TextAlign.center, style: amiri(20)),
      const SizedBox(height: 8),
      Text('Merkez Camii Vilsbiburg', textAlign: TextAlign.center, style: marcellus(15, ls: 1)),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text('© $year Muslimgemeinde Vilsbiburg e.V.', textAlign: TextAlign.center, style: manrope(13, color: muted)),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('Sabah ezanı kaydı: sazman (freesound.org, CC BY)',
            textAlign: TextAlign.center, style: manrope(10.5, color: muted.withValues(alpha: 0.5))),
      ),
      Text('Sürüm 1.8', textAlign: TextAlign.center, style: manrope(11, color: muted.withValues(alpha: 0.5))),
    ]);
  }

  Widget _stat(String big, String small) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Column(children: [
          Text(big, style: marcellus(20, color: gold)),
          Text(small, style: manrope(12, color: muted)),
        ]),
      );
}
