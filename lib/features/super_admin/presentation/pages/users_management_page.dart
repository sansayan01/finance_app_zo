import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';

class UsersManagementPage extends StatelessWidget {
  const UsersManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: D.bg(context),
      body: SafeArea(
        child: Padding(
          padding: D.bodyPad,
          child: Text('Users', style: D.h1(isDark)),
        ),
      ),
    );
  }
}
