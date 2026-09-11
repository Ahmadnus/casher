import '../../storage/hive_storage.dart';

/// Where the web build finds the local Casher Print Agent. Platform-neutral
/// (plain Hive) so the printer settings screen can edit it on any build;
/// only the web backend actually uses it.
class PrintAgentConfig {
  static const String defaultUrl = 'http://127.0.0.1:9123';
  static const String _urlKey = 'printAgentUrl';
  static const String _tokenKey = 'printAgentToken';

  static String get agentUrl {
    try {
      final v = HiveStorage.printerSettings.get(_urlKey) as String?;
      if (v != null && v.trim().isNotEmpty) return normalize(v);
    } catch (_) {}
    return defaultUrl;
  }

  static set agentUrl(String url) {
    try {
      HiveStorage.printerSettings.put(_urlKey, normalize(url));
    } catch (_) {}
  }

  static String? get agentToken {
    try {
      final v = HiveStorage.printerSettings.get(_tokenKey) as String?;
      return (v == null || v.isEmpty) ? null : v;
    } catch (_) {
      return null;
    }
  }

  static set agentToken(String? token) {
    try {
      if (token == null || token.isEmpty) {
        HiveStorage.printerSettings.delete(_tokenKey);
      } else {
        HiveStorage.printerSettings.put(_tokenKey, token);
      }
    } catch (_) {}
  }

  static String normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return defaultUrl;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }
}
