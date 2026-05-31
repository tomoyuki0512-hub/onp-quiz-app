import 'package:flutter/cupertino.dart';
import '../models/quiz_note.dart';
import 'staff_painter.dart';

/// 五線譜に1つの音符を表示するカード。
class StaffView extends StatelessWidget {
  final QuizNote note;

  const StaffView({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
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
        height: 240,
        width: double.infinity,
        child: CustomPaint(
          painter: StaffPainter(
            note: note,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}
