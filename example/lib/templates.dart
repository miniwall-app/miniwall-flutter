// Template sweep support, the counterpart of `-tpl <name>` in the iOS sample app and `--es tpl <name>` in the Android sample app:
// presents a template of the library (the spec's fixtures/templates, or components/) by name.
// The JSON files are copied into assets/ by tool/sync_templates.sh (not committed: they are the spec's fixtures).
import 'dart:convert';

import 'package:flutter/services.dart';

/// The template named in a deep link, `miniwall-example://present?tpl=<name>` (the route the engine reports is `/present?tpl=<name>`
/// or `/?tpl=<name>`), or null when the link names none.
String? templateFromRoute(String route) {
  final name = Uri.tryParse(route)?.queryParameters['tpl'];
  return name == null || name.isEmpty ? null : name;
}

/// How a placement would show the template: the library names its display in the file name; everything else is a full screen.
Map<String, Object?>? styleFor(String name) {
  if (name.endsWith('-toast')) return {'type': 'toast', 'seconds': 60};
  if (name.endsWith('-bar') || name.endsWith('-banner')) return {'type': 'banner', 'position': 'top'};
  if (name.endsWith('-slide-in')) return {'type': 'sheet'};
  if (name.endsWith('-drawer') || name.endsWith('-launcher')) return {'type': 'modal'};
  return null;
}

/// A template (`{description, paywall}`) or one of the small component screens; null when the app does not bundle it.
Future<Map<String, Object?>?> loadTemplate(String name, {AssetBundle? bundle}) async {
  final source = bundle ?? rootBundle;
  for (final folder in const ['templates', 'components']) {
    try {
      final root = jsonDecode(await source.loadString('assets/$folder/$name.json')) as Map<String, Object?>;
      return (root['paywall'] as Map<String, Object?>?) ?? root;
    } catch (_) {
      // not in this folder
    }
  }
  return null;
}
