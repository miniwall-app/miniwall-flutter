// Integration test: the Dart API against the REAL native SDK (iOS MiniwallSDK / Android app.miniwall:sdk) on a device or
// simulator, with a local stand-in for the delivery API started inside this test. Not run at cloud (needs a device).
//
//   cd example && flutter test integration_test -d <device id>
//
// What it covers: configure, present with a placement, the toast style that closes by itself, frequency cap, holdout and audience
// skips, analytics events reaching the server, the offline cache, load errors, auto placements start/stop.
// What it cannot do: tap INSIDE the native screen (it is not a Flutter widget). Choosing a plan, Subscribe, Restore, questions and
// the Back button are covered by the Maestro flows of the React Native repository (e2e/maestro) (same sample app testIDs) and by the
// XCUITest / Compose UI tests of the native SDKs.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:integration_test/integration_test.dart';
import 'package:miniwall_flutter/miniwall_flutter.dart';

Map<String, Object?> tinyScreen(String id) => {
      'id': id,
      'default_locale': 'en_US',
      'components_localizations': {
        'en_US': {'l': 'Hello from Miniwall'},
      },
      'components_config': {
        'base': {
          'stack': {
            'type': 'stack',
            'id': 'root',
            'size': {'width': {'type': 'fill'}, 'height': {'type': 'fit'}},
            'dimension': {'type': 'vertical', 'alignment': 'center', 'distribution': 'start'},
            'padding': {'top': 16, 'bottom': 16, 'leading': 16, 'trailing': 16},
            'components': [
              {
                'type': 'text',
                'id': 't1',
                'text_lid': 'l',
                'font_size': 16,
                'size': {'width': {'type': 'fill'}, 'height': {'type': 'fit'}},
              },
            ],
          },
        },
      },
    };

Map<String, Object?> body(String placement, {Map<String, Object?> extra = const {}}) =>
    {'placement': placement, 'paywallId': 'p_$placement', 'version': 1, 'paywall': tinyScreen('p_$placement'), ...extra};

/// A toast that closes itself: the only way to end a screen without tapping inside it.
const toast = <String, Object?>{'type': 'toast', 'seconds': 3};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  var offline = false;
  final events = <Map<String, Object?>>[];
  final placements = <String, Map<String, Object?>>{
    'toast': body('toast', extra: {'display': {'format': 'toast', 'duration': 3}}),
    'capped': body('capped', extra: {'frequency': {'max': 1, 'per': 'ever'}}),
    'holdout': body('holdout', extra: {'holdout': {'id': 'h1', 'share': 100}}),
    'audience': body('audience', extra: {
      'rules': [
        {
          'id': 'r1',
          'conditions': [
            {'field': 'user.plan', 'op': 'eq', 'value': 'pro'},
          ],
          'paywall': null,
        },
      ],
    }),
  };

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (offline) {
        (await request.response.detachSocket(writeHeaders: false)).destroy();
        return;
      }
      final path = request.uri.path;
      Future<void> reply(int status, Object? json) async {
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(json));
        await request.response.close();
      }

      final match = RegExp(r'^/v1/sdk/placements/([^/]+)$').firstMatch(path);
      if (request.method == 'GET' && match != null) {
        final found = placements[Uri.decodeComponent(match.group(1)!)];
        return reply(found == null ? 404 : 200, found ?? {'error': {'message': 'unknown placement'}});
      }
      if (request.method == 'POST' && path == '/v1/sdk/events') {
        final data = jsonDecode(await utf8.decodeStream(request)) as Map<String, Object?>;
        events.addAll((data['events'] as List).cast<Map<String, Object?>>());
        return reply(200, {});
      }
      return reply(404, {'error': {'message': 'not found'}});
    });
    await Miniwall.configure(
      'pk_test_ui',
      apiUrl: 'http://127.0.0.1:${server.port}', // the SDK runs on the same device as this test
      attributes: const {'plan': 'pro'},
    );
  });

  tearDownAll(() async {
    await Miniwall.stopAutoPlacements();
    await server.close(force: true);
  });

  Future<PurchaseResult> present(String placement, {PresentOptions options = const PresentOptions()}) =>
      Miniwall.present(ScreenSource.placement(placement), options: options).timeout(const Duration(seconds: 30));

  testWidgets('a toast placement shows and closes by itself ("closed")', (tester) async {
    final result = await present('toast');
    expect(result.outcome, 'closed');
  });

  testWidgets('events (view, close) reach the server with the platform', (tester) async {
    events.clear();
    await present('toast');
    final deadline = DateTime.now().add(const Duration(seconds: 20));
    while (!events.any((e) => e['type'] == 'close') && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    expect(events.map((e) => e['type']), containsAll(['view', 'close']));
    expect(events.first['placement'], 'toast');
    expect(events.first['platform'], Platform.isIOS ? 'ios' : 'android');
  });

  testWidgets('frequency cap: shown once, then skipped (frequency_cap)', (tester) async {
    final first = await present('capped', options: const PresentOptions(style: toast));
    expect(first.outcome, 'closed');
    final second = await present('capped', options: const PresentOptions(style: toast));
    expect([second.outcome, second.reason], ['skipped', 'frequency_cap']);
  });

  testWidgets('holdout 100% skips; an audience rule with no screen skips (audience)', (tester) async {
    final held = await present('holdout');
    expect([held.outcome, held.reason], ['skipped', 'holdout']);
    final audience = await present('audience'); // attributes.plan == pro matches the rule that shows nothing
    expect([audience.outcome, audience.reason], ['skipped', 'audience']);
  });

  testWidgets('an unknown placement fails with a PlatformException', (tester) async {
    await expectLater(present('does_not_exist'), throwsA(isA<PlatformException>()));
  });

  testWidgets('offline: a placement seen before still shows from the cache; one never loaded fails', (tester) async {
    await present('toast'); // warm
    offline = true;
    try {
      final cached = await present('toast');
      expect(cached.outcome, 'closed');
      await expectLater(present('never_loaded'), throwsA(isA<PlatformException>()));
    } finally {
      offline = false;
    }
  });

  testWidgets('auto placements start and stop; track does not throw', (tester) async {
    final results = <String>[];
    await Miniwall.startAutoPlacements(onResult: (placement, result) => results.add('$placement ${result.outcome}'));
    await Miniwall.track('level_completed');
    await Miniwall.stopAutoPlacements();
    await Miniwall.startAutoPlacements();
    await Miniwall.stopAutoPlacements();
  });
}
