/// 音部記号。レベル1ではト音記号とヘ音記号を扱う。
enum Clef {
  treble,
  bass;

  /// 画面表示用の名称。
  String get label => switch (this) {
        Clef.treble => 'ト音記号',
        Clef.bass => 'ヘ音記号',
      };

  /// Bravura(SMuFL) のグリフ。gClef = U+E050 / fClef = U+E062。
  String get glyph => switch (this) {
        Clef.treble => '\u{E050}',
        Clef.bass => '\u{E062}',
      };

  /// 五線最下線の diatonic degree（= octave*7 + letterIndex, C=0 基準）。
  /// ト音記号は最下線が E4(=30)、ヘ音記号は G2(=18)。
  int get bottomLineDegree => switch (this) {
        Clef.treble => 30, // E4
        Clef.bass => 18, // G2
      };

  /// 記号の原点(baseline)が乗る五線の線インデックス（下から 0..4）。
  /// ト音記号は G4 線（下から2本目 = index1）に巻き付き、
  /// ヘ音記号は F3 線（下から4本目 = index3）を2点で挟む。
  int get anchorLineFromBottom => switch (this) {
        Clef.treble => 1,
        Clef.bass => 3,
      };
}
