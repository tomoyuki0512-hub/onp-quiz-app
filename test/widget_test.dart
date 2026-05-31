import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_deleter/main.dart';
import 'package:photo_deleter/models/clef.dart';
import 'package:photo_deleter/models/quiz_note.dart';
import 'package:photo_deleter/data/level1.dart';

void main() {
  testWidgets('ホーム画面にタイトルが表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const MusicQuizApp());
    await tester.pumpAndSettle();

    expect(find.text('音符あてクイズ'), findsOneWidget);
    expect(find.text('はじめる'), findsOneWidget);
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
}
