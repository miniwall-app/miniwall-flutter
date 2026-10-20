// Unit tests of lib/miniwall_flutter.dart with the `miniwall` MethodChannel mocked (no native code, no device):
//   flutter test
// `onNative` plays the native side: it sees every call Dart makes, and `fromNative` sends Dart the requests the native SDK
// would (purchase, restore, action, ...), returning what Dart answered.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miniwall_flutter/miniwall_flutter.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miniwall');
  const codec = StandardMethodCodec();

  final calls = <MethodCall>[];
  Future<Object?> Function(MethodCall call)? onNative;

  setUp(() {
    calls.clear();
    onNative = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return onNative?.call(call);
    });
  });

  tearDown(() => binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

  /// Native -> Dart: delivers one request and returns the (decoded) answer.
  Future<Object?> fromNative(String method, Map<String, Object?> args) async {
    final done = Completer<ByteData?>();
    binding.defaultBinaryMessenger.handlePlatformMessage('miniwall', codec.encodeMethodCall(MethodCall(method, args)), done.complete);
    final data = await done.future;
    return data == null ? null : codec.decodeEnvelope(data);
  }

  const closed = {'outcome': 'closed', 'answers': <String, Object?>{}};

  /// Presents with [options]; while the "screen" is open [during] gets the presentation id to send requests.
  Future<PurchaseResult> presentWith(
    PresentOptions options,
    Future<void> Function(String id) during, {
    Map<String, Object?> result = closed,
    ScreenSource source = const ScreenSource.placement('onboarding'),
  }) {
    onNative = (call) async {
      if (call.method != 'present') return null;
      await during((call.arguments as Map)['presentationId'] as String);
      return result;
    };
    return Miniwall.present(source, options: options);
  }

  Map<String, Object?> args(MethodCall call) => Map<String, Object?>.from(call.arguments as Map);

  group('calls to native', () {
    test('configure sends the key and the defaults, and only the optional values that were given', () async {
      await Miniwall.configure('pk_test');
      expect(calls.single.method, 'configure');
      expect(args(calls.single), {'apiKey': 'pk_test', 'analytics': true, 'attributes': <String, Object?>{}});
      calls.clear();
      await Miniwall.configure('pk_test', apiUrl: 'http://127.0.0.1:8799', locale: 'fr_FR', colorMode: 'dark', analytics: false, attributes: {'plan': 'pro'}, timeoutMs: 3000, maxFontScale: 1.2);
      expect(args(calls.single), {
        'apiKey': 'pk_test',
        'apiUrl': 'http://127.0.0.1:8799',
        'locale': 'fr_FR',
        'colorMode': 'dark',
        'analytics': false,
        'attributes': {'plan': 'pro'},
        'timeoutMs': 3000,
        'maxFontScale': 1.2,
      });
    });

    test('track, preload, reset, setAttributes and reportPurchase use these method names and arguments', () async {
      await Miniwall.track('level_completed');
      await Miniwall.preload(['a', 'b']);
      await Miniwall.reset(placements: ['onboarding']);
      await Miniwall.reset();
      await Miniwall.setAttributes({'plan': 'pro', 'beta': null});
      await Miniwall.reportPurchase(packageId: 'annual');
      await Miniwall.reportPurchase();
      expect(calls.map((c) => c.method), ['track', 'preload', 'reset', 'reset', 'setAttributes', 'reportPurchase', 'reportPurchase']);
      expect(calls[0].arguments, {'event': 'level_completed'});
      expect(calls[1].arguments, {'placements': ['a', 'b']});
      expect(calls[2].arguments, {'placements': ['onboarding']});
      expect(calls[3].arguments, {'placements': <String>[]});
      expect(calls[4].arguments, {'plan': 'pro', 'beta': null});
      expect(calls[5].arguments, {'packageId': 'annual'});
      expect(calls[6].arguments, <String, Object?>{});
    });

    test('ProductInfo.toMap keeps only what is set and nests the offer', () {
      expect(const ProductInfo(price: 9.99, currency: 'USD').toMap(), {'price': 9.99, 'currency': 'USD'});
      expect(
        const ProductInfo(price: 79.99, currency: 'USD', period: 'year', title: 'Annual', offerPrice: 0, offerPeriod: {'unit': 'day', 'count': 7}).toMap(),
        {'price': 79.99, 'currency': 'USD', 'period': 'year', 'title': 'Annual', 'offer': {'price': 0.0, 'period': {'unit': 'day', 'count': 7}}},
      );
    });
  });

  group('present', () {
    test('sends the source and the options without functions, with flags for the handlers', () async {
      late Map<String, Object?> sent;
      final result = await presentWith(
        PresentOptions(
          products: const {'monthly': ProductInfo(price: 9.99, currency: 'USD', period: 'month')},
          locale: 'en_US',
          colorMode: 'light',
          onPurchase: (id, answers) async => true,
          onRestore: () async => false,
        ),
        (id) async => sent = args(calls.last),
        result: {'outcome': 'purchased', 'packageId': 'monthly', 'answers': {'goal': 'energy'}},
      );
      expect(sent['source'], {'placement': 'onboarding'});
      final options = Map<String, Object?>.from(sent['options'] as Map);
      expect(options['hasPurchase'], true);
      expect(options['hasRestore'], true);
      expect(options['hasAction'], false);
      expect(options['hasOpenUrl'], false);
      expect(options['locale'], 'en_US');
      expect((options['products'] as Map)['monthly'], {'price': 9.99, 'currency': 'USD', 'period': 'month'});
      expect(sent['presentationId'], isA<String>());
      expect(result.outcome, 'purchased');
      expect(result.packageId, 'monthly');
      expect(result.answers, {'goal': 'energy'});
    });

    test('sends the display options, and the defaults only where they matter', () async {
      late Map<String, Object?> sent;
      await presentWith(
        const PresentOptions(maxContentWidth: 480, closeOnBackdrop: false, size: 'small', position: 'top'),
        (_) async => sent = args(calls.last),
      );
      var options = Map<String, Object?>.from(sent['options'] as Map);
      expect(options['maxContentWidth'], 480);
      expect(options['closeOnBackdrop'], false);
      expect(options['size'], 'small');
      expect(options['position'], 'top');
      await presentWith(const PresentOptions(), (_) async => sent = args(calls.last));
      options = Map<String, Object?>.from(sent['options'] as Map);
      expect(options['closeOnBackdrop'], true);
      expect(options.containsKey('maxContentWidth'), false);
      expect(options.containsKey('size'), false);
      expect(options.containsKey('position'), false);
      expect(options.containsKey('onClose'), false);
    });

    test('onClose fires when the user closed the screen, onSkip with the reason when targeting showed nothing', () async {
      var closes = 0;
      final skips = <String>[];
      final options = PresentOptions(onClose: () => closes++, onSkip: skips.add);
      await presentWith(options, (_) async {});
      expect([closes, skips], [1, <String>[]]);
      await presentWith(options, (_) async {}, result: {'outcome': 'skipped', 'reason': 'holdout'});
      expect([closes, skips], [1, ['holdout']]);
      await presentWith(options, (_) async {}, result: {'outcome': 'purchased', 'packageId': 'm', 'answers': {}});
      expect([closes, skips], [1, ['holdout']]);
    });

    test('paywallId and json sources', () async {
      late Object? source;
      await presentWith(const PresentOptions(), (_) async => source = args(calls.last)['source'], source: const ScreenSource.paywallId('p1'));
      expect(source, {'paywallId': 'p1'});
      await presentWith(const PresentOptions(), (_) async => source = args(calls.last)['source'], source: const ScreenSource.json({'id': 'x'}));
      expect(source, {'json': {'id': 'x'}});
    });

    test('parses every outcome, including skipped with its reason', () async {
      final action = await presentWith(const PresentOptions(), (_) async {}, result: {'outcome': 'action', 'actionId': 'upgrade', 'answers': {}});
      expect([action.outcome, action.actionId], ['action', 'upgrade']);
      final skipped = await presentWith(const PresentOptions(), (_) async {}, result: {'outcome': 'skipped', 'reason': 'frequency_cap'});
      expect([skipped.outcome, skipped.reason, skipped.answers], ['skipped', 'frequency_cap', <String, Object?>{}]);
      expect(skipped.toString(), 'PurchaseResult(skipped, frequency_cap)');
    });

    test('a native failure (timeout) reaches the caller and the presentation is forgotten', () async {
      late String id;
      onNative = (call) async {
        id = (call.arguments as Map)['presentationId'] as String;
        throw PlatformException(code: 'load_failed', message: 'Miniwall: the screen took too long to load');
      };
      await expectLater(
        Miniwall.present(const ScreenSource.placement('slow'), options: PresentOptions(onPurchase: (_, __) async => true)),
        throwsA(isA<PlatformException>().having((e) => e.message, 'message', contains('took too long'))),
      );
      expect(await fromNative('purchase', {'presentationId': id, 'packageId': 'm', 'answers': {}}), isNull);
    });

    test('every call has its own presentation id', () async {
      final ids = <String>[];
      await presentWith(const PresentOptions(), (id) async => ids.add(id));
      await presentWith(const PresentOptions(), (id) async => ids.add(id));
      expect(ids.toSet().length, 2);
    });
  });

  group('requests from native', () {
    test('purchase: onPurchase gets the package and the answers, and its result goes back', () async {
      String? gotPackage;
      Answers? gotAnswers;
      Object? reply;
      await presentWith(
        PresentOptions(onPurchase: (id, answers) async {
          gotPackage = id;
          gotAnswers = answers;
          return true;
        }),
        (id) async => reply = await fromNative('purchase', {'presentationId': id, 'packageId': 'annual', 'answers': {'goal': 'energy'}}),
      );
      expect(gotPackage, 'annual');
      expect(gotAnswers, {'goal': 'energy'});
      expect(reply, true);
    });

    test('purchase without a handler, or cancelled, answers false', () async {
      Object? none;
      Object? cancelled;
      await presentWith(const PresentOptions(), (id) async => none = await fromNative('purchase', {'presentationId': id, 'packageId': 'm'}));
      await presentWith(PresentOptions(onPurchase: (_, __) async => false), (id) async => cancelled = await fromNative('purchase', {'presentationId': id, 'packageId': 'm'}));
      expect(none, false);
      expect(cancelled, false);
    });

    test('a handler that throws answers { error } instead of crashing the channel', () async {
      Object? reply;
      await presentWith(
        PresentOptions(onPurchase: (_, __) async => throw StateError('store busy')),
        (id) async => reply = await fromNative('purchase', {'presentationId': id, 'packageId': 'm', 'answers': {}}),
      );
      expect(reply, {'error': contains('store busy')});
    });

    test('restore answers the handler result, false without one', () async {
      Object? yes;
      Object? no;
      await presentWith(PresentOptions(onRestore: () async => true), (id) async => yes = await fromNative('restore', {'presentationId': id}));
      await presentWith(const PresentOptions(), (id) async => no = await fromNative('restore', {'presentationId': id}));
      expect(yes, true);
      expect(no, false);
    });

    test('action: only false keeps the screen open; no handler closes it', () async {
      Object? keep;
      Object? close;
      Object? none;
      await presentWith(PresentOptions(onAction: (_, __) async => false), (id) async => keep = await fromNative('action', {'presentationId': id, 'actionId': 'upgrade', 'answers': {}}));
      await presentWith(PresentOptions(onAction: (_, __) async => true), (id) async => close = await fromNative('action', {'presentationId': id, 'actionId': 'upgrade', 'answers': {}}));
      await presentWith(const PresentOptions(), (id) async => none = await fromNative('action', {'presentationId': id, 'actionId': 'x', 'answers': {}}));
      expect([keep, close, none], [false, true, true]);
    });

    test('answer, openUrl and error notify the handlers and answer null', () async {
      final seen = <String>[];
      final replies = <Object?>[];
      await presentWith(
        PresentOptions(
          onAnswer: (field, value, answers) => seen.add('answer $field=$value $answers'),
          onOpenUrl: (url) => seen.add('url $url'),
          onError: (message) => seen.add('error $message'),
        ),
        (id) async {
          replies.add(await fromNative('answer', {'presentationId': id, 'fieldId': 'goal', 'value': 'energy', 'answers': {'goal': 'energy'}}));
          replies.add(await fromNative('openUrl', {'presentationId': id, 'url': 'https://example.com/terms'}));
          replies.add(await fromNative('error', {'presentationId': id, 'message': 'could not load'}));
        },
      );
      expect(seen, ['answer goal=energy {goal: energy}', 'url https://example.com/terms', 'error could not load']);
      expect(replies, [null, null, null]);
    });

    test('an unknown presentation answers null and calls nothing', () async {
      var called = false;
      await presentWith(PresentOptions(onPurchase: (_, __) async => called = true), (_) async {});
      expect(await fromNative('purchase', {'presentationId': 'nope', 'packageId': 'm', 'answers': {}}), isNull);
      expect(called, false);
    });
  });

  group('auto placements', () {
    test('startAutoPlacements registers the options as "auto" and routes autoResult to onResult', () async {
      final heard = <String>[];
      var bought = false;
      await Miniwall.startAutoPlacements(
        options: PresentOptions(onPurchase: (_, __) async => bought = true),
        onResult: (placement, result) => heard.add('$placement ${result.outcome} ${result.reason}'),
      );
      expect(calls.single.method, 'startAutoPlacements');
      expect((args(calls.single)['options'] as Map)['hasPurchase'], true);
      expect(await fromNative('purchase', {'presentationId': 'auto', 'packageId': 'm', 'answers': {}}), true);
      expect(bought, true);
      await fromNative('autoResult', {'presentationId': 'auto', 'placement': 'launch', 'result': {'outcome': 'skipped', 'reason': 'holdout', 'answers': {}}});
      expect(heard, ['launch skipped holdout']);
    });

    test('stopAutoPlacements stops native and drops the handlers; it can start again', () async {
      final heard = <String>[];
      await Miniwall.startAutoPlacements(onResult: (placement, result) => heard.add(placement));
      await Miniwall.stopAutoPlacements();
      expect(calls.map((c) => c.method), ['startAutoPlacements', 'stopAutoPlacements']);
      await fromNative('autoResult', {'presentationId': 'auto', 'placement': 'a', 'result': closed});
      expect(heard, isEmpty);
      await Miniwall.startAutoPlacements(onResult: (placement, result) => heard.add(placement));
      await fromNative('autoResult', {'presentationId': 'auto', 'placement': 'b', 'result': closed});
      expect(heard, ['b']);
    });
  });
}
