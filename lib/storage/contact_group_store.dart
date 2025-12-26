import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contact_group.dart';

class ContactGroupStore {
  static const String _key = 'contact_groups';

  Future<List<ContactGroup>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(ContactGroup.fromJson)
            .toList();
      }
    } catch (_) {
      // Return empty list on parse errors.
    }
    return [];
  }

  Future<void> saveGroups(List<ContactGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(groups.map((group) => group.toJson()).toList());
    await prefs.setString(_key, encoded);
  }
}
