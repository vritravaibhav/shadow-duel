import 'dart:math' as math;
import 'dart:ui';

/// What a finger stroke on the right half of the screen meant.
enum GestureKind { tap, swipeUp, swipeDown, swipeLeft, swipeRight, glyphV, glyphW }

class GestureResult {
  const GestureResult(this.kind, this.points, this.corners);
  final GestureKind kind;

  /// The stroke resampled to evenly spaced points.
  final List<Offset> points;

  /// Indices into [points] where the stroke turned sharply.
  final List<int> corners;
}

/// Turns raw stroke points into a tap, a directional swipe, or a drawn glyph.
///
/// Glyphs are recognised by their sharp corners: a **V** is one corner with
/// the vertex below both ends; a **W** is three corners alternating
/// low-high-low, drawn with steady horizontal progress.
class GestureRecognizer {
  static const tapLength = 28.0;
  static const samples = 32;
  static const cornerDeg = 58.0;

  static GestureResult recognize(List<Offset> raw) {
    final pts = _dedupe(raw);
    final length = _pathLength(pts);
    if (pts.length < 2 || length < tapLength) {
      return GestureResult(GestureKind.tap, pts, const []);
    }
    final p = _resample(pts, samples);
    final corners = _corners(p);
    final d = p.last - p.first;
    final xs = p.map((o) => o.dx);
    final ys = p.map((o) => o.dy);
    final w = xs.reduce(math.max) - xs.reduce(math.min);
    final h = ys.reduce(math.max) - ys.reduce(math.min);

    final glyph = _glyph(p, w, h);
    if (glyph != null) return GestureResult(glyph, p, corners);
    // Anything else is a directional swipe along its dominant axis.
    if (d.dy.abs() > d.dx.abs()) {
      return GestureResult(d.dy < 0 ? GestureKind.swipeUp : GestureKind.swipeDown, p, corners);
    }
    return GestureResult(d.dx < 0 ? GestureKind.swipeLeft : GestureKind.swipeRight, p, corners);
  }

  /// V / W from the stroke's height profile: a V is one deep trough between
  /// two high ends; a W is trough–peak–trough. Works for rounded, sloppy or
  /// fast glyphs because it never needs a sharp corner.
  static GestureKind? _glyph(List<Offset> p, double w, double h) {
    if (h < 24 || w < 24) return null;
    // Steady horizontal progress in one direction.
    var forward = 0, backward = 0;
    for (var i = 1; i < p.length; i++) {
      final dx = p[i].dx - p[i - 1].dx;
      if (dx > 0.5) forward++;
      if (dx < -0.5) backward++;
    }
    if (math.max(forward, backward) < (p.length - 1) * 0.6) return null;

    // Smoothed height profile and its prominent extrema (y grows downward).
    final n = p.length;
    final ys = List<double>.generate(n, (i) {
      var sum = 0.0;
      var cnt = 0;
      for (var j = math.max(0, i - 1); j <= math.min(n - 1, i + 1); j++) {
        sum += p[j].dy;
        cnt++;
      }
      return sum / cnt;
    });
    final ext = <(int, bool)>[]; // (index, isTrough)
    for (var i = 2; i < n - 2; i++) {
      final trough = ys[i] >= ys[i - 1] && ys[i] >= ys[i + 1] && ys[i] > ys[i - 2] && ys[i] > ys[i + 2];
      final peak = ys[i] <= ys[i - 1] && ys[i] <= ys[i + 1] && ys[i] < ys[i - 2] && ys[i] < ys[i + 2];
      if (trough || peak) ext.add((i, trough));
    }
    // Keep only extrema that stand out by a fraction of the glyph height.
    final minProm = h * 0.22;
    final kept = <(int, bool)>[];
    for (final (i, isTrough) in ext) {
      final lo = kept.isEmpty ? 0 : kept.last.$1;
      var promL = 0.0, promR = 0.0;
      for (var j = lo; j < i; j++) {
        promL = math.max(promL, (ys[i] - ys[j]).abs());
      }
      for (var j = i + 1; j < n; j++) {
        promR = math.max(promR, (ys[i] - ys[j]).abs());
      }
      if (math.min(promL, promR) < minProm) continue;
      if (kept.isNotEmpty && kept.last.$2 == isTrough) {
        // Same kind twice: keep the more extreme one.
        final last = kept.last.$1;
        final better = isTrough ? ys[i] > ys[last] : ys[i] < ys[last];
        if (better) kept[kept.length - 1] = (i, isTrough);
        continue;
      }
      kept.add((i, isTrough));
    }
    final ends = math.max(ys.first, ys.last);
    final bottom = ys.reduce(math.max);
    if (kept.length == 1 && kept[0].$2) {
      final i = kept[0].$1;
      final a = p.first, b = p.last, v = p[i];
      final legA = (v - a).distance, legB = (b - v).distance;
      final vertexIsLowest = ys[i] >= bottom - h * 0.15;
      final endsHigh = math.min(v.dy - a.dy, v.dy - b.dy) > h * 0.45;
      if (vertexIsLowest && endsHigh && legA > 20 && legB > 20 &&
          math.min(legA, legB) / math.max(legA, legB) > 0.3) {
        return GestureKind.glyphV;
      }
    }
    if (kept.length == 3 && kept[0].$2 && !kept[1].$2 && kept[2].$2) {
      final t1 = ys[kept[0].$1], pk = ys[kept[1].$1], t2 = ys[kept[2].$1];
      final troughsLow = t1 > ends + h * 0.25 && t2 > ends + h * 0.25;
      final peakUp = pk < math.min(t1, t2) - h * 0.2;
      if (troughsLow && peakUp && w > 40) return GestureKind.glyphW;
    }
    return null;
  }

  static List<Offset> _dedupe(List<Offset> raw) {
    final out = <Offset>[];
    for (final o in raw) {
      if (out.isEmpty || (o - out.last).distance > 0.5) out.add(o);
    }
    return out;
  }

  static double _pathLength(List<Offset> p) {
    var l = 0.0;
    for (var i = 1; i < p.length; i++) {
      l += (p[i] - p[i - 1]).distance;
    }
    return l;
  }

  static List<Offset> _resample(List<Offset> p, int n) {
    final total = _pathLength(p);
    final step = total / (n - 1);
    final out = <Offset>[p.first];
    var acc = 0.0;
    var i = 1;
    var prev = p.first;
    while (i < p.length && out.length < n) {
      final seg = (p[i] - prev).distance;
      if (acc + seg >= step) {
        final t = (step - acc) / seg;
        final q = prev + (p[i] - prev) * t;
        out.add(q);
        prev = q;
        acc = 0;
      } else {
        acc += seg;
        prev = p[i];
        i++;
      }
    }
    while (out.length < n) {
      out.add(p.last);
    }
    return out;
  }

  /// Sharp turns, found from the angle between the incoming and outgoing
  /// directions over a two-sample window, keeping only local maxima.
  static List<int> _corners(List<Offset> p) {
    const k = 2;
    final angles = List<double>.filled(p.length, 0);
    for (var i = k; i < p.length - k; i++) {
      final a = p[i] - p[i - k];
      final b = p[i + k] - p[i];
      if (a.distance < 1e-3 || b.distance < 1e-3) continue;
      final cos = (a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance);
      angles[i] = math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi;
    }
    final out = <int>[];
    for (var i = k; i < p.length - k; i++) {
      if (angles[i] < cornerDeg) continue;
      var isMax = true;
      for (var j = math.max(0, i - 3); j <= math.min(p.length - 1, i + 3); j++) {
        if (j != i && angles[j] > angles[i]) isMax = false;
      }
      if (isMax && (out.isEmpty || i - out.last > 3)) out.add(i);
    }
    return out;
  }
}
