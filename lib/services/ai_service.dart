import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const _apiKey = '';
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = (data['content'] as List).first['text'] as String;
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (_) {}

    return {'category': '기타', 'amount': 0, 'name': rawInput};
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
        '월 수입: ${income}원, 저축 목표: ${savingsGoal}원, '
        '목표 기간: ${savingsMonths}개월, '
        '사용 가능 예산: ${availableBudget}원, '
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
    } catch (_) {}

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
