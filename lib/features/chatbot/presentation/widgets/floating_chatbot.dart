import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_config_provider.dart';
import '../../../home/data/providers/dashboard_providers.dart' show loanSummaryProvider;

/// Messenger-style draggable chatbot that can be moved anywhere on screen.
/// - Drag to reposition
/// - Tap to open/close chat panel
/// - Snaps to nearest screen edge on release
/// - Persists position across sessions
/// - Panel expands away from the snapped edge
class FloatingChatbot extends ConsumerStatefulWidget {
  const FloatingChatbot({super.key});

  @override
  ConsumerState<FloatingChatbot> createState() => _FloatingChatbotState();
}

class _FloatingChatbotState extends ConsumerState<FloatingChatbot>
    with SingleTickerProviderStateMixin {
  static const _prefKeyX = 'chatbot_pos_x';
  static const _prefKeyY = 'chatbot_pos_y';
  static const _buttonSize = 58.0;
  static const _edgePadding = 8.0;
  static const _panelWidth = 340.0;
  static const _panelMaxHeight = 500.0;

  bool _isOpen = false;
  Offset _position = const Offset(-1, -1); // -1,-1 = not yet loaded
  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartY = 0;
  bool _isInitialized = false;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Edge the button is snapped to
  _SnapEdge _snapEdge = _SnapEdge.right;

  late AnimationController _snapAnimController;
  Animation<Offset>? _snapAnimation;

  @override
  void initState() {
    super.initState();
    _snapAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_snapAnimation != null) {
          setState(() {
            _position = _snapAnimation!.value;
          });
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadPosition();
    }
  }

  Future<void> _loadPosition() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final bottomOffset = isMobile ? 100.0 : 30.0;

    final savedX = prefs.getDouble(_prefKeyX);
    final savedY = prefs.getDouble(_prefKeyY);

    if (savedX != null && savedY != null) {
      setState(() {
        _position = Offset(savedX, savedY);
        _snapEdge = _detectEdge(savedX, savedY, size);
      });
    } else {
      // Default: bottom-right
      setState(() {
        _position = Offset(
          size.width - _buttonSize - 16,
          size.height - _buttonSize - bottomOffset,
        );
        _snapEdge = _SnapEdge.right;
      });
    }
  }

  Future<void> _savePosition(double x, double y) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKeyX, x);
    await prefs.setDouble(_prefKeyY, y);
  }

  _SnapEdge _detectEdge(double x, double y, Size screenSize) {
    final centerX = x + _buttonSize / 2;
    final centerY = y + _buttonSize / 2;

    final distLeft = centerX;
    final distRight = screenSize.width - centerX;
    final distTop = centerY;
    final distBottom = screenSize.height - centerY;

    final minDist = min(min(distLeft, distRight), min(distTop, distBottom));

    if (minDist == distLeft) return _SnapEdge.left;
    if (minDist == distRight) return _SnapEdge.right;
    if (minDist == distTop) return _SnapEdge.top;
    return _SnapEdge.bottom;
  }

  Offset _snapToEdge(double x, double y, Size screenSize) {
    final isMobile = screenSize.width < 600;
    final bottomNavHeight = isMobile ? 80.0 : 0.0;
    final topNavHeight = isMobile ? 0.0 : 60.0; // HUD nav on desktop

    // Clamp within safe bounds
    final minX = _edgePadding;
    final maxX = screenSize.width - _buttonSize - _edgePadding;
    final minY = topNavHeight + _edgePadding;
    final maxY = screenSize.height - _buttonSize - bottomNavHeight - _edgePadding;

    x = x.clamp(minX, maxX);
    y = y.clamp(minY, maxY);

    final centerX = x + _buttonSize / 2;
    final centerY = y + _buttonSize / 2;

    // Calculate distances to each edge
    final distLeft = centerX;
    final distRight = screenSize.width - centerX;
    final distTop = centerY;
    final distBottom = screenSize.height - centerY;

    final minDist = min(min(distLeft, distRight), min(distTop, distBottom));

    // Snap to the nearest edge
    if (minDist == distLeft) {
      _snapEdge = _SnapEdge.left;
      return Offset(minX, y);
    } else if (minDist == distRight) {
      _snapEdge = _SnapEdge.right;
      return Offset(maxX, y);
    } else if (minDist == distTop) {
      _snapEdge = _SnapEdge.top;
      return Offset(x, minY);
    } else {
      _snapEdge = _SnapEdge.bottom;
      return Offset(x, maxY);
    }
  }

  void _onPanStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx - _position.dx;
    _dragStartY = details.globalPosition.dy - _position.dy;
    _snapAnimController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final newX = details.globalPosition.dx - _dragStartX;
    final newY = details.globalPosition.dy - _dragStartY;

    // Mark as dragging only if moved more than a threshold
    final dx = (newX - _position.dx).abs();
    final dy = (newY - _position.dy).abs();
    if (!_isDragging && (dx > 5 || dy > 5)) {
      setState(() => _isDragging = true);
    }

    if (_isDragging) {
      setState(() {
        _position = Offset(newX, newY);
      });
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) {
      // It was a tap, not a drag
      _toggleChat();
      setState(() => _isDragging = false);
      return;
    }

    // Snap to nearest edge with animation
    final size = MediaQuery.of(context).size;
    final snapped = _snapToEdge(_position.dx, _position.dy, size);

    _snapAnimation = Tween<Offset>(
      begin: _position,
      end: snapped,
    ).animate(CurvedAnimation(
      parent: _snapAnimController,
      curve: Curves.easeOutBack,
    ));

    _snapAnimController.forward(from: 0);
    _savePosition(snapped.dx, snapped.dy);
    setState(() => _isDragging = false);
  }

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

  /// Calculate where the chat panel should appear based on the snap edge
  Offset _getPanelPosition(Size screenSize) {
    const gap = 12.0;

    switch (_snapEdge) {
      case _SnapEdge.right:
        // Panel appears to the left of the button
        return Offset(
          _position.dx - _panelWidth - gap,
          _position.dy - _panelMaxHeight + _buttonSize,
        );
      case _SnapEdge.left:
        // Panel appears to the right of the button
        return Offset(
          _position.dx + _buttonSize + gap,
          _position.dy - _panelMaxHeight + _buttonSize,
        );
      case _SnapEdge.top:
        // Panel appears below the button
        return Offset(
          _position.dx + _buttonSize / 2 - _panelWidth / 2,
          _position.dy + _buttonSize + gap,
        );
      case _SnapEdge.bottom:
        // Panel appears above the button
        return Offset(
          _position.dx + _buttonSize / 2 - _panelWidth / 2,
          _position.dy - _panelMaxHeight - gap,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_position == const Offset(-1, -1)) {
      return const SizedBox.shrink(); // Not yet loaded
    }

    // Hide chatbot if user disabled it in settings
    final config = ref.watch(chatConfigProvider);
    if (!config.chatbotEnabled) {
      return const SizedBox.shrink();
    }

    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final screenSize = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Chat Panel (positioned relative to the button)
        if (_isOpen)
          _buildPositionedPanel(chatState, theme, primary, screenSize),

        // Floating draggable button
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: _buildFloatingButton(chatState, primary),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionedPanel(
      ChatState chatState, ThemeData theme, Color primary, Size screenSize) {
    final panelPos = _getPanelPosition(screenSize);

    // Clamp panel within screen bounds
    final clampedLeft = panelPos.dx.clamp(
        8.0, screenSize.width - _panelWidth - 8.0);
    final clampedTop = panelPos.dy.clamp(
        8.0, screenSize.height - _panelMaxHeight - 8.0);

    return Positioned(
      left: clampedLeft,
      top: clampedTop,
      child: _buildChatPanel(chatState, theme, primary),
    );
  }

  Widget _buildFloatingButton(ChatState chatState, Color primary) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _buttonSize,
      height: _buttonSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isDragging
              ? [primary.withValues(alpha: 0.9), primary.withValues(alpha: 0.7)]
              : [primary, primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: _isDragging ? 0.6 : 0.4),
            blurRadius: _isDragging ? 32 : 20,
            offset: Offset(0, _isDragging ? 4 : 6),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: Icon(
          _isOpen ? Icons.close_rounded : Icons.auto_awesome_rounded,
          key: ValueKey(_isOpen),
          color: Colors.white,
          size: 26,
        ),
      ),
    )
        .animate(
            onPlay: _isDragging ? null : (controller) => controller.repeat(reverse: true))
        .shimmer(
            duration: 3.seconds, color: Colors.white.withValues(alpha: 0.25))
        .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.06, 1.06),
            duration: 2.seconds,
            curve: Curves.easeInOut);
  }

  Widget _buildChatPanel(ChatState chatState, ThemeData theme, Color primary) {
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final panelW = min(_panelWidth, size.width - 16.0);
    final panelH = min(_panelMaxHeight, size.height - 100 - (bottomInset > 0 ? bottomInset : 0));

    return Material(
      type: MaterialType.transparency,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            width: panelW,
            height: panelH.clamp(300.0, _panelMaxHeight),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1E).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildHeader(chatState, isDark, primary),
                Expanded(
                  child: _buildMessageList(chatState, isDark, primary),
                ),
                if (chatState.messages.isEmpty)
                  _buildQuickActions(isDark, primary),
                _buildInputArea(chatState, isDark, primary),
              ],
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms)
          .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack),
    );
  }

  Widget _buildHeader(ChatState chatState, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          _buildPulseDot(primary),
          const SizedBox(width: 10),
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
                    fontSize: 14,
                    letterSpacing: -0.5,
                    color: chatState.isListening
                        ? primary
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  chatState.isListening
                      ? 'Speak now'
                      : 'Online • Neural Engine',
                  style: TextStyle(
                    fontSize: 9,
                    color: chatState.isListening
                        ? primary.withValues(alpha: 0.6)
                        : primary.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          // Drag handle indicator
          Tooltip(
            message: 'Drag to reposition',
            child: Icon(
              Icons.drag_indicator_rounded,
              size: 16,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              chatState.isContinuous
                  ? Icons.hearing_rounded
                  : Icons.hearing_disabled_rounded,
              size: 18,
              color: chatState.isContinuous
                  ? primary
                  : (isDark ? Colors.white38 : Colors.black38),
            ),
            onPressed: () =>
                ref.read(chatProvider.notifier).toggleContinuousMode(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: _toggleChat,
            color: isDark ? Colors.white38 : Colors.black38,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseDot(Color primary) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.4),
              blurRadius: 6,
              spreadRadius: 1),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: actions
            .map((action) => GestureDetector(
                  onTap: () =>
                      ref.read(chatProvider.notifier).sendMessage(action),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: primary.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      action,
                      style: TextStyle(
                          color: primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ))
            .toList(),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15, end: 0);
  }

  Widget _buildMessageList(ChatState chatState, bool isDark, Color primary) {
    _scrollToBottom();

    if (chatState.messages.isEmpty && chatState.error == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: primary.withValues(alpha: 0.25), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              'AI Financial Assistant',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ask me anything about your portfolio',
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
          const SizedBox(height: 6),
          Text(
            'Connection Error',
            style: TextStyle(
                color: Colors.red, fontWeight: FontWeight.w700, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54, fontSize: 10),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms);
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark, Color primary) {
    final isUser = message.role == MessageRole.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = min(screenWidth * 0.65, 250.0);

    final hasLoanSummaryTag = message.text.contains('[UI:LOAN_SUMMARY]');
    final cleanText = message.text.replaceAll('[UI:LOAN_SUMMARY]', '').trim();

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
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
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            if (hasLoanSummaryTag && !isUser) ...[
              if (cleanText.isNotEmpty) const SizedBox(height: 8),
              _buildRichLoanSummaryCard(isDark, primary),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: isUser ? 0.08 : -0.08, end: 0);
  }

  Widget _buildRichLoanSummaryCard(bool isDark, Color primary) {
    return Consumer(builder: (context, ref, child) {
      final summaryAsync = ref.watch(loanSummaryProvider);
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primary.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pie_chart_rounded, size: 14, color: primary),
                const SizedBox(width: 5),
                Text('Live Portfolio',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        color: primary)),
              ],
            ),
            const SizedBox(height: 8),
            summaryAsync.when(
              data: (data) => _buildLiveMetrics(data, isDark, primary),
              loading: () => const SizedBox(
                  height: 30,
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('Error loading metrics',
                  style: TextStyle(color: Colors.red, fontSize: 9)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLiveMetrics(dynamic data, bool isDark, Color primary) {
    final par = data.parPercentage / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAR Rate',
            style: TextStyle(
                fontSize: 9, color: isDark ? Colors.white70 : Colors.black54)),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: par.clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        ),
        const SizedBox(height: 8),
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
                fontSize: 8, color: isDark ? Colors.white54 : Colors.black54)),
        const SizedBox(height: 1),
        Text(val,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }

  Widget _buildLoadingIndicator(Color primary) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
              3,
              (i) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.3),
                        shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat()).scale(
                      delay: (i * 150).ms,
                      duration: 700.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.5, 1.5))),
        ),
      ),
    );
  }

  Widget _buildInputArea(ChatState chatState, bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.01)
            : Colors.black.withValues(alpha: 0.01),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildVoiceButton(chatState, primary),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.02)),
              ),
              child: TextField(
                controller: _messageController,
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  hintStyle: TextStyle(
                      color: isDark ? Colors.white24 : Colors.black26,
                      fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (val) {
                  ref.read(chatProvider.notifier).sendMessage(val);
                  _messageController.clear();
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: chatState.isListening
              ? Colors.red.withValues(alpha: 0.12)
              : primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          chatState.isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          size: 18,
          color: chatState.isListening ? Colors.red : primary,
        ),
      )
          .animate(target: chatState.isListening ? 1 : 0)
          .shimmer(color: Colors.white)
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.15, 1.15),
              duration: 400.ms,
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
              color: primary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.white),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        onPressed: () {
          ref.read(chatProvider.notifier).sendMessage(_messageController.text);
          _messageController.clear();
        },
      ),
    );
  }

  @override
  void dispose() {
    _snapAnimController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

enum _SnapEdge { left, right, top, bottom }
