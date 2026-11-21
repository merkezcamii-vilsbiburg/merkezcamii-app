import 'dart:async';
import 'dart:math' as m;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin.dart';
import 'brand.dart';
import 'data.dart';
import 'islamic.dart';
import 'pages.dart';
import 'prayer.dart';
import 'theme.dart';

String two(int v) => v.toString().padLeft(2, '0');
String fmtDur(int secs) => '${two(secs ~/ 3600)}:${two(secs % 3600 ~/ 60)}:${two(secs % 60)}';

// ================================================================ Ramazan / Bayram / Kandil

/// Großer Ramazan-Countdown (nur im Ramazan sichtbar). Wird jede Sekunde mit der Vakitler-Seite neu gebaut.
Widget ramazanCard() {
  final day = Islamic.ramazanDay();
  if (day == null) return const SizedBox.shrink();
  final now = DateTime.now().toUtc();
  final b = Prayer.nowBerlin();
  final today = Prayer.forBerlinDate(b);
  final tm = b.add(const Duration(days: 1));
  final tomorrow = Prayer.compute(tm.year, tm.month, tm.day);
  late String label;
  late DateTime target;
  if (now.isBefore(today['imsak']!)) {
    label = 'SAHURA KALAN';
    target = today['imsak']!;
  } else if (now.isBefore(today['aksam']!)) {
    label = 'İFTARA KALAN';
    target = today['aksam']!;
  } else {
    label = 'SAHURA KALAN';
    target = tomorrow['imsak']!;
  }
  final secs = target.difference(now).inSeconds.clamp(0, 999999);
  final kadir = day == 26 && !now.isBefore(today['aksam']!) || day == 27 && now.isBefore(today['imsak']!);
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FadeUp(
      child: Container(
        decoration: glass().copyWith(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gold.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.03)],
          ),
        ),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(children: [
          Text('🌙  RAMAZAN-I ŞERİF', style: manrope(11, w: 800, color: gold, ls: 2.4)),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Ramazan\'ın $day. günü', style: marcellus(24)),
          ),
          const SizedBox(height: 10),
          Text(label, style: manrope(11, w: 700, color: muted, ls: 2)),
          ShaderMask(
            shaderCallback: (r) => goldGradient.createShader(r),
            child: Text(fmtDur(secs),
                style: manrope(46, w: 700, color: Colors.white)
                    .copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Sahur ${Prayer.hm(today['imsak']!)}', style: manrope(13, w: 600, color: muted)),
            Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 12), color: line),
            Text('İftar ${Prayer.hm(today['aksam']!)}', style: manrope(13, w: 600, color: muted)),
          ]),
          if (kadir)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('✨ Bu gece Kadir Gecesi', style: manrope(15, w: 700, color: gold)),
            ),
        ]),
      ),
    ),
  );
}

/// Bayram- oder Kandil-Hinweis oben auf der Vakitler-Seite.
Widget holyBanner() {
  final bay = Islamic.bayramToday();
  String? title, sub;
  if (bay != null) {
    title = '${bay.$1}ınız mübarek olsun';
    sub = '${bay.$2}. gün · Vilsbiburg Merkez Camii olarak bayramınızı tebrik ederiz.';
  } else {
    final k = Islamic.kandilTonight();
    if (k != null) {
      title = k.key == 'kadir' ? 'Bu gece Kadir Gecesi' : 'Bu gece ${k.name}';
      sub = k.key == 'kadir' ? 'Kadir Geceniz mübarek olsun.' : '${k.name}iniz mübarek olsun.';
    }
  }
  if (title == null) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: FadeUp(
      child: Container(
        decoration: glass(r: 22).copyWith(
          gradient: LinearGradient(colors: [gold.withValues(alpha: 0.22), gold.withValues(alpha: 0.05)]),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          Text(bay != null ? '🌙' : '✨', style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: marcellus(19)),
              Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub!, style: manrope(13, color: muted))),
            ]),
          ),
        ]),
      ),
    ),
  );
}

/// Nächster besonderer Tag (kleine Zeile unter den Vakitler)
Widget nextHolyDayLine() {
  final list = Islamic.upcoming(120).where((h) => h.date.isAfter(DateTime.now())).toList();
  if (list.isEmpty) return const SizedBox.shrink();
  final h = list.first;
  final days = DateTime(h.date.year, h.date.month, h.date.day)
      .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
      .inDays;
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text('${h.isBayram ? '🌙' : '✨'} ${h.name}: ${Islamic.fmtDate(h.date)} · $days gün kaldı',
        textAlign: TextAlign.center, style: manrope(12, w: 600, color: gold.withValues(alpha: 0.85))),
  );
}

// ================================================================ Kıble

const _kaabaLat = 21.4225, _kaabaLng = 39.8262;

double qiblaBearing() {
  final p1 = Prayer.lat * m.pi / 180, p2 = _kaabaLat * m.pi / 180;
  final dl = (_kaabaLng - Prayer.lng) * m.pi / 180;
  final y = m.sin(dl) * m.cos(p2);
  final x = m.cos(p1) * m.sin(p2) - m.sin(p1) * m.cos(p2) * m.cos(dl);
  return (m.atan2(y, x) * 180 / m.pi + 360) % 360;
}

Widget qiblaButton() => GestureDetector(
      onTap: () {
        app.showQibla = true;
        app.ui();
      },
      child: Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: glass(r: 20, elevated: false),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🧭', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Text('Kıble yönü', style: manrope(16, w: 700)),
        ]),
      ),
    );

class QiblaScreen extends StatelessWidget {
  final VoidCallback onClose;
  const QiblaScreen({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final q = qiblaBearing();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onClose();
      },
      child: Material(
        color: bg,
        child: Stack(children: [
          const Positioned.fill(child: BrandBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Text('Kıble', style: marcellus(25))),
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
                Expanded(
                  child: StreamBuilder<CompassEvent>(
                    stream: FlutterCompass.events,
                    builder: (context, snap) {
                      final heading = snap.data?.heading;
                      if (FlutterCompass.events == null || (snap.hasData && heading == null)) {
                        return _noSensor(q);
                      }
                      final h = heading ?? 0;
                      final diff = ((q - h + 540) % 360) - 180; // -180..180
                      final aligned = diff.abs() < 4;
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: Transform.rotate(
                            angle: -h * m.pi / 180,
                            child: CustomPaint(painter: _CompassPainter(q, aligned)),
                          ),
                        ),
                        const SizedBox(height: 26),
                        Text(aligned ? 'Kıble yönündesiniz ✓' : (diff > 0 ? 'Sağa dönün ↻' : 'Sola dönün ↺'),
                            style: marcellus(24, color: aligned ? gold : textC)),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Kıble açısı ${q.round()}° · Telefonu düz tutun',
                              style: manrope(13, color: muted)),
                        ),
                      ]);
                    },
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _noSensor(double q) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${q.round()}°', style: marcellus(64, color: gold)),
          Text('Güneydoğu (kuzeyden saat yönünde)', style: manrope(15, color: muted)),
          const SizedBox(height: 14),
          Text('Bu telefonda pusula sensörü bulunamadı.', style: manrope(13, color: muted)),
        ]),
      );
}

class _CompassPainter extends CustomPainter {
  final double qibla;
  final bool aligned;
  _CompassPainter(this.qibla, this.aligned);

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);
    final r = s.width * 0.44;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0C2119));
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = gold.withValues(alpha: 0.5));
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * m.pi / 180;
      final long = i % 18 == 0;
      final p1 = c + Offset(m.sin(a), -m.cos(a)) * r;
      final p2 = c + Offset(m.sin(a), -m.cos(a)) * (r - (long ? 16 : 7));
      canvas.drawLine(p1, p2, Paint()
        ..strokeWidth = long ? 2 : 1
        ..color = gold.withValues(alpha: long ? 0.9 : 0.35));
    }
    const dirs = ['K', 'D', 'G', 'B'];
    for (var i = 0; i < 4; i++) {
      final a = i * 90 * m.pi / 180;
      final tp = TextPainter(
        text: TextSpan(text: dirs[i], style: manrope(16, w: 800, color: i == 0 ? closedRed : textC)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(m.sin(a), -m.cos(a)) * (r - 32);
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    // Kıble-Nadel
    final qa = qibla * m.pi / 180;
    final tip = c + Offset(m.sin(qa), -m.cos(qa)) * (r - 44);
    canvas.drawLine(c, tip, Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [gold2, gold]).createShader(Rect.fromPoints(c, tip)));
    canvas.drawCircle(tip, aligned ? 18 : 14, Paint()..color = aligned ? gold : gold.withValues(alpha: 0.85));
    final tp = TextPainter(text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 18)), textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, tip - Offset(tp.width / 2, tp.height / 2));
    canvas.drawCircle(c, 7, Paint()..color = gold);
  }

  @override
  bool shouldRepaint(_CompassPainter o) => o.qibla != qibla || o.aligned != aligned;
}

// ================================================================ Bağış & İletişim (Hakkımızda)

String euro(double v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '$b €';
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

Widget donationsCard(BuildContext context) {
  final iban = app.setting('iban'), paypal = app.setting('paypal');
  final owner = app.setting('hesap_sahibi'), bank = app.setting('banka');
  if (app.donations.isEmpty && iban.isEmpty && paypal.isEmpty) return const SizedBox.shrink();
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    sectionHead('Bağış', 'Sadaka · Destek', top: 34),
    for (final d in app.donations)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: glassBox(
          r: 20,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.title, style: manrope(16, w: 700)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(euro(d.collected), style: marcellus(24, color: gold)),
              if (d.target > 0) ...[
                Text('  / ${euro(d.target)}', style: manrope(13, color: muted)),
                const Spacer(),
                Text('%${(d.collected / d.target * 100).clamp(0, 999).round()}', style: manrope(14, w: 800, color: gold)),
              ],
            ]),
            if (d.target > 0)
              Container(
                margin: const EdgeInsets.only(top: 10),
                height: 8,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (d.collected / d.target).clamp(0.0, 1.0),
                  child: Container(
                      decoration:
                          BoxDecoration(gradient: const LinearGradient(colors: [gold2, gold]), borderRadius: BorderRadius.circular(8))),
                ),
              ),
          ]),
        ),
      ),
    if (iban.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: glassBox(
          r: 20,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('BANKA HAVALESİ', style: manrope(11, w: 700, color: gold, ls: 2)),
            if (owner.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(owner, style: manrope(14, w: 600))),
            Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(iban, style: manrope(17, w: 700, ls: 0.5))),
            if (bank.isNotEmpty) Text(bank, style: manrope(13, color: muted)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: iban.replaceAll(' ', '')));
                toast(context, 'IBAN kopyalandı');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(gradient: goldGradient, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Text('IBAN\'ı kopyala', style: manrope(15, w: 800, color: bg)),
              ),
            ),
          ]),
        ),
      ),
    if (paypal.isNotEmpty)
      GestureDetector(
        onTap: () => openUrl(paypal.startsWith('http') ? paypal : 'https://$paypal'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: glass(r: 20, elevated: false),
          alignment: Alignment.center,
          child: Text('PayPal ile bağış yap', style: manrope(16, w: 700)),
        ),
      ),
  ]);
}

Widget contactCard() {
  final adres = app.setting('adres'), tel = app.setting('telefon'), mail = app.setting('eposta');
  if (adres.isEmpty && tel.isEmpty && mail.isEmpty) return const SizedBox.shrink();
  Widget row(String emoji, String text, String action, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text(text, style: manrope(15, w: 600))),
            Text(action, style: manrope(13, w: 700, color: gold)),
          ]),
        ),
      );
  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    sectionHead('İletişim', 'Bize ulaşın', top: 34),
    glassBox(
      r: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      child: Column(children: [
        if (adres.isNotEmpty)
          row('📍', adres, 'Harita',
              () => openUrl('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(adres)}')),
        if (tel.isNotEmpty) row('📞', tel, 'Ara', () => openUrl('tel:${tel.replaceAll(' ', '')}')),
        if (mail.isNotEmpty) row('✉️', mail, 'Yaz', () => openUrl('mailto:$mail')),
      ]),
    ),
  ]);
}

// ================================================================ Cami bilgileri düzenle (Yönetici)

class InfoEditScreen extends StatefulWidget {
  final VoidCallback onClose;
  const InfoEditScreen({super.key, required this.onClose});
  @override
  State<InfoEditScreen> createState() => _InfoEditScreenState();
}

class _InfoEditScreenState extends State<InfoEditScreen> {
  static const fields = [
    ['adres', 'Adres', 'Örn: Musterstraße 1, 84137 Vilsbiburg'],
    ['telefon', 'Telefon', 'Örn: 08741 12345'],
    ['eposta', 'E-posta', 'Örn: info@…'],
    ['hesap_sahibi', 'Hesap sahibi', 'Muslimgemeinde Vilsbiburg e.V.'],
    ['iban', 'IBAN', 'DE00 0000 0000 0000 0000 00'],
    ['banka', 'Banka', 'Örn: Sparkasse Landshut'],
    ['paypal', 'PayPal linki', 'Örn: paypal.me/…'],
    ['ramazan_baslangic', 'Ramazan başlangıcı (düzeltme)', 'YYYY-AA-GG, boş = otomatik'],
    ['kurban_bayrami', 'Kurban Bayramı 1. gün (düzeltme)', 'YYYY-AA-GG, boş = otomatik'],
  ];
  late final Map<String, TextEditingController> c = {
    for (final f in fields) f[0]: TextEditingController(text: app.setting(f[0]))
  };
  bool busy = false;
  String? msg;

  Future<void> save() async {
    setState(() {
      busy = true;
      msg = null;
    });
    try {
      for (final f in fields) {
        final v = c[f[0]]!.text.trim();
        if (v != app.setting(f[0])) await app.setSetting(f[0], v);
      }
      msg = '✓ Kaydedildi';
    } catch (e) {
      msg = 'Kaydedilemedi: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> editDonation(Donation? d) async {
    final t = TextEditingController(text: d?.title ?? '');
    final col = TextEditingController(text: d == null ? '' : d.collected.round().toString());
    final tar = TextEditingController(text: d == null ? '' : d.target.round().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0C2119),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: line)),
        title: Text(d == null ? 'Yeni bağış hedefi' : 'Bağış hedefi', style: marcellus(22)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          bigField(t, 'Örn: Cami tadilatı', size: 16),
          const SizedBox(height: 10),
          bigField(col, 'Toplanan (€)', type: TextInputType.number, size: 16,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
          const SizedBox(height: 10),
          bigField(tar, 'Hedef (€)', type: TextInputType.number, size: 16,
              formatters: [FilteringTextInputFormatter.digitsOnly]),
        ]),
        actions: [
          if (d != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx, false);
                await app.deleteDonation(d.id);
                if (mounted) setState(() {});
              },
              child: Text('Sil', style: manrope(15, w: 700, color: closedRed)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: manrope(15, color: muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Kaydet', style: manrope(15, w: 800, color: gold))),
        ],
      ),
    );
    if (ok == true && t.text.trim().isNotEmpty) {
      try {
        await app.saveDonation(d?.id, t.text.trim(), double.tryParse(col.text) ?? 0, double.tryParse(tar.text) ?? 0);
      } catch (e) {
        if (mounted) toast(context, 'Kaydedilemedi: $e');
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onClose();
        },
        child: Material(
          color: bg,
          child: Stack(children: [
            const Positioned.fill(child: BrandBackground()),
            SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 40 + MediaQuery.of(context).viewInsets.bottom),
                children: [
                  Row(children: [
                    Expanded(child: Text('Cami bilgileri', style: marcellus(25))),
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
                  const SizedBox(height: 18),
                  fieldLabel('Bağış hedefleri'),
                  for (final d in app.donations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () => editDonation(d),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: glass(r: 18, elevated: false),
                          child: Row(children: [
                            Expanded(child: Text(d.title, style: manrope(15, w: 700))),
                            Text('${euro(d.collected)} / ${euro(d.target)}', style: manrope(13, color: gold)),
                            const SizedBox(width: 8),
                            Text('✎', style: manrope(16, color: muted)),
                          ]),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => editDonation(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: line)),
                      alignment: Alignment.center,
                      child: Text('＋ Bağış hedefi ekle', style: manrope(15, w: 700, color: gold)),
                    ),
                  ),
                  const SizedBox(height: 22),
                  for (final f in fields) ...[
                    fieldLabel(f[1]),
                    bigField(c[f[0]]!, f[2], size: 16),
                    const SizedBox(height: 14),
                  ],
                  if (msg != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(msg!, textAlign: TextAlign.center,
                          style: manrope(15, w: 700, color: msg!.startsWith('✓') ? openGreen : closedRed)),
                    ),
                  bigButton(busy ? '…' : 'KAYDET', enabled: !busy, onTap: save),
                ],
              ),
            ),
          ]),
        ),
      );
}

/// Unbenutzt – hält den Timer-Import für spätere Erweiterungen stabil.
Timer? unusedTimer;
