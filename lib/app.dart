import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/vilka_controller.dart';
import 'features/shell/vilka_scope.dart';

class VilkaApp extends StatelessWidget {
  const VilkaApp({required this.controller, super.key});

  final VilkaController controller;

  @override
  Widget build(BuildContext context) {
    return VilkaScope(
      controller: controller,
      child: MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: const HomeShell(),
      ),
    );
  }
}
