import '../models/clef.dart';
import '../models/level.dart';
import '../models/quiz_note.dart';
import 'level1.dart';

/// 指定 clef・degree 範囲 [fromDegree, toDegree]（両端含む）の自然音を
/// 低音→高音の順で生成する。
///
/// degree = octave*7 + letterIndex（C=0..B=6）なので、整数 degree は
/// ちょうど1つの自然音（白鍵）に対応する。
List<QuizNote> notesInRange(Clef clef, int fromDegree, int toDegree) {
  return [
    for (int d = fromDegree; d <= toDegree; d++)
      QuizNote(clef: clef, letterIndex: d % 7, octave: d ~/ 7),
  ];
}

// 五線の基準 degree（C=0基準）。
//   ト音: 最下線 E4=30 / 最上線 F5=38
//   ヘ音: 最下線 G2=18 / 最上線 A3=26

/// レベル1: 中央ド基準の1オクターブ（実装済みプールを再利用）。
final Level level1 = Level(
  id: 1,
  title: 'レベル1',
  concept: '中央ド基準の1オクターブ',
  description: 'ト音記号（中央ド〜上のド）とヘ音記号（下のド〜中央ド）',
  pool: level1Notes,
);

/// レベル2: 五線をフルに読む（加線なし）。
final Level level2 = Level(
  id: 2,
  title: 'レベル2',
  concept: '五線をフルに読む',
  description: '加線なし。ト音 ミ〜ファ／ヘ音 ソ〜ラ の五線上の音',
  pool: [
    ...notesInRange(Clef.treble, 30, 38), // E4..F5
    ...notesInRange(Clef.bass, 18, 26), // G2..A3
  ],
);

/// レベル3: 少しの加線（上下1本まで）。
final Level level3 = Level(
  id: 3,
  title: 'レベル3',
  concept: '少しの加線',
  description: '上下1本の加線まで。ト音 中央ド〜上のラ／ヘ音 下のミ〜中央ド',
  pool: [
    ...notesInRange(Clef.treble, 28, 40), // C4..A5
    ...notesInRange(Clef.bass, 16, 28), // E2..C4
  ],
);

/// レベル4: 大譜表（中央ドの橋渡し）。
/// 中央ド(28)を境にヘ音/ト音へ振り分ける（大譜表では位置=degreeで描画するため
/// clef は表示上の所属の目安）。
final Level level4 = Level(
  id: 4,
  title: 'レベル4',
  concept: '大譜表（中央ドの橋渡し）',
  description: 'ト音とヘ音を同時に表示。中央ド周辺のつながりを読む',
  pool: [
    for (int d = 16; d <= 40; d++)
      QuizNote(
        clef: d >= 28 ? Clef.treble : Clef.bass,
        letterIndex: d % 7,
        octave: d ~/ 7,
      ),
  ],
  grandStaff: true,
);

/// レベル5: タイムアタック総合（レベル1〜3の全範囲を単一譜表で）。
/// level3 のプールが treble 28..40 + bass 16..28 を網羅しているため再利用する。
final Level level5 = Level(
  id: 5,
  title: 'レベル5',
  concept: 'タイムアタック総合',
  description: 'レベル1〜4の全範囲をランダム。制限時間内に何問解ける？',
  pool: level3.pool,
  timeLimit: const Duration(seconds: 60),
);

/// 全レベル（推奨学習順）。
final List<Level> levels = [level1, level2, level3, level4, level5];
