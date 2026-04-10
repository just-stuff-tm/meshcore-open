import '../utils/app_logger.dart';
import 'prefs_manager.dart';

class ContactSettingsStore {
  static const String _smazKeyPrefix = 'contact_smaz_';
  static const String _autoClockSyncKeyPrefix = 'contact_auto_clock_sync_';

  String publicKeyHex = '';
  set setPublicKeyHex(String value) =>
      publicKeyHex = value.length > 10 ? value.substring(0, 10) : '';

  String _keyFor(String keyPrefix) => '$keyPrefix$publicKeyHex';

  Future<bool> loadSmazEnabled(String contactKeyHex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load contact settings.',
      );
      return false;
    }
    final prefs = PrefsManager.instance;
    final key = '${_keyFor(_smazKeyPrefix)}$contactKeyHex';
    final oldKey = '$_smazKeyPrefix$contactKeyHex';
    bool? enabled = prefs.getBool(key);
    if (enabled == null) {
      // Attempt migration from legacy unscoped key on first load
      enabled = prefs.getBool(oldKey);
      prefs.remove(oldKey);
      if (enabled != null) {
        appLogger.info(
          'Migrating contact settings from legacy key $oldKey to scoped key $key',
        );
        await prefs.setBool(key, enabled);
      }
    }
    return prefs.getBool(key) ?? false;
  }

  Future<void> saveSmazEnabled(String contactKeyHex, bool enabled) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save contact settings.',
      );
      return;
    }
    final prefs = PrefsManager.instance;
    final key = '${_keyFor(_smazKeyPrefix)}$contactKeyHex';
    await prefs.setBool(key, enabled);
  }

  Future<bool> loadAutoClockSyncEnabled(String contactKeyHex) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot load contact settings.',
      );
      return false;
    }
    final prefs = PrefsManager.instance;
    final key = '${_keyFor(_autoClockSyncKeyPrefix)}$contactKeyHex';
    return prefs.getBool(key) ?? false;
  }

  Future<void> saveAutoClockSyncEnabled(
    String contactKeyHex,
    bool enabled,
  ) async {
    if (publicKeyHex.isEmpty) {
      appLogger.warn(
        'Public key hex is not set. Cannot save contact settings.',
      );
      return;
    }
    final prefs = PrefsManager.instance;
    final key = '${_keyFor(_autoClockSyncKeyPrefix)}$contactKeyHex';
    await prefs.setBool(key, enabled);
  }
}
