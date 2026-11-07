import 'package:flutter/material.dart';

import 'app.dart';
import 'features/shell/vilka_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await VilkaController.open();
  runApp(VilkaApp(controller: controller));
}
