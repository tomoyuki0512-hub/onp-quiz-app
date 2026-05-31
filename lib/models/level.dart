import 'quiz_note.dart';

/// 1つの学習レベルの定義。出題プールと表示・進行のオプションを持つ。
class Level {
  /// レベル番号（1始まり）。
  final int id;

  /// 表示名（例: 'レベル2'）。
  final String title;

  /// そのレベルで新しく増える概念（例: '五線をフルに読む'）。
  final String concept;

  /// 補足説明（出題範囲など）。
  final String description;

  /// 出題に使う音符プール。セッション毎にシャッフルして使う。
  final List<QuizNote> pool;

  /// 大譜表（ト音＋ヘ音を同時表示）で出題するか。
  final bool grandStaff;

  /// 制限時間（タイムアタック）。null なら [questionCount] 問の固定モード。
  final Duration? timeLimit;

  /// 固定モードでの出題数。
  final int questionCount;

  Level({
    required this.id,
    required this.title,
    required this.concept,
    required this.description,
    required this.pool,
    this.grandStaff = false,
    this.timeLimit,
    this.questionCount = 10,
  });

  /// タイムアタックかどうか。
  bool get isTimed => timeLimit != null;
}
