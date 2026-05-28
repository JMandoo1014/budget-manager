import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InputScreen extends StatefulWidget {
  const InputScreen({super.key});

  @override
  State<InputScreen> createState() => _InputScreenState();
}

class _InputScreenState extends State<InputScreen> {
  final _controller = TextEditingController();
  String _input = '';

  // 하드코딩된 AI 분류 결과
  final String _category = '식비';
  final String _categoryEmoji = '🍚';
  final String _amount = '15,000원';

  // 경고를 표시할 카테고리
  final _warningCategories = {'술', '카페'};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasInput => _input.trim().isNotEmpty;
  bool get _showWarning => _warningCategories.contains(_category);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '지출 입력',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputField(),
                  const SizedBox(height: 6),
                  const Text(
                    '← 이렇게 짧게만 써도 AI가 분류해줘',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  if (_hasInput) ...[
                    const SizedBox(height: 20),
                    _buildResultCard(),
                    if (_showWarning) ...[
                      const SizedBox(height: 12),
                      _buildWarningBox(),
                    ],
                  ],
                ],
              ),
            ),
          ),
          _buildBottomButton(context),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: const Color(0xFF534AB7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) context.go('/home');
          if (index == 2) context.go('/analysis');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: '입력'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: '분석'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: '설정'),
        ],
      ),
    );
  }

  Widget _buildInputField() {
    return TextField(
      controller: _controller,
      onChanged: (value) => setState(() => _input = value),
      style: const TextStyle(fontSize: 18),
      decoration: InputDecoration(
        hintText: '치킨 15000',
        hintStyle: const TextStyle(fontSize: 18, color: Colors.grey),
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF534AB7)),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('카테고리', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEDFE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_categoryEmoji $_category',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF534AB7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('금액', style: TextStyle(fontSize: 13, color: Colors.grey)),
              Text(
                _amount,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '카테고리 수정',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEEDFE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              '⚠ 식비 예산의 83% 썼어. 오늘 하루 7,000원 남았어.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF534AB7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Opacity(
        opacity: _hasInput ? 1.0 : 0.4,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _hasInput ? () => context.go('/home') : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF534AB7),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF534AB7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              '기록하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
