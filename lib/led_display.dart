import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const int    kRows     = 32;
const double kBaseDot  = 8.0;
const double kBaseGap  = 2.0;
const double kBaseStep = kBaseDot + kBaseGap; // 10px
const double kDispH    = kRows * kBaseStep;   // 320px
const int    kColsPerChar = 8; // min LED columns per glyph in fit mode
const double kMinFitDot   = 4.0;

// ── Color helpers ─────────────────────────────────────────────────────────────
Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

Color hslToColor(double hDeg, double s, double l) {
  final h = hDeg / 360.0;
  double r, g, b;
  if (s == 0) {
    r = g = b = l;
  } else {
    double hue2rgb(double p, double q, double t) {
      if (t < 0) t += 1;
      if (t > 1) t -= 1;
      if (t < 1 / 6) return p + (q - p) * 6 * t;
      if (t < 1 / 2) return q;
      if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
      return p;
    }
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  return Color.fromARGB(
    255,
    (r * 255).round().clamp(0, 255),
    (g * 255).round().clamp(0, 255),
    (b * 255).round().clamp(0, 255),
  );
}

bool isGrayish(int r, int g, int b) =>
    r > 150 && (max(r, max(g, b)) - min(r, min(g, b))) < 35;

// ── LED Bitmap ────────────────────────────────────────────────────────────────
class LEDBitmap {
  final Uint8List data;
  final int w;
  final int h;
  LEDBitmap({required this.data, required this.w, required this.h});
}

Future<LEDBitmap> buildScrollBitmap(String text, double sizeRatio) async {
  if (text.isEmpty) text = ' ';
  const scale     = 4;
  final srcH      = (kDispH * scale).round();
  final fontSize  = (srcH * sizeRatio).round().toDouble();
  const scaleX    = 0.72;

  final recorder  = ui.PictureRecorder();
  final offCanvas = Canvas(recorder);

  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  tp.layout();

  final pad    = (fontSize * 0.5).round();
  final srcW   = (tp.width * scaleX + pad * 2).ceil().clamp(1, 16000);

  offCanvas.drawRect(
    Rect.fromLTWH(0, 0, srcW.toDouble(), srcH.toDouble()),
    Paint()..color = Colors.black,
  );
  offCanvas.save();
  offCanvas.scale(scaleX, 1.0);
  tp.paint(offCanvas, Offset(pad / scaleX, (srcH - tp.height) / 2));
  offCanvas.restore();

  final picture = recorder.endRecording();
  final image   = await picture.toImage(srcW, srcH);
  final bytes   = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();

  return LEDBitmap(
    data: bytes!.buffer.asUint8List(),
    w:    srcW,
    h:    srcH,
  );
}

Future<LEDBitmap> buildFitBitmap(
    String text, double sizeRatio, int fitCols) async {
  if (text.isEmpty) text = ' ';
  const scale    = 4;
  final fh       = kRows * scale;
  final fontSize = (fh * sizeRatio).round().toDouble();

  // Measure natural width
  final tp0 = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final naturalW = tp0.width;
  final fitScaleX = (fitCols - 2) / max(naturalW, 1.0);

  final recorder  = ui.PictureRecorder();
  final offCanvas = Canvas(recorder);
  offCanvas.drawRect(
    Rect.fromLTWH(0, 0, fitCols.toDouble(), fh.toDouble()),
    Paint()..color = Colors.black,
  );
  offCanvas.save();
  offCanvas.scale(fitScaleX, 1.0);
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: Colors.white),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(offCanvas, Offset(1 / fitScaleX, (fh - tp.height) / 2));
  offCanvas.restore();

  final picture = recorder.endRecording();
  final image   = await picture.toImage(fitCols, fh);
  final bytes   = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();

  return LEDBitmap(
    data: bytes!.buffer.asUint8List(),
    w:    fitCols,
    h:    fh,
  );
}

// Sample: vertical average for one LED row
List<int> sampleBitmap(LEDBitmap bm, int x, int row) {
  if (x < 0 || x >= bm.w) return [0, 0, 0, 0];
  final y0 = ((row       / kRows) * bm.h).round().clamp(0, bm.h - 1);
  final y1 = (((row + 1) / kRows) * bm.h).round().clamp(0, bm.h);
  final n  = max(y1 - y0, 1);
  int r = 0, g = 0, b = 0, a = 0;
  for (int y = y0; y < y1; y++) {
    final idx = (y * bm.w + x) * 4;
    r += bm.data[idx];
    g += bm.data[idx + 1];
    b += bm.data[idx + 2];
    a += bm.data[idx + 3];
  }
  return [r ~/ n, g ~/ n, b ~/ n, a ~/ n];
}

// ── LED Painter ───────────────────────────────────────────────────────────────
class LEDPainter extends CustomPainter {
  final LEDBitmap? scrollBm;
  final LEDBitmap? fitBm;
  final int fitCols;
  final double fitStep;
  final double fitDot;
  final Color ledColor;
  final bool rainbow;
  final double scrollOffset;
  final bool flashVisible;
  final String effect;
  final double time;
  final double waveAmp;
  final double waveSpeed;
  final double waveFreq;
  final double pulseRate;
  final double rippleSpeed;
  final double rippleFreq;
  final double glitchInt;
  final List<double> glitchOffsets;
  final double bounceShift;
  final String inAnim;
  final String outAnim;
  final double zoneRatio;
  final String dotShape;
  final bool plusOn;

  LEDPainter({
    required this.scrollBm,
    required this.fitBm,
    required this.fitCols,
    required this.fitStep,
    required this.fitDot,
    required this.ledColor,
    required this.rainbow,
    required this.scrollOffset,
    required this.flashVisible,
    required this.effect,
    required this.time,
    required this.waveAmp,
    required this.waveSpeed,
    required this.waveFreq,
    required this.pulseRate,
    required this.rippleSpeed,
    required this.rippleFreq,
    required this.glitchInt,
    required this.glitchOffsets,
    required this.bounceShift,
    required this.inAnim,
    required this.outAnim,
    required this.zoneRatio,
    required this.dotShape,
    required this.plusOn,
  });

  bool get isFit => effect != 'none';

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF020202),
    );

    if (isFit) {
      _paintFit(canvas, size);
    } else {
      _paintScroll(canvas, size);
    }
  }

  // ── FIT mode ───────────────────────────────────────────────────────────────
  void _paintFit(Canvas canvas, Size size) {
    final bm = fitBm;
    if (bm == null) return;
    final rowH = kDispH / kRows;

    for (int col = 0; col < fitCols; col++) {
      final screenX = col * fitStep;
      final cx      = screenX + fitDot / 2;
      final bmX     = col;

      for (int row = 0; row < kRows; row++) {
        final cy = row * rowH + rowH / 2;

        double sampleRow = row.toDouble();
        double brightMod = 1.0;
        int    bmXOff    = 0;
        Color? forceCol;

        switch (effect) {
          case 'wave':
            sampleRow = row - sin(col * waveFreq * 0.3 + time * waveSpeed) * waveAmp;
          case 'pulse':
            brightMod = 0.25 + 0.75 * (0.5 + 0.5 * sin(time * pulseRate * pi * 2));
          case 'ripple':
            final d = (row - kRows / 2).abs();
            brightMod = 0.4 + 0.6 * max(0, sin(d * rippleFreq - time * rippleSpeed));
          case 'glitch':
            bmXOff = glitchOffsets[row].round();
          case 'fire':
            final fl = sin(col * 0.25 + time * 10 + row * 0.7) * (glitchInt / 10);
            brightMod = (0.3 + (row / kRows) * 0.7 + fl).clamp(0.1, 1.4);
          case 'bounce':
            sampleRow = row - bounceShift;
          case 'matrix':
            final drop = ((col * 7 + time * 12) % (kRows * 1.5)).floor();
            final dist = (row - drop % kRows).abs();
            brightMod  = dist == 0 ? 1.5 : dist < 4 ? 1 - dist / 5 : 0.05;
            forceCol   = const Color(0xFF00FF50);
        }

        sampleRow = sampleRow.clamp(0, kRows - 1.0);
        final px  = sampleBitmap(bm, bmX + bmXOff, sampleRow.round());
        final alpha = (px[3] / 255.0) * brightMod;

        if (!flashVisible || alpha < 0.05) {
          _drawDot(canvas, cx, cy, fitDot * 0.38, const Color(0xFF0E0E0E));
          continue;
        }

        final col0 = _resolveColor(px, forceCol, col, 0);
        _renderDot(canvas, cx, cy, fitDot, col0, alpha);
      }
    }
  }

  // ── SCROLL mode ────────────────────────────────────────────────────────────
  void _paintScroll(Canvas canvas, Size size) {
    final bm = scrollBm;
    if (bm == null) return;
    final numCols = (size.width / kBaseStep).ceil() + 2;

    for (int col = 0; col < numCols; col++) {
      final screenX = col * kBaseStep;
      final srcX    = (screenX + scrollOffset).round() - size.width.round();

      final iom = _getInOutMod(srcX, bm.w);

      for (int row = 0; row < kRows; row++) {
        final cx = screenX + kBaseDot / 2;
        final cy = row * kBaseStep + kBaseDot / 2 + iom['yShift']!;

        final px    = sampleBitmap(bm, srcX, row);
        final alpha = (px[3] / 255.0) * iom['alpha']!;
        final dotR  = kBaseDot * iom['scale']!;

        if (!flashVisible || alpha < 0.05) {
          _drawDot(canvas, cx, cy, dotR * 0.38, const Color(0xFF0F0F0F));
          continue;
        }

        final c = _resolveColor(px, null, col, scrollOffset);
        _renderDot(canvas, cx, cy, dotR, c, alpha);
      }
    }
  }

  // ── Color resolve ──────────────────────────────────────────────────────────
  Color _resolveColor(List<int> px, Color? force, int col, double off) {
    if (force != null) return force;
    if (rainbow) return hslToColor((col * 10 + off * 0.4) % 360, 1.0, 0.55);
    if (isGrayish(px[0], px[1], px[2])) return ledColor;
    return Color.fromARGB(255, px[0], px[1], px[2]);
  }

  // ── Render one LED dot ─────────────────────────────────────────────────────
  void _renderDot(Canvas canvas, double cx, double cy, double dotR, Color c, double alpha) {
    final bri = min(1.0, alpha * 1.3);

    if (dotR >= 5) {
      // Outer glow
      final glowR = dotR * 2.2;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            c.withValues(alpha: bri * 0.52),
            c.withValues(alpha: bri * 0.14),
            Colors.transparent,
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: glowR));
      canvas.drawCircle(Offset(cx, cy), glowR, paint);

      // Inner halo
      _drawDot(canvas, cx, cy, dotR * 0.68,
        c.withValues(alpha: bri * 0.36));
    } else {
      // Small dot — no glow, just a soft halo
      _drawDot(canvas, cx, cy, dotR * 0.80,
        c.withValues(alpha: bri * 0.55));
    }

    // Bright core
    _drawDot(canvas, cx, cy, dotR * 0.42, Color.fromARGB(
      255,
      min(255, c.red   + 100),
      min(255, c.green + 100),
      min(255, c.blue  + 100),
    ));
  }

  // ── Draw shaped dot ────────────────────────────────────────────────────────
  void _drawDot(Canvas canvas, double cx, double cy, double r, Color c) {
    final paint = Paint()..color = c;
    final shape = plusOn ? dotShape : 'circle';
    switch (shape) {
      case 'square':
        canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2), paint);
      case 'diamond':
        final path = Path()
          ..moveTo(cx, cy - r) ..lineTo(cx + r, cy)
          ..lineTo(cx, cy + r) ..lineTo(cx - r, cy) ..close();
        canvas.drawPath(path, paint);
      case 'rounded':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2),
            Radius.circular(r * 0.55),
          ), paint);
      default:
        canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  // ── In/Out modifier ────────────────────────────────────────────────────────
  Map<String, double> _getInOutMod(int srcX, int bmW) {
    final zone = max((bmW * zoneRatio).round(), 20);
    final tIn  = srcX < zone      ? max(0.0, srcX / zone)         : 1.0;
    final tOut = srcX > bmW - zone ? max(0.0, (bmW - srcX) / zone) : 1.0;
    final t    = min(tIn, tOut);
    final anim = srcX < bmW / 2 ? inAnim : outAnim;
    switch (anim) {
      case 'fade':
        return {'alpha': t, 'yShift': 0, 'scale': 1};
      case 'slide':
        return {'alpha': t, 'yShift': (srcX < bmW / 2 ? (1 - tIn) : -(1 - tOut)) * kDispH * 0.6, 'scale': 1};
      case 'zoom':
        return {'alpha': t, 'yShift': 0, 'scale': 0.1 + 0.9 * t};
      case 'typewriter':
        return {'alpha': srcX < bmW / 2 ? tIn : tOut, 'yShift': 0, 'scale': 1};
      case 'wipe':
        return {'alpha': t < 0.5 ? 0 : 1, 'yShift': 0, 'scale': 1};
      default:
        return {'alpha': 1, 'yShift': 0, 'scale': 1};
    }
  }

  @override
  bool shouldRepaint(LEDPainter old) => true;
}

// ── LEDDisplay widget ─────────────────────────────────────────────────────────
class LEDDisplay extends StatefulWidget {
  final String text;
  final Color ledColor;
  final bool rainbow;
  final double sizeRatio;
  final double speed;
  final bool flash;
  final double flashRate;
  final String effect;
  final double waveAmp;
  final double waveSpeed;
  final double waveFreq;
  final double pulseRate;
  final double rippleSpeed;
  final double rippleFreq;
  final double glitchInt;
  final String inAnim;
  final String outAnim;
  final double zoneRatio;
  final String dotShape;
  final bool plusOn;

  const LEDDisplay({
    super.key,
    required this.text,
    required this.ledColor,
    required this.rainbow,
    required this.sizeRatio,
    required this.speed,
    required this.flash,
    required this.flashRate,
    required this.effect,
    required this.waveAmp,
    required this.waveSpeed,
    required this.waveFreq,
    required this.pulseRate,
    required this.rippleSpeed,
    required this.rippleFreq,
    required this.glitchInt,
    required this.inAnim,
    required this.outAnim,
    required this.zoneRatio,
    required this.dotShape,
    required this.plusOn,
  });

  @override
  State<LEDDisplay> createState() => _LEDDisplayState();
}

class _LEDDisplayState extends State<LEDDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  LEDBitmap? _scrollBm;
  LEDBitmap? _fitBm;
  int    _fitCols = 0;
  double _fitStep = kBaseStep;
  double _fitDot  = kBaseDot;

  double _scrollOffset = 0;
  bool   _flashVis     = true;
  double _lastFlash    = 0;
  double _prevT        = 0;
  double _time         = 0;
  final  _glitchOff    = List<double>.filled(kRows, 0);
  double _glitchTimer  = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(days: 365))
      ..addListener(_tick)
      ..forward();
    _rebuildBitmaps();
  }

  @override
  void didUpdateWidget(LEDDisplay old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text ||
        old.sizeRatio != widget.sizeRatio ||
        old.effect != widget.effect) {
      _rebuildBitmaps();
    }
  }

  void _rebuildBitmaps() async {
    final cssW = context.size?.width ?? 320;
    _computeFitGrid(cssW);

    final sb = await buildScrollBitmap(widget.text, widget.sizeRatio);
    final fb = await buildFitBitmap(widget.text, widget.sizeRatio, _fitCols);
    if (mounted) setState(() { _scrollBm = sb; _fitBm = fb; });
  }

  void _computeFitGrid(double cssW) {
    final minFitStep = kMinFitDot / 0.78;
    final maxCols    = (cssW / minFitStep).floor();
    final glyphs     = widget.text.runes.length;
    final idealCols  = glyphs * kColsPerChar;
    _fitCols = min(idealCols, maxCols).clamp(10, 9999);
    _fitStep = cssW / _fitCols;
    _fitDot  = _fitStep * 0.78;
  }

  void _tick() {
    final now = (_ctrl.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
    final dt  = min(now - _prevT, 0.05);
    _prevT    = now;
    _time    += dt;

    final bm = _scrollBm;
    if (bm != null) {
      _scrollOffset = (_scrollOffset + widget.speed * dt) % (bm.w + (context.size?.width ?? 320));
    }

    // Flash
    if (widget.flash) {
      _lastFlash += dt;
      if (_lastFlash >= 1 / widget.flashRate) {
        _flashVis  = !_flashVis;
        _lastFlash -= 1 / widget.flashRate;
      }
    } else { _flashVis = true; _lastFlash = 0; }

    // Glitch tick
    if (widget.effect == 'glitch') {
      _glitchTimer += dt;
      for (int i = 0; i < kRows; i++) _glitchOff[i] *= 0.82;
      if (_glitchTimer > 0.04 + _time.remainder(0.1) * 0.8) {
        _glitchTimer = 0;
        if (DateTime.now().microsecondsSinceEpoch % 3 == 0) {
          final r = (DateTime.now().microsecondsSinceEpoch % kRows).toInt();
          _glitchOff[r] = ((_time * 1000) % 2 - 1) * widget.glitchInt * kBaseStep * 2.5;
        }
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      final w = constraints.maxWidth;
      if (_fitCols == 0 || (w / _fitStep).round() != _fitCols) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { _computeFitGrid(w); _rebuildBitmaps(); }
        });
      }

      final bounceShift = widget.effect == 'bounce'
          ? sin(_time * pi * 2 * 1.2) * 3.5 : 0.0;

      return SizedBox(
        width:  w,
        height: kDispH,
        child: CustomPaint(
          painter: LEDPainter(
            scrollBm:     _scrollBm,
            fitBm:        _fitBm,
            fitCols:      _fitCols,
            fitStep:      _fitStep,
            fitDot:       _fitDot,
            ledColor:     widget.ledColor,
            rainbow:      widget.rainbow,
            scrollOffset: _scrollOffset,
            flashVisible: _flashVis,
            effect:       widget.effect,
            time:         _time,
            waveAmp:      widget.waveAmp,
            waveSpeed:    widget.waveSpeed,
            waveFreq:     widget.waveFreq,
            pulseRate:    widget.pulseRate,
            rippleSpeed:  widget.rippleSpeed,
            rippleFreq:   widget.rippleFreq,
            glitchInt:    widget.glitchInt,
            glitchOffsets:_glitchOff,
            bounceShift:  bounceShift,
            inAnim:       widget.inAnim,
            outAnim:      widget.outAnim,
            zoneRatio:    widget.zoneRatio,
            dotShape:     widget.dotShape,
            plusOn:       widget.plusOn,
          ),
        ),
      );
    });
  }
}
