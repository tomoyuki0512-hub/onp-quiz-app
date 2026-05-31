import 'package:flutter/cupertino.dart';
import '../models/clef.dart';
import '../models/quiz_note.dart';

/// 五線・加線・音部記号・符頭を描画する CustomPainter。
///
/// 位置計算は diatonic degree を用い、1音度 = 半スペース（線間隔の半分）。
/// 音部記号と符頭は Bravura(SMuFL) のグリフをそのまま描画する。
class StaffPainter extends CustomPainter {
  final QuizNote note;
  final Color color;

  /// noteheadWhole(U+E0A2): ステム不要で初心者にも見やすい全音符の符頭。
  static const String _noteheadWhole = '\u{E0A2}';

  StaffPainter({required this.note, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // 線間隔。加線や音部記号の高さも考慮して画面に収まるよう決める。
    final double staffSpace = (size.height / 13).clamp(8.0, 22.0).toDouble();
    final centerX = size.width / 2;
    // 五線の中央線を画面の縦中央に置く。
    final midLineY = size.height / 2;
    // 中央線は最下線から degree +4（2スペース上）。
    final bottomLineY = midLineY + 2 * staffSpace;

    double yForDegree(int degree) =>
        bottomLineY - (degree - note.clef.bottomLineDegree) * (staffSpace / 2);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // 五線（下から0..4）
    final staffLeft = size.width * 0.10;
    final staffRight = size.width * 0.92;
    for (int k = 0; k < 5; k++) {
      final y = bottomLineY - k * staffSpace;
      canvas.drawLine(Offset(staffLeft, y), Offset(staffRight, y), linePaint);
    }

    // 音部記号（baseline = アンカー線に乗せる）
    final em = staffSpace * 4;
    final clefAnchorDegree =
        note.clef.bottomLineDegree + 2 * note.clef.anchorLineFromBottom;
    _drawGlyph(
      canvas,
      note.clef.glyph,
      em,
      staffLeft + staffSpace * 0.4,
      yForDegree(clefAnchorDegree),
    );

    // 加線（五線の外に出る音符のため）
    final topLineDegree = note.clef.bottomLineDegree + 8;
    final bottomLineDegree = note.clef.bottomLineDegree;
    final ledgerHalf = staffSpace * 0.9;
    if (note.degree > topLineDegree) {
      for (int d = topLineDegree + 2; d <= note.degree; d += 2) {
        final y = yForDegree(d);
        canvas.drawLine(Offset(centerX - ledgerHalf, y),
            Offset(centerX + ledgerHalf, y), linePaint);
      }
    } else if (note.degree < bottomLineDegree) {
      for (int d = bottomLineDegree - 2; d >= note.degree; d -= 2) {
        final y = yForDegree(d);
        canvas.drawLine(Offset(centerX - ledgerHalf, y),
            Offset(centerX + ledgerHalf, y), linePaint);
      }
    }

    // 符頭（baseline = 符頭の縦中心 = 音高位置）
    _drawGlyph(
      canvas,
      _noteheadWhole,
      em,
      centerX,
      yForDegree(note.degree),
      centerHorizontally: true,
    );
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
    final base = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic) ??
        tp.height;
    final x = centerHorizontally ? leftX - tp.width / 2 : leftX;
    tp.paint(canvas, Offset(x, baselineY - base));
  }

  @override
  bool shouldRepaint(covariant StaffPainter old) =>
      old.note != note || old.color != color;
}
