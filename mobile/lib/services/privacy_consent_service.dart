import 'package:shared_preferences/shared_preferences.dart';

class PrivacyConsentService {
  static const int currentVersion = 2;
  static const String acceptedKey = 'privacyConsentAccepted';
  static const String versionKey = 'privacyConsentVersion';
  static const String acceptedAtKey = 'privacyConsentAcceptedAt';

  static Future<bool> hasAcceptedCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getBool(acceptedKey) ?? false) &&
        (prefs.getInt(versionKey) ?? 0) >= currentVersion;
  }

  static Future<void> acceptCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(acceptedKey, true);
    await prefs.setInt(versionKey, currentVersion);
    await prefs.setString(acceptedAtKey, DateTime.now().toIso8601String());
  }

  static Future<String> acceptedAtText() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(acceptedAtKey);
    if (raw == null || raw.isEmpty) return '尚未确认';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.year}-${_two(parsed.month)}-${_two(parsed.day)} '
        '${_two(parsed.hour)}:${_two(parsed.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
