import 'package:shared_preferences/shared_preferences.dart';

class MapMarkerService {
  static const String _removedKey = 'map_removed_marker_ids';

  Future<Set<String>> loadRemovedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final items = prefs.getStringList(_removedKey) ?? const [];
    return items.toSet();
  }

  Future<void> saveRemovedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_removedKey, ids.toList());
  }
}
