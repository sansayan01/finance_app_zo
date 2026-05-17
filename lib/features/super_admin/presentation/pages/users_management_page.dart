import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/async_value_widget.dart';
import '../../data/providers/super_admin_providers.dart';

class UsersManagementPage extends ConsumerStatefulWidget {
  const UsersManagementPage({super.key});
  @override
  ConsumerState<UsersManagementPage> createState() =>
      _UsersManagementPageState();
}

class _UsersManagementPageState extends ConsumerState<UsersManagementPage> {
  final _search = TextEditingController();
  String? _role;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = D.bg(context);
    final cardBg = D.surface(context);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: D.bodyPad,
              sliver: SliverToBoxAdapter(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      D.header('Users', 'All platform users', isDark),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _search,
                        decoration: D.searchInput(context, _search, () {
                          _search.clear();
                          setState(() {});
                        }),
                        style: TextStyle(fontSize: 14, color: D.text(context)),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      _roleFilter(isDark),
                      const SizedBox(height: 20),
                    ]),
              ),
            ),
            SliverPadding(
              padding: D.bodyBottomPad,
              sliver: AsyncValueSliver(
                value: ref.watch(
                    allUsersProvider({'search': _search.text, 'role': _role})),
                builder: (users) => SliverList(
                    delegate: SliverChildBuilderDelegate(
                        (_, i) => _userCard(users[i], isDark, cardBg),
                        childCount: users.length)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleFilter(bool isDark) {
    final roles = [
      'All',
      'superAdmin',
      'executiveAdmin',
      'manager',
      'collectionAgent'
    ];
    final labels = ['All', 'Super Admin', 'Admin', 'Manager', 'Agent'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: List.generate(roles.length, (i) {
        final sel = (i == 0 && _role == null) || _role == roles[i];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => setState(() => _role = i == 0 ? null : roles[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:
                    sel ? D.accent.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: sel
                        ? D.accent.withValues(alpha: 0.3)
                        : D.borderColor(isDark)),
              ),
              child: Text(labels[i],
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: sel ? D.accent : D.muted(context))),
            ),
          ),
        );
      })),
    );
  }

  Widget _userCard(Map<String, dynamic> u, bool isDark, Color cardBg) {
    final role = u['role'] as String? ?? 'customer';
    final active = u['is_active'] as bool? ?? true;
    final rc = _roleColor(role);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: D.card(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(D.radius),
          onTap: () => _detail(u),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: rc.withValues(alpha: 0.12),
                child: Text(((u['name'] as String? ?? '?')[0]).toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: rc, fontSize: 16)),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(u['name'] as String? ?? '',
                        style: D.titleStyle(isDark)),
                    const SizedBox(height: 2),
                    Text(u['email'] as String? ?? '',
                        style: D.subtitleStyle(isDark)),
                  ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: rc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_roleName(role),
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: rc))),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                          color: active ? Colors.green : Colors.red,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(active ? 'Active' : 'Inactive',
                      style: D.subtitleStyle(isDark)),
                ]),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  Color _roleColor(String r) {
    switch (r) {
      case 'superAdmin':
        return Colors.red;
      case 'executiveAdmin':
        return Colors.orange;
      case 'manager':
        return Colors.blue;
      case 'collectionAgent':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  String _roleName(String r) {
    switch (r) {
      case 'superAdmin':
        return 'Super Admin';
      case 'executiveAdmin':
        return 'Admin';
      case 'manager':
        return 'Manager';
      case 'collectionAgent':
        return 'Agent';
      default:
        return 'Customer';
    }
  }

  void _detail(Map<String, dynamic> u) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: D.surface(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: D.dim(context),
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text(u['name'] as String? ?? '', style: D.h2(isDark)),
                  const SizedBox(height: 4),
                  Text(u['email'] as String? ?? '',
                      style: D.subtitleStyle(isDark)),
                  const SizedBox(height: 20),
                  _detailRow(Icons.badge, 'Role', _roleName(u['role'] ?? '')),
                  _detailRow(Icons.email, 'Email', u['email'] ?? ''),
                  _detailRow(Icons.phone, 'Phone', u['phone'] ?? 'N/A'),
                  _detailRow(Icons.calendar_today, 'Joined',
                      (u['created_at'] as String?)?.substring(0, 10) ?? 'N/A'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final newState = !(u['is_active'] ?? true);
                        await ref
                            .read(superAdminActionsProvider.notifier)
                            .updateUserStatus(u['id'], newState);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: Icon((u['is_active'] ?? true)
                          ? Icons.block
                          : Icons.check_circle),
                      label: Text((u['is_active'] ?? true)
                          ? 'Deactivate User'
                          : 'Activate User'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (u['is_active'] ?? true)
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: D.iconMuted(context)),
        const SizedBox(width: 12),
        SizedBox(
            width: 80,
            child: Text(label,
                style: D.labelStyle(
                    Theme.of(context).brightness == Brightness.dark))),
        Expanded(
            child: Text(value,
                style: D.valueStyle(
                    Theme.of(context).brightness == Brightness.dark))),
      ]),
    );
  }
}
