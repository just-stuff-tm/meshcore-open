import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../widgets/debug_frame_viewer.dart';
import '../services/repeater_command_service.dart';

class RepeaterCliScreen extends StatefulWidget {
  final Contact repeater;
  final String password;

  const RepeaterCliScreen({
    super.key,
    required this.repeater,
    required this.password,
  });

  @override
  State<RepeaterCliScreen> createState() => _RepeaterCliScreenState();
}

class _RepeaterCliScreenState extends State<RepeaterCliScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _commandHistory = [];
  int _historyIndex = -1;
  StreamSubscription<Uint8List>? _frameSubscription;
  RepeaterCommandService? _commandService;

  // Common commands for quick access
  final List<Map<String, String>> _quickCommands = [
    {'label': 'Get Name', 'command': 'get name'},
    {'label': 'Get Radio', 'command': 'get radio'},
    {'label': 'Get TX', 'command': 'get tx'},
    {'label': 'Neighbors', 'command': 'neighbors'},
    {'label': 'Version', 'command': 'ver'},
    {'label': 'Advertise', 'command': 'advert'},
    {'label': 'Clock', 'command': 'clock'},
  ];

  @override
  void initState() {
    super.initState();
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);
    _commandService = RepeaterCommandService(connector);
    _setupMessageListener();
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    _commandService?.dispose();
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupMessageListener() {
    final connector = Provider.of<MeshCoreConnector>(context, listen: false);

    // Listen for incoming text messages from the repeater
    _frameSubscription = connector.receivedFrames.listen((frame) {
      if (frame.isEmpty) return;

      // Check if it's a text message response
      if (frame[0] == respCodeContactMsgRecv ||
          frame[0] == respCodeContactMsgRecvV3) {
        _handleTextMessageResponse(frame);
      }
    });
  }

  void _handleTextMessageResponse(Uint8List frame) {
    final parsed = parseContactMessageText(frame);
    if (parsed == null) return;
    if (!_matchesRepeaterPrefix(parsed.senderPrefix)) return;

    // Notify command service of response (for retry handling)
    _commandService?.handleResponse(widget.repeater, parsed.text);

    // Note: The command service will handle the response via the Future
    // We don't need to add it to history here anymore as _sendCommand will do it
  }

  bool _matchesRepeaterPrefix(Uint8List prefix) {
    final target = widget.repeater.publicKey;
    if (target.length < 6 || prefix.length < 6) return false;
    for (int i = 0; i < 6; i++) {
      if (prefix[i] != target[i]) return false;
    }
    return true;
  }

  void _sendCommand({bool showDebug = false}) async {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    setState(() {
      _commandHistory.add({
        'type': 'command',
        'text': command,
        'timestamp': DateTime.now().toString(),
      });
    });

    // Show debug info if requested
    if (showDebug && mounted) {
      final frame = buildSendCliCommandFrame(widget.repeater.publicKey, command);
      DebugFrameViewer.showFrameDebug(context, frame, 'CLI Command Frame');
    }

    // Send CLI command to repeater with retry
    try {
      if (_commandService != null) {
        final response = await _commandService!.sendCommand(
          widget.repeater,
          command,
        );

        if (mounted) {
          setState(() {
            _commandHistory.add({
              'type': 'response',
              'text': response,
              'timestamp': DateTime.now().toString(),
            });
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _commandHistory.add({
            'type': 'response',
            'text': 'Error: $e',
            'timestamp': DateTime.now().toString(),
          });
        });
      }
    }

    _commandController.clear();
    _historyIndex = -1;

    // Auto-scroll to bottom
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useQuickCommand(String command) {
    _commandController.text = command;
    _sendCommand();
  }

  void _navigateHistory(bool up) {
    final commands = _commandHistory
        .where((entry) => entry['type'] == 'command')
        .toList()
        .reversed
        .toList();

    if (commands.isEmpty) return;

    if (up) {
      if (_historyIndex < commands.length - 1) {
        _historyIndex++;
      }
    } else {
      if (_historyIndex > 0) {
        _historyIndex--;
      } else {
        _historyIndex = -1;
        _commandController.clear();
        return;
      }
    }

    if (_historyIndex >= 0 && _historyIndex < commands.length) {
      _commandController.text = commands[_historyIndex]['text'] ?? '';
      _commandController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commandController.text.length),
      );
    }
  }

  void _clearHistory() {
    setState(() {
      _commandHistory.clear();
      _historyIndex = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Repeater CLI'),
            Text(
              widget.repeater.name,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Next Command',
            onPressed: () {
              // Set a flag or just send next command with debug
              if (_commandController.text.trim().isNotEmpty) {
                _sendCommand(showDebug: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a command first')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Command Help',
            onPressed: () => _showCommandHelp(context),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear History',
            onPressed: _commandHistory.isEmpty ? null : _clearHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildQuickCommandsBar(),
          const Divider(height: 1),
          Expanded(
            child: _commandHistory.isEmpty
                ? _buildEmptyState()
                : _buildCommandHistory(),
          ),
          const Divider(height: 1),
          _buildCommandInput(),
        ],
      ),
    );
  }

  Widget _buildQuickCommandsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickCommands.map((cmd) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(cmd['label']!),
                onPressed: () => _useQuickCommand(cmd['command']!),
                avatar: const Icon(Icons.play_arrow, size: 16),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.terminal, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No commands sent yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Type a command below or use quick commands',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildCommandHistory() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _commandHistory.length,
      itemBuilder: (context, index) {
        final entry = _commandHistory[index];
        final isCommand = entry['type'] == 'command';

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isCommand
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  isCommand ? Icons.chevron_right : Icons.arrow_back,
                  size: 16,
                  color: isCommand
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      entry['text']!,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: isCommand
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward, size: 20),
              tooltip: 'Previous command',
              onPressed: () => _navigateHistory(true),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward, size: 20),
              tooltip: 'Next command',
              onPressed: () => _navigateHistory(false),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _commandController,
                decoration: const InputDecoration(
                  hintText: 'Enter command...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  prefixText: '> ',
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendCommand(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: _sendCommand,
            ),
          ],
        ),
      ),
    );
  }

  void _showCommandHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Commands List'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NOTE: for the various "set ..." commands, there is also a "get ..." command.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              _buildHelpSection('General', [
                'advert - Sends an advertisement packet',
                "reboot - Reboots the device. (note, you'll prob get 'Timeout' which is normal)",
                "clock - Displays current time per device's clock.",
                'password {new-password} - Sets a new admin password for the device.',
                'ver - Shows the device version and firmware build date.',
                'clear stats - Resets various stats counters to zero.',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('Settings', [
                'set af {air-time-factor} - Sets the air-time-factor.',
                'set tx {tx-power-dbm} - Sets LoRa transmit power in dBm. (reboot to apply)',
                'set repeat {on|off} - Enables or disables the repeater role for this node.',
                "set allow.read.only {on|off} - (Room server) If 'on', then login in blank password will be allowed, but cannot Post to room. (just read only)",
                'set flood.max {max-hops} - Sets the maximum number of hops of inbound flood packet (if >= max, packet is not forwarded)',
                'set int.thresh {db} - Sets the Interference Threshold (in DB). Default is 14. Set to 0 to disable channel interference detection.',
                'set agc.reset.interval {seconds} - Sets the interval to reset the Auto Gain Controller. Set to 0 to disable.',
                "set multi.acks {0|1} - Enables or disables the 'double ACKs' feature.",
                'set advert.interval {minutes} - Sets the timer interval in minutes to send a local (zero-hop) advertisement packet. Set to 0 to disable.',
                'set flood.advert.interval {hours} - Sets the timer interval in hours to send a flood advertisement packet. Set to 0 to disable.',
                'set guest.password {guess-password} - Sets/updates the guest password. (for repeaters, guest logins can send the "Get Stats" request)',
                'set name {name} - Sets the advertisement name.',
                'set lat {latitude} - Sets the advertisement map latitude. (decimal degrees)',
                'set lon {longitude} - Sets the advertisement map longitude. (decimal degrees)',
                'set radio {freq},{bw},{sf},{cr} - Sets completely new radio params, and saves to preferences. Requires a "reboot" command to apply.',
                'set rxdelay {base} - Sets (experimental) base (must be > 1 for effect) for applying slight delay to received packets, based on signal strength/score. Set to 0 to disable.',
                'set txdelay {factor} - Sets a factor multiplied with time-on-air for a flood-mode packet and with a randomized slot system, to delay its forwarding. (to decrease likelihood of collisions)',
                'set direct.txdelay {factor} - Same as txdelay, but for applying a random delay to the forwarding of direct-mode packets.',
                'set bridge.enabled {on|off} - Enable/Disable bridge.',
                'set bridge.delay {0-10000} - Set delay before retransmitting packets.',
                'set bridge.source {rx|tx} - Choose wether the bridge will retransmit received packets or transmitted packets.',
                'set bridge.baud {speed} - Set serial link baudrate for rs232 bridges.',
                'set bridge.secret {shared-secret} - Set bridge secret for espnow bridges.',
                'set adc.multiplier {factor} - Sets custom factor to adjust reported battery voltage (only supported on select boards).',
                'tempradio {freq},{bw},{sf},{cr},{minutes} - Sets temporary radio params for the given number of {minutes}, reverting to original radio params afterward. (does NOT save to preferences).',
                'setperm {pubkey-hex} {permissions} - Modifies the ACL. Removes matching entry (by pubkey prefix) if "permissions" is zero. Adds new entry if pubkey-hex is full length and is not currently in ACL. Updates entry by matching pubkey prefix. Permission bits vary per firmware role, but low 2 bits are: 0 (Guest), 1 (Read only), 2 (Read write), 3 (Admin)',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('Bridge', [
                'get bridge.type - Gets bridge type none, rs232, espnow',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('Logging', [
                'log start - Starts packet logging to file system.',
                'log stop - Stops packet logging to file system.',
                'log erase - Erases the packet logs from file system.',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('Neighbors (Repeater only)', [
                'neighbors - Shows a list of other repeater nodes heard via zero-hop adverts. Each line is {id-prefix-hex}:{timestamp}:{snr-times-4}',
                'neighbor.remove {pubkey-prefix} - Removes first matching entry (by pubkey prefix (hex)), from neighbors list.',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('Region Management (Repeater only)', [
                'region commands have been introduced to manage region definitions and permissions.',
                'region - (serial only) Lists all defined regions and current flood permissions.',
                'region load - NOTE: this is a special multi-command invocation. Each subsequent command is a region name (indented with spaces to indicate parent hierarchy, with one space at minimum). Terminated by sending a blank line/command.',
                "region get {* | name-prefix} - Searches for region with given name prefix (or '*' for the global scope). Replies with \"-> {region-name} ({parent-name}) {'F'}\"",
                'region put {name} {* | parent-name-prefix} - Adds or updates a region definition with given name.',
                'region remove {name} - Removes a region definition with given name. (must match exactly, and have no child regions)',
                "region allowf {* | name-prefix} - Sets the 'F'lood permission for the given region. ('*' for the global/legacy scope)",
                "region denyf {* | name-prefix} - Removes the 'F'lood permission for the given region. (NOTE: at this stage NOT advised to use this on the global/legacy scope!!)",
                "region home - Replies with the current 'home' region. (Note applied anywhere yet, reserved for future)",
                "region home {* | name-prefix} - Sets the 'home' region.",
                'region save - Persists the region list/map to storage.',
              ]),
              const SizedBox(height: 16),
              _buildHelpSection('GPS Management', [
                'gps command has been introduced to manage location related topics.',
                'gps - Gives status of gps. When gps is off, it replies only off, if on it replies with on, {status}, {fix}, {sat count}',
                'gps {on|off} - Toggles gps power state.',
                'gps sync - Syncs node time with gps clock.',
                "gps setloc - Sets node's position to gps coordinates and save preferences.",
                'gps advert - Gives location advert configuration of the node:',
                "none: don't include location in adverts",
                'share: share gps location (from SensorManager)',
                'prefs: advert the location stored in preferences',
                'gps advert {none|share|prefs} - Sets location advert configuration.',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, List<String> commands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        ...commands.map((cmd) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Text(
                '• $cmd',
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              ),
            )),
      ],
    );
  }
}
