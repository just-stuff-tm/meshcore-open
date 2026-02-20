import 'package:flutter/material.dart';

class InputLengthCounter extends StatelessWidget {
  final int charCount;
  final int byteCount;
  final int maxBytes;

  const InputLengthCounter({
    super.key,
    required this.charCount,
    required this.byteCount,
    required this.maxBytes,
  });

  @override
  Widget build(BuildContext context) {
    final remainingBytes = maxBytes - byteCount;
    final isOverLimit = remainingBytes < 0;
    final color = isOverLimit
        ? Colors.red
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);

    return Text(
      'Chars: $charCount  Bytes: $byteCount/$maxBytes  Left: $remainingBytes',
      style: TextStyle(fontSize: 11, color: color),
    );
  }
}
