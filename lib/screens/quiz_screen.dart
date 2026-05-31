import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../data/level1.dart';
import '../models/quiz_note.dart';
import '../services/tone_player.dart';
import '../widgets/answer_choices.dart';
import '../widgets/answer_piano.dart';
import '../widgets/staff_view.dart';

/// 解答方法のモード。
enum AnswerMode { buttons, piano }

class QuizScreen extends StatefulWidget {
  /// 1セッションの出題数。
  final int questionCount;

  const QuizScreen({super.key, this.questionCount = 10});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TonePlayer _tone = TonePlayer();
  late List<QuizNote> _questions;

  int _index = 0;
  int _score = 0;
  int? _selectedLetter;
  bool _answered = false;
  bool _finished = false;
  AnswerMode _mode = AnswerMode.buttons;

  @override
  void initState() {
    super.initState();
    _questions = _buildQuestions();
  }

  @override
  void dispose() {
    _tone.dispose();
    super.dispose();
  }

  List<QuizNote> _buildQuestions() {
    final pool = [...level1Notes]..shuffle(Random());
    final count = min(widget.questionCount, pool.length);
    return pool.take(count).toList();
  }

  QuizNote get _current => _questions[_index];

  void _answer(int letterIndex) {
    if (_answered) return;
    final correct = _current.matches(letterIndex);
    setState(() {
      _selectedLetter = letterIndex;
      _answered = true;
      if (correct) _score++;
    });
    // 出題された音の高さを鳴らす。
    _tone.playMidi(_current.midi);
  }

  void _next() {
    if (_index + 1 >= _questions.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selectedLetter = null;
      _answered = false;
    });
  }

  void _restart() {
    setState(() {
      _questions = _buildQuestions();
      _index = 0;
      _score = 0;
      _selectedLetter = null;
      _answered = false;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_finished ? '結果' : '${_index + 1} / ${_questions.length}'),
        trailing: _finished
            ? null
            : Text('$_score問正解',
                style: const TextStyle(
                    fontSize: 14, color: CupertinoColors.secondaryLabel)),
      ),
      child: SafeArea(
        child: _finished ? _buildResult() : _buildQuiz(),
      ),
    );
  }

  // ---- クイズ本体 ----

  Widget _buildQuiz() {
    final correctLetter = _answered ? _current.letterIndex : null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  _current.clef.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                StaffView(note: _current),
                const SizedBox(height: 12),
                _buildFeedback(),
              ],
            ),
          ),
        ),
        _buildBottomControls(correctLetter),
      ],
    );
  }

  Widget _buildFeedback() {
    if (!_answered) {
      return const Text(
        'この音符の音名は？',
        style: TextStyle(fontSize: 16, color: CupertinoColors.secondaryLabel),
      );
    }
    final correct = _current.matches(_selectedLetter!);
    return Column(
      children: [
        Text(
          correct ? '⭕️ 正解！' : '❌ ざんねん',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: correct ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '正解: ${_current.solfege}（${_current.alphabet}）',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildBottomControls(int? correctLetter) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: CupertinoColors.systemBackground,
        border: Border(
          top: BorderSide(color: CupertinoColors.separator, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 解答方法のワンタッチ切替
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<AnswerMode>(
              groupValue: _mode,
              onValueChanged: (m) {
                if (m != null) setState(() => _mode = m);
              },
              children: const {
                AnswerMode.buttons: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('ボタン'),
                ),
                AnswerMode.piano: Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text('ピアノ'),
                ),
              },
            ),
          ),
          const SizedBox(height: 14),
          _mode == AnswerMode.buttons
              ? AnswerChoices(
                  onSelected: _answer,
                  selectedLetter: _selectedLetter,
                  correctLetter: correctLetter,
                )
              : AnswerPiano(
                  onSelected: _answer,
                  selectedLetter: _selectedLetter,
                  correctLetter: correctLetter,
                ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _answered ? _next : null,
              borderRadius: BorderRadius.circular(12),
              child: Text(
                _index + 1 >= _questions.length ? '結果を見る' : '次の問題',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- 結果画面 ----

  Widget _buildResult() {
    final total = _questions.length;
    final allCorrect = _score == total;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            allCorrect ? '🎉' : '🎵',
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            '$total問中 $_score問 正解',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            allCorrect ? 'すばらしい！全問正解です。' : 'くりかえして音符に慣れよう。',
            style: const TextStyle(
                fontSize: 15, color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: _restart,
              borderRadius: BorderRadius.circular(12),
              child: const Text('もう一度'),
            ),
          ),
          const SizedBox(height: 12),
          CupertinoButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ホームへ'),
          ),
        ],
      ),
    );
  }
}
