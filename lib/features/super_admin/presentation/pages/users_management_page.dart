import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/enums.dart';
import '../../data/providers/super_admin_providers.dart';

/// Users Management Page
class UsersManagementPage extends ConsumerStatefulWidget {
  const UsersManagementPage({super.key});

  @override
  ConsumerState<UsersManagementPage> createState() => _UsersManagementPageState();
}

class _UsersManagementPageState extends ConsumerState<UsersManagementPage> {
  final _searchController = TextEditingController();
  String? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('All Users'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.filter_list),
                onSelected: (value) => setState(() {
                  _roleFilter = value.isEmpty ? null : value;
                }),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: '', child: Text('All Roles')),
                  const PopupMenuItem(value: 'superAdmin', child: Text('Super Admin')),
                  const PopupMenuItem(value: 'executiveAdmin', child: Text('Executive Admin')),
                  const PopupMenuItem(value: 'manager', child: Text('Manager')),
                  const PopupMenuItem(value: 'collectionAgent', child: Text('Collection Agent')),
                  const PopupMenuItem(value: 'customer', child: Text('Customer')),
                ],
              ),
            ],
          ),

          // Search
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),

          // Users List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: AsyncValueSliver(
              value: ref.watch(allUsersProvider({
                'search': _searchController.text,
                'role': _roleFilter,
              })),
              builder: (users) => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildUserCard(context, users[index], isDark),
                  childCount: users.length,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user, bool isDark) {
    final role = user['role'] as String? ?? 'customer';
    final isActive = user['is_active'] as bool? ?? true;
    final lastLogin = user['last_login'] != null 
        ? DateTime.tryParse(user['last_login']) 
        : null;
    final orgName = user['organizations']?['name'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isDark ? Colors.grey[900] : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(role).withOpacity(0.1),
          child: Text(
            (user['name'] as String?)?.isNotEmpty == true 
                ? user['name'][0].toUpperCase() 
                : '?',
            style: TextStyle(
              color: _getRoleColor(role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          user['name'] ?? 'Unknown',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user['email'] ?? ''),
            if (orgName != null)
              Text(
                orgName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRoleDisplayName(role),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _getRoleColor(role),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isActive ? Icons.check_circle : Icons.block,
              color: isActive ? Colors.green : Colors.red,
              size: 20,
            ),
          ],
        ),
        onTap: () => _showUserDetails(user),
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'superAdmin':
        return Colors.red;
      case 'executiveAdmin':
        return Colors.orange;
      case 'manager':
        return Colors.blue;
      case 'collectionAgent':
        return Colors.green;
      case 'customer':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'superAdmin':
        return 'Super Admin';
      case 'executiveAdmin':
        return 'Executive Admin';
      case 'manager':
        return 'Manager';
      case 'collectionAgent':
        return 'Agent';
      case 'customer':
        return 'Customer';
      default:
        return role;
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                user['name'] ?? 'Unknown',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                user['email'] ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _toggleUserStatus(user['id'], !(user['is_active'] ?? true)),
                      icon: Icon(user['is_active'] == true ? Icons.block : Icons.check),
                      label: Text(user['is_active'] == true ? 'Deactivate' : 'Activate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: user['is_active'] == true ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleUserStatus(String userId, bool isActive) async {
    final success = await ref.read(superAdminActionsProvider.notifier).updateUserStatus(userId, isActive);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'User ${isActive ? 'activated' : 'deactivated'}' 
              : 'Failed to update user'),
        ),
      );
    }
  }
}
