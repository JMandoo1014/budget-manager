import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  static const String _proEntitlement = 'pro';

  Future<void> init() async {
    final apiKey = dotenv.env['REVENUECAT_API_KEY'] ?? '';
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  Future<bool> isPro() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active.containsKey(_proEntitlement);
    } catch (_) {
      return false;
    }
  }

  Future<bool> purchasePro() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package == null) return false;
      final customerInfo = await Purchases.purchasePackage(package);
      return customerInfo.entitlements.active.containsKey(_proEntitlement);
    } on PurchasesError catch (e) {
      if (e.code == PurchasesErrorCode.purchaseCancelledError) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await Purchases.restorePurchases();
  }
}
