import 'package:flutter/services.dart';

import 'byte_counter.dart';

class ByteLimitInputFormatter extends TextInputFormatter {
  final int maxBytes;
  final String Function(String input)? transformForCount;

  const ByteLimitInputFormatter({
    required this.maxBytes,
    this.transformForCount,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (maxBytes <= 0) return oldValue;
    final transformed = transformForCount?.call(newValue.text) ?? newValue.text;
    final bytes = ByteCounter.countBytes(transformed);
    if (bytes <= maxBytes) return newValue;
    return oldValue;
  }
}
