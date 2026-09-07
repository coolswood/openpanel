import 'package:flutter/widgets.dart';

import 'openpanel.dart';

/// A [NavigatorObserver] that reports route changes as `screen_view` events.
///
/// Attach it to your app:
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [OpenpanelNavigatorObserver()],
///   ...
/// )
/// ```
///
/// Only routes with a non-empty [RouteSettings.name] are reported — anonymous
/// routes (e.g. modal dialogs without names) are skipped. The reported
/// property map is `{ 'name': <route name> }`.
class OpenpanelNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sendScreenView(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _sendScreenView(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _sendScreenView(previousRoute);

  void _sendScreenView(Route<dynamic>? route) {
    final String? name = route?.settings.name;
    if (name == null || name.isEmpty) {
      return;
    }
    Openpanel.instance
        .track('screen_view', properties: <String, Object?>{'name': name});
  }
}
