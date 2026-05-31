import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

/// MIDIノート番号から音程を合成して鳴らす簡易プレイヤー。
///
/// 音源アセットを持たず、Dart 側で WAV(PCM) を生成して再生するため
/// 完全にオフラインで動作する。
class TonePlayer {
  final AudioPlayer _player = AudioPlayer();
  static const int _sampleRate = 44100;

  /// [midi] の高さの音を [seconds] 秒鳴らす。
  Future<void> playMidi(int midi, {double seconds = 0.7}) async {
    final bytes = _wavForMidi(midi, seconds);
    try {
      await _player.stop();
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'), volume: 1.0);
    } catch (_) {
      // 音が出せない環境でもクイズ自体は継続させる。
    }
  }

  Future<void> dispose() => _player.dispose();

  Uint8List _wavForMidi(int midi, double seconds) {
    final freq = 440.0 * pow(2, (midi - 69) / 12.0);
    final n = (_sampleRate * seconds).round();
    final samples = Int16List(n);
    for (int i = 0; i < n; i++) {
      final t = i / _sampleRate;
      // 立ち上がり(10ms)＋指数減衰のエンベロープ
      final env = t < 0.01 ? t / 0.01 : exp(-3.0 * (t - 0.01));
      // 基音＋オクターブ上の弱い倍音で少しだけ整音
      final s = sin(2 * pi * freq * t) * 0.6 + sin(2 * pi * freq * 2 * t) * 0.2;
      samples[i] = (s * env * 0.8 * 32767).clamp(-32768.0, 32767.0).toInt();
    }
    return _encodeWav(samples);
  }

  /// 16bit / モノラル / [_sampleRate] の WAV にエンコードする。
  Uint8List _encodeWav(Int16List samples) {
    final pcm = samples.buffer.asUint8List(); // ARM/x86 はリトルエンディアン
    final dataLength = pcm.length;
    final out = BytesBuilder();
    void str(String s) => out.add(s.codeUnits);
    void u32(int v) =>
        out.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => out.add([v & 0xff, (v >> 8) & 0xff]);

    str('RIFF');
    u32(36 + dataLength);
    str('WAVE');
    str('fmt ');
    u32(16); // fmt チャンクサイズ
    u16(1); // PCM
    u16(1); // モノラル
    u32(_sampleRate);
    u32(_sampleRate * 2); // バイトレート（2バイト/サンプル）
    u16(2); // ブロックアライン
    u16(16); // ビット深度
    str('data');
    u32(dataLength);
    out.add(pcm);
    return out.toBytes();
  }
}
