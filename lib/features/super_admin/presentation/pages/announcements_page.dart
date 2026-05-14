import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/providers/super_admin_providers.dart';

/// Platform Announcements Page
class AnnouncementsPage extends ConsumerStatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  ConsumerState<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends ConsumerState<AnnouncementsPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final announcementsAsync = ref.watch(platformAnnouncementsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Announcements'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreateAnnouncementDialog,
              ),
            ],
          ),

          announcementsAsync.when(
            data: (announcements) => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: announcements.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Center(
                        child: Text('No announcements yet'),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildAnnouncementCard(
                          context,
                          announcements[index],
                          isDark,
                        ),
                        childCount: announcements.length,
                      ),
                    ),
            ),
            loading: () => const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, dynamic announcement, bool isDark) {
    final type = announcement.type as String? ?? 'info';
    final createdAt = announcement.createdAt;
    final typeColor = _getTypeColor(type);
    final typeIcon = _getTypeIcon(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!announcement.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'INACTIVE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d, y • h:mm a').format(createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _editAnnouncement(announcement),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'info':
        return Colors.blue;
      case 'warning':
        return Colors.orange;
      case 'critical':
        return Colors.red;
      case 'maintenance':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'info':
        return Icons.info_outline;
      case 'warning':
        return Icons.warning_amber;
      case 'critical':
        return Icons.error_outline;
      case 'maintenance':
        return Icons.build_outlined;
      default:
        return Icons.campaign;
    }
  }

  void _showCreateAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String type = 'info';
    String audience = 'all';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'info'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'admins', child: Text('Admins Only')),
                    DropdownMenuItem(value: 'managers', child: Text('Managers Only')),
                    DropdownMenuItem(value: 'agents', child: Text('Agents Only')),
                  ],
                  onChanged: (v) => setState(() => audience = v ?? 'all'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) {
                  return;
                }

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                
                final success = await ref.read(superAdminActionsProvider.notifier).createAnnouncement(
                  title: titleController.text,
                  message: messageController.text,
                  type: type,
                  targetAudience: audience,
                );

                if (!mounted) return;
                
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(success 
                          ? 'Announcement created' 
                          : 'Failed to create announcement'),
                    ),
                  );
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _editAnnouncement(dynamic announcement) {
    final titleController = TextEditingController(text: announcement.title);
    final messageController = TextEditingController(text: announcement.message);
    String type = announcement.type ?? 'info';
    String audience = announcement.targetAudience ?? 'all';
    bool isActive = announcement.isActive;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Announcement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'maintenance', child: Text('Maintenance')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'info'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: audience,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Users')),
                    DropdownMenuItem(value: 'admins', child: Text('Admins Only')),
                    DropdownMenuItem(value: 'managers', child: Text('Managers Only')),
                    DropdownMenuItem(value: 'agents', child: Text('Agents Only')),
                  ],
                  onChanged: (v) => setState(() => audience = v ?? 'all'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Announcement?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final success = await ref.read(superAdminActionsProvider.notifier).deleteAnnouncement(announcement.id);
                  
                  if (!mounted) return;
                  if (success) {
                    navigator.pop(); // Close edit dialog
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Announcement deleted')));
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || messageController.text.isEmpty) {
                  return;
                }

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                
                final success = await ref.read(superAdminActionsProvider.notifier).updateAnnouncement(
                  id: announcement.id,
                  title: titleController.text,
                  message: messageController.text,
                  type: type,
                  targetAudience: audience,
                  isActive: isActive,
                );

                if (!mounted) return;
                
                if (success) {
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Announcement updated')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
