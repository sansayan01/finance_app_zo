import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/providers/customer_support_providers.dart';
import '../../data/models/customer_ticket_model.dart';
import '../widgets/customer_ticket_card.dart';
import '../widgets/customer_empty_state.dart';
import '../../data/providers/customer_member_provider.dart';

class CustomerSupportPage extends ConsumerStatefulWidget {
  const CustomerSupportPage({super.key});

  @override
  ConsumerState<CustomerSupportPage> createState() =>
      _CustomerSupportPageState();
}

class _CustomerSupportPageState extends ConsumerState<CustomerSupportPage>
    with TickerProviderStateMixin {
  late final AnimationController _staggerController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    );
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOutCubic),
    ));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ticketsAsync = ref.watch(customerTicketsProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Column(
        children: [
          _buildGradientHeader(context, isDark, theme),
          Expanded(
            child: ticketsAsync.when(
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.errorDark),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Something went wrong',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      e.toString(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              data: (tickets) {
                if (tickets.isEmpty) {
                  return CustomerEmptyState(
                    icon: Icons.support_agent_rounded,
                    title: 'No Support Tickets',
                    subtitle:
                        'Need help? Tap the button below to create a new ticket.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(customerTicketsProvider),
                  color: AppColors.primary,
                  child: _buildTicketList(tickets, isDark, theme),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader(
      BuildContext context, bool isDark, ThemeData theme) {
    return FadeTransition(
      opacity: _headerFade,
      child: SlideTransition(
        position: _headerSlide,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      const Color(0xFF1A1040),
                      const Color(0xFF0F1115),
                    ]
                  : [
                      AppColors.primary,
                      AppColors.accent,
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        isDark: isDark,
                      ),
                      const Spacer(),
                      _HeaderIconButton(
                        icon: Icons.add_rounded,
                        onTap: () => _showCreateTicketSheet(context),
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Support',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'We\'re here to help you',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTicketList(
      List<CustomerTicketModel> tickets, bool isDark, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xxl),
      itemCount: tickets.length,
      itemBuilder: (context, index) {
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final animation = CurvedAnimation(
          parent: _staggerController,
          curve: Interval(delay, delay + 0.4, curve: Curves.easeOutCubic),
        );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.12),
              end: Offset.zero,
            ).animate(animation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: CustomerTicketCard(
                ticket: tickets[index],
                onTap: () =>
                    _showTicketDetailSheet(context, tickets[index]),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Create Ticket ──────────────────────────────────────────────────────

  void _showCreateTicketSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTicketSheet(),
    );
  }

  // ── Ticket Detail ──────────────────────────────────────────────────────

  void _showTicketDetailSheet(
      BuildContext context, CustomerTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Header Icon Button
// ══════════════════════════════════════════════════════════════════════════════

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Create Ticket Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _CreateTicketSheet extends ConsumerStatefulWidget {
  const _CreateTicketSheet();

  @override
  ConsumerState<_CreateTicketSheet> createState() => _CreateTicketSheetState();
}

class _CreateTicketSheetState extends ConsumerState<_CreateTicketSheet> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _subjectFocus = FocusNode();
  String _priority = 'normal';
  bool _isSubmitting = false;

  static const _priorities = [
    _PriorityOption('low', 'Low', Color(0xFF94A3B8), Color(0xFF64748B)),
    _PriorityOption('normal', 'Normal', AppColors.info, AppColors.primary),
    _PriorityOption('high', 'High', Color(0xFFF97316), Color(0xFFEA580C)),
    _PriorityOption('urgent', 'Urgent', Color(0xFFEF4444), Color(0xFFDC2626)),
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _subjectFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight)
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.premiumGradient,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.headset_mic_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Support Ticket',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Describe your issue and we\'ll get back to you',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Subject field
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _PremiumTextField(
                controller: _subjectController,
                focusNode: _subjectFocus,
                label: 'Subject',
                hint: 'Brief description of your issue',
                icon: Icons.subject_rounded,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Message field
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _PremiumTextField(
                controller: _messageController,
                label: 'Message',
                hint: 'Describe your issue in detail...',
                icon: Icons.message_rounded,
                maxLines: 4,
                isDark: isDark,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Priority selector
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: _priorities.map((p) {
                      final isSelected = _priority == p.value;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: p == _priorities.last ? 0 : AppSpacing.sm,
                          ),
                          child: _PriorityChip(
                            option: p,
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () =>
                                setState(() => _priority = p.value),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Submit button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: _GradientButton(
                label: 'Submit Ticket',
                icon: Icons.send_rounded,
                isLoading: _isSubmitting,
                onTap: _handleSubmit,
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final subject = _subjectController.text.trim();
    final message = _messageController.text.trim();
    if (subject.isEmpty || message.isEmpty) return;

    final customerId = ref.read(currentCustomerIdSyncProvider);
    if (customerId == null) return;

    setState(() => _isSubmitting = true);

    final success = await ref
        .read(createTicketProvider.notifier)
        .createTicket(
          customerId: customerId,
          subject: subject,
          message: message,
          priority: _priority,
        );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) Navigator.of(context).pop();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Ticket Detail Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _TicketDetailSheet extends ConsumerStatefulWidget {
  final CustomerTicketModel ticket;
  const _TicketDetailSheet({required this.ticket});

  @override
  ConsumerState<_TicketDetailSheet> createState() =>
      _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<_TicketDetailSheet> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final messagesAsync =
        ref.watch(customerTicketMessagesProvider(widget.ticket.id));
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: isDark ? 0.5 : 0.08),
                blurRadius: 40,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Premium header
              _buildDetailHeader(isDark, theme),

              // Messages
              Expanded(
                child: messagesAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Failed to load messages',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48,
                                color: (isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight)
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'No messages yet',
                              style:
                                  theme.textTheme.bodyMedium?.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Send a message to start the conversation',
                              style:
                                  theme.textTheme.bodySmall?.copyWith(
                                color: (isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight)
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isCustomer = msg.senderId ==
                            ref.read(currentCustomerIdSyncProvider);
                        return _ChatBubble(
                          message: msg.message,
                          isCustomer: isCustomer,
                          timestamp: msg.createdAt,
                          isDark: isDark,
                        );
                      },
                    );
                  },
                ),
              ),

              // Message input
              if (!widget.ticket.isResolved)
                _buildMessageInput(isDark, theme, bottomPadding),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailHeader(bool isDark, ThemeData theme) {
    final statusColor = switch (widget.ticket.status) {
      'open' => AppColors.warning,
      'in_progress' || 'inProgress' => AppColors.info,
      'resolved' || 'closed' => AppColors.success,
      _ => AppColors.warning,
    };
    final statusLabel = switch (widget.ticket.status) {
      'in_progress' || 'inProgress' => 'In Progress',
      _ =>
        widget.ticket.status[0].toUpperCase() +
            widget.ticket.status.substring(1),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight)
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      statusColor,
                      statusColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.ticket.isResolved
                      ? Icons.check_circle_rounded
                      : Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.ticket.subject,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _PriorityBadge(
                            priority: widget.ticket.priority,
                            isDark: isDark),
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: (isDark
                            ? Colors.white
                            : Colors.black)
                        .withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close_rounded,
                      size: 18,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),

          // Original message
          if (widget.ticket.message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                color: (isDark
                        ? Colors.white
                        : AppColors.primary)
                    .withValues(alpha: isDark ? 0.03 : 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (isDark
                          ? Colors.white
                          : AppColors.primary)
                      .withValues(alpha: isDark ? 0.04 : 0.08),
                  width: 0.5,
                ),
              ),
              child: Text(
                widget.ticket.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput(
      bool isDark, ThemeData theme, double bottomPadding) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md,
          bottomPadding + AppSpacing.sm),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: isDark ? AppColors.fillDark : AppColors.fillLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: null,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: _handleSendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.premiumGradient,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendMessage() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    final customerId = ref.read(currentCustomerIdSyncProvider);
    if (customerId == null) return;

    final success = await ref
        .read(ticketMessageProvider.notifier)
        .addMessage(
          ticketId: widget.ticket.id,
          senderId: customerId,
          message: msg,
        );

    if (success && mounted) {
      _messageController.clear();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared Components
// ══════════════════════════════════════════════════════════════════════════════

class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final bool isDark;

  const _PremiumTextField({
    required this.controller,
    this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.fillDark : AppColors.fillLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment:
                maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  top: maxLines > 1 ? AppSpacing.md + 2 : 0,
                ),
                child: Icon(icon,
                    size: 20,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: maxLines,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 4,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriorityOption {
  final String value;
  final String label;
  final Color color;
  final Color darkColor;

  const _PriorityOption(this.value, this.label, this.color, this.darkColor);
}

class _PriorityChip extends StatelessWidget {
  final _PriorityOption option;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.option,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDark ? option.darkColor : option.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.18 : 0.1)
              : (isDark ? AppColors.fillDark : AppColors.fillLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : (isDark
                        ? Colors.white
                        : Colors.black)
                    .withValues(alpha: isDark ? 0.06 : 0.04),
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.6),
                  ],
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  final bool isDark;

  const _PriorityBadge({required this.priority, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (priority) {
      'urgent' => (const Color(0xFFEF4444), 'Urgent'),
      'high' => (const Color(0xFFF97316), 'High'),
      'normal' => (AppColors.info, 'Normal'),
      'low' => (const Color(0xFF94A3B8), 'Low'),
      _ => (const Color(0xFF94A3B8), priority),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onTap;

  const _GradientButton({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLoading
                ? [
                    AppColors.primary.withValues(alpha: 0.6),
                    AppColors.accent.withValues(alpha: 0.6),
                  ]
                : AppColors.premiumGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isLoading
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isCustomer;
  final DateTime? timestamp;
  final bool isDark;

  const _ChatBubble({
    required this.message,
    required this.isCustomer,
    this.timestamp,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Column(
          crossAxisAlignment:
              isCustomer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                gradient: isCustomer
                    ? const LinearGradient(
                        colors: AppColors.premiumGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isCustomer
                    ? null
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.fillLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isCustomer ? 18 : 4),
                  bottomRight: Radius.circular(isCustomer ? 4 : 18),
                ),
                border: isCustomer
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                        width: 0.5,
                      ),
              ),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isCustomer
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                  height: 1.45,
                ),
              ),
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _formatTimestamp(timestamp!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[dt.weekday - 1]} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
