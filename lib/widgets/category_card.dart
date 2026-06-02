import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../utils/format.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.spent,
    required this.limit,
    required this.color,
    this.onTap,
  });

  final String emoji;
  final String name;
  final int spent;
  final int limit;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = limit > 0 ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final isOver = spent > limit;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '$emoji $name',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    if (isOver) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                    ],
                  ],
                ),
                Text(
                  '${formatNumber(spent)}원 / ${formatNumber(limit)}원',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.divider,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
