import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';

/// Точка входа в интерфейс чата.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text(AppConstants.appName)));
  }
}
