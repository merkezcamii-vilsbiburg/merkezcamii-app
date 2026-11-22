import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ---------- Farben (wie Webseite) ----------
const bg = Color(0xFF06140F);
const bg2 = Color(0xFF0B2A20);
const gold = Color(0xFFE3BF72);
const gold2 = Color(0xFFB8903F);
const textC = Color(0xFFF4EFE4);
const muted = Color(0x9EF4EFE4);
const line = Color(0x38E3BF72);
const openGreen = Color(0xFF4ADE80);
const closedRed = Color(0xFFF87171);

const goldGradient = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [gold, gold2]);

/// Text in Manrope mit echter Variable-Font-Stärke.
TextStyle manrope(double size, {int w = 400, Color color = textC, double? ls, double? height}) => TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontVariations: [FontVariation('wght', w.toDouble())],
      fontWeight: FontWeight.values[((w ~/ 100) - 1).clamp(0, 8)],
      color: color,
      letterSpacing: ls,
      height: height,
    );

TextStyle marcellus(double size, {Color color = textC, double? ls}) =>
    TextStyle(fontFamily: 'Marcellus', fontSize: size, color: color, letterSpacing: ls);

TextStyle amiri(double size, {Color color = gold}) => TextStyle(fontFamily: 'Amiri', fontSize: size, color: color);

/// Glas-Karte
BoxDecoration glass({double r = 26, bool elevated = true}) => BoxDecoration(
      color: const Color(0xFF0C2119),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.09), Colors.white.withValues(alpha: 0.03)],
      ),
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: line),
      boxShadow: elevated
          ? const [BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 14))]
          : null,
    );

Widget glassBox({required Widget child, double r = 26, bool elevated = true, EdgeInsets? padding}) => Container(
      decoration: glass(r: r, elevated: elevated).copyWith(color: const Color(0xFF0C2119)),
      clipBehavior: Clip.antiAlias,
      padding: padding,
      child: child,
    );

// ---------- Strich-Icons (Pfade von der Webseite) ----------
String _svg(List<String> paths, {double w = 1.7}) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" '
    'stroke-width="$w" stroke-linecap="round" stroke-linejoin="round">'
    '${paths.map((d) => '<path d="$d"/>').join()}</svg>';

class Ic {
  static final clock = _svg(['M4,13a8,8 0 1,0 16,0a8,8 0 1,0 -16,0', 'M12 9v4l2.5 2.5M9 2h6']);
  static final speaker = _svg(['M4 10v4a1 1 0 0 0 1 1h3l6 4V5L8 9H5a1 1 0 0 0-1 1z', 'M18 8.5a5 5 0 0 1 0 7']);
  static final mosque = _svg(['M4 21V11a8 8 0 0 1 16 0v10M2 21h20M12 3V1M9 21v-5a3 3 0 0 1 6 0v5']);
  static final lockClosed = _svg([
    'M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z',
    'M8 11V7a4 4 0 0 1 8 0v4'
  ], w: 2);
  static final lockOpen = _svg([
    'M7 11h10a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2z',
    'M8 11V7a4 4 0 0 1 7.5-2'
  ], w: 2);
  static final gear = _svg([
    'M9,12a3,3 0 1,0 6,0a3,3 0 1,0 -6,0',
    'M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z'
  ], w: 1.6);
  static final compass = _svg(['M3,12a9,9 0 1,0 18,0a9,9 0 1,0 -18,0', 'M16.24 7.76l-2.12 6.36-6.36 2.12 2.12-6.36z'], w: 1.6);
  static final printer = _svg(['M6 9V2h12v7', 'M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2', 'M6 14h12v8H6z'], w: 1.8);
  static final pen = _svg(['M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z'], w: 1.8);
  static final ball = _svg(['M3,12a9,9 0 1,0 18,0a9,9 0 1,0 -18,0', 'M12 7.5l3.8 2.8-1.5 4.4H9.7l-1.5-4.4z']);
  static final camera = _svg([
    'M4 8h3l2-2.5h6L17 8h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z',
    'M9,13a3,3 0 1,0 6,0a3,3 0 1,0 -6,0'
  ]);
  static const _moon = 'M20 14.5A8 8 0 0 1 9.5 4a8 8 0 1 0 10.5 10.5z';
  static final prayer = <String, String>{
    'imsak': _svg([_moon], w: 1.6),
    'gunes': _svg(['M3 18h18M6 18a6 6 0 0 1 12 0M12 6v3M5 11l2 1.5M19 11l-2 1.5'], w: 1.6),
    'ogle': _svg([
      'M8,12a4,4 0 1,0 8,0a4,4 0 1,0 -8,0',
      'M12 2v2M12 20v2M2 12h2M20 12h2M5 5l1.5 1.5M17.5 17.5L19 19M5 19l1.5-1.5M17.5 6.5L19 5'
    ], w: 1.6),
    'ikindi': _svg([
      'M8,13a4,4 0 1,0 8,0a4,4 0 1,0 -8,0',
      'M12 4v2M4 13h2M18 13h2M6.3 7.3l1.4 1.4M16.3 8.7l1.4-1.4M3 20h18'
    ], w: 1.6),
    'aksam': _svg(['M3 18h18M7 18a5 5 0 0 1 10 0M12 9V5M9.5 7.5L12 5l2.5 2.5'], w: 1.6),
    'yatsi': _svg([_moon, 'M17 4l.5 1.5L19 6l-1.5.5L17 8l-.5-1.5L15 6l1.5-.5z'], w: 1.6),
  };
}

Widget icon(String svg, {double size = 22, Color color = textC}) => SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );

/// Goldener Trennstrich
Widget goldDivider() => Container(
      width: 120,
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [Colors.transparent, gold, Colors.transparent]),
      ),
    );

/// Sanftes Einblenden von unten
class FadeUp extends StatefulWidget {
  final Widget child;
  final int delayMs;
  const FadeUp({super.key, required this.child, this.delayMs = 0});
  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, child) {
          final p = Curves.easeOutCubic.transform(c.value);
          return Opacity(opacity: p, child: Transform.translate(offset: Offset(0, (1 - p) * 22), child: child));
        },
        child: widget.child,
      );
}

/// Goldenes Abzeichen mit Zahl
Widget goldBadge(int count) => Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        gradient: goldGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(count > 9 ? '9+' : '$count', style: manrope(10, w: 800, color: bg)),
    );

ImageFilter blurBy(double s) => ImageFilter.blur(sigmaX: s, sigmaY: s);
