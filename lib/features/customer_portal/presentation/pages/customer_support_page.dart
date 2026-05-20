import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../data/providers/customer_support_providers.dart';
import '../../data/providers/customer_member_provider.dart';
import '../../data/models/customer_ticket_model.dart';
import '../widgets/customer_ticket_card.dart';
import '../widgets/customer_empty_state.dart';

class CustomerSupportPage extends ConsumerWidget {
  const CustomerSupportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync = ref.watch(customerTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTicketDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Ticket'),
      ),
      body: ticketsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tickets) {
          if (tickets.isEmpty) {
            return const CustomerEmptyState(
              icon: Icons.support_agent_rounded,
              title: 'No Support Tickets',
              subtitle: 'Need help? Create a new support ticket.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(customerTicketsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: tickets.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: CustomerTicketCard(
                    ticket: tickets[index],
                    onTap: () => _showTicketDetail(context, ref, tickets[index]),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateTicketDialog(BuildContext context, WidgetRef ref) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('New Support Ticket'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        hintText: 'Brief description of your issue',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText: 'Describe your issue in detail',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                            value: 'normal', child: Text('Normal')),
                        DropdownMenuItem(
                            value: 'high', child: Text('High')),
                        DropdownMenuItem(
                            value: 'urgent', child: Text('Urgent')),
                      ],
                      onChanged: (v) =>
                          setDialogState(() => priority = v ?? 'normal'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (subjectController.text.trim().isEmpty ||
                        messageController.text.trim().isEmpty) {
                      return;
                    }
                    final customerId =
                        ref.read(currentCustomerIdSyncProvider);
                    if (customerId == null) return;

                    final success = await ref
                        .read(createTicketProvider.notifier)
                        .createTicket(
                          customerId: customerId,
                          subject: subjectController.text.trim(),
                          message: messageController.text.trim(),
                          priority: priority,
                        );
                    if (success && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showTicketDetail(
      BuildContext context, WidgetRef ref, CustomerTicketModel ticket) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _TicketDetailSheet(ticket: ticket),
    );
  }
}

class _TicketDetailSheet extends ConsumerStatefulWidget {
  final CustomerTicketModel ticket;
  const _TicketDetailSheet({required this.ticket});

  @override
  ConsumerState<_TicketDetailSheet> createState() => _TicketDetailSheetState();
}

class _TicketDetailSheetState extends ConsumerState<_TicketDetailSheet> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
        customerTicketMessagesProvider(widget.ticket.id));
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.ticket.subject,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.ticket.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                          ?.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            // Messages
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet'),
                    );
                  }
                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm + 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppSpacing.md),
                          ),
                          child: Text(msg.message),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Message input
            if (!widget.ticket.isResolved)
              Container(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: () async {
                        final msg = _messageController.text.trim();
                        if (msg.isEmpty) return;
                        final customerId =
                            ref.read(currentCustomerIdSyncProvider);
                        if (customerId == null) return;

                        final success = await ref
                            .read(ticketMessageProvider.notifier)
                            .addMessage(
                              ticketId: widget.ticket.id,
                              senderId: customerId,
                              message: msg,
                            );
                        if (success) {
                          _messageController.clear();
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
