import 'package:flutter/material.dart';

import '../constants/app_categories.dart';
import '../constants/app_colors.dart';

export '../constants/app_categories.dart';

const categoryList = AppCategories.expenseList;

const _categoryEmojis = <String, String>{
  '식비': '🍚',
  '술': '🍺',
  '교통': '🚌',
  '카페': '☕',
  '쇼핑': '🛍',
  '기타': '📦',
};

const _incomeEmojis = <String, String>{
  '알바': '💼',
  '용돈': '💰',
  '기타수입': '💵',
};

String categoryEmoji(String category) => _categoryEmojis[category] ?? '📦';

String incomeEmoji(String category) => _incomeEmojis[category] ?? '💵';

Color progressColor(int spent, int limit) {
  if (limit == 0) return AppColors.primary;
  final ratio = spent / limit;
  if (ratio >= 1.0) return AppColors.danger;
  if (ratio >= 0.8) return AppColors.warning;
  return AppColors.primary;
}
