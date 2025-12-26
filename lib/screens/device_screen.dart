import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import 'channels_screen.dart';
import 'contacts_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Main hub screen after connecting to a MeshCore device
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  bool _showBatteryVoltage = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshCoreConnector>(
      builder: (context, connector, child) {
        // If disconnected, pop back to scanner
        if (!connector.isConnected) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.popUntil(context, (route) => route.isFirst);
            }
          });
        }

        return PopScope(
          canPop: false,
          child: Scaffold(
            appBar: AppBar(
              title: Text(connector.device?.platformName ?? 'MeshCore Device'),
              centerTitle: true,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.bluetooth_disabled),
                  tooltip: 'Disconnect',
                  onPressed: () => _disconnect(context, connector),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Connection status card
                  _buildStatusCard(connector, context),

                  const SizedBox(height: 24),

                  // Navigation grid
                  Expanded(
                    child: _buildNavigationGrid(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(MeshCoreConnector connector, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.bluetooth_connected, color: Colors.green, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    connector.device?.platformName ?? 'Unknown Device',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    connector.device?.remoteId.toString() ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildBatteryIndicator(connector, context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryIndicator(MeshCoreConnector connector, BuildContext context) {
    final percent = connector.batteryPercent;
    final millivolts = connector.batteryMillivolts;
    final percentLabel = percent != null ? '$percent%' : '--%';
    final voltageLabel = millivolts == null
        ? '-- V'
        : '${(millivolts / 1000.0).toStringAsFixed(2)} V';
    final displayLabel = _showBatteryVoltage ? voltageLabel : percentLabel;
    final icon = _batteryIcon(percent);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _showBatteryVoltage = !_showBatteryVoltage;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 4),
            Text(
              displayLabel,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _batteryIcon(int? percent) {
    if (percent == null) return Icons.battery_unknown;
    if (percent <= 15) return Icons.battery_alert;
    return Icons.battery_full;
  }

  Widget _buildNavigationGrid(BuildContext context) {
    final items = [
      _NavItem(
        icon: Icons.people_outline,
        label: 'Contacts',
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ContactsScreen()),
        ),
      ),
      _NavItem(
        icon: Icons.tag,
        label: 'Channels',
        color: Colors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChannelsScreen()),
        ),
      ),
      _NavItem(
        icon: Icons.map_outlined,
        label: 'Map',
        color: Colors.orange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MapScreen()),
        ),
      ),
      _NavItem(
        icon: Icons.settings_outlined,
        label: 'Settings',
        color: Colors.grey,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ),
      ),
    ];

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildNavCard(item);
      },
    );
  }

  Widget _buildNavCard(_NavItem item) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 48,
              color: item.color,
            ),
            const SizedBox(height: 12),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _disconnect(BuildContext context, MeshCoreConnector connector) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect'),
        content: const Text('Are you sure you want to disconnect from this device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await connector.disconnect();
    }
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  _NavItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
