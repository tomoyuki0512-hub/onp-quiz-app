import 'package:flutter_test/flutter_test.dart';
import 'package:photo_deleter/main.dart';
import 'package:photo_deleter/models/clef.dart';
import 'package:photo_deleter/models/quiz_note.dart';
import 'package:photo_deleter/data/level1.dart';
import 'package:photo_deleter/data/levels.dart';

void main() {
  testWidgets('ホーム画面にレベル一覧が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicQuizApp());
    await tester.pumpAndSettle();

    expect(find.text('音符あてクイズ'), findsOneWidget);
    expect(find.text('レベル1'), findsOneWidget);
    expect(find.text('レベル5'), findsOneWidget);
  });

  group('QuizNote の導出値', () {
    test('中央ド C4', () {
      const c4 = QuizNote(clef: Clef.treble, letterIndex: 0, octave: 4);
      expect(c4.solfege, 'ド');
      expect(c4.alphabet, 'C');
      expect(c4.midi, 60);
      expect(c4.degree, 28);
    });

    test('A4 = MIDI 69', () {
      const a4 = QuizNote(clef: Clef.treble, letterIndex: 5, octave: 4);
      expect(a4.midi, 69);
      expect(a4.solfege, 'ラ');
    });

    test('音名一致で正解判定（オクターブ違いの同音名も正解）', () {
      const c5 = QuizNote(clef: Clef.treble, letterIndex: 0, octave: 5);
      expect(c5.matches(0), isTrue); // ド
      expect(c5.matches(1), isFalse); // レ
    });
  });

  group('レベル1の出題プール', () {
    test('ト音記号は C4〜C5 の8音', () {
      expect(level1TrebleNotes.length, 8);
      expect(level1TrebleNotes.first.midi, 60); // C4
      expect(level1TrebleNotes.last.midi, 72); // C5
      expect(level1TrebleNotes.every((n) => n.clef == Clef.treble), isTrue);
    });

    test('ヘ音記号は C3〜C4 の8音', () {
      expect(level1BassNotes.length, 8);
      expect(level1BassNotes.first.midi, 48); // C3
      expect(level1BassNotes.last.midi, 60); // C4(中央ド)
      expect(level1BassNotes.every((n) => n.clef == Clef.bass), isTrue);
    });

    test('全体は16音', () {
      expect(level1Notes.length, 16);
    });
  });

  group('notesInRange', () {
    test('両端を含み、自然音を degree 昇順で生成する', () {
      final notes = notesInRange(Clef.treble, 30, 38); // E4..F5
      expect(notes.length, 9);
      expect(notes.first.midi, 64); // E4
      expect(notes.last.midi, 77); // F5
      expect(notes.every((n) => n.clef == Clef.treble), isTrue);
      // degree が単調増加
      for (int i = 1; i < notes.length; i++) {
        expect(notes[i].degree, greaterThan(notes[i - 1].degree));
      }
    });
  });

  group('レベル2〜5の構成', () {
    test('レベル2: 五線フル（加線なし）', () {
      expect(level2.pool.length, 18); // 9 + 9
      expect(level2.grandStaff, isFalse);
      expect(level2.isTimed, isFalse);
    });

    test('レベル3: 少しの加線（中央ドを含む）', () {
      expect(level3.pool.length, 26); // 13 + 13
      // 中央ド(C4, midi60)が含まれる
      expect(level3.pool.any((n) => n.midi == 60), isTrue);
    });

    test('レベル4: 大譜表', () {
      expect(level4.grandStaff, isTrue);
      expect(level4.pool.length, 25); // degree 16..40
    });

    test('レベル5: タイムアタック', () {
      expect(level5.isTimed, isTrue);
      expect(level5.timeLimit, const Duration(seconds: 60));
    });

    test('全5レベルが推奨順に並ぶ', () {
      expect(levels.length, 5);
      expect(levels.map((l) => l.id), [1, 2, 3, 4, 5]);
    });
  });
}
