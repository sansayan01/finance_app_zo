import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum CollectionFilter {
  all,
  dueToday,
  overdue,
  paid,
  upcoming,
}

enum CollectionSort {
  dueDate,
  amountHighToLow,
  amountLowToHigh,
  nameAZ,
  nameZA,
  area,
}

class CollectionFilterChip extends StatelessWidget {
  final CollectionFilter filter;
  final bool isSelected;
  final VoidCallback? onTap;
  final int? count;

  const CollectionFilterChip({
    super.key,
    required this.filter,
    this.isSelected = false,
    this.onTap,
    this.count,
  });

  String get _label {
    switch (filter) {
      case CollectionFilter.all:
        return 'All';
      case CollectionFilter.dueToday:
        return 'Due Today';
      case CollectionFilter.overdue:
        return 'Overdue';
      case CollectionFilter.paid:
        return 'Paid';
      case CollectionFilter.upcoming:
        return 'Upcoming';
    }
  }

  IconData get _icon {
    switch (filter) {
      case CollectionFilter.all:
        return Icons.list;
      case CollectionFilter.dueToday:
        return Icons.today;
      case CollectionFilter.overdue:
        return Icons.warning_amber;
      case CollectionFilter.paid:
        return Icons.check_circle;
      case CollectionFilter.upcoming:
        return Icons.calendar_today;
    }
  }

  Color get _color {
    switch (filter) {
      case CollectionFilter.all:
        return Colors.grey;
      case CollectionFilter.dueToday:
        return AppColors.info;
      case CollectionFilter.overdue:
        return AppColors.error;
      case CollectionFilter.paid:
        return AppColors.success;
      case CollectionFilter.upcoming:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return FilterChip(
      avatar: Icon(
        _icon,
        size: 16,
        color: isSelected ? _color : theme.colorScheme.onSurfaceVariant,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_label),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected 
                    ? _color.withOpacity(0.2)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? _color : null,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onTap?.call(),
      selectedColor: _color.withOpacity(0.15),
      checkmarkColor: _color,
      side: BorderSide(
        color: isSelected ? _color : theme.colorScheme.outline.withOpacity(0.3),
      ),
      labelStyle: TextStyle(
        color: isSelected ? _color : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class CollectionSortButton extends StatelessWidget {
  final CollectionSort currentSort;
  final ValueChanged<CollectionSort>? onSortChanged;

  const CollectionSortButton({
    super.key,
    required this.currentSort,
    this.onSortChanged,
  });

  String get _currentLabel {
    switch (currentSort) {
      case CollectionSort.dueDate:
        return 'Due Date';
      case CollectionSort.amountHighToLow:
        return 'Amount: High to Low';
      case CollectionSort.amountLowToHigh:
        return 'Amount: Low to High';
      case CollectionSort.nameAZ:
        return 'Name: A to Z';
      case CollectionSort.nameZA:
        return 'Name: Z to A';
      case CollectionSort.area:
        return 'Area';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CollectionSort>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sort, size: 18),
          const SizedBox(width: 4),
          Text(
            _currentLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
      onSelected: onSortChanged,
      itemBuilder: (context) => [
        _buildSortItem(
          CollectionSort.dueDate,
          'Due Date',
          Icons.calendar_today,
        ),
        _buildSortItem(
          CollectionSort.amountHighToLow,
          'Amount: High to Low',
          Icons.trending_down,
        ),
        _buildSortItem(
          CollectionSort.amountLowToHigh,
          'Amount: Low to High',
          Icons.trending_up,
        ),
        _buildSortItem(
          CollectionSort.nameAZ,
          'Name: A to Z',
          Icons.sort_by_alpha,
        ),
        _buildSortItem(
          CollectionSort.nameZA,
          'Name: Z to A',
          Icons.sort_by_alpha,
          reverse: true,
        ),
        _buildSortItem(
          CollectionSort.area,
          'Area',
          Icons.location_on_outlined,
        ),
      ],
    );
  }

  PopupMenuItem<CollectionSort> _buildSortItem(
    CollectionSort value,
    String label,
    IconData icon, {
    bool reverse = false,
  }) {
    return PopupMenuItem<CollectionSort>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: currentSort == value 
                ? AppColors.primary 
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontWeight: currentSort == value 
                  ? FontWeight.w600 
                  : FontWeight.w400,
            ),
          ),
          if (currentSort == value) ...[
            const Spacer(),
            const Icon(Icons.check, size: 18, color: AppColors.primary),
          ],
        ],
      ),
    );
  }
}

class AreaFilterDropdown extends StatelessWidget {
  final String? selectedArea;
  final List<String> areas;
  final ValueChanged<String?>? onChanged;

  const AreaFilterDropdown({
    super.key,
    this.selectedArea,
    this.areas = const [],
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      value: selectedArea,
      decoration: InputDecoration(
        labelText: 'Area',
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('All Areas'),
        ),
        ...areas.map((area) => DropdownMenuItem(
          value: area,
          child: Text(area),
        )),
      ],
      onChanged: onChanged,
    );
  }
}
