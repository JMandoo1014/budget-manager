import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static String get _apiKey => dotenv.env['CLAUDE_API_KEY'] ?? '';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-20250514';

  Map<String, String> get _headers => {
        'x-api-key': _apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      };

  Future<Map<String, dynamic>> classifyExpense(String rawInput) async {
    const systemPrompt =
        '너는 지출 분류 AI야. 사용자가 입력한 지출 내역을 분석해서 '
        '반드시 JSON만 반환해. 다른 텍스트 절대 금지. '
        '카테고리는 식비/술/교통/카페/쇼핑/기타 중 하나. '
        '형식: {"category": "식비", "amount": 15000, "name": "치킨"}';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 500,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': rawInput},
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List).first['text'] as String;
        return jsonDecode(text) as Map<String, dynamic>;
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        return _fallbackClassify(rawInput);
      }
    } catch (e) {
      // 네트워크 오류, 타임아웃 → fallback
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
    final availableBudget = income - savingsGoal;

    const systemPrompt =
        '너는 예산 관리 AI야. 반드시 JSON만 반환해. 다른 텍스트 절대 금지. '
        '카테고리: 식비, 술, 교통, 카페, 쇼핑, 기타 '
        '모든 카테고리 합계가 반드시 사용가능예산과 일치해야 해. '
        '형식: {"식비": 60000, "술": 30000, "교통": 30000, "카페": 20000, "쇼핑": 10000, "기타": 27400}';

    final userMessage =
        '월 수입: $income원, 저축 목표: $savingsGoal원, '
        '목표 기간: $savingsMonths개월, '
        '사용 가능 예산: $availableBudget원, '
        '소비 패턴: ${spendingPatterns.join(", ")}';

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: _headers,
        body: jsonEncode({
          'model': _model,
          'max_tokens': 500,
          'system': systemPrompt,
          'messages': [
            {'role': 'user', 'content': userMessage},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List).first['text'] as String;
        final parsed = jsonDecode(text) as Map<String, dynamic>;
        return parsed.map((key, value) => MapEntry(key, (value as num).toInt()));
      }
    } catch (e) {
      // 네트워크 오류, 타임아웃 → fallback
    }

    // 파싱 실패 시 균등 분배 fallback
    final perCategory = availableBudget ~/ 6;
    final remainder = availableBudget - perCategory * 6;
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
