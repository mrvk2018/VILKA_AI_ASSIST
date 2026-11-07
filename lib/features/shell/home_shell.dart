import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../characters/presentation/control_panel_screen.dart';
import '../chat/presentation/chat_screen.dart';
import 'vilka_controller.dart';
import 'vilka_scope.dart';

/// Две вкладки: чат и панель характеров с будильниками.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  VilkaController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = VilkaScope.of(context);
    if (identical(_controller, next)) return;
    _controller?.removeListener(_showNotice);
    _controller = next;
    next.addListener(_showNotice);
  }

  @override
  void dispose() {
    _controller?.removeListener(_showNotice);
    super.dispose();
  }

  void _showNotice() {
    final notice = _controller?.consumeNotice();
    if (notice == null || !mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(notice.message),
        backgroundColor: notice.isError ? scheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = VilkaScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [ChatScreen(), ControlPanelScreen()],
            ),
          ),
          if (controller.speaking)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('stop-button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: controller.interrupt,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('СТОП / ПЕРЕБИТЬ'),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чат',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune),
            selectedIcon: Icon(Icons.tune),
            label: 'Управление',
          ),
        ],
      ),
    );
  }
}
