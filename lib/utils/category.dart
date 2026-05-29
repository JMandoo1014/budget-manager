import 'package:flutter/material.dart';

const categoryMeta = <String, (String, Color)>{
  '식비': ('🍚', Color(0xFF1D9E75)),
  '술': ('🍺', Color(0xFFE24B4A)),
  '교통': ('🚌', Color(0xFF1D9E75)),
  '카페': ('☕', Color(0xFFEF9F27)),
  '쇼핑': ('🛍', Color(0xFF1D9E75)),
  '기타': ('📦', Color(0xFF9E9E9E)),
};

const categoryList = <(String, String)>[
  ('🍚', '식비'),
  ('🍺', '술'),
  ('🚌', '교통'),
  ('☕', '카페'),
  ('🛍', '쇼핑'),
  ('📦', '기타'),
];

String categoryEmoji(String category) => categoryMeta[category]?.$1 ?? '📦';

Color progressColor(int spent, int limit) {
  if (limit == 0) return const Color(0xFF1D9E75);
  final ratio = spent / limit;
  if (ratio >= 1.0) return const Color(0xFFE24B4A);
  if (ratio >= 0.8) return const Color(0xFFEF9F27);
  return const Color(0xFF1D9E75);
}
