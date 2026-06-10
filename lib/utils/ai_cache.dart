import 'package:shared_preferences/shared_preferences.dart';

class AiCache {
  AiCache._();

  static const keyReport = 'ai_report_cache';
  static const keyReportDate = 'ai_report_date';
  static const keyWarning = 'ai_warning_cache';
  static const keyWarningDate = 'ai_warning_date';

  static Future<void> invalidateAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(keyReport),
      prefs.remove(keyReportDate),
      prefs.remove(keyWarning),
      prefs.remove(keyWarningDate),
    ]);
  }
}
