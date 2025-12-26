import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connector/meshcore_connector.dart';
import '../connector/meshcore_protocol.dart';
import '../models/contact.dart';
import '../models/contact_group.dart';
import '../storage/contact_group_store.dart';
import '../widgets/repeater_login_dialog.dart';
import '../utils/emoji_utils.dart';
import 'chat_screen.dart';
import 'repeater_hub_screen.dart';

enum ContactSortOption {
  lastSeen,
  recentMessages,
  name,
  type,
}

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ContactSortOption _sortOption = ContactSortOption.lastSeen;
  final ContactGroupStore _groupStore = ContactGroupStore();
  List<ContactGroup> _groups = [];

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    final groups = await _groupStore.loadGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
    });
  }

  Future<void> _saveGroups() async {
    await _groupStore.saveGroups(_groups);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        centerTitle: true,
        actions: [
          PopupMenuButton<ContactSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (option) {
              setState(() {
                _sortOption = option;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ContactSortOption.lastSeen,
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 20,
                      color: _sortOption == ContactSortOption.lastSeen
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Last Seen',
                      style: TextStyle(
                        fontWeight: _sortOption == ContactSortOption.lastSeen
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContactSortOption.recentMessages,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble,
                      size: 20,
                      color: _sortOption == ContactSortOption.recentMessages
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Recent Messages',
                      style: TextStyle(
                        fontWeight: _sortOption == ContactSortOption.recentMessages
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContactSortOption.name,
                child: Row(
                  children: [
                    Icon(
                      Icons.sort_by_alpha,
                      size: 20,
                      color: _sortOption == ContactSortOption.name
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Name',
                      style: TextStyle(
                        fontWeight: _sortOption == ContactSortOption.name
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ContactSortOption.type,
                child: Row(
                  children: [
                    Icon(
                      Icons.category,
                      size: 20,
                      color: _sortOption == ContactSortOption.type
                          ? Theme.of(context).primaryColor
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Type',
                      style: TextStyle(
                        fontWeight: _sortOption == ContactSortOption.type
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'New group',
            onPressed: () {
              final contacts = context.read<MeshCoreConnector>().contacts;
              _showGroupEditor(context, contacts);
            },
          ),
          Consumer<MeshCoreConnector>(
            builder: (context, connector, child) {
              return IconButton(
                icon: connector.isLoadingContacts
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: connector.isLoadingContacts
                    ? null
                    : () => connector.getContacts(),
              );
            },
          ),
        ],
      ),
      body: Consumer<MeshCoreConnector>(
        builder: (context, connector, child) {
          final contacts = connector.contacts;

          if (contacts.isEmpty && connector.isLoadingContacts && _groups.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (contacts.isEmpty && _groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No contacts yet',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Contacts will appear when devices advertise',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final filteredAndSorted = _filterAndSortContacts(contacts, connector);
          final filteredGroups = _filterAndSortGroups(_groups, contacts);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              Expanded(
                child: filteredAndSorted.isEmpty && filteredGroups.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No contacts or groups found',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => connector.getContacts(),
                        child: ListView.builder(
                          itemCount: filteredGroups.length + filteredAndSorted.length,
                          itemBuilder: (context, index) {
                            if (index < filteredGroups.length) {
                              final group = filteredGroups[index];
                              return _buildGroupTile(context, group, contacts);
                            }
                            final contact = filteredAndSorted[index - filteredGroups.length];
                            return _ContactTile(
                              contact: contact,
                              onTap: () => _openChat(context, contact),
                              onLongPress: () => _showContactOptions(context, connector, contact),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<ContactGroup> _filterAndSortGroups(List<ContactGroup> groups, List<Contact> contacts) {
    final query = _searchQuery.trim().toLowerCase();
    final contactNames = <String, String>{};
    for (final contact in contacts) {
      contactNames[contact.publicKeyHex] = contact.name.toLowerCase();
    }

    final filtered = groups.where((group) {
      if (query.isEmpty) return true;
      if (group.name.toLowerCase().contains(query)) return true;
      for (final key in group.memberKeys) {
        final name = contactNames[key];
        if (name != null && name.contains(query)) return true;
      }
      return false;
    }).toList();

    filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  List<Contact> _filterAndSortContacts(List<Contact> contacts, MeshCoreConnector connector) {
    var filtered = contacts.where((contact) {
      if (_searchQuery.isEmpty) return true;
      return contact.name.toLowerCase().contains(_searchQuery);
    }).toList();

    switch (_sortOption) {
      case ContactSortOption.lastSeen:
        filtered.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
        break;
      case ContactSortOption.recentMessages:
        filtered.sort((a, b) {
          final aMessages = connector.getMessages(a);
          final bMessages = connector.getMessages(b);
          final aLastMsg = aMessages.isEmpty ? DateTime(1970) : aMessages.last.timestamp;
          final bLastMsg = bMessages.isEmpty ? DateTime(1970) : bMessages.last.timestamp;
          return bLastMsg.compareTo(aLastMsg);
        });
        break;
      case ContactSortOption.name:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case ContactSortOption.type:
        filtered.sort((a, b) {
          final typeCompare = a.type.compareTo(b.type);
          if (typeCompare != 0) return typeCompare;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        break;
    }

    return filtered;
  }

  Widget _buildGroupTile(BuildContext context, ContactGroup group, List<Contact> contacts) {
    final memberContacts = _resolveGroupContacts(group, contacts);
    final subtitle = _formatGroupMembers(memberContacts);
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.teal,
        child: Icon(Icons.group, color: Colors.white, size: 20),
      ),
      title: Text(group.name),
      subtitle: Text(subtitle),
      trailing: Text(
        memberContacts.length.toString(),
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      onTap: () => _showGroupOptions(context, group, contacts),
      onLongPress: () => _showGroupOptions(context, group, contacts),
    );
  }

  List<Contact> _resolveGroupContacts(ContactGroup group, List<Contact> contacts) {
    final byKey = <String, Contact>{};
    for (final contact in contacts) {
      byKey[contact.publicKeyHex] = contact;
    }
    final resolved = <Contact>[];
    for (final key in group.memberKeys) {
      final contact = byKey[key];
      if (contact != null) {
        resolved.add(contact);
      }
    }
    resolved.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return resolved;
  }

  String _formatGroupMembers(List<Contact> members) {
    if (members.isEmpty) return 'No members';
    final names = members.map((c) => c.name).toList();
    if (names.length <= 2) return names.join(', ');
    return '${names.take(2).join(', ')} +${names.length - 2}';
  }

  void _openChat(BuildContext context, Contact contact) {
    // Check if this is a repeater
    if (contact.type == advTypeRepeater) {
      _showRepeaterLogin(context, contact);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(contact: contact)),
      );
    }
  }

  void _showRepeaterLogin(BuildContext context, Contact repeater) {
    showDialog(
      context: context,
      builder: (context) => RepeaterLoginDialog(
        repeater: repeater,
        onLogin: (password) {
          // Navigate to repeater hub screen after successful login
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RepeaterHubScreen(
                repeater: repeater,
                password: password,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showGroupOptions(BuildContext context, ContactGroup group, List<Contact> contacts) {
    final members = _resolveGroupContacts(group, contacts);
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Group'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showGroupEditor(context, contacts, group: group);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDeleteGroup(context, group);
                },
              ),
              if (members.isNotEmpty) const Divider(),
              ...members.map((member) {
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(member.name),
                  subtitle: Text(member.typeLabel),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openChat(context, member);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, ContactGroup group) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Remove "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() {
                _groups.removeWhere((g) => g.name == group.name);
              });
              await _saveGroups();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showGroupEditor(
    BuildContext context,
    List<Contact> contacts, {
    ContactGroup? group,
  }) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: group?.name ?? '');
    final selectedKeys = <String>{...group?.memberKeys ?? []};
    String filterQuery = '';
    final sortedContacts = List<Contact>.from(contacts)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) {
          final filteredContacts = filterQuery.isEmpty
              ? sortedContacts
              : sortedContacts
                  .where((contact) => contact.name.toLowerCase().contains(filterQuery))
                  .toList();
          return AlertDialog(
            title: Text(isEditing ? 'Edit Group' : 'New Group'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Group name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Filter contacts...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        filterQuery = value.toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 240,
                    child: filteredContacts.isEmpty
                        ? const Center(child: Text('No contacts match your filter'))
                        : ListView.builder(
                            itemCount: filteredContacts.length,
                            itemBuilder: (context, index) {
                              final contact = filteredContacts[index];
                              final isSelected = selectedKeys.contains(contact.publicKeyHex);
                              return CheckboxListTile(
                                value: isSelected,
                                title: Text(contact.name),
                                subtitle: Text(contact.typeLabel),
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedKeys.add(contact.publicKeyHex);
                                    } else {
                                      selectedKeys.remove(contact.publicKeyHex);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Group name is required')),
                    );
                    return;
                  }
                  final exists = _groups.any((g) {
                    if (isEditing && g.name == group!.name) return false;
                    return g.name.toLowerCase() == name.toLowerCase();
                  });
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Group "$name" already exists')),
                    );
                    return;
                  }
                  setState(() {
                    if (isEditing) {
                      final index = _groups.indexWhere((g) => g.name == group!.name);
                      if (index != -1) {
                        _groups[index] = ContactGroup(
                          name: name,
                          memberKeys: selectedKeys.toList(),
                        );
                      }
                    } else {
                      _groups.add(ContactGroup(name: name, memberKeys: selectedKeys.toList()));
                    }
                  });
                  await _saveGroups();
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showContactOptions(
    BuildContext context,
    MeshCoreConnector connector,
    Contact contact,
  ) {
    final isRepeater = contact.type == advTypeRepeater;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isRepeater)
              ListTile(
                leading: const Icon(Icons.cell_tower, color: Colors.orange),
                title: const Text('Manage Repeater'),
                onTap: () {
                  Navigator.pop(context);
                  _showRepeaterLogin(context, contact);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Open Chat'),
                onTap: () {
                  Navigator.pop(context);
                  _openChat(context, contact);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Contact', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, connector, contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    MeshCoreConnector connector,
    Contact contact,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Remove ${contact.name} from contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              connector.removeContact(contact);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getTypeColor(contact.type),
        child: _buildContactAvatar(contact),
      ),
      title: Text(contact.name),
      subtitle: Text('${contact.typeLabel} • ${contact.pathLabel}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatLastSeen(contact.lastSeen),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (contact.hasLocation)
            Icon(Icons.location_on, size: 14, color: Colors.grey[400]),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  Widget _buildContactAvatar(Contact contact) {
    final emoji = firstEmoji(contact.name);
    if (emoji != null) {
      return Text(
        emoji,
        style: const TextStyle(fontSize: 18),
      );
    }
    return Icon(_getTypeIcon(contact.type), color: Colors.white, size: 20);
  }

  IconData _getTypeIcon(int type) {
    switch (type) {
      case advTypeChat:
        return Icons.chat;
      case advTypeRepeater:
        return Icons.cell_tower;
      case advTypeRoom:
        return Icons.group;
      case advTypeSensor:
        return Icons.sensors;
      default:
        return Icons.device_unknown;
    }
  }

  Color _getTypeColor(int type) {
    switch (type) {
      case advTypeChat:
        return Colors.blue;
      case advTypeRepeater:
        return Colors.orange;
      case advTypeRoom:
        return Colors.purple;
      case advTypeSensor:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${lastSeen.month}/${lastSeen.day}';
  }
}
