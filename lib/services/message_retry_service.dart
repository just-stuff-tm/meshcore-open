import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';
import '../models/message.dart';
import '../models/path_selection.dart';
import 'storage_service.dart';
import 'app_settings_service.dart';

class _AckHistoryEntry {
  final String messageId;
  final List<Uint8List> ackHashes;
  final DateTime timestamp;

  _AckHistoryEntry({
    required this.messageId,
    required this.ackHashes,
    required this.timestamp,
  });
}

class MessageRetryService extends ChangeNotifier {
  static const int maxRetries = 5;
  static const int maxAckHistorySize = 100;

  final StorageService _storage;
  final Map<String, Timer> _timeoutTimers = {};
  final Map<String, Message> _pendingMessages = {};
  final Map<String, Contact> _pendingContacts = {};
  final Map<String, PathSelection> _pendingPathSelections = {};
  final Map<String, List<Uint8List>> _expectedAckHashes = {}; // Track all expected ACKs for retries
  final List<_AckHistoryEntry> _ackHistory = []; // Rolling buffer of recent ACK hashes

  Function(Contact, String, int, int)? _sendMessageCallback;
  Function(String, Message)? _addMessageCallback;
  Function(Message)? _updateMessageCallback;
  Function(Contact)? _clearContactPathCallback;
  Function(Contact, Uint8List, int)? _setContactPathCallback;
  Function(int, int)? _calculateTimeoutCallback;
  AppSettingsService? _appSettingsService;
  Function(String, PathSelection, bool, int?)? _recordPathResultCallback;

  MessageRetryService(this._storage);

  void initialize({
    required Function(Contact, String, int, int) sendMessageCallback,
    required Function(String, Message) addMessageCallback,
    required Function(Message) updateMessageCallback,
    Function(Contact)? clearContactPathCallback,
    Function(Contact, Uint8List, int)? setContactPathCallback,
    Function(int pathLength, int messageBytes)? calculateTimeoutCallback,
    AppSettingsService? appSettingsService,
    Function(String, PathSelection, bool, int?)? recordPathResultCallback,
  }) {
    _sendMessageCallback = sendMessageCallback;
    _addMessageCallback = addMessageCallback;
    _updateMessageCallback = updateMessageCallback;
    _clearContactPathCallback = clearContactPathCallback;
    _setContactPathCallback = setContactPathCallback;
    _calculateTimeoutCallback = calculateTimeoutCallback;
    _appSettingsService = appSettingsService;
    _recordPathResultCallback = recordPathResultCallback;
  }

  Future<void> sendMessageWithRetry({
    required Contact contact,
    required String text,
    bool clearPath = false,
    PathSelection? pathSelection,
    Uint8List? pathBytes,
    int? pathLength,
  }) async {
    final messageId = const Uuid().v4();
    final useClearPath = clearPath || (pathSelection?.useFlood ?? false);
    final messagePathBytes =
        pathBytes ?? _resolveMessagePathBytes(contact, useClearPath, pathSelection);
    final messagePathLength =
        pathLength ?? _resolveMessagePathLength(contact, useClearPath, pathSelection);
    final message = Message(
      senderKey: contact.publicKey,
      text: text,
      timestamp: DateTime.now(),
      isOutgoing: true,
      status: MessageStatus.pending,
      messageId: messageId,
      retryCount: 0,
      pathLength: messagePathLength,
      pathBytes: messagePathBytes,
    );

    _pendingMessages[messageId] = message;
    _pendingContacts[messageId] = contact;
    if (pathSelection != null) {
      _pendingPathSelections[messageId] = pathSelection;
    }

    if (_addMessageCallback != null) {
      _addMessageCallback!(contact.publicKeyHex, message);
    }

    await _attemptSend(messageId);
  }

  Future<void> _attemptSend(String messageId) async {
    final message = _pendingMessages[messageId];
    final contact = _pendingContacts[messageId];

    if (message == null || contact == null) return;

    // Sync path settings with device before sending
    // Use the path that was captured when the message was first sent
    if (_setContactPathCallback != null && _clearContactPathCallback != null) {
      if (message.pathLength != null && message.pathLength! < 0) {
        // Flood mode - clear the path
        debugPrint('Setting flood mode for retry attempt ${message.retryCount}');
        _clearContactPathCallback!(contact);
      } else if (message.pathLength != null && message.pathLength! >= 0) {
        // Specific path (including direct neighbor with pathLength=0)
        final pathStr = message.pathBytes.isEmpty
            ? 'direct'
            : message.pathBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(',');
        debugPrint('Setting path [$pathStr] (${message.pathLength} hops) for retry attempt ${message.retryCount}');
        await _setContactPathCallback!(contact, message.pathBytes, message.pathLength!);
      }
    }

    final attempt = message.retryCount.clamp(0, 3);

    if (_sendMessageCallback != null) {
      final timestampSeconds = message.timestamp.millisecondsSinceEpoch ~/ 1000;
      _sendMessageCallback!(
        contact,
        message.text,
        attempt,
        timestampSeconds,
      );
    }
  }

  void updateMessageFromSent(Uint8List ackHash, int timeoutMs) {
    for (var entry in _pendingMessages.entries) {
      final message = entry.value;
      // Only update if pending (waiting to send) or already sent with matching ACK
      if (message.status == MessageStatus.pending ||
          (message.status == MessageStatus.sent &&
           message.expectedAckHash != null &&
           listEquals(message.expectedAckHash, ackHash))) {
        final contact = _pendingContacts[entry.key];
        final selection = _pendingPathSelections[entry.key];

        // Add this ACK hash to the list of expected ACKs for this message
        _expectedAckHashes[entry.key] ??= [];
        if (!_expectedAckHashes[entry.key]!.any((hash) => listEquals(hash, ackHash))) {
          _expectedAckHashes[entry.key]!.add(Uint8List.fromList(ackHash));
          debugPrint('Added ACK hash ${ackHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()} to message ${entry.key} (total: ${_expectedAckHashes[entry.key]!.length})');
        }

        // Use device-provided timeout, or calculate from radio settings if timeout is 0 or invalid
        int actualTimeout = timeoutMs;
        if (timeoutMs <= 0 && _calculateTimeoutCallback != null && contact != null) {
          int pathLengthValue;
          if (selection != null) {
            pathLengthValue = selection.useFlood ? -1 : selection.hopCount;
            if (pathLengthValue < 0) pathLengthValue = contact.pathLength;
          } else if (message.pathLength != null) {
            pathLengthValue = message.pathLength!;
          } else {
            pathLengthValue = contact.pathLength;
          }
          actualTimeout = _calculateTimeoutCallback!(pathLengthValue, message.text.length);
          debugPrint('Using calculated timeout: ${actualTimeout}ms for ${contact.pathLength} hops');
        }

        final updatedMessage = message.copyWith(
          status: MessageStatus.sent,
          expectedAckHash: ackHash, // Keep the most recent one for display
          estimatedTimeoutMs: actualTimeout,
          sentAt: DateTime.now(),
        );

        _pendingMessages[entry.key] = updatedMessage;

        if (_updateMessageCallback != null) {
          _updateMessageCallback!(updatedMessage);
        }

        _startTimeoutTimer(entry.key, actualTimeout);
        debugPrint('Updated message ${entry.key} with ACK hash: ${ackHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
        return;
      }
    }
    debugPrint('No pending message found for ACK hash: ${ackHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
  }

  void _startTimeoutTimer(String messageId, int timeoutMs) {
    _timeoutTimers[messageId]?.cancel();
    _timeoutTimers[messageId] = Timer(Duration(milliseconds: timeoutMs), () {
      _handleTimeout(messageId);
    });
  }

  void _handleTimeout(String messageId) {
    final message = _pendingMessages[messageId];
    final contact = _pendingContacts[messageId];
    final selection = _pendingPathSelections[messageId];

    if (message == null || contact == null) return;

    debugPrint('Timeout for message $messageId (retry ${message.retryCount}/${maxRetries - 1})');

    if (message.retryCount < maxRetries - 1) {
      final backoffMs = 1000 * (1 << message.retryCount);

      final updatedMessage = message.copyWith(
        retryCount: message.retryCount + 1,
        status: MessageStatus.pending,
        // Keep expectedAckHash - it will be updated when the new attempt is sent
      );

      _pendingMessages[messageId] = updatedMessage;

      if (_updateMessageCallback != null) {
        _updateMessageCallback!(updatedMessage);
      }

      debugPrint('Scheduling retry after ${backoffMs}ms');
      Timer(Duration(milliseconds: backoffMs), () {
        _attemptSend(messageId);
      });
    } else {
      // Max retries reached - mark as failed
      final failedMessage = message.copyWith(status: MessageStatus.failed);

      // Move ACK hashes to history before removing
      _moveAckHashesToHistory(messageId);

      _pendingMessages.remove(messageId);
      _pendingContacts.remove(messageId);
      _pendingPathSelections.remove(messageId);
      _timeoutTimers[messageId]?.cancel();
      _timeoutTimers.remove(messageId);

      // Check if we should clear the path on max retry
      if (_appSettingsService?.settings.clearPathOnMaxRetry == true &&
          _clearContactPathCallback != null) {
        _clearContactPathCallback!(contact);
      }

      _recordPathResultFromMessage(contact.publicKeyHex, message, selection, false, null);

      if (_updateMessageCallback != null) {
        _updateMessageCallback!(failedMessage);
      }

      notifyListeners();
    }
  }

  void _moveAckHashesToHistory(String messageId) {
    final ackHashes = _expectedAckHashes.remove(messageId);
    if (ackHashes != null && ackHashes.isNotEmpty) {
      _ackHistory.add(_AckHistoryEntry(
        messageId: messageId,
        ackHashes: ackHashes,
        timestamp: DateTime.now(),
      ));

      // Trim history to max size (rolling buffer)
      while (_ackHistory.length > maxAckHistorySize) {
        _ackHistory.removeAt(0);
      }

      debugPrint('Moved ${ackHashes.length} ACK hashes to history for message $messageId (history size: ${_ackHistory.length})');
    }
  }

  bool _checkAckHistory(Uint8List ackHash) {
    for (final entry in _ackHistory) {
      for (final expectedHash in entry.ackHashes) {
        if (listEquals(expectedHash, ackHash)) {
          debugPrint('Found ACK match in history: messageId=${entry.messageId}, age=${DateTime.now().difference(entry.timestamp).inSeconds}s');
          return true;
        }
      }
    }
    return false;
  }

  void handleAckReceived(Uint8List ackHash, int tripTimeMs) {
    String? matchedMessageId;
    final ackHashHex = ackHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    debugPrint('ACK received: $ackHashHex, trip time: ${tripTimeMs}ms');
    debugPrint('Pending messages:');
    for (var entry in _pendingMessages.entries) {
      final message = entry.value;
      final expectedHex = message.expectedAckHash?.map((b) => b.toRadixString(16).padLeft(2, '0')).join() ?? 'none';
      final allExpectedHashes = _expectedAckHashes[entry.key]?.map((h) => h.map((b) => b.toRadixString(16).padLeft(2, '0')).join()).join(', ') ?? 'none';
      debugPrint('  ${entry.key}: status=${message.status}, latestAck=$expectedHex, allAcks=[$allExpectedHashes], retry=${message.retryCount}');
    }

    // Check against ALL expected ACK hashes (from all retry attempts)
    for (var entry in _expectedAckHashes.entries) {
      final messageId = entry.key;
      final expectedHashes = entry.value;

      for (final expectedHash in expectedHashes) {
        if (listEquals(expectedHash, ackHash)) {
          matchedMessageId = messageId;
          debugPrint('Matched ACK to message: $matchedMessageId (matched hash from attempt ${expectedHashes.indexOf(expectedHash)})');
          break;
        }
      }

      if (matchedMessageId != null) break;
    }

    if (matchedMessageId != null) {
      final message = _pendingMessages[matchedMessageId]!;
      final contact = _pendingContacts[matchedMessageId];
      final selection = _pendingPathSelections[matchedMessageId];

      // Cancel any pending timeout or retry
      _timeoutTimers[matchedMessageId]?.cancel();
      _timeoutTimers.remove(matchedMessageId);

      final deliveredMessage = message.copyWith(
        status: MessageStatus.delivered,
        deliveredAt: DateTime.now(),
        tripTimeMs: tripTimeMs,
      );

      // Move ACK hashes to history before removing
      _moveAckHashesToHistory(matchedMessageId);

      _pendingMessages.remove(matchedMessageId);
      _pendingContacts.remove(matchedMessageId);
      _pendingPathSelections.remove(matchedMessageId);

      if (_updateMessageCallback != null) {
        _updateMessageCallback!(deliveredMessage);
      }

      if (contact != null) {
        _recordPathResultFromMessage(contact.publicKeyHex, message, selection, true, tripTimeMs);
      }

      notifyListeners();
    } else {
      // Check ACK history for recently completed messages
      if (_checkAckHistory(ackHash)) {
        debugPrint('ACK matched a recently completed message from history');
      } else {
        debugPrint('No matching message found for ACK: $ackHashHex');
      }
    }
  }

  Uint8List _resolveMessagePathBytes(
    Contact contact,
    bool forceFlood,
    PathSelection? selection,
  ) {
    if (forceFlood || contact.pathLength < 0 || selection?.useFlood == true) {
      return Uint8List(0);
    }
    if (selection != null && selection.pathBytes.isNotEmpty) {
      return Uint8List.fromList(selection.pathBytes);
    }
    return contact.path;
  }

  int? _resolveMessagePathLength(
    Contact contact,
    bool forceFlood,
    PathSelection? selection,
  ) {
    if (forceFlood || contact.pathLength < 0 || selection?.useFlood == true) {
      return -1;
    }
    if (selection != null && selection.pathBytes.isNotEmpty) {
      return selection.hopCount;
    }
    return contact.pathLength;
  }

  String? getContactKeyForAckHash(Uint8List ackHash) {
    for (var entry in _pendingMessages.entries) {
      final message = entry.value;
      if (message.expectedAckHash != null &&
          listEquals(message.expectedAckHash, ackHash)) {
        final contact = _pendingContacts[entry.key];
        return contact?.publicKeyHex;
      }
    }
    return null;
  }

  int calculateDefaultTimeout(Contact contact) {
    if (contact.pathLength < 0) {
      return 15000;
    } else {
      return 3000 + (3000 * contact.pathLength);
    }
  }

  void _recordPathResultFromMessage(
    String contactKey,
    Message message,
    PathSelection? selection,
    bool success,
    int? tripTimeMs,
  ) {
    if (_recordPathResultCallback == null) return;
    final recordSelection = selection ?? _selectionFromMessage(message);
    if (recordSelection == null) return;
    _recordPathResultCallback!(contactKey, recordSelection, success, tripTimeMs);
  }

  PathSelection? _selectionFromMessage(Message message) {
    if (message.pathLength != null && message.pathLength! < 0) {
      return const PathSelection(pathBytes: [], hopCount: -1, useFlood: true);
    }
    if (message.pathBytes.isEmpty && message.pathLength == null) {
      return null;
    }
    return PathSelection(
      pathBytes: message.pathBytes,
      hopCount: message.pathLength ?? message.pathBytes.length,
      useFlood: false,
    );
  }

  @override
  void dispose() {
    for (var timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
    _pendingMessages.clear();
    _pendingContacts.clear();
    _pendingPathSelections.clear();
    _expectedAckHashes.clear();
    _ackHistory.clear();
    super.dispose();
  }
}
