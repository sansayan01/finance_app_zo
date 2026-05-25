import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/providers/branch_manager_providers.dart';
import '../../../../core/constants/layout.dart';

class StaffManagementPage extends ConsumerWidget {
  const StaffManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchId = ref.watch(currentUserBranchIdProvider);
    final staffAsync =
        branchId != null ? ref.watch(branchStaffProvider(branchId)) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/branch/staff/add'),
          ),
        ],
      ),
      body: staffAsync == null
          ? const Center(child: Text('No branch assigned'))
          : staffAsync.when(
              data: (staff) => staff.isEmpty
                  ? const Center(child: Text('No staff members yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: staff.length,
                      itemBuilder: (context, index) {
                        final member = staff[index];
                        return _buildStaffCard(context, ref, member)
                            .animate()
                            .fadeIn(
                                duration: 300.ms,
                                delay: Duration(milliseconds: index * 50))
                            .slideX(begin: 0.1, end: 0);
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
            ),
      floatingActionButton: Padding(
        padding: kFabSafeAreaPadding,
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/branch/staff/add'),
          icon: const Icon(Icons.person_add),
          label: const Text('Add Staff'),
        ),
      ),
    );
  }

  Widget _buildStaffCard(BuildContext context, WidgetRef ref, dynamic staff) {
    final theme = Theme.of(context);
    final roleDisplay = staff.role
        .toString()
        .split('.')
        .last
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => ' ${match.group(0)}',
        )
        .trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            staff.fullName?.isNotEmpty == true ? staff.fullName![0].toUpperCase() : '?',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
        ),
        title: Text(staff.fullName ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(roleDisplay),
            if (staff.phone != null) Text(staff.phone!),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(
                value: 'performance', child: Text('Performance')),
            const PopupMenuItem(value: 'areas', child: Text('Assign Areas')),
            const PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view':
                context.push('/branch/staff/${staff.id}');
                break;
              case 'performance':
                context.push('/branch/staff/${staff.id}/performance');
                break;
              case 'areas':
                context.push('/branch/staff/${staff.id}/areas');
                break;
            }
          },
        ),
      ),
    );
  }
}
