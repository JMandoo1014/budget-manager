import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class AiService {
  static final AiService _instance = AiService._internal();
  factory AiService() => _instance;
  AiService._internal();

  static String get _apiKey => dotenv.env['GEMINI_API_KEY'] ?? '';
  static String get _endpoint =>
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash:generateContent?key=$_apiKey';

  static const _headers = {'content-type': 'application/json'};

  String _extractText(Map<String, dynamic> data) =>
      data['candidates'][0]['content']['parts'][0]['text'] as String;

  Future<Map<String, dynamic>> classifyExpense(String rawInput) async {
    final prompt =
        '지출 내역을 분석해서 JSON만 반환해. 마크다운이나 다른 텍스트 절대 금지.\n'
        '카테고리: 식비/술/교통/카페/쇼핑/기타\n'
        '형식: {"category": "식비", "amount": 15000, "name": "치킨"}\n'
        '입력: $rawInput';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ],
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data).trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (_) {}

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
        '예산을 배분해서 JSON만 반환해. 마크다운이나 다른 텍스트 절대 금지.\n'
        '수입: $income\n'
        '월저축목표: $monthlySavings원\n'
        '사용가능예산: $available원\n'
        '소비패턴: ${spendingPatterns.join(", ")}\n'
        '카테고리: 식비/술/교통/카페/쇼핑/기타\n'
        '모든 카테고리 합계 = 사용가능예산\n'
        '형식: {"식비": 60000, "술": 30000, "교통": 30000, "카페": 20000, "쇼핑": 10000, "기타": 27400}';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ],
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data).trim();
        final parsed = jsonDecode(text) as Map<String, dynamic>;
        return parsed.map((key, value) => MapEntry(key, (value as num).toInt()));
      }
    } catch (_) {}

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

  Future<String> generateMonthlyReport({
    required int totalSpent,
    required int totalBudget,
    required Map<String, int> spentByCategory,
    required Map<String, int> budgetByCategory,
  }) async {
    final categoryLines = budgetByCategory.entries.map((e) {
      final spent = spentByCategory[e.key] ?? 0;
      return '${e.key}: 예산 ${e.value}원 / 지출 $spent원';
    }).join('\n');

    final prompt =
        '이번 달 예산 분석 결과야. 반드시 존댓말로, 친근하지만 정중한 말투로 2~3문장 피드백 줘. 반말 절대 금지. 잘한 점과 아쉬운 점 모두 포함해. JSON이나 마크다운 절대 금지. 평문으로만 답해.\n'
        '총예산: $totalBudget원\n'
        '총지출: $totalSpent원\n'
        '카테고리별:\n$categoryLines';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ],
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractText(data).trim();
      }
    } catch (_) {}

    return '이번 달 지출 패턴을 분석 중이에요.';
  }

  Future<String> generateBudgetWarning({
    required int remainingBudget,
    required int totalBudget,
    required int remainingDays,
    required Map<String, int> spentByCategory,
    required Map<String, int> budgetByCategory,
  }) async {
    final prompt =
        '예산 상황을 보고 한국어로 1-2문장 경고 메시지만 줘.\n'
        '반드시 존댓말로. 친근하지만 정중한 말투로.\n'
        '반말 절대 금지.\n'
        '남은예산: $remainingBudget원\n'
        '총예산: $totalBudget원\n'
        '남은일수: $remainingDays일\n'
        '카테고리별 지출: $spentByCategory\n'
        '카테고리별 예산: $budgetByCategory\n'
        'JSON 말고 일반 텍스트로만 반환해.';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ],
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return _extractText(data).trim();
      }
    } catch (_) {}

    return '예산의 80% 이상을 사용했어요. 남은 기간 지출을 줄여보세요!';
  }

  Future<Map<String, dynamic>> classifyIncome(String rawInput) async {
    final prompt =
        '수입 내역을 분석해서 JSON만 반환해. 다른 텍스트 절대 금지.\n'
        '카테고리: 알바/용돈/기타수입\n'
        '형식: {"category": "알바", "amount": 200000, "name": "알바비"}\n'
        '입력: $rawInput';

    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: _headers,
            body: jsonEncode({
              'contents': [
                {
                  'parts': [{'text': prompt}]
                }
              ],
              'generationConfig': {
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final text = _extractText(data).trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (_) {}

    return _fallbackClassifyIncome(rawInput);
  }

  static const _incomeKeywordMap = <String, List<String>>{
    '알바': ['알바', '아르바이트', '파트타임', '시급', '주급'],
    '용돈': ['용돈', '부모님', '엄마', '아빠', '가족'],
  };

  Map<String, dynamic> _fallbackClassifyIncome(String rawInput) {
    final lower = rawInput.toLowerCase();
    String category = '기타수입';
    for (final entry in _incomeKeywordMap.entries) {
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
}
