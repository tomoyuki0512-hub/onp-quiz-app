import '../models/clef.dart';
import '../models/quiz_note.dart';

/// 「ド」から1オクターブ上の「ド」まで（C..B + 次のC）の8音を作る。
List<QuizNote> _octaveFrom(Clef clef, int startOctave) => [
      for (int i = 0; i < 7; i++)
        QuizNote(clef: clef, letterIndex: i, octave: startOctave),
      // 1オクターブ上のド
      QuizNote(clef: clef, letterIndex: 0, octave: startOctave + 1),
    ];

/// レベル1・ト音記号: 中央ド(C4) 〜 上のド(C5)。
final List<QuizNote> level1TrebleNotes = _octaveFrom(Clef.treble, 4);

/// レベル1・ヘ音記号: 下のド(C3) 〜 中央ド(C4)。
final List<QuizNote> level1BassNotes = _octaveFrom(Clef.bass, 3);

/// レベル1の全出題プール（ト音記号＋ヘ音記号）。
final List<QuizNote> level1Notes = [...level1TrebleNotes, ...level1BassNotes];
