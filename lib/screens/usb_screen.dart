import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_connector_usb.dart';
import '../l10n/l10n.dart';
import '../utils/platform_info.dart';
import '../utils/usb_port_labels.dart';
import 'contacts_screen.dart';
import 'scanner_screen.dart';

class UsbScreen extends StatefulWidget {
  const UsbScreen({super.key});

  @override
  State<UsbScreen> createState() => _UsbScreenState();
}

class _UsbScreenState extends State<UsbScreen> {
  final List<String> _ports = <String>[];
  bool _isLoadingPorts = true;
  bool _isConnecting = false;
  bool _navigatedToContacts = false;
  bool _didScheduleInitialLoad = false;
  String? _selectedPort;
  String? _connectedPortDisplayLabel;
  String? _errorText;
  late final MeshCoreConnector _connector;
  late final MeshCoreConnectorUsb _usbConnector;
  late final VoidCallback _connectionListener;

  @override
  void initState() {
    super.initState();
    _connector = context.read<MeshCoreConnector>();
    _usbConnector = MeshCoreConnectorUsb(_connector);
    _connectionListener = () {
      if (!mounted) return;
      final activeUsbPortDisplayLabel = _usbConnector.activeUsbPortDisplayLabel;
      final shouldUpdateDisplayLabel =
          activeUsbPortDisplayLabel != _connectedPortDisplayLabel;
      if (_usbConnector.state == MeshCoreConnectionState.disconnected) {
        _navigatedToContacts = false;
        setState(() {
          _isConnecting = false;
          _connectedPortDisplayLabel = activeUsbPortDisplayLabel;
        });
      } else if (shouldUpdateDisplayLabel) {
        setState(() {
          _connectedPortDisplayLabel = activeUsbPortDisplayLabel;
        });
      }
      if (_usbConnector.state == MeshCoreConnectionState.connected &&
          _usbConnector.isUsbTransportConnected &&
          !_navigatedToContacts) {
        _navigatedToContacts = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );
      }
    };
    _usbConnector.addListener(_connectionListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _usbConnector.setRequestPortLabel(context.l10n.usbScreenStatus);
    if (!_didScheduleInitialLoad) {
      _didScheduleInitialLoad = true;
      unawaited(_loadPorts());
    }
  }

  @override
  void dispose() {
    _usbConnector.removeListener(_connectionListener);
    if (!_navigatedToContacts &&
        _usbConnector.activeTransport == MeshCoreTransportType.usb &&
        _usbConnector.state != MeshCoreConnectionState.disconnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_usbConnector.disconnect(manual: true));
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            debugPrint('UsbScreen: back button pressed');
            Navigator.of(context).maybePop();
          },
        ),
        title: Text(
          l10n.connectionChoiceUsbLabel,
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: [
          if (PlatformInfo.isWeb ||
              PlatformInfo.isAndroid ||
              PlatformInfo.isIOS)
            TextButton.icon(
              onPressed: () {
                debugPrint(
                  'UsbScreen: Bluetooth selected, opening ScannerScreen',
                );
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ScannerScreen()),
                );
              },
              icon: const Icon(Icons.bluetooth),
              label: Text(l10n.connectionChoiceBluetoothLabel),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : 600.0;
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 800.0;
            final gap = math.max(8.0, math.min(16.0, availableHeight * 0.025));
            final iconSize = math.max(
              28.0,
              math.min(72.0, availableHeight * 0.12),
            );
            final isNarrow = availableWidth < 460.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    flex: 3,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.usb,
                            size: iconSize,
                            color: theme.colorScheme.primary,
                          ),
                          SizedBox(height: gap),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.usbScreenTitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: math.max(4.0, gap * 0.5)),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l10n.usbScreenSubtitle,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: gap),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Chip(
                              label: Text(
                                _connectedPortDisplayLabel != null &&
                                        _connectedPortDisplayLabel!.isNotEmpty
                                    ? _friendlyPortName(
                                        _connectedPortDisplayLabel!,
                                      )
                                    : _selectedPort == null
                                    ? l10n.usbScreenStatus
                                    : _friendlyPortName(_selectedPort!),
                                overflow: TextOverflow.ellipsis,
                              ),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  Expanded(child: _buildPortList(context)),
                  if (_errorText != null) ...[
                    SizedBox(height: gap),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _errorText!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: gap),
                  if (isNarrow)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isLoadingPorts || _isConnecting
                              ? null
                              : () {
                                  debugPrint(
                                    'UsbScreen: refresh ports pressed',
                                  );
                                  _loadPorts();
                                },
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.repeater_refresh),
                        ),
                        SizedBox(height: gap),
                        FilledButton.icon(
                          onPressed: _canConnect
                              ? () {
                                  final rawPortName = normalizeUsbPortName(
                                    _selectedPort!,
                                  );
                                  debugPrint(
                                    'UsbScreen: connect pressed for $_selectedPort (raw: $rawPortName)',
                                  );
                                  _connectSelectedPort();
                                }
                              : null,
                          icon: _isConnecting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.usb),
                          label: Text(l10n.common_connect),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingPorts || _isConnecting
                                ? null
                                : () {
                                    debugPrint(
                                      'UsbScreen: refresh ports pressed',
                                    );
                                    _loadPorts();
                                  },
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.repeater_refresh),
                          ),
                        ),
                        SizedBox(width: gap),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _canConnect
                                ? () {
                                    final rawPortName = normalizeUsbPortName(
                                      _selectedPort!,
                                    );
                                    debugPrint(
                                      'UsbScreen: connect pressed for $_selectedPort (raw: $rawPortName)',
                                    );
                                    _connectSelectedPort();
                                  }
                                : null,
                            icon: _isConnecting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.usb),
                            label: Text(l10n.common_connect),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: math.max(4.0, gap * 0.75)),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.usbScreenNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _canConnect =>
      !_isLoadingPorts &&
      !_isConnecting &&
      _selectedPort != null &&
      _selectedPort!.isNotEmpty;

  Widget _buildPortList(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (_isLoadingPorts) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.common_loading),
          ],
        ),
      );
    }

    if (_ports.isEmpty) {
      return Center(
        child: Text(
          l10n.usbScreenEmptyState,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: _ports.length,
      itemBuilder: (context, index) {
        final port = _ports[index];
        final isSelected = port == _selectedPort;
        final displayName = _friendlyPortName(port);
        final rawName = normalizeUsbPortName(port);
        final showRawName =
            rawName != displayName && !rawName.startsWith('web:');
        return Material(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            onTap: _isConnecting
                ? null
                : () {
                    setState(() {
                      _selectedPort = port;
                      _errorText = null;
                    });
                    debugPrint('UsbScreen: selected port $port');
                  },
            leading: Icon(
              Icons.usb,
              color: isSelected
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
              ),
            ),
            subtitle: showRawName
                ? Text(
                    rawName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : null,
            trailing: isSelected
                ? Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.onPrimaryContainer,
                  )
                : null,
          ),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 10),
    );
  }

  Future<void> _loadPorts() async {
    if (!mounted) return;
    _usbConnector.setRequestPortLabel(context.l10n.usbScreenStatus);

    setState(() {
      _isLoadingPorts = true;
      _errorText = null;
    });

    try {
      final ports = await _usbConnector.listPorts();
      if (!mounted) return;
      setState(() {
        _ports
          ..clear()
          ..addAll(ports);
        if (_ports.isEmpty) {
          _selectedPort = null;
        } else if (!_ports.contains(_selectedPort)) {
          _selectedPort = _ports.first;
        }
        _isLoadingPorts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _ports.clear();
        _selectedPort = null;
        _errorText = error.toString();
        _isLoadingPorts = false;
      });
    }
  }

  Future<void> _connectSelectedPort() async {
    final selectedPort = _selectedPort;
    if (selectedPort == null || selectedPort.isEmpty) {
      return;
    }
    _usbConnector.setRequestPortLabel(context.l10n.usbScreenStatus);
    if (_usbConnector.state != MeshCoreConnectionState.disconnected) {
      setState(() {
        _isConnecting = false;
        _errorText = null;
      });
      return;
    }
    final rawPortName = normalizeUsbPortName(selectedPort);

    setState(() {
      _isConnecting = true;
      _errorText = null;
    });

    try {
      await _usbConnector.connect(portName: rawPortName);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _errorText = error.toString();
      });
    }
  }

  String _friendlyPortName(String portLabel) => friendlyUsbPortName(portLabel);
}
