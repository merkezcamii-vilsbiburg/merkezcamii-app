import 'dart:math' as m;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Hintergrund: Licht + langsam wanderndes Ornament-Muster.
class BrandBackground extends StatefulWidget {
  const BrandBackground({super.key});
  @override
  State<BrandBackground> createState() => _BrandBackgroundState();
}

class _BrandBackgroundState extends State<BrandBackground> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(seconds: 90))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: c,
          builder: (_, __) => CustomPaint(painter: _BgPainter(c.value), size: Size.infinite),
        ),
      );
}

class _BgPainter extends CustomPainter {
  final double drift;
  _BgPainter(this.drift);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = bg);
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF081B14), bg])
              .createShader(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = RadialGradient(
            center: Alignment.topCenter,
            radius: 1.1 * w / m.max(w, h) * 2,
            colors: const [Color(0xFF0F3A2B), Colors.transparent],
          ).createShader(rect));
    canvas.drawCircle(
        Offset(w / 2, h * 0.22),
        w * 0.75,
        Paint()
          ..shader = RadialGradient(colors: [gold.withValues(alpha: 0.16), Colors.transparent])
              .createShader(Rect.fromCircle(center: Offset(w / 2, h * 0.22), radius: w * 0.75)));

    // Ornament mit Maske
    canvas.saveLayer(rect, Paint());
    const tile = 96.0;
    final shift = drift * tile - tile;
    final p = Paint()
      ..color = gold.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final diamond = Path()
      ..moveTo(48, 14.06)
      ..lineTo(81.94, 48)
      ..lineTo(48, 81.94)
      ..lineTo(14.06, 48)
      ..close();
    final cols = (w / tile).ceil() + 2, rows = (h / tile).ceil() + 2;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.save();
        canvas.translate(c * tile + shift, r * tile + shift);
        canvas.drawRect(const Rect.fromLTWH(24, 24, 48, 48), p);
        canvas.drawPath(diamond, p);
        canvas.drawCircle(const Offset(48, 48), 12, p);
        canvas.drawLine(Offset.zero, const Offset(24, 24), p);
        canvas.drawLine(const Offset(96, 0), const Offset(72, 24), p);
        canvas.drawLine(const Offset(0, 96), const Offset(24, 72), p);
        canvas.drawLine(const Offset(96, 96), const Offset(72, 72), p);
        canvas.restore();
      }
    }
    final maskRect = Rect.fromCircle(center: Offset(w / 2, h * 0.24), radius: w * 0.95);
    canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = RadialGradient(colors: [
            Colors.black,
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent
          ]).createShader(maskRect));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BgPainter o) => o.drift != drift;
}

double seg(double t, double start, double dur, Curve e) => e.transform(((t - start) / dur).clamp(0.0, 1.0));

const easeRise = Cubic(0.65, 0, 0.25, 1);
const easeOutC = Cubic(0.2, 0.8, 0.2, 1);
const easeStd = Cubic(0.25, 0.1, 0.25, 1);

/// Logo aus drei Ebenen: Kuppel steigt auf, Hilal senkt sich und leuchtet, Schrift wird scharf.
class AnimatedLogo extends StatefulWidget {
  final double t; // ms
  const AnimatedLogo({super.key, required this.t});
  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo> with SingleTickerProviderStateMixin {
  late final AnimationController pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final dome = seg(t, 150, 950, easeRise);
    final cres = seg(t, 950, 650, easeOutC);
    final txt = seg(t, 1250, 650, easeStd);
    return AspectRatio(
      aspectRatio: 2041 / 1271,
      child: LayoutBuilder(builder: (_, cs) {
        final w = cs.maxWidth, h = cs.maxHeight;
        return Stack(clipBehavior: Clip.none, children: [
          Positioned(
            left: w * 0.523 - w * 0.13,
            top: w * 168 / 1100 * 0.42 - w * 0.13,
            width: w * 0.26,
            height: w * 0.26,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, __) {
                final pv = 0.35 + 0.65 * easeStd.transform(pulse.value);
                return DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                        colors: [gold.withValues(alpha: 0.55 * pv * cres), Colors.transparent]),
                  ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: ClipRect(
              clipper: _TopClip(1 - dome),
              child: Image.asset('assets/img/logo_dome.png', fit: BoxFit.fill),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            width: w,
            height: w * 168 / 1100,
            child: Opacity(
              opacity: cres,
              child: Transform.translate(
                offset: Offset(0, (1 - cres) * -14),
                child: Transform.scale(
                    scale: 0.96 + 0.04 * cres, child: Image.asset('assets/img/logo_cres.png', fit: BoxFit.fill)),
              ),
            ),
          ),
          Positioned(
            left: w * 0.2401,
            top: h * 0.7002,
            width: w * 0.5242,
            child: Opacity(
              opacity: txt,
              child: ImageFiltered(
                imageFilter: blurBy((1 - txt) * 4 + 0.001),
                child: AspectRatio(aspectRatio: 577 / 129, child: Image.asset('assets/img/logo_txt.png', fit: BoxFit.fill)),
              ),
            ),
          ),
        ]);
      }),
    );
  }
}

class _TopClip extends CustomClipper<Rect> {
  final double topFraction;
  _TopClip(this.topFraction);
  @override
  Rect getClip(Size s) => Rect.fromLTRB(0, s.height * topFraction, s.width, s.height);
  @override
  bool shouldReclip(_TopClip o) => o.topFraction != topFraction;
}

const splashMs = 2300.0;

/// Startanimation: Besmele → Kuppel → Hilal → Schrift. Antippen überspringt.
class Splash extends StatefulWidget {
  final VoidCallback onDone;
  const Splash({super.key, required this.onDone});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final AnimationController c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));
  bool done = false;

  void finish() {
    if (done) return;
    done = true;
    widget.onDone();
  }

  @override
  void initState() {
    super.initState();
    c.forward().whenComplete(finish);
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: finish,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          const Positioned.fill(child: BrandBackground()),
          Center(
            child: AnimatedBuilder(
              animation: c,
              builder: (_, __) {
                final t = c.value * splashMs;
                final b = seg(t, 0, 700, easeStd);
                final n = seg(t, 1600, 600, easeStd);
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Opacity(
                    opacity: b,
                    child: Transform.translate(
                      offset: Offset(0, (1 - b) * 14),
                      child: Text('بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ', style: amiri(24), textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(height: 26),
                  FractionallySizedBox(widthFactor: 0.86, child: AnimatedLogo(t: t)),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: n,
                    child: Transform.translate(
                      offset: Offset(0, (1 - n) * 14),
                      child: Text('Muslimgemeinde Vilsbiburg e.V.', style: marcellus(21, ls: 1.2)),
                    ),
                  ),
                ]);
              },
            ),
          ),
        ]),
      );
}
