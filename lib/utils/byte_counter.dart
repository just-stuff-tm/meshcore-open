import 'dart:convert';

class ByteCounter {
  /// Returns the number of bytes in the string when encoded as UTF-8.
  static int countBytes(String text) {
    return utf8.encode(text).length;
  }

  /// Truncates the string so that its UTF-8 byte count is <= [limit].
  /// Ensures that multi-byte characters are not split.
  static String truncateToByteLimit(String text, int limit) {
    final bytes = utf8.encode(text);
    if (bytes.length <= limit) return text;

    var sublist = bytes.sublist(0, limit);
    while (sublist.isNotEmpty) {
      try {
        return utf8.decode(sublist);
      } catch (_) {
        sublist = sublist.sublist(0, sublist.length - 1);
      }
    }
    return '';
  }
}
