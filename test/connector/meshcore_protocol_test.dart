import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';

void main() {
  group('maxChannelMessageBytes', () {
    test('reserves bytes for sender prefix and null terminator', () {
      // "Alice" => "Alice: " prefix is 7 bytes.
      // 160 max payload - 7 prefix - 1 terminator = 152 bytes user text.
      expect(maxChannelMessageBytes('Alice'), 152);
    });

    test('uses conservative sender length when name is unknown', () {
      // Unknown sender defaults to maxNameSize-1 (31 bytes).
      // 160 - (31 + 2) - 1 = 126.
      expect(maxChannelMessageBytes(null), 126);
    });
  });

  group('buildSendChannelTextMsgFrame', () {
    test('frame stays within maxFrameSize at channel text limit', () {
      final limit = maxChannelMessageBytes('Alice');
      final text = 'a' * limit;
      final frame = buildSendChannelTextMsgFrame(1, text);
      expect(frame.length <= maxFrameSize, isTrue);
    });

    test('utf8 channel text limit can be encoded and sent in one frame', () {
      final limit = maxChannelMessageBytes('Alice');
      final text = 'é' * (limit ~/ utf8.encode('é').length);
      final frame = buildSendChannelTextMsgFrame(1, text);
      expect(frame.length <= maxFrameSize, isTrue);
    });
  });
}
