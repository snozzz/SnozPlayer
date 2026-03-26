import 'package:flutter/material.dart';

import '../features/shell/presentation/shell_page.dart';
import 'app_controller.dart';
import 'app_scope.dart';
import 'theme/app_theme.dart';

class SnozPlayerApp extends StatefulWidget {
  const SnozPlayerApp({super.key});

  @override
  State<SnozPlayerApp> createState() => _SnozPlayerAppState();
}

class _SnozPlayerAppState extends State<SnozPlayerApp> {
  late final SnozPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SnozPlayerController()..initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SnozPlayerScope(
      controller: _controller,
      child: MaterialApp(
        title: 'SnozPlayer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const ShellPage(),
      ),
    );
  }
}
