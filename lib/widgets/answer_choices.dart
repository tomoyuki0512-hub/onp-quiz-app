import 'package:flutter/cupertino.dart';

/// ド〜シ の7択ボタンで解答する入力UI。
class AnswerChoices extends StatelessWidget {
  /// 押された音名インデックス（0=ド..6=シ）を返す。
  final void Function(int letterIndex) onSelected;

  /// ユーザーが選んだ音名（未解答なら null）。
  final int? selectedLetter;

  /// 正解の音名（解答後に設定。null の間は未解答）。
  final int? correctLetter;

  const AnswerChoices({
    super.key,
    required this.onSelected,
    required this.selectedLetter,
    required this.correctLetter,
  });

  static const _solfege = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ'];

  @override
  Widget build(BuildContext context) {
    final answered = correctLetter != null;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < _solfege.length; i++)
          _buildButton(context, i, answered),
      ],
    );
  }

  Widget _buildButton(BuildContext context, int i, bool answered) {
    Color bg;
    Color fg;
    if (!answered) {
      bg = CupertinoColors.systemGrey6.resolveFrom(context);
      fg = CupertinoColors.label.resolveFrom(context);
    } else if (i == correctLetter) {
      bg = CupertinoColors.systemGreen;
      fg = CupertinoColors.white;
    } else if (i == selectedLetter) {
      bg = CupertinoColors.systemRed;
      fg = CupertinoColors.white;
    } else {
      bg = CupertinoColors.systemGrey6.resolveFrom(context);
      fg = CupertinoColors.secondaryLabel.resolveFrom(context);
    }

    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: answered ? null : () => onSelected(i),
      child: Container(
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _solfege[i],
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }
}
