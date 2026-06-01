import 'package:flutter/material.dart';

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

const categoryList = <(String, String)>[
  ('🍚', '식비'),
  ('🍺', '술'),
  ('🚌', '교통'),
  ('☕', '카페'),
  ('🛍', '쇼핑'),
  ('📦', '기타'),
];

String categoryEmoji(String category) => _categoryEmojis[category] ?? '📦';

String incomeEmoji(String category) => _incomeEmojis[category] ?? '💵';

Color progressColor(int spent, int limit) {
  if (limit == 0) return const Color(0xFF1D9E75);
  final ratio = spent / limit;
  if (ratio >= 1.0) return const Color(0xFFE24B4A);
  if (ratio >= 0.8) return const Color(0xFFEF9F27);
  return const Color(0xFF1D9E75);
}
