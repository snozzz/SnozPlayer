import 'package:flutter/material.dart';

import 'app_controller.dart';

class SnozPlayerScope extends InheritedNotifier<SnozPlayerController> {
  const SnozPlayerScope({
    required SnozPlayerController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static SnozPlayerController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SnozPlayerScope>();
    assert(scope != null, 'SnozPlayerScope is missing above this context.');
    return scope!.notifier!;
  }
}
