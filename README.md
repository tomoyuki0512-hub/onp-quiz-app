# おんぷクイズ (music note quiz)

音楽初心者向けの「音符あてクイズ」アプリ（Flutter / iOS）。
五線譜に表示された音符を見て、その音名（ドレミファソラシ）を当てます。

## レベル構成（全5レベル）

音名読みの基礎を、1レベルにつき新概念を1つずつ積み上げます（自然音のみ）。

| Lv | 新しく増える概念 | 出題範囲 |
|----|------------------|----------|
| 1 | 中央ド基準の1オクターブ | ト音 C4–C5 / ヘ音 C3–C4 |
| 2 | 五線をフルに読む（加線なし） | ト音 E4–F5 / ヘ音 G2–A3 |
| 3 | 少しの加線（上下1本まで） | ト音 C4–A5 / ヘ音 E2–C4 |
| 4 | 大譜表（中央ドの橋渡し） | レベル3範囲を大譜表で同時表示 |
| 5 | タイムアタック総合 | 全範囲をランダム・制限時間60秒 |

ホーム画面のレベル一覧から選んで開始します。

## 特長

- **2通りの解答方法をワンタッチ切替**: 「ド〜シの7択ボタン」と「ピアノ鍵盤」を
  セグメントコントロールでいつでも切り替え可能。
- **音が鳴る**: 解答すると、その音符の高さの音を再生（耳でも確認）。
  音源アセットを持たず、Dart 側で WAV を合成するため完全オフライン。
- **本格的な楽譜表示**: 五線・加線・符頭は `CustomPainter` で描画し、音部記号と符頭は
  SMuFL 標準フォント **Bravura** のグリフを使用。中央ドの加線位置も正確。

## 構成

| ファイル | 役割 |
| --- | --- |
| `lib/main.dart` | エントリポイント |
| `lib/screens/home_screen.dart` | タイトル・レベル選択 |
| `lib/screens/quiz_screen.dart` | 出題・採点・フィードバック・結果 |
| `lib/widgets/staff_painter.dart` | 五線譜（五線・加線・音部記号・符頭）の描画 |
| `lib/widgets/answer_choices.dart` | 7択ボタンの解答UI |
| `lib/widgets/answer_piano.dart` | ピアノ鍵盤の解答UI |
| `lib/services/tone_player.dart` | MIDIノート→WAV合成→再生 |
| `lib/models/quiz_note.dart` | 音符モデル（音名・MIDI・五線位置を導出） |
| `lib/data/level1.dart` | レベル1の出題プール |

## ビルド

```sh
flutter pub get
cd ios && pod install && cd ..
flutter run
flutter test     # スモークテスト＋音符モデル/出題プールのユニットテスト
```

## ライセンス

音楽フォント Bravura は SIL Open Font License 1.1（`assets/fonts/OFL.txt`）。
© Steinberg Media Technologies GmbH.
