import 'package:flutter/material.dart';

import '../features/shell/presentation/shell_page.dart';
import 'theme/app_theme.dart';

class SnozPlayerApp extends StatelessWidget {
  const SnozPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnozPlayer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const ShellPage(),
    );
  }
}
