import 'package:flutter/cupertino.dart';

/// 1オクターブ（ド〜ド）のピアノ鍵盤で解答する入力UI。
///
/// 白鍵をタップすると対応する音名インデックス（0=ド..6=シ）を返す。
/// 黒鍵はレベル1では使わないため、見た目のみの装飾（タップ不可）。
class AnswerPiano extends StatelessWidget {
  final void Function(int letterIndex) onSelected;
  final int? selectedLetter;
  final int? correctLetter;

  const AnswerPiano({
    super.key,
    required this.onSelected,
    required this.selectedLetter,
    required this.correctLetter,
  });

  // ド〜上のド（C D E F G A B C）の8白鍵。値は音名インデックス。
  static const _whiteLetters = [0, 1, 2, 3, 4, 5, 6, 0];
  static const _whiteSolfege = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ', 'ド'];
  // 黒鍵を「白鍵 index と index+1 の境界上」に置く位置。
  static const _blackAfterWhite = [0, 1, 3, 4, 5];

  @override
  Widget build(BuildContext context) {
    final answered = correctLetter != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final whiteWidth = totalWidth / _whiteLetters.length;
        const height = 150.0;
        final blackWidth = whiteWidth * 0.62;
        final blackHeight = height * 0.6;

        return SizedBox(
          height: height,
          width: totalWidth,
          child: Stack(
            children: [
              // 白鍵
              Row(
                children: [
                  for (int j = 0; j < _whiteLetters.length; j++)
                    SizedBox(
                      width: whiteWidth,
                      height: height,
                      child: _whiteKey(context, j, answered),
                    ),
                ],
              ),
              // 黒鍵（装飾）
              for (final i in _blackAfterWhite)
                Positioned(
                  left: (i + 1) * whiteWidth - blackWidth / 2,
                  top: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: blackWidth,
                      height: blackHeight,
                      decoration: BoxDecoration(
                        color: CupertinoColors.black,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _whiteKey(BuildContext context, int j, bool answered) {
    final letter = _whiteLetters[j];
    Color bg = CupertinoColors.white;
    if (answered) {
      if (letter == correctLetter) {
        bg = CupertinoColors.systemGreen;
      } else if (letter == selectedLetter) {
        bg = CupertinoColors.systemRed;
      }
    }
    final highlighted = answered &&
        (letter == correctLetter || letter == selectedLetter);

    return GestureDetector(
      onTap: answered ? null : () => onSelected(letter),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: CupertinoColors.systemGrey3),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _whiteSolfege[j],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: highlighted
                    ? CupertinoColors.white
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
