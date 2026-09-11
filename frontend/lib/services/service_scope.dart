import 'package:flutter/widgets.dart';
import 'emergency_service.dart';

class EmergencyServiceScope extends InheritedNotifier<EmergencyService> {
  const EmergencyServiceScope({
    super.key,
    required EmergencyService service,
    required super.child,
  }) : super(notifier: service);

  static EmergencyService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<EmergencyServiceScope>();
    assert(scope != null, 'No EmergencyServiceScope found in context');
    return scope!.notifier!;
  }
}
