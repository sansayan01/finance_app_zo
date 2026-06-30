import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/enums.dart';
import '../../data/models/member_model.dart';
import '../providers/member_providers.dart';

/// A searchable member/customer picker that looks like the existing
/// dropdown but opens a searchable bottom sheet on tap.
class MemberSearchablePicker extends ConsumerStatefulWidget {
  final String? selectedId;
  final String hint;
  final ValueChanged<String?> onChanged;

  const MemberSearchablePicker({
    super.key,
    this.selectedId,
    required this.hint,
    required this.onChanged,
  });

  @override
  ConsumerState<MemberSearchablePicker> createState() =>
      _MemberSearchablePickerState();
}

class _MemberSearchablePickerState
    extends ConsumerState<MemberSearchablePicker> {
  String _displayLabel = '';

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      _loadDisplayLabel();
    }
  }

  @override
  void didUpdateWidget(MemberSearchablePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedId != widget.selectedId && widget.selectedId != null) {
      _loadDisplayLabel();
    }
  }

  Future<void> _loadDisplayLabel() async {
    try {
      final members = await ref.read(membersProvider.future);
      if (!mounted) return;
      final match = members.where((m) => m.id == widget.selectedId).toList();
      if (match.isNotEmpty) {
        setState(() => _displayLabel = match.first.fullName);
      }
    } catch (_) {
      // silently fail — will show hint text instead
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showPickerSheet(theme, isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.fillDark : AppColors.fillLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _displayLabel.isNotEmpty ? _displayLabel : widget.hint,
                style: TextStyle(
                  color: _displayLabel.isNotEmpty
                      ? theme.colorScheme.onSurface
                      : theme.textTheme.bodySmall?.color,
                  fontWeight:
                      _displayLabel.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.search_rounded,
              color: theme.textTheme.bodySmall?.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPickerSheet(ThemeData theme, bool isDark) async {
    final membersAsync = await ref.read(membersProvider.future);
    if (!mounted) return;
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberPickerSheet(
        theme: theme,
        isDark: isDark,
        members: membersAsync,
        selectedId: widget.selectedId,
      ),
    );

    if (result != null && mounted) {
      widget.onChanged(result);
      final match = membersAsync.where((m) => m.id == result).toList();
      if (match.isNotEmpty) {
        setState(() => _displayLabel = match.first.fullName);
      }
    }
  }
}

// ─── Bottom Sheet ────────────────────────────────────────────────────────────

class _MemberPickerSheet extends StatefulWidget {
  final ThemeData theme;
  final bool isDark;
  final List<MemberModel> members;
  final String? selectedId;

  const _MemberPickerSheet({
    required this.theme,
    required this.isDark,
    required this.members,
    this.selectedId,
  });

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<MemberModel> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.members;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String q) {
    setState(() {
      _query = q;
      if (q.isEmpty) {
        _filtered = widget.members;
      } else {
        final lower = q.toLowerCase();
        _filtered = widget.members.where((m) {
          return m.fullName.toLowerCase().contains(lower) ||
              m.phone.contains(q) ||
              m.memberId.toLowerCase().contains(lower);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: widget.theme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.theme.colorScheme.primary
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.people_rounded,
                        size: 20,
                        color: widget.theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select Customer',
                        style: widget.theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _searchController,
                  onChanged: _filter,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or member ID...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _filter('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: widget.isDark
                        ? AppColors.fillDark
                        : AppColors.fillLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Results count
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Row(
                  children: [
                    Text(
                      '${_filtered.length} member${_filtered.length != 1 ? 's' : ''}',
                      style: widget.theme.textTheme.bodySmall?.copyWith(
                        color: widget.theme.textTheme.bodySmall?.color,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // Members list
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: widget.theme.textTheme.bodySmall?.color,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No members found',
                              style:
                                  widget.theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    widget.theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final member = _filtered[index];
                          final isSelected = member.id == widget.selectedId;
                          return _MemberTile(
                            member: member,
                            isSelected: isSelected,
                            theme: widget.theme,
                            isDark: widget.isDark,
                            onTap: () => Navigator.pop(context, member.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Member Tile ────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final MemberModel member;
  final bool isSelected;
  final ThemeData theme;
  final bool isDark;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.isSelected,
    required this.theme,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kycColor = member.kycStatus == KYCStatus.verified
        ? AppColors.success
        : member.kycStatus == KYCStatus.rejected
            ? AppColors.error
            : AppColors.warningDark;

    final kycLabel = member.kycStatus == KYCStatus.verified
        ? 'Verified'
        : member.kycStatus == KYCStatus.rejected
            ? 'Rejected'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      member.fullName.isNotEmpty
                          ? member.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            member.phone.isNotEmpty
                                ? member.phone
                                : 'No phone',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          if (member.memberId.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.textTheme.bodySmall?.color ??
                                    Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              member.memberId,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // KYC badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kycColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    kycLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: kycColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
