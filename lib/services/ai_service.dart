import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Map<String, String> get _headers => {
        'x-goog-api-key': _apiKey,
        'content-type': 'application/json',
      };

  String _extractText(Map<String, dynamic> data) {
    return data['candidates'][0]['content']['parts'][0]['text'] as String;
  }

  Future<Map<String, dynamic>> classifyExpense(String rawInput) async {
    final prompt =
        '지출 내역을 분석해서 JSON만 반환해. 다른 텍스트 금지.\n'
        '카테고리: 식비/술/교통/카페/쇼핑/기타\n'
        '형식: {"category": "식비", "amount": 15000, "name": "치킨"}\n'
        '입력: $rawInput';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data).trim();
        final clean = text.replaceAll(RegExp(r'^```json|^```|```$'), '').trim();
        return jsonDecode(clean) as Map<String, dynamic>;
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        return _fallbackClassify(rawInput);
      }
    } catch (_) {
      // 네트워크 오류, 타임아웃, 파싱 실패 → fallback
    }

    return _fallbackClassify(rawInput);
  }

  static const _keywordMap = <String, List<String>>{
    '식비': ['치킨', '피자', '밥', '식당', '편의점', '마트', '배달'],
    '교통': ['버스', '지하철', '택시', '기차', '카카오택시'],
    '카페': ['카페', '커피', '스타벅스', '아메리카노'],
    '술': ['맥주', '소주', '술', '호프', '막걸리'],
    '쇼핑': ['쇼핑', '옷', '신발', '쿠팡', '배민'],
  };

  Map<String, dynamic> _fallbackClassify(String rawInput) {
    final lower = rawInput.toLowerCase();

    String category = '기타';
    for (final entry in _keywordMap.entries) {
      if (entry.value.any((kw) => lower.contains(kw))) {
        category = entry.key;
        break;
      }
    }

    final digits = RegExp(r'\d+').allMatches(rawInput.replaceAll(',', ''));
    final amount = digits.isEmpty ? 0 : (int.tryParse(digits.last.group(0)!) ?? 0);
    final name = rawInput.replaceAll(RegExp(r'[\d,]+'), '').trim();

    return {
      'category': category,
      'amount': amount,
      'name': name.isNotEmpty ? name : rawInput,
    };
  }

  Future<Map<String, int>> generateBudget({
    required int income,
    required int savingsGoal,
    required int savingsMonths,
    required List<String> spendingPatterns,
  }) async {
    final monthlySavings = savingsGoal ~/ savingsMonths;
    final available = income - monthlySavings;

    final prompt =
        '예산을 배분해서 JSON만 반환해. 다른 텍스트 금지.\n'
        '수입: $income, 월저축목표: $monthlySavings\n'
        '사용가능예산: $available\n'
        '소비패턴: ${spendingPatterns.join(", ")}\n'
        '카테고리: 식비/술/교통/카페/쇼핑/기타\n'
        '모든 카테고리 합계 = 사용가능예산\n'
        '형식: {"식비": 60000, "술": 30000, "교통": 30000, "카페": 20000, "쇼핑": 10000, "기타": 27400}';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'contents': [
            {
              'parts': [{'text': prompt}]
            }
          ],
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data).trim();
        final clean = text.replaceAll(RegExp(r'^```json|^```|```$'), '').trim();
        final parsed = jsonDecode(clean) as Map<String, dynamic>;
        return parsed.map((key, value) => MapEntry(key, (value as num).toInt()));
      }
    } catch (_) {
      // 네트워크 오류, 타임아웃, 파싱 실패 → fallback
    }

    final perCategory = available ~/ 6;
    final remainder = available - perCategory * 6;
    return {
      '식비': perCategory,
      '술': perCategory,
      '교통': perCategory,
      '카페': perCategory,
      '쇼핑': perCategory,
      '기타': perCategory + remainder,
    };
  }
}
