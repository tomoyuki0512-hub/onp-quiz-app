import 'package:flutter/cupertino.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('おんぷクイズ'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🎼', style: TextStyle(fontSize: 72), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text(
                '音符あてクイズ',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '五線譜の音符を見て、音名（ドレミ）を当てよう。',
                style: TextStyle(
                    fontSize: 15, color: CupertinoColors.secondaryLabel),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _levelCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'レベル1',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'ト音記号（中央ド〜上のド）と\nヘ音記号（下のド〜中央ド）の1オクターブ',
            style:
                TextStyle(fontSize: 14, color: CupertinoColors.secondaryLabel),
          ),
          const SizedBox(height: 20),
          CupertinoButton.filled(
            borderRadius: BorderRadius.circular(12),
            onPressed: () => Navigator.of(context).push(
              CupertinoPageRoute(builder: (_) => const QuizScreen()),
            ),
            child: const Text('はじめる',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
