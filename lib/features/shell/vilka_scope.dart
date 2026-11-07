import 'package:flutter/material.dart';

import 'vilka_controller.dart';

/// Доступ к общему состоянию из экранов.
class VilkaScope extends InheritedNotifier<VilkaController> {
  const VilkaScope({
    required VilkaController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static VilkaController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<VilkaScope>();
    assert(scope != null, 'VilkaScope не найден');
    return scope!.notifier!;
  }
}
