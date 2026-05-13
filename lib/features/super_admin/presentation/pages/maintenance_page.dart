import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../data/providers/super_admin_providers.dart';

/// Maintenance Management Page
class MaintenancePage extends ConsumerStatefulWidget {
  const MaintenancePage({super.key});

  @override
  ConsumerState<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends ConsumerState<MaintenancePage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maintenanceAsync = ref.watch(maintenanceWindowsProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Maintenance'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _showCreateMaintenanceDialog,
              ),
            ],
          ),

          // Info Card
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Card(
                color: Colors.purple.withOpacity(0.1),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.purple),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Schedule maintenance windows to notify users about downtime',
                          style: TextStyle(color: Colors.purple),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Maintenance Windows
          maintenanceAsync.when(
            data: (windows) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: windows.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.build_outlined, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                'No maintenance windows scheduled',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMaintenanceCard(
                          context,
                          windows[index],
                          isDark,
                        ),
                        childCount: windows.length,
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

  Widget _buildMaintenanceCard(BuildContext context, dynamic window, bool isDark) {
    final scheduledStart = window.scheduledStart;
    final scheduledEnd = window.scheduledEnd;
    final isActive = window.isActive;
    final isUpcoming = scheduledStart.isAfter(DateTime.now());
    final isOngoing = DateTime.now().isAfter(scheduledStart) && DateTime.now().isBefore(scheduledEnd);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isActive
              ? Colors.orange
              : isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: isActive ? 2 : 1,
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isActive ? Colors.orange : Colors.grey).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.build_outlined,
                    color: isActive ? Colors.orange : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        window.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isOngoing
                            ? 'ONGOING'
                            : isUpcoming
                                ? 'UPCOMING'
                                : 'COMPLETED',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isOngoing
                              ? Colors.orange
                              : isUpcoming
                                  ? Colors.blue
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  onChanged: (value) => _toggleMaintenance(window.id, value),
                  activeColor: Colors.orange,
                ),
              ],
            ),
            if (window.description != null) ...[
              const SizedBox(height: 12),
              Text(
                window.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start: ${DateFormat('MMM d, y • h:mm a').format(scheduledStart)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'End: ${DateFormat('MMM d, y • h:mm a').format(scheduledEnd)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${window.duration.inHours}h',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (window.affectedServices.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: window.affectedServices.map<Widget>((service) {
                  return Chip(
                    label: Text(service),
                    backgroundColor: Colors.purple.withOpacity(0.1),
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  void _toggleMaintenance(String windowId, bool isActive) async {
    final repo = ref.read(superAdminRepositoryProvider);
    final success = await repo.toggleMaintenanceMode(windowId, isActive);
    if (mounted) {
      ref.invalidate(maintenanceWindowsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Maintenance mode ${isActive ? 'enabled' : 'disabled'}' 
              : 'Failed to update'),
        ),
      );
    }
  }

  void _showCreateMaintenanceDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 2, minute: 0);
    int durationHours = 2;
    List<String> affectedServices = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Schedule Maintenance'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Scheduled System Upgrade',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(DateFormat('MMM d, y').format(startDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => startDate = date);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(startTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (time != null) {
                      setState(() => startTime = time);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: durationHours,
                  decoration: const InputDecoration(
                    labelText: 'Duration',
                  ),
                  items: [1, 2, 3, 4, 6, 8, 12, 24].map((h) {
                    return DropdownMenuItem(
                      value: h,
                      child: Text('$h ${h == 1 ? 'hour' : 'hours'}'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => durationHours = v ?? 2),
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
                if (titleController.text.isEmpty) return;

                final scheduledStart = DateTime(
                  startDate.year,
                  startDate.month,
                  startDate.day,
                  startTime.hour,
                  startTime.minute,
                );
                final scheduledEnd = scheduledStart.add(Duration(hours: durationHours));

                final success = await ref.read(superAdminActionsProvider.notifier).createMaintenanceWindow(
                  title: titleController.text,
                  description: descController.text.isEmpty ? null : descController.text,
                  scheduledStart: scheduledStart,
                  scheduledEnd: scheduledEnd,
                  affectedServices: affectedServices.isEmpty ? null : affectedServices,
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success 
                          ? 'Maintenance scheduled' 
                          : 'Failed to schedule maintenance'),
                    ),
                  );
                }
              },
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
