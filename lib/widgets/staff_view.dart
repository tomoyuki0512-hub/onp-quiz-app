import 'package:flutter/cupertino.dart';
import '../models/quiz_note.dart';
import 'grand_staff_painter.dart';
import 'staff_painter.dart';

/// 五線譜に1つの音符を表示するカード。
/// [grandStaff] が true のときはト音＋ヘ音の大譜表で描画する。
class StaffView extends StatelessWidget {
  final QuizNote note;
  final bool grandStaff;

  const StaffView({super.key, required this.note, this.grandStaff = false});

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.label.resolveFrom(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: SizedBox(
        height: grandStaff ? 300 : 240,
        width: double.infinity,
        child: CustomPaint(
          painter: grandStaff
              ? GrandStaffPainter(note: note, color: color)
              : StaffPainter(note: note, color: color),
        ),
      ),
    );
  }
}
