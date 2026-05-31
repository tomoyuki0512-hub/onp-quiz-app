import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import '../models/level.dart';
import '../models/quiz_note.dart';
import '../services/tone_player.dart';
import '../widgets/answer_choices.dart';
import '../widgets/answer_piano.dart';
import '../widgets/staff_view.dart';

/// 解答方法のモード。
enum AnswerMode { buttons, piano }

class QuizScreen extends StatefulWidget {
  final Level level;

  const QuizScreen({super.key, required this.level});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TonePlayer _tone = TonePlayer();
  final Random _rng = Random();

  List<QuizNote> _buffer = [];
  late QuizNote _current;

  int _qNo = 1; // 何問目（固定モードの表示用）
  int _attempted = 0; // 解答した数
  int _score = 0;
  int? _selectedLetter;
  bool _answered = false;
  bool _finished = false;
  AnswerMode _mode = AnswerMode.buttons;

  Timer? _timer;
  int _remainingSec = 0;

  bool get _timed => widget.level.isTimed;

  @override
  void initState() {
    super.initState();
    _current = _drawNote();
    if (_timed) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tone.dispose();
    super.dispose();
  }

  void _startTimer() {
    _remainingSec = widget.level.timeLimit!.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remainingSec--;
        if (_remainingSec <= 0) {
          _remainingSec = 0;
          t.cancel();
          _finished = true;
        }
      });
    });
  }

  /// シャッフル済みバッファから1音取り出す。空なら補充する。
  QuizNote _drawNote() {
    if (_buffer.isEmpty) {
      _buffer = [...widget.level.pool]..shuffle(_rng);
    }
    return _buffer.removeLast();
  }

  void _answer(int letterIndex) {
    if (_answered || _finished) return;
    final correct = _current.matches(letterIndex);
    setState(() {
      _selectedLetter = letterIndex;
      _answered = true;
      _attempted++;
      if (correct) _score++;
    });
    // 出題された音の高さを鳴らす。
    _tone.playMidi(_current.midi);
  }

  void _next() {
    if (!_timed && _qNo >= widget.level.questionCount) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _current = _drawNote();
      _qNo++;
      _selectedLetter = null;
      _answered = false;
    });
  }

  void _restart() {
    _timer?.cancel();
    setState(() {
      _buffer = [];
      _current = _drawNote();
      _qNo = 1;
      _attempted = 0;
      _score = 0;
      _selectedLetter = null;
      _answered = false;
      _finished = false;
    });
    if (_timed) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(_navTitle()),
        trailing: _finished
            ? null
            : Text('$_score正解',
                style: const TextStyle(
                    fontSize: 14, color: CupertinoColors.secondaryLabel)),
      ),
      child: SafeArea(
        child: _finished ? _buildResult() : _buildQuiz(),
      ),
    );
  }

  String _navTitle() {
    if (_finished) return '結果';
    if (_timed) return '残り $_remainingSec秒';
    return '$_qNo / ${widget.level.questionCount}';
  }

  // ---- クイズ本体 ----

  Widget _buildQuiz() {
    final correctLetter = _answered ? _current.letterIndex : null;
    final caption =
        widget.level.grandStaff ? '大譜表' : _current.clef.label;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.secondaryLabel,
                  ),
                ),
                const SizedBox(height: 8),
                StaffView(note: _current, grandStaff: widget.level.grandStaff),
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
            color:
                correct ? CupertinoColors.systemGreen : CupertinoColors.systemRed,
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
    final isLastFixed = !_timed && _qNo >= widget.level.questionCount;
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
                isLastFixed ? '結果を見る' : '次の問題',
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
    final total = _timed ? _attempted : widget.level.questionCount;
    final allCorrect = total > 0 && _score == total;
    final subtitle = _timed
        ? '制限時間 ${widget.level.timeLimit!.inSeconds}秒'
        : (allCorrect ? 'すばらしい！全問正解です。' : 'くりかえして音符に慣れよう。');

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(allCorrect ? '🎉' : '🎵', style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            '$total問中 $_score問 正解',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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
