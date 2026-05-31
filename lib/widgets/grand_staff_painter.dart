import 'package:flutter/cupertino.dart';
import '../models/clef.dart';
import '../models/quiz_note.dart';

/// 大譜表（ト音＋ヘ音を1段に同時表示）に1音を描く CustomPainter。
///
/// 大譜表は中央ド(degree=28)を境に上下対称で、treble/bass を通して
/// degree 軸が連続する。よって単一の `yFor(degree)` で全要素を配置できる。
///   - ト音の線: degree 30,32,34,36,38（E4..F5）
///   - ヘ音の線: degree 18,20,22,24,26（G2..A3）
///   - 中央ド(28)は両譜表の中間に浮く加線
class GrandStaffPainter extends CustomPainter {
  final QuizNote note;
  final Color color;

  static const String _noteheadWhole = '\u{E0A2}';
  static const List<int> _trebleLines = [30, 32, 34, 36, 38];
  static const List<int> _bassLines = [18, 20, 22, 24, 26];

  GrandStaffPainter({required this.note, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double staffSpace = (size.height / 17).clamp(8.0, 18.0).toDouble();
    final centerY = size.height / 2; // 中央ド(28)を縦中央に置く
    double yFor(int degree) => centerY - (degree - 28) * (staffSpace / 2);

    final staffLeft = size.width * 0.14;
    final staffRight = size.width * 0.92;
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 五線（上下段）
    for (final d in [..._trebleLines, ..._bassLines]) {
      final y = yFor(d);
      canvas.drawLine(Offset(staffLeft, y), Offset(staffRight, y), linePaint);
    }

    // 左端の連結線（簡易ブレース）
    canvas.drawLine(
      Offset(staffLeft - staffSpace * 0.5, yFor(38)),
      Offset(staffLeft - staffSpace * 0.5, yFor(18)),
      Paint()
        ..color = color
        ..strokeWidth = 2.4,
    );

    // 音部記号（baseline = アンカー線）
    final em = staffSpace * 4;
    _drawGlyph(canvas, Clef.treble.glyph, em, staffLeft + staffSpace * 0.3,
        yFor(32)); // G4
    _drawGlyph(canvas, Clef.bass.glyph, em, staffLeft + staffSpace * 0.3,
        yFor(24)); // F3

    // 加線
    final centerX = size.width / 2;
    final half = staffSpace * 0.9;
    void ledger(int d) {
      final y = yFor(d);
      canvas.drawLine(
          Offset(centerX - half, y), Offset(centerX + half, y), linePaint);
    }

    final d = note.degree;
    if (d == 28) {
      ledger(28); // 中央ド
    } else if (d > 38) {
      for (int x = 40; x <= d; x += 2) {
        ledger(x);
      }
    } else if (d < 18) {
      for (int x = 16; x >= d; x -= 2) {
        ledger(x);
      }
    }

    // 符頭
    _drawGlyph(canvas, _noteheadWhole, em, centerX, yFor(d),
        centerHorizontally: true);
  }

  /// SMuFL グリフを、その alphabetic baseline が [baselineY] に来るように描画する。
  void _drawGlyph(
    Canvas canvas,
    String glyph,
    double em,
    double leftX,
    double baselineY, {
    bool centerHorizontally = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(fontFamily: 'Bravura', fontSize: em, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final base =
        tp.computeDistanceToActualBaseline(TextBaseline.alphabetic) ?? tp.height;
    final x = centerHorizontally ? leftX - tp.width / 2 : leftX;
    tp.paint(canvas, Offset(x, baselineY - base));
  }

  @override
  bool shouldRepaint(covariant GrandStaffPainter old) =>
      old.note != note || old.color != color;
}
