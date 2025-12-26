import 'dart:convert';
import 'dart:typed_data';

import '../connector/meshcore_protocol.dart';

class Channel {
  final int index;
  final String name;
  final Uint8List psk; // 16 bytes

  Channel({
    required this.index,
    required this.name,
    required this.psk,
  });

  String get pskBase64 => base64Encode(psk);

  bool get isEmpty => name.isEmpty && psk.every((b) => b == 0);

  bool get isPublicChannel => pskBase64 == publicChannelPsk;

  static Channel? fromFrame(Uint8List data) {
    // CHANNEL_INFO format:
    // [0] = RESP_CODE_CHANNEL_INFO (18)
    // [1] = channel_idx
    // [2-33] = name (32 bytes, null-terminated)
    // [34-49] = psk (16 bytes)
    if (data.length < 50) return null;
    if (data[0] != respCodeChannelInfo) return null;

    final index = data[1];
    final name = readCString(data, 2, 32);
    final psk = Uint8List.fromList(data.sublist(34, 50));

    return Channel(index: index, name: name, psk: psk);
  }

  static Channel empty(int index) {
    return Channel(
      index: index,
      name: '',
      psk: Uint8List(16),
    );
  }

  static Channel fromPsk(int index, String name, String pskBase64) {
    final pskBytes = base64Decode(pskBase64);
    final psk = Uint8List(16);
    for (int i = 0; i < pskBytes.length && i < 16; i++) {
      psk[i] = pskBytes[i];
    }
    return Channel(index: index, name: name, psk: psk);
  }

  static const String publicChannelPsk = 'izOH6cXN6mrJ5e26oRXNcg==';
}
