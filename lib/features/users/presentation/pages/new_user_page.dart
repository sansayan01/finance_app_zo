import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/new_user_provider.dart';

class NewUserPage extends ConsumerStatefulWidget {
  final String? initialBranchId;

  const NewUserPage({super.key, this.initialBranchId});

  @override
  ConsumerState<NewUserPage> createState() => _NewUserPageState();
}

class _NewUserPageState extends ConsumerState<NewUserPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _employeeIdController = TextEditingController();
  final TextEditingController _zoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _aadharController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  TextInputType _panKeyboardType = TextInputType.text;
  final FocusNode _panFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(newUserProvider);
      _fullNameController.text = state.fullName;
      _emailController.text = state.email;
      _mobileController.text = state.mobileNumber;
      _employeeIdController.text = state.employeeId;
      _zoneController.text = state.assignedZone;
      _addressController.text = "";
      _aadharController.text = state.aadharNumber;
      _panController.text = state.panNumber;
      _passwordController.text = state.password;
    });

    _panFocusNode.addListener(() {
      if (_panFocusNode.hasFocus) {
        _updatePanKeyboard(_panController.text);
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _employeeIdController.dispose();
    _zoneController.dispose();
    _addressController.dispose();
    _aadharController.dispose();
    _panController.dispose();
    _passwordController.dispose();
    _panFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final state = ref.watch(newUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    // Hierarchy check: Only Admin and Manager can create users
    final canCreate = currentUser?.role == UserRole.executiveAdmin ||
        currentUser?.role == UserRole.manager;

    if (!canCreate) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: const Center(
            child: Text('You do not have permission to create users.')),
      );
    }

    // Filter roles based on hierarchy
    final List<UserRole> availableRoles;
    if (currentUser?.role == UserRole.superAdmin) {
      // Super Admin can create anyone
      availableRoles = UserRole.values;
    } else if (currentUser?.role == UserRole.executiveAdmin) {
      // Executive Admin can create manager, collectionAgent, customer
      availableRoles = [
        UserRole.manager,
        UserRole.collectionAgent,
        UserRole.customer,
      ];
    } else {
      // Manager can only create collectionAgent and customer for their branch
      availableRoles = [UserRole.collectionAgent, UserRole.customer];
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            ref.read(newUserProvider.notifier).reset();
            context.pop();
          },
        ),
        title: Text(
          'New User',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ),
      body: Column(
        children: [
          // ── Scrollable form body ──
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  isNarrow ? 16 : 24, 8, isNarrow ? 16 : 24, 24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  if (isDesktop) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 3,
                            child: _buildFormDetails(state, theme, isDark,
                                primary, false, availableRoles)),
                        const SizedBox(width: 24),
                        Expanded(
                            flex: 2,
                            child:
                                _buildSummary(state, theme, isDark, primary)),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildSummary(state, theme, isDark, primary),
                        const SizedBox(height: 20),
                        _buildFormDetails(state, theme, isDark, primary,
                            isNarrow, availableRoles),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
          // ── Fixed bottom action bar ──
          _buildBottomBar(theme, isDark, primary, state),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOTTOM ACTION BAR
  // ═══════════════════════════════════════════════════
  Widget _buildBottomBar(
      ThemeData theme, bool isDark, Color primary, NewUserState state) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.elevatedDark : Colors.white,
        border: Border(
            top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ref.read(newUserProvider.notifier).reset();
                context.pop();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Discard',
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () async {
                      try {
                        await ref.read(newUserProvider.notifier).createUser();

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 12),
                                Text('User Profile Created Successfully'),
                              ],
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        context.pop();
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add_rounded, size: 18),
              label: Text(
                state.isLoading ? 'Creating...' : 'Create Profile',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                disabledBackgroundColor: primary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  SECTION HEADER
  // ═══════════════════════════════════════════════════
  Widget _buildSectionHeader(
      String title, IconData icon, ThemeData theme, Color accent) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.18),
                accent.withValues(alpha: 0.06)
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        const SizedBox(width: 12),
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  FORM DETAILS
  // ═══════════════════════════════════════════════════
  Widget _buildFormDetails(NewUserState state, ThemeData theme, bool isDark,
      Color primary, bool isNarrow, List<UserRole> availableRoles) {
    return Column(
      children: [
        // ── Account Details Card ──
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Account Details',
                  Icons.person_outline_rounded, theme, primary),
              const SizedBox(height: 28),
              _buildTwoColumn(
                isNarrow: isNarrow,
                first: _buildInputField(
                  label: 'FULL NAME',
                  hint: 'Enter legal name',
                  controller: _fullNameController,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (val) =>
                      ref.read(newUserProvider.notifier).updateFullName(val),
                  theme: theme,
                  isDark: isDark,
                ),
                second: _buildInputField(
                  label: 'EMAIL ADDRESS',
                  hint: 'staff@microflow.pro',
                  icon: Icons.mail_outline_rounded,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [LowerCaseTextFormatter()],
                  onChanged: (val) =>
                      ref.read(newUserProvider.notifier).updateEmail(val),
                  theme: theme,
                  isDark: isDark,
                ),
              ),
              const SizedBox(height: 20),
              _buildTwoColumn(
                isNarrow: isNarrow,
                first: _buildInputField(
                  label: 'MOBILE NUMBER',
                  hint: '+91 XXXXXXXXXX',
                  icon: Icons.phone_android_outlined,
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(14),
                    _MobileFormatter(),
                  ],
                  onChanged: (val) => ref
                      .read(newUserProvider.notifier)
                      .updateMobileNumber(val.replaceAll(RegExp(r'\D'), '')),
                  theme: theme,
                  isDark: isDark,
                ),
                second: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('SYSTEM ROLE', theme),
                    const SizedBox(height: 10),
                    _buildDropdown(
                      value: state.role.name,
                      hint: 'Select role',
                      icon: Icons.shield_outlined,
                      items: availableRoles.map((e) => e.name).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(newUserProvider.notifier).updateRole(
                                UserRole.values
                                    .firstWhere((e) => e.name == val),
                              );
                        }
                      },
                      theme: theme,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildInputField(
                label: 'RESIDENTIAL ADDRESS',
                hint: 'Enter complete home address',
                icon: Icons.home_outlined,
                controller: _addressController,
                textCapitalization: TextCapitalization.words,
                onChanged: (val) {},
                theme: theme,
                isDark: isDark,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0),

        // ── Field Operations Card (conditional) ──
        if (state.role != UserRole.customer) ...[
          const SizedBox(height: 20),
          GlassCard(
            padding: EdgeInsets.all(isNarrow ? 18 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                    'Field Operations',
                    Icons.corporate_fare_outlined,
                    theme,
                    isDark ? AppColors.warningDark : AppColors.orange),
                const SizedBox(height: 28),
                _buildTwoColumn(
                  isNarrow: isNarrow,
                  first: _buildInputField(
                    label: 'EMPLOYEE ID',
                    hint: 'Internal reference #',
                    controller: _employeeIdController,
                    onChanged: (val) => ref
                        .read(newUserProvider.notifier)
                        .updateEmployeeId(val),
                    theme: theme,
                    isDark: isDark,
                  ),
                  second: _buildInputField(
                    label: 'ASSIGNED ZONE / AREA',
                    hint: 'e.g. North Sector',
                    icon: Icons.location_on_outlined,
                    controller: _zoneController,
                    onChanged: (val) => ref
                        .read(newUserProvider.notifier)
                        .updateAssignedZone(val),
                    theme: theme,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.04, end: 0),
        ],

        // ── Identity Details Card ──
        const SizedBox(height: 20),
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Identity Verification', Icons.badge_outlined,
                  theme, isDark ? AppColors.successDark : AppColors.success),
              const SizedBox(height: 28),
              _buildTwoColumn(
                isNarrow: isNarrow,
                first: _buildInputField(
                  label: 'AADHAR NUMBER',
                  hint: 'XXXX XXXX XXXX',
                  icon: Icons.fingerprint_outlined,
                  controller: _aadharController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(14),
                    _AadharFormatter(),
                  ],
                  onChanged: (val) => ref
                      .read(newUserProvider.notifier)
                      .updateAadharNumber(val.replaceAll(' ', '')),
                  theme: theme,
                  isDark: isDark,
                ),
                second: _buildInputField(
                  label: 'PAN NUMBER',
                  hint: 'ABCDE 1234 F',
                  icon: Icons.credit_card_outlined,
                  controller: _panController,
                  focusNode: _panFocusNode,
                  keyboardType: _panKeyboardType,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(10),
                    _PanFormatter(),
                  ],
                  onChanged: (val) {
                    ref.read(newUserProvider.notifier).updatePanNumber(val);
                    _updatePanKeyboard(val);
                  },
                  theme: theme,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.04, end: 0),

        // ── Security Credentials Card ──
        const SizedBox(height: 20),
        GlassCard(
          padding: EdgeInsets.all(isNarrow ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('Security Credentials', Icons.key_rounded,
                  theme, theme.colorScheme.error),
              const SizedBox(height: 28),
              _buildLabel('INITIAL PASSWORD', theme),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                onChanged: (val) =>
                    ref.read(newUserProvider.notifier).updatePassword(val),
                decoration: InputDecoration(
                  hintText: 'Minimum 8 characters',
                  filled: true,
                  fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primary, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: theme.textTheme.bodySmall?.color,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'User will be prompted to change password on first login.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.04, end: 0),
      ],
    );
  }

  void _updatePanKeyboard(String val) {
    TextInputType newType;
    if (val.length >= 5 && val.length < 9) {
      newType = TextInputType.number;
    } else {
      newType = TextInputType.text;
    }

    if (newType != _panKeyboardType) {
      setState(() {
        _panKeyboardType = newType;
      });
      if (_panFocusNode.hasFocus) {
        _panFocusNode.unfocus();
        Future.delayed(const Duration(milliseconds: 50), () {
          _panFocusNode.requestFocus();
        });
      }
    }
  }

  // ═══════════════════════════════════════════════════
  //  SUMMARY SIDEBAR
  // ═══════════════════════════════════════════════════
  Widget _buildSummary(
      NewUserState state, ThemeData theme, bool isDark, Color primary) {
    final roleDisplay = _getRoleDisplayName(state.role);
    final roleDescription = _getRoleDescription(state.role);

    return Column(
      children: [
        GlassCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                  'Permission Matrix', Icons.shield_outlined, theme, primary),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      primary.withValues(alpha: 0.14),
                      primary.withValues(alpha: 0.04)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECTED ROLE',
                        style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: primary.withValues(alpha: 0.7))),
                    const SizedBox(height: 8),
                    Text(
                      roleDisplay,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                roleDescription,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontSize: 13, height: 1.6),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms).slideX(begin: 0.08, end: 0),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.successDark.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.history_outlined,
                    size: 18,
                    color: isDark ? AppColors.successDark : AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audit Log',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'All user creation events are logged with the administrator\'s timestamp.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 250.ms).slideX(begin: 0.08, end: 0),
      ],
    );
  }

  // ═══════════════════════════════════════════════════
  //  REUSABLE COMPONENTS
  // ═══════════════════════════════════════════════════
  Widget _buildLabel(String text, ThemeData theme) {
    return Text(
      text,
      style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700, letterSpacing: 0.8, fontSize: 11),
    );
  }

  Widget _buildTwoColumn(
      {required bool isNarrow, required Widget first, required Widget second}) {
    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [first, const SizedBox(height: 20), second],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 16),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    IconData? icon,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    required TextEditingController controller,
    required Function(String) onChanged,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, theme),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          onChanged: onChanged,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null
                ? Icon(icon, color: theme.textTheme.bodySmall?.color, size: 20)
                : null,
            filled: true,
            fillColor: isDark ? AppColors.fillDark : AppColors.fillLight,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required String hint,
    IconData? icon,
    required List<String> items,
    required Function(String?) onChanged,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? AppColors.fillDark : AppColors.fillLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          hint: Text(hint, style: theme.textTheme.bodySmall),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: theme.textTheme.bodySmall?.color, size: 22),
          dropdownColor: isDark ? AppColors.elevatedDark : Colors.white,
          borderRadius: BorderRadius.circular(14),
          items: items.map((String item) {
            UserRole role = UserRole.values.firstWhere((e) => e.name == item);
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon,
                        color: theme.textTheme.bodySmall?.color, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _getRoleDisplayName(role),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.executiveAdmin:
        return 'Executive Admin';
      case UserRole.manager:
        return 'Branch Manager';
      case UserRole.collectionAgent:
        return 'Collection Agent (Field Staff)';
      case UserRole.customer:
        return 'Customer';
    }
  }

  String _getRoleDescription(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Platform-level administrator with access to all organizations and global infrastructure.';
      case UserRole.executiveAdmin:
        return 'Organization admin with full access to their organization. Can create branches, managers, and manage all organization settings.';
      case UserRole.manager:
        return 'Branch admin who manages their assigned branch. Can create collection agents and customers for their branch.';
      case UserRole.collectionAgent:
        return 'Field staff who collects payments from customers in assigned areas. Can view and collect loans, manage customer interactions.';
      case UserRole.customer:
        return 'End user who has loans and savings. Can view their personal data, payment schedules, and transaction history.';
    }
  }
}

class _PanFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.toUpperCase();
    String formatted = '';

    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      if (i < 5) {
        if (RegExp(r'[A-Z]').hasMatch(char)) formatted += char;
      } else if (i < 9) {
        if (RegExp(r'[0-9]').hasMatch(char)) formatted += char;
      } else if (i < 10) {
        if (RegExp(r'[A-Z]').hasMatch(char)) formatted += char;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 12) digits = digits.substring(0, 12);

    StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) formatted.write(' ');
      formatted.write(digits[i]);
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _MobileFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    StringBuffer formatted = StringBuffer();
    if (digits.isNotEmpty) {
      formatted.write('+91 ');
      if (digits.length > 5) {
        formatted.write('${digits.substring(0, 5)} ${digits.substring(5)}');
      } else {
        formatted.write(digits);
      }
    }

    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class LowerCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toLowerCase(),
      selection: TextSelection.collapsed(offset: newValue.text.length),
    );
  }
}
