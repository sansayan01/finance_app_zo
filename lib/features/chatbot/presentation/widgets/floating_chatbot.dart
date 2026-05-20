import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart' show loanSummaryProvider;

class FloatingChatbot extends ConsumerStatefulWidget {
  const FloatingChatbot({super.key});

  @override
  ConsumerState<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends ConsumerState<FloatingChatbot> {
  bool _isOpen = false;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _toggleChat() {
    setState(() {
      _isOpen = !_isOpen;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Shift the button up on mobile to avoid overlapping the Navbar
    final bottomOffset = isMobile ? 100.0 : 30.0;

    return Stack(
      children: [
        // Chat Panel
        if (_isOpen)
          Positioned(
            bottom: bottomOffset + 70,
            right: 20,
            child: _buildChatPanel(chatState, theme, primary),
          ),

        // Floating Button
        Positioned(
          bottom: bottomOffset + (bottomInset > 0 ? bottomInset : 0),
          right: 20,
          child: _buildFloatingButton(chatState, primary),
        ),
      ],
    );
  }

  Widget _buildFloatingButton(ChatState chatState, Color primary) {
    return GestureDetector(
      onTap: _toggleChat,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: Icon(
            _isOpen ? Icons.close_rounded : Icons.auto_awesome_rounded,
            key: ValueKey(_isOpen),
            color: Colors.white,
            size: 30,
          ),
        ),
      )
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .shimmer(
              duration: 3.seconds, color: Colors.white.withValues(alpha: 0.3))
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.08, 1.08),
              duration: 2.seconds,
              curve: Curves.easeInOut),
    );
  }

  Widget _buildChatPanel(ChatState chatState, ThemeData theme, Color primary) {
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Responsive Dimensions
    final panelWidth = (size.width - 40).clamp(0.0, 360.0);
    final panelHeight =
        (size.height - 150 - (bottomInset > 0 ? bottomInset : 0))
            .clamp(0.0, 560.0);

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: panelWidth,
            height: panelHeight,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1E).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 50,
                  offset: const Offset(0, 25),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(chatState, isDark, primary),

                // Messages
                Expanded(
                  child: _buildMessageList(chatState, isDark, primary),
                ),

                // Quick Actions
                if (chatState.messages.isEmpty)
                  _buildQuickActions(isDark, primary),

                // Input Area
                _buildInputArea(chatState, isDark, primary),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 400.ms)
          .moveY(begin: 20, end: 0, curve: Curves.easeOutBack),
    );
  }

  Widget _buildHeader(ChatState chatState, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          _buildPulseDot(primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chatState.isListening
                      ? 'Listening...'
                      : 'MicroFlow Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.5,
                    color: chatState.isListening
                        ? primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  chatState.isListening
                      ? 'Speak now'
                      : 'Online • Neural Engine Active',
                  style: TextStyle(
                    fontSize: 10,
                    color: chatState.isListening
                        ? primary.withValues(alpha: 0.6)
                        : primary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              chatState.isContinuous
                  ? Icons.hearing_rounded
                  : Icons.hearing_disabled_rounded,
              size: 20,
              color: chatState.isContinuous
                  ? primary
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            onPressed: () =>
                ref.read(chatProvider.notifier).toggleContinuousMode(),
          ),
          IconButton(
            icon: const Icon(Icons.close_fullscreen_rounded, size: 20),
            onPressed: _toggleChat,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot(Color primary) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 2),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat()).scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.2, 1.2),
        duration: 1.seconds,
        curve: Curves.easeInOut);
  }

  Widget _buildQuickActions(bool isDark, Color primary) {
    final actions = [
      'Check Loan Stats',
      'Savings Growth',
      'System Health',
      'Security Audit'
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map((action) => GestureDetector(
                  onTap: () =>
                      ref.read(chatProvider.notifier).sendMessage(action),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ))
            .toList(),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMessageList(ChatState chatState, bool isDark, Color primary) {
    _scrollToBottom();

    if (chatState.messages.isEmpty && chatState.error == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: primary.withValues(alpha: 0.3), size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              'Sophisticated AI Guidance',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: chatState.messages.length +
          (chatState.isLoading ? 1 : 0) +
          (chatState.error != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < chatState.messages.length) {
          final message = chatState.messages[index];
          return _buildMessageBubble(message, isDark, primary);
        }

        if (chatState.isLoading && index == chatState.messages.length) {
          return _buildLoadingIndicator(primary);
        }

        if (chatState.error != null) {
          return _buildErrorState(chatState.error!, isDark);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 24),
          const SizedBox(height: 8),
          Text(
            'Connection Error',
            style: TextStyle(
                color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54, fontSize: 11),
          ),
        ],
      ),
    ).animate().shake(duration: 500.ms);
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark, Color primary) {
    final isUser = message.role == MessageRole.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = (screenWidth * 0.75).clamp(0.0, 280.0);

    final hasLoanSummaryTag = message.text.contains('[UI:LOAN_SUMMARY]');
    final cleanText = message.text.replaceAll('[UI:LOAN_SUMMARY]', '').trim();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          gradient: isUser
              ? LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser
              ? null
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cleanText.isNotEmpty)
              Text(
                cleanText,
                style: TextStyle(
                  color: isUser
                      ? Colors.white
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.black),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            if (hasLoanSummaryTag && !isUser) ...[
              if (cleanText.isNotEmpty) const SizedBox(height: 12),
              _buildRichLoanSummaryCard(isDark, primary),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: isUser ? 0.1 : -0.1, end: 0);
  }

  Widget _buildRichLoanSummaryCard(bool isDark, Color primary) {
    return Consumer(builder: (context, ref, child) {
      // We will just read the current state if available. We avoid watch to prevent rebuild loops in static messages,
      // but reading is fine. Actually, since it's a FutureProvider, we can handle its state.
      final summaryAsync = ref.watch(loanSummaryProvider);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 16, color: primary),
                const SizedBox(width: 6),
                Text('Live Portfolio',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: primary)),
              ],
            ),
            const SizedBox(height: 12),
            summaryAsync.when(
              data: (data) => _buildLiveMetrics(data, isDark, primary),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error loading metrics',
                  style: TextStyle(color: Colors.red, fontSize: 10)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLiveMetrics(dynamic data, bool isDark, Color primary) {
    // data is LoanSummary
    final par = data.parPercentage / 100.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Portfolio at Risk (PAR)',
            style: TextStyle(
                fontSize: 10, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: par.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildMetricStat(
                'Active', '${data.activeLoans}', Colors.green, isDark),
            _buildMetricStat(
                'Default', '${data.defaultLoans}', Colors.red, isDark),
            _buildMetricStat('Total', '${data.totalLoans}', primary, isDark),
          ],
        )
      ],
    );
  }

  Widget _buildMetricStat(String label, String val, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 9, color: isDark ? Colors.white54 : Colors.black54)),
        const SizedBox(height: 2),
        Text(val,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildLoadingIndicator(Color primary) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              3,
              (i) => Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat()).scale(
                      delay: (i * 200).ms,
                      duration: 800.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.6, 1.6))),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatState chatState, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.01)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Expanded Voice Input
          _buildVoiceButton(chatState, primary),
          const SizedBox(width: 12),
          // Capsule Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.02)),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (val) {
                  ref.read(chatProvider.notifier).sendMessage(val);
                  _messageController.clear();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildSendButton(primary),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(ChatState chatState, Color primary) {
    return GestureDetector(
      onTap: chatState.isListening
          ? () => ref.read(chatProvider.notifier).stopListening()
          : () => ref.read(chatProvider.notifier).startListening(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: chatState.isListening
              ? Colors.red.withValues(alpha: 0.15)
              : primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          chatState.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 22,
          color: chatState.isListening ? Colors.red : primary,
        ),
      )
          .animate(target: chatState.isListening ? 1 : 0)
          .shimmer(color: Colors.white)
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.2, 1.2),
              duration: 500.ms,
              curve: Curves.elasticOut),
    );
  }

  Widget _buildSendButton(Color primary) {
    return Container(
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_upward_rounded,
            size: 20, color: Colors.white),
        onPressed: () {
          ref.read(chatProvider.notifier).sendMessage(_messageController.text);
          _messageController.clear();
        },
      ),
    );
  }
}
