import 'clef.dart';

/// 出題される1つの音符。
///
/// 音名・MIDI番号・五線上の位置はすべて [letterIndex]（C=0..B=6）と
/// [octave] から導出するため、データ入力時の不整合が起きない。
class QuizNote {
  /// どの音部記号で表示するか。
  final Clef clef;

  /// 音名のインデックス。0=C(ド) .. 6=B(シ)。
  final int letterIndex;

  /// オクターブ（中央ド C4 の octave は 4）。
  final int octave;

  const QuizNote({
    required this.clef,
    required this.letterIndex,
    required this.octave,
  });

  static const _solfege = ['ド', 'レ', 'ミ', 'ファ', 'ソ', 'ラ', 'シ'];
  static const _names = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  // C メジャー各音の、C からの半音数。
  static const _semitone = [0, 2, 4, 5, 7, 9, 11];

  /// ソルフェージュ表記（ド・レ・ミ…）。
  String get solfege => _solfege[letterIndex];

  /// 英語音名（C・D・E…）。
  String get alphabet => _names[letterIndex];

  /// 五線上の縦位置計算に使う diatonic degree（半音ではなく音度）。
  int get degree => octave * 7 + letterIndex;

  /// MIDIノート番号（A4=69, 中央ド C4=60）。音の再生に使う。
  int get midi => 12 * (octave + 1) + _semitone[letterIndex];

  /// [letterIndex] が一致していれば正解（オクターブ違いの同音名も正解扱い）。
  bool matches(int answerLetterIndex) => answerLetterIndex == letterIndex;
}
