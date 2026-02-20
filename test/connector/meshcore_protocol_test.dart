import 'package:flutter_test/flutter_test.dart';
import 'package:meshcore_open/connector/meshcore_protocol.dart';

void main() {
  group('channel byte helpers', () {
    test('calculates sender bytes with utf8 and max-name cap', () {
      expect(channelSenderNameUtf8Bytes('Alice'), 5);
      expect(channelSenderNameUtf8Bytes('🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂🙂'), 31);
    });

    test('calculates message bytes with emoji utf8 length', () {
      expect(channelMessageUtf8Bytes('abc'), 3);
      expect(channelMessageUtf8Bytes('🙂'), 4);
      expect(channelMessageUtf8Bytes('a🙂b'), 6);
    });

    test('enforces payload limit including sender prefix and terminator', () {
      final sender = 'Alice'; // 5 bytes
      final maxMessageBytes = maxChannelMessageBytes(sender); // 152
      final okMessage = 'a' * maxMessageBytes;
      final tooLongMessage = 'a' * (maxMessageBytes + 1);

      expect(isChannelMessageWithinPayloadLimit(sender, okMessage), isTrue);
      expect(isChannelMessageWithinPayloadLimit(sender, tooLongMessage), isFalse);
      expect(channelOverAirPayloadBytes(sender, okMessage), maxTextPayloadBytes);
    });

    test('reliable limit auto-calculates from sender bytes', () {
      // 5-char sender:
      // raw max = 160 - (5 + 2) - 1 = 152
      // reliable max = 152 - headroom(5) = 147
      expect(maxReliableChannelMessageBytes('Alice'), 147);
      expect(
        isChannelMessageWithinReliableLimit('Alice', 'a' * 147),
        isTrue,
      );
      expect(
        isChannelMessageWithinReliableLimit('Alice', 'a' * 148),
        isFalse,
      );
    });
  });
}
