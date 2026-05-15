import 'package:flutter/cupertino.dart';
import '../models/burst_group.dart';

class BurstGroupCard extends StatelessWidget {
  final BurstGroup group;
  final VoidCallback onTap;
  final bool isSelectMode;
  final bool isSelected;

  const BurstGroupCard({
    super.key,
    required this.group,
    required this.onTap,
    this.isSelectMode = false,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Text('${group.count}枚'),
      ),
    );
  }
}
