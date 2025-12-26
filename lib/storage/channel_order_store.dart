import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChannelOrderStore {
  static const String _key = 'channel_order';

  Future<void> saveChannelOrder(List<int> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(order));
  }

  Future<List<int>> loadChannelOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((value) => value is int ? value : int.tryParse('$value')).whereType<int>().toList();
      }
    } catch (_) {
      // fall through to legacy parse
    }
    return raw
        .split(',')
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toList();
  }
}
