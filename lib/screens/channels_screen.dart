import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../models/channel.dart';
import 'channel_chat_screen.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MeshCoreConnector>().getChannels();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<MeshCoreConnector>().getChannels(),
          ),
        ],
      ),
      body: Consumer<MeshCoreConnector>(
        builder: (context, connector, child) {
          if (connector.isLoadingChannels) {
            return const Center(child: CircularProgressIndicator());
          }

          final channels = connector.channels;

          if (channels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tag, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No channels configured',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _addPublicChannel(context, connector),
                    icon: const Icon(Icons.public),
                    label: const Text('Add Public Channel'),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: channels.length,
            onReorder: (oldIndex, newIndex) async {
              if (newIndex > oldIndex) newIndex -= 1;
              final reordered = List<Channel>.from(channels);
              final item = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, item);
              await connector.setChannelOrder(
                reordered.map((c) => c.index).toList(),
              );
            },
            itemBuilder: (context, index) {
              final channel = channels[index];
              return _buildChannelTile(context, connector, channel);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddChannelDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildChannelTile(
    BuildContext context,
    MeshCoreConnector connector,
    Channel channel,
  ) {
    return Card(
      key: ValueKey('channel_${channel.index}'),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: channel.isPublicChannel
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.blue.withValues(alpha: 0.2),
          child: Icon(
            channel.isPublicChannel
                ? Icons.public
                : channel.name.startsWith('#')
                    ? Icons.tag
                    : Icons.lock,
            color: channel.isPublicChannel ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(
          channel.name.isEmpty ? 'Channel ${channel.index}' : channel.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
          subtitle: Text(
            channel.name.startsWith('#')
                ? 'Hashtag channel'
                : channel.isPublicChannel
                    ? 'Public channel'
                    : 'Private channel',
          ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _showEditChannelDialog(context, connector, channel),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDeleteChannel(context, connector, channel);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChannelChatScreen(channel: channel),
          ),
        ),
      ),
    );
  }

  void _showAddChannelDialog(BuildContext context) {
    final connector = context.read<MeshCoreConnector>();
    final nameController = TextEditingController();
    final pskController = TextEditingController();
    final maxChannels = connector.maxChannels;
    int selectedIndex = _findNextAvailableIndex(connector.channels, maxChannels);
    bool usePublicPsk = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Channel'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedIndex,
                  decoration: const InputDecoration(
                    labelText: 'Channel Index',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(maxChannels, (i) => i)
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text('Channel $i'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedIndex = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Channel Name',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 31,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: const Text('Use Public Channel'),
                  subtitle: const Text('Standard public PSK'),
                  value: usePublicPsk,
                  onChanged: (value) {
                    setDialogState(() {
                      usePublicPsk = value ?? false;
                      if (usePublicPsk) {
                        nameController.text = 'Public';
                        pskController.text = Channel.publicChannelPsk;
                      } else {
                        pskController.clear();
                      }
                    });
                  },
                ),
                if (!usePublicPsk) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: pskController,
                    decoration: InputDecoration(
                      labelText: 'PSK (Base64)',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.casino),
                        tooltip: 'Generate random PSK',
                        onPressed: () {
                          final random = Random.secure();
                          final bytes = Uint8List(16);
                          for (int i = 0; i < 16; i++) {
                            bytes[i] = random.nextInt(256);
                          }
                          pskController.text = base64Encode(bytes);
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final pskBase64 = usePublicPsk
                    ? Channel.publicChannelPsk
                    : pskController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a channel name')),
                  );
                  return;
                }

                Uint8List psk;
                try {
                  final decoded = base64Decode(pskBase64);
                  psk = Uint8List(16);
                  for (int i = 0; i < decoded.length && i < 16; i++) {
                    psk[i] = decoded[i];
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PSK format')),
                  );
                  return;
                }

                Navigator.pop(context);
                connector.setChannel(selectedIndex, name, psk);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Channel "$name" added')),
                );
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditChannelDialog(
    BuildContext context,
    MeshCoreConnector connector,
    Channel channel,
  ) {
    final nameController = TextEditingController(text: channel.name);
    final pskController = TextEditingController(text: channel.pskBase64);
    bool smazEnabled = connector.isChannelSmazEnabled(channel.index);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Channel ${channel.index}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Channel Name',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 31,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pskController,
                  decoration: InputDecoration(
                    labelText: 'PSK (Base64)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.casino),
                      tooltip: 'Generate random PSK',
                      onPressed: () {
                        final random = Random.secure();
                        final bytes = Uint8List(16);
                        for (int i = 0; i < 16; i++) {
                          bytes[i] = random.nextInt(256);
                        }
                        pskController.text = base64Encode(bytes);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('SMAZ compression'),
                  value: smazEnabled,
                  onChanged: (value) => setState(() => smazEnabled = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final pskBase64 = pskController.text.trim();

                Uint8List psk;
                try {
                  final decoded = base64Decode(pskBase64);
                  psk = Uint8List(16);
                  for (int i = 0; i < decoded.length && i < 16; i++) {
                    psk[i] = decoded[i];
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid PSK format')),
                  );
                  return;
                }

                Navigator.pop(context);
                connector.setChannel(channel.index, name, psk);
                connector.setChannelSmazEnabled(channel.index, smazEnabled);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Channel "$name" updated')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteChannel(
    BuildContext context,
    MeshCoreConnector connector,
    Channel channel,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Channel'),
        content: Text('Delete "${channel.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              connector.deleteChannel(channel.index);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Channel "${channel.name}" deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addPublicChannel(BuildContext context, MeshCoreConnector connector) {
    final psk = Uint8List(16);
    final decoded = base64Decode(Channel.publicChannelPsk);
    for (int i = 0; i < decoded.length && i < 16; i++) {
      psk[i] = decoded[i];
    }
    connector.setChannel(0, 'Public', psk);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public channel added')),
    );
  }

  int _findNextAvailableIndex(List<Channel> channels, int maxChannels) {
    final usedIndices = channels.map((c) => c.index).toSet();
    for (int i = 0; i < maxChannels; i++) {
      if (!usedIndices.contains(i)) return i;
    }
    return 0;
  }
}
