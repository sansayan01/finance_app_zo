import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/aurora_background.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../branches/data/providers/branch_providers.dart';
import '../../../branches/models/branch_model.dart';
import '../../data/csv_utils.dart';
import '../providers/user_list_provider.dart';

/// Bulk import customers (members) from a CSV file.
///
/// Expected columns (header row, case-insensitive):
///   full_name, phone, email, address, city, state, pincode, member_id
/// `full_name` is required. Everything else is optional.
class BulkImportMembersPage extends ConsumerStatefulWidget {
  const BulkImportMembersPage({super.key});

  @override
  ConsumerState<BulkImportMembersPage> createState() =>
      _BulkImportMembersPageState();
}

class _BulkImportMembersPageState extends ConsumerState<BulkImportMembersPage> {
  String? _fileName;
  List<Map<String, dynamic>> _validRows = [];
  List<String> _errors = [];
  String? _branchId;
  bool _busy = false;

  static const List<String> _knownHeaders = [
    'full_name',
    'phone',
    'email',
    'address',
    'city',
    'state',
    'pincode',
    'member_id',
    'aadhar',
    'pan',
    'date_of_birth',
    'gender',
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final f = result.files.first;
    String text;
    if (f.bytes != null) {
      text = utf8.decode(f.bytes!);
    } else if (f.path != null) {
      text = await File(f.path!).readAsString();
    } else {
      return;
    }

    setState(() {
      _fileName = f.name;
      _parse(text);
    });
  }

  void _parse(String text) {
    final rows = CsvUtils.parse(text);
    _validRows = [];
    _errors = [];

    if (rows.isEmpty) {
      _errors.add('CSV is empty');
      return;
    }

    final header = rows.first
        .map((c) => c.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();

    if (!header.contains('full_name')) {
      _errors.add('Missing required column "full_name" in header row.');
      return;
    }

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.every((c) => c.trim().isEmpty)) continue;
      final map = <String, dynamic>{};
      for (var j = 0; j < header.length && j < row.length; j++) {
        final key = header[j];
        final value = row[j].trim();
        if (!_knownHeaders.contains(key)) continue;
        if (value.isEmpty) continue;
        map[key] = value;
      }
      if ((map['full_name']?.toString().trim() ?? '').isEmpty) {
        _errors.add('Row ${i + 1}: missing full_name');
        continue;
      }
      if (_branchId != null) map['branch_id'] = _branchId;
      _validRows.add(map);
    }
  }

  Future<void> _import() async {
    if (_validRows.isEmpty) return;
    setState(() => _busy = true);
    HapticService.medium();
    final notifier = ref.read(userAdminProvider.notifier);
    final inserted = await notifier.bulkInsertMembers(_validRows);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Imported $inserted of ${_validRows.length} customers.'),
        backgroundColor:
            inserted > 0 ? AppColors.success : AppColors.error,
      ),
    );
    if (inserted > 0 && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branchesAsync = ref.watch(activeBranchesProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bulk Import Customers',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Upload a CSV to onboard customers in bulk',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  children: [
                    _buildSchemaCard(theme),
                    const SizedBox(height: 12),
                    _buildBranchPicker(theme, branchesAsync),
                    const SizedBox(height: 12),
                    _buildPickerCard(theme),
                    if (_errors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildErrorsCard(theme),
                    ],
                    if (_validRows.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildPreviewCard(theme),
                    ],
                  ],
                ),
              ),
              if (_validRows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _import,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        _busy
                            ? 'Importing...'
                            : 'Import ${_validRows.length} customers',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppColors.success,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSchemaCard(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('CSV format',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'First row must be a header. `full_name` is required.\n'
            'Recognised columns: ${_knownHeaders.join(", ")}',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchPicker(
      ThemeData theme, AsyncValue<List<BranchModel>> async) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: async.when(
        data: (branches) {
          if (branches.isEmpty) return const SizedBox.shrink();
          return Row(
            children: [
              const Icon(Icons.location_city_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Text('Default branch:'),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  value: _branchId,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  hint: const Text('Unassigned'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Unassigned')),
                    ...branches.map((b) => DropdownMenuItem<String?>(
                          value: b.id,
                          child: Text(b.name),
                        )),
                  ],
                  onChanged: (v) => setState(() => _branchId = v),
                ),
              ),
            ],
          );
        },
        loading: () => const SizedBox(
            height: 24, child: Center(child: CircularProgressIndicator())),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildPickerCard(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_fileName ?? 'Choose a CSV file',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      _fileName == null
                          ? 'Tap to pick a .csv file from your device'
                          : '${_validRows.length} valid rows · ${_errors.length} errors',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: Text(_fileName == null ? 'Choose file' : 'Choose another'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorsCard(ThemeData theme) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.error.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text('${_errors.length} errors',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 8),
          ..._errors.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('• $e',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
              )),
          if (_errors.length > 8)
            Text('… and ${_errors.length - 8} more',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPreviewCard(ThemeData theme) {
    final preview = _validRows.take(5).toList();
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Preview · first ${preview.length} of ${_validRows.length} rows',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final row in preview)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${row['full_name']}'
                '${row['phone'] != null ? "  ·  ${row['phone']}" : ""}'
                '${row['email'] != null ? "  ·  ${row['email']}" : ""}',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
