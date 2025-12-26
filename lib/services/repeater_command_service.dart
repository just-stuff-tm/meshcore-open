import 'dart:async';
import 'dart:typed_data';
import '../models/contact.dart';
import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';

class RepeaterCommandService {
  final MeshCoreConnector _connector;
  final Map<String, Completer<String>> _pendingCommands = {};
  final Map<String, Timer> _commandTimeouts = {};
  final Map<String, String> _commandPrefixes = {};
  final Map<String, String> _pendingByPrefix = {};
  int _prefixCounter = 0;

  static const int timeoutSeconds = 10; // Flood mode timeout
  static const int maxRetries = 5;

  RepeaterCommandService(this._connector);

  /// Send a CLI command to a repeater with automatic retries
  /// Returns a future that completes when a response is received or after max retries
  Future<String> sendCommand(
    Contact repeater,
    String command, {
    Function(String)? onResponse,
    Function(int)? onAttempt,
  }) async {
    final repeaterKey = repeater.publicKeyHex;
    final hasPending = _pendingCommands.keys.any((id) => id.startsWith(repeaterKey));
    if (hasPending) {
      throw Exception('Another command is still awaiting a response.');
    }

    // Create completer for this command
    final commandId = '${repeaterKey}_${DateTime.now().millisecondsSinceEpoch}';
    final completer = Completer<String>();
    _pendingCommands[commandId] = completer;

    onAttempt?.call(0);

    // Send frame once (no retries)
    try {
      final prefix = _nextPrefixToken();
      _commandPrefixes[commandId] = prefix;
      _pendingByPrefix[prefix] = commandId;
      final framedCommand = '$prefix$command';
      final frame = buildSendCliCommandFrame(repeater.publicKey, framedCommand, attempt: 0);
      await _connector.sendFrame(frame);
    } catch (e) {
      _cleanup(commandId);
      throw Exception('Failed to send command: $e');
    }

    // Set timeout for this attempt
    _commandTimeouts[commandId]?.cancel();
    _commandTimeouts[commandId] = Timer(
      Duration(seconds: timeoutSeconds),
      () {
        final completer = _pendingCommands[commandId];
        if (completer != null && !completer.isCompleted) {
          completer.completeError('Command timeout after $timeoutSeconds seconds');
          _cleanup(commandId);
        }
      },
    );

    // Wait for response or timeout
    try {
      final response = await completer.future;
      return response;
    } finally {
      _cleanup(commandId);
    }
  }

  /// Call this when a text message response is received from a repeater
  void handleResponse(Contact repeater, String responseText) {
    // Find pending command for this repeater and complete it
    final repeaterKey = repeater.publicKeyHex;

    String? commandId;
    String responsePayload = responseText;
    if (responseText.length >= 3 && responseText[2] == '|') {
      final prefix = responseText.substring(0, 3);
      commandId = _pendingByPrefix[prefix];
      responsePayload = responseText.substring(3).trimLeft();
    }

    commandId ??= _pendingCommands.keys.firstWhere(
      (id) => id.startsWith(repeaterKey),
      orElse: () => '',
    );

    if (commandId.isEmpty) return;

    final completer = _pendingCommands[commandId];
    if (completer != null && !completer.isCompleted) {
      completer.complete(responsePayload);
      _cleanup(commandId);
    }
  }

  void _cleanup(String commandId) {
    _commandTimeouts[commandId]?.cancel();
    _commandTimeouts.remove(commandId);
    _pendingCommands.remove(commandId);
    final prefix = _commandPrefixes.remove(commandId);
    if (prefix != null) {
      _pendingByPrefix.remove(prefix);
    }
  }

  void dispose() {
    for (final timer in _commandTimeouts.values) {
      timer.cancel();
    }
    _commandTimeouts.clear();
    _pendingCommands.clear();
    _commandPrefixes.clear();
    _pendingByPrefix.clear();
  }

  String _nextPrefixToken() {
    for (var i = 0; i < 256; i++) {
      final value = _prefixCounter++ & 0xFF;
      final token = '${value.toRadixString(16).padLeft(2, '0').toUpperCase()}|';
      if (!_pendingByPrefix.containsKey(token)) {
        return token;
      }
    }
    return '00|';
  }
}
