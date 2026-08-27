
import 'package:flutter_test/flutter_test.dart';
import 'package:shadow_duel/game/gestures.dart';

List<Offset> line(Offset a, Offset b, [int n = 12]) =>
    [for (var i = 0; i <= n; i++) a + (b - a) * (i / n)];

List<Offset> poly(List<Offset> vertices) {
  final out = <Offset>[];
  for (var i = 0; i < vertices.length - 1; i++) {
    out.addAll(line(vertices[i], vertices[i + 1]));
  }
  return out;
}

void main() {
  test('tap and swipes', () {
    expect(GestureRecognizer.recognize([const Offset(10, 10), const Offset(14, 12)]).kind, GestureKind.tap);
    expect(GestureRecognizer.recognize(line(const Offset(0, 100), const Offset(0, 0))).kind, GestureKind.swipeUp);
    expect(GestureRecognizer.recognize(line(const Offset(0, 0), const Offset(0, 120))).kind, GestureKind.swipeDown);
    expect(GestureRecognizer.recognize(line(const Offset(0, 0), const Offset(150, 10))).kind, GestureKind.swipeRight);
    expect(GestureRecognizer.recognize(line(const Offset(150, 0), const Offset(0, 8))).kind, GestureKind.swipeLeft);
  });

  test('V glyph', () {
    final v = poly([const Offset(0, 0), const Offset(60, 110), const Offset(120, 0)]);
    expect(GestureRecognizer.recognize(v).kind, GestureKind.glyphV);
    // Drawn right-to-left, slightly uneven legs, still a V.
    final v2 = poly([const Offset(130, 10), const Offset(50, 100), const Offset(0, 20)]);
    expect(GestureRecognizer.recognize(v2).kind, GestureKind.glyphV);
    // An inverted V (^) is not a V.
    final caret = poly([const Offset(0, 100), const Offset(60, 0), const Offset(120, 100)]);
    expect(GestureRecognizer.recognize(caret).kind, isNot(GestureKind.glyphV));
  });

  test('W glyph', () {
    final w = poly([
      const Offset(0, 0), const Offset(40, 110), const Offset(80, 30),
      const Offset(120, 110), const Offset(160, 0),
    ]);
    expect(GestureRecognizer.recognize(w).kind, GestureKind.glyphW);
    // A zigzag with two corners is a plain swipe, not a W.
    final z = poly([const Offset(0, 0), const Offset(120, 0), const Offset(0, 100), const Offset(120, 100)]);
    expect(GestureRecognizer.recognize(z).kind, isNot(GestureKind.glyphW));
  });
}
