// Instagram-Bild für eine Duyuru: Foto passend machen (4:5 … 1,91:1) oder ein Text-Bild im Cami-Design erzeugen.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import 'theme.dart';

const _w = 1080.0, _h = 1350.0;

Future<ui.Image> _asset(String name) async {
  final d = await rootBundle.load('assets/img/$name');
  final c = await ui.instantiateImageCodec(d.buffer.asUint8List());
  return (await c.getNextFrame()).image;
}

void _drawImg(Canvas c, ui.Image i, Rect dst) {
  c.drawImageRect(i, Rect.fromLTWH(0, 0, i.width.toDouble(), i.height.toDouble()), dst,
      Paint()..filterQuality = FilterQuality.high);
}

/// JPEG für Instagram. [photo] ist das Foto der Duyuru (JPEG) oder null.
Future<Uint8List> instagramImage({
  Uint8List? photo,
  required String section,
  required String title,
  required String body,
}) async {
  if (photo != null) return _fitPhoto(photo);
  return _textCard(section, title, body);
}

Future<Uint8List> _fitPhoto(Uint8List photo) async {
  final src = img.decodeImage(photo);
  if (src == null) return photo;
  final r = src.width / src.height;
  if (r >= 0.8 && r <= 1.91) return photo; // Instagram nimmt es so
  // Zu hoch oder zu breit: auf 1080×1350 mit dunkelgrünem Rand einpassen
  final out = img.Image(width: _w.toInt(), height: _h.toInt());
  img.fill(out, color: img.ColorRgb8(0x06, 0x14, 0x0F));
  final s = (src.width / _w > src.height / _h) ? _w / src.width : _h / src.height;
  final rw = (src.width * s).round(), rh = (src.height * s).round();
  final rs = img.copyResize(src, width: rw, height: rh, interpolation: img.Interpolation.cubic);
  img.compositeImage(out, rs, dstX: ((_w - rw) / 2).round(), dstY: ((_h - rh) / 2).round());
  return Uint8List.fromList(img.encodeJpg(out, quality: 88));
}

TextPainter _tp(String t, TextStyle s, double maxW, {int? maxLines, TextAlign align = TextAlign.center}) {
  final p = TextPainter(
    text: TextSpan(text: t, style: s),
    textAlign: align,
    textDirection: TextDirection.ltr,
    maxLines: maxLines,
    ellipsis: maxLines == null ? null : '…',
  );
  p.layout(maxWidth: maxW);
  return p;
}

Future<Uint8List> _textCard(String section, String title, String body) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, _w, _h));
  const full = Rect.fromLTWH(0, 0, _w, _h);

  // Hintergrund: dunkelgrün mit leichtem Licht oben
  c.drawRect(full, Paint()..color = bg);
  c.drawRect(
      full,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(_w / 2, 260), 900,
            [bg2, bg.withValues(alpha: 0)]));
  // Goldener Doppelrahmen
  final fr = Paint()
    ..style = PaintingStyle.stroke
    ..color = gold.withValues(alpha: 0.75)
    ..strokeWidth = 3;
  c.drawRRect(RRect.fromRectAndRadius(full.deflate(40), const Radius.circular(36)), fr);
  c.drawRRect(RRect.fromRectAndRadius(full.deflate(54), const Radius.circular(28)),
      fr..color = gold.withValues(alpha: 0.3)..strokeWidth = 1.5);

  // Logo
  double y;
  if (section == 'cami') {
    final dome = await _asset('logo_dome.png');
    final cres = await _asset('logo_cres.png');
    final txt = await _asset('logo_txt.png');
    const lw = 420.0, lh = lw * 685 / 1100, lx = (_w - lw) / 2, ly = 110.0;
    _drawImg(c, dome, const Rect.fromLTWH(lx, ly, lw, lh));
    _drawImg(c, cres, const Rect.fromLTWH(lx, ly, lw, lw * 168 / 1100));
    _drawImg(c, txt, Rect.fromLTWH(lx + lw * 0.2401, ly + lh * 0.7002, lw * 0.5242, lw * 0.5242 * 129 / 577));
    y = ly + lh + 40;
  } else {
    final g = await _asset('logo_genclik.png');
    const lw = 560.0, lh = lw * 321 / 992;
    _drawImg(c, g, const Rect.fromLTWH((_w - lw) / 2, 130, lw, lh));
    y = 130 + lh + 50;
  }

  // Goldene Trennlinie mit Raute
  final lp = Paint()
    ..shader = ui.Gradient.linear(Offset(_w / 2 - 220, y), Offset(_w / 2 + 220, y),
        [gold.withValues(alpha: 0), gold, gold.withValues(alpha: 0)], [0, 0.5, 1])
    ..strokeWidth = 2;
  c.drawLine(Offset(_w / 2 - 220, y), Offset(_w / 2 + 220, y), lp);
  c.save();
  c.translate(_w / 2, y);
  c.rotate(0.785398);
  c.drawRect(const Rect.fromLTWH(-7, -7, 14, 14), Paint()..color = gold);
  c.restore();
  y += 56;

  const textW = _w - 200;
  const footerTop = _h - 150;
  if (title.trim().isNotEmpty) {
    final t = _tp(title.trim(), const TextStyle(fontFamily: 'Marcellus', fontSize: 64, color: gold, height: 1.15),
        textW, maxLines: 3);
    t.paint(c, Offset((_w - t.width) / 2, y));
    y += t.height + 40;
  }
  // Text: Größe so wählen, dass er in den freien Platz passt
  final avail = footerTop - 40 - y;
  TextPainter? b;
  for (var fs = 44.0; fs >= 26; fs -= 2) {
    b = _tp(
        body.trim(),
        TextStyle(
            fontFamily: 'Manrope',
            fontSize: fs,
            color: textC,
            height: 1.4,
            fontVariations: const [ui.FontVariation('wght', 500)]),
        textW);
    if (b.height <= avail) break;
  }
  if (b != null && b.height > avail) {
    final lines = (avail / (26 * 1.4)).floor().clamp(1, 60);
    b = _tp(
        body.trim(),
        const TextStyle(
            fontFamily: 'Manrope', fontSize: 26, color: textC, height: 1.4, fontVariations: [ui.FontVariation('wght', 500)]),
        textW,
        maxLines: lines);
  }
  if (b != null) {
    final by = y + (avail - b.height).clamp(0, double.infinity) * 0.35;
    b.paint(c, Offset((_w - b.width) / 2, by));
  }

  // Fußzeile
  final f = _tp(section == 'cami' ? 'MERKEZ CAMİİ · VİLSBİBURG' : 'GENÇLİK KOLLARI · MERKEZ CAMİİ VİLSBİBURG',
      TextStyle(fontFamily: 'Marcellus', fontSize: 30, color: gold.withValues(alpha: 0.9), letterSpacing: 4), textW);
  f.paint(c, Offset((_w - f.width) / 2, footerTop + 30));

  final pic = rec.endRecording();
  final image = await pic.toImage(_w.toInt(), _h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final raw = img.Image.fromBytes(
      width: _w.toInt(), height: _h.toInt(), bytes: data!.buffer, numChannels: 4, order: img.ChannelOrder.rgba);
  return Uint8List.fromList(img.encodeJpg(raw, quality: 90));
}
