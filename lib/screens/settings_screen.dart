import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/budget.dart';
import '../services/purchase_service.dart';
import '../services/storage_service.dart';
import '../utils/format.dart';
import '../widgets/app_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Budget? _budget;
  bool _isLoading = true;
  bool _isPro = false;
  bool _isLoadingPro = true;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadBudget();
    _loadProStatus();
  }

  Future<void> _loadBudget() async {
    final budget = await StorageService().getCurrentBudget();
    if (mounted) {
      setState(() {
        _budget = budget;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProStatus() async {
    final isPro = await PurchaseService().isPro();
    if (mounted) {
      setState(() {
        _isPro = isPro;
        _isLoadingPro = false;
      });
    }
  }

  Future<void> _onPurchasePro() async {
    setState(() => _isPurchasing = true);
    final success = await PurchaseService().purchasePro();
    if (mounted) {
      setState(() {
        _isPro = success;
        _isPurchasing = false;
      });
      if (success) {
        AppToast.show(context, 'Pro 구독이 완료됐어요! 🎉');
      } else {
        AppToast.show(context, '현재 구독 서비스를 준비 중이에요.');
      }
    }
  }

  Future<void> _onRestorePurchases() async {
    try {
      await PurchaseService().restorePurchases();
      final isPro = await PurchaseService().isPro();
      if (mounted) {
        setState(() => _isPro = isPro);
        AppToast.show(context, isPro ? '구매가 복원됐어요! ✅' : '복원할 구매 내역이 없어요.');
      }
    } catch (e) {
      if (mounted) AppToast.show(context, '복원에 실패했어요.');
    }
  }

  Future<void> _onResetBudget() async {
    await context.push('/');
    if (mounted) context.go('/home');
  }

  Future<void> _onToggleAutoRollover(bool value) async {
    try {
      await StorageService().updateAutoRollover(value);
      if (mounted) setState(() => _budget = _budget?.copyWith(autoRollover: value));
    } catch (e) {
      if (mounted) AppToast.show(context, '변경에 실패했어요.');
    }
  }

  Future<void> _onDeleteExpenses() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '지출 내역 초기화',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          '이번 달 지출 내역이 모두 삭제돼요.\n정말 초기화할까요?',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '초기화',
              style: TextStyle(color: Color(0xFFE24B4A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await StorageService().deleteMonthExpenses();
      if (mounted) AppToast.show(context, '지출 내역을 초기화했어요.');
    } catch (e) {
      if (mounted) AppToast.show(context, '초기화에 실패했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '설정',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(),
            const SizedBox(height: 16),
            const Text(
              '구독',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildProSection(),
            const SizedBox(height: 16),
            const Text(
              '관리',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildMenuSection(),
            const SizedBox(height: 16),
            const Text(
              '앱 정보',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            _buildInfoSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE1F5EE),
                  child: Icon(Icons.person_rounded, color: Color(0xFF1D9E75), size: 28),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('이번 달 예산', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(
                      _budget != null ? '${formatNumber(_budget!.totalBudget)}원' : '미설정',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('월 저축 목표', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text(
                      _budget != null
                          ? '${formatNumber(_budget!.savingsGoal ~/ _budget!.savingsMonths)}원'
                          : '미설정',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildProSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: _isLoadingPro
          ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                if (_isPro)
                  const ListTile(
                    leading: Icon(Icons.verified_rounded, color: Color(0xFF1D9E75), size: 28),
                    title: Text(
                      '✅ Pro 구독 중',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '모든 프리미엄 기능을 사용 중이에요',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  )
                else
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F5EE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFF1D9E75)),
                    ),
                    title: const Text('Pro로 업그레이드', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: const Text('프리미엄 기능 전체 이용', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: _isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D9E75)),
                          )
                        : const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                    onTap: _isPurchasing ? null : _onPurchasePro,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5EE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restore_rounded, size: 18, color: Color(0xFF1D9E75)),
                  ),
                  title: const Text('구매 복원', style: TextStyle(fontSize: 14, color: Colors.black87)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                  onTap: _onRestorePurchases,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildMenuItem(
            icon: Icons.tune_rounded,
            label: '예산 재설정',
            onTap: _onResetBudget,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildToggleItem(
            icon: Icons.autorenew_rounded,
            label: '자동 이월',
            value: _budget?.autoRollover ?? true,
            onChanged: _budget != null ? _onToggleAutoRollover : null,
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _buildMenuItem(
            icon: Icons.delete_outline_rounded,
            label: '이번 달 지출 내역 초기화',
            onTap: _onDeleteExpenses,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFE24B4A) : Colors.black87;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFCEBEB)
              : const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 14, color: color),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String label,
    required bool value,
    ValueChanged<bool>? onChanged,
  }) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: Colors.black87),
      ),
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF1D9E75),
        activeTrackColor: const Color(0xFFE1F5EE),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildInfoTile('버전', '1.0.0'),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildInfoTile('만든이', '최지호'),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
          Text(value, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}
