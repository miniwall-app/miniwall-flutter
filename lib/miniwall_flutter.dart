/// Miniwall for Flutter: a thin layer over the native SDKs (iOS MiniwallSDK, Android
/// app.miniwall:sdk). Screens render natively; your app keeps selling (Miniwall never charges).
library miniwall_flutter;

import 'dart:async';

import 'package:flutter/services.dart';

/// A package's price as your app knows it (store or server). Fills `{{ product.* }}` texts.
class ProductInfo {
  const ProductInfo({required this.price, required this.currency, this.period, this.title, this.offerPrice, this.offerPeriod});

  final double price;

  /// ISO 4217 code, e.g. `USD`.
  final String currency;

  /// `day`, `week`, `month`, `year`, `lifetime`, or `{'unit': 'month', 'count': 3}`.
  final Object? period;
  final String? title;

  /// Introductory or trial offer; a free trial has price 0.
  final double? offerPrice;
  final Object? offerPeriod;

  Map<String, Object?> toMap() => {
        'price': price,
        'currency': currency,
        if (period != null) 'period': period,
        if (title != null) 'title': title,
        if (offerPrice != null && offerPeriod != null) 'offer': {'price': offerPrice, 'period': offerPeriod},
      };
}

/// Answers to questions: an option id or typed text, or option ids for a multiple choice.
typedef Answers = Map<String, Object?>;

/// How a presented screen ended.
class PurchaseResult {
  const PurchaseResult._(this.outcome, this.packageId, this.actionId, this.reason, this.answers);

  /// `purchased`, `restored`, `closed`, `action` or `skipped`.
  final String outcome;
  final String? packageId;
  final String? actionId;

  /// For `skipped`: `frequency_cap`, `audience` or `holdout`.
  final String? reason;
  final Answers answers;

  factory PurchaseResult._fromMap(Map<Object?, Object?> m) => PurchaseResult._(
        m['outcome'] as String,
        m['packageId'] as String?,
        m['actionId'] as String?,
        m['reason'] as String?,
        Map<String, Object?>.from((m['answers'] as Map?) ?? const {}),
      );

  @override
  String toString() => 'PurchaseResult($outcome${packageId != null ? ', $packageId' : ''}${actionId != null ? ', $actionId' : ''}${reason != null ? ', $reason' : ''})';
}

/// Where a screen comes from.
class ScreenSource {
  const ScreenSource.placement(String name) : _map = const {}, _placement = name, _paywallId = null, _json = null;
  const ScreenSource.paywallId(String id) : _map = const {}, _placement = null, _paywallId = id, _json = null;
  const ScreenSource.json(Map<String, Object?> json) : _map = const {}, _placement = null, _paywallId = null, _json = json;

  final Map<String, Object?> _map;
  final String? _placement;
  final String? _paywallId;
  final Map<String, Object?>? _json;

  Map<String, Object?> toMap() => {
        ..._map,
        if (_placement != null) 'placement': _placement,
        if (_paywallId != null) 'paywallId': _paywallId,
        if (_json != null) 'json': _json,
      };
}

/// Per-call options of [Miniwall.present].
class PresentOptions {
  const PresentOptions({
    this.products = const {},
    this.variablesPerPackage = const {},
    this.customVariables = const {},
    this.attributes = const {},
    this.locale,
    this.colorMode,
    this.style,
    this.screens = const {},
    this.onPurchase,
    this.onRestore,
    this.onAction,
    this.onAnswer,
    this.onOpenUrl,
    this.onError,
    this.onClose,
    this.onSkip,
    this.maxContentWidth,
    this.closeOnBackdrop = true,
    this.size,
    this.position,
  });

  final Map<String, ProductInfo> products;
  final Map<String, Map<String, String>> variablesPerPackage;
  final Map<String, Object> customVariables;
  final Map<String, Object> attributes;
  final String? locale;

  /// `light`, `dark` or `system`.
  final String? colorMode;

  /// Overrides the placement's display: `{'type': 'fullscreen' | 'modal' | 'sheet' | 'banner' | 'toast', ...}`.
  final Map<String, Object?>? style;
  final Map<String, Map<String, Object?>> screens;

  /// Run your purchase. Return true when bought, false when cancelled; throw on failure.
  final Future<bool> Function(String packageId, Answers answers)? onPurchase;

  /// Restore purchases; true when something was restored. Without it the button is hidden.
  final Future<bool> Function()? onRestore;

  /// A "Run your code" button. Complete with false to keep the screen open; anything else closes it.
  final Future<bool> Function(String actionId, Answers answers)? onAction;
  final void Function(String fieldId, Object? value, Answers answers)? onAnswer;
  final void Function(String url)? onOpenUrl;

  /// Called with the reason (a plain message, not an exception) when the screen reports a problem: load failure,
  /// a handler that threw, an unusable link.
  final void Function(String message)? onError;

  /// The user closed the screen (close button, Back, tap outside): the outcome is `closed`. Not called for a
  /// purchase, restore or action.
  final void Function()? onClose;

  /// The placement's targeting chose to show nothing: no screen was opened. [reason] is `frequency_cap`,
  /// `audience` or `holdout`.
  final void Function(String reason)? onSkip;

  /// Widest the content gets, in dp/pt; centered on wide screens. Wins over [size]. Default: no limit.
  final double? maxContentWidth;

  /// Close a modal or sheet by tapping outside it (iOS: also by swiping down). Default true.
  final bool closeOnBackdrop;

  /// Width of a modal, sheet or toast on wide screens: `small`, `medium` or `large`. Overrides the placement's display.
  final String? size;

  /// Where a banner or toast sits: `top` or `bottom`. Overrides the placement's display.
  final String? position;

  /// [onClose] / [onSkip] as the Web SDK fires them, from the result the native side reports.
  void _notify(PurchaseResult result) {
    if (result.outcome == 'closed') {
      onClose?.call();
    } else if (result.outcome == 'skipped') {
      onSkip?.call(result.reason ?? '');
    }
  }

  Map<String, Object?> toMap() => {
        'products': products.map((k, v) => MapEntry(k, v.toMap())),
        'variablesPerPackage': variablesPerPackage,
        'customVariables': customVariables,
        'attributes': attributes,
        if (locale != null) 'locale': locale,
        if (colorMode != null) 'colorMode': colorMode,
        if (style != null) 'style': style,
        'screens': screens,
        'hasPurchase': onPurchase != null,
        'hasRestore': onRestore != null,
        'hasAction': onAction != null,
        'hasOpenUrl': onOpenUrl != null,
        if (maxContentWidth != null) 'maxContentWidth': maxContentWidth,
        'closeOnBackdrop': closeOnBackdrop,
        if (size != null) 'size': size,
        if (position != null) 'position': position,
      };
}

class Miniwall {
  Miniwall._();

  static const MethodChannel _channel = MethodChannel('miniwall');
  static final Map<String, PresentOptions> _presentations = {};
  static int _nextId = 0;
  static bool _listening = false;
  static void Function(String placement, PurchaseResult result)? _onAutoResult;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      try {
        final args = Map<String, Object?>.from(call.arguments as Map);
        final options = _presentations[args['presentationId']];
        if (options == null) return null;
        final answers = Map<String, Object?>.from((args['answers'] as Map?) ?? const {});
        switch (call.method) {
          case 'purchase':
            return await options.onPurchase?.call(args['packageId'] as String, answers) ?? false;
          case 'restore':
            return await options.onRestore?.call() ?? false;
          case 'action':
            return await options.onAction?.call(args['actionId'] as String, answers) ?? true;
          case 'answer':
            options.onAnswer?.call(args['fieldId'] as String, args['value'], answers);
            return null;
          case 'openUrl':
            options.onOpenUrl?.call(args['url'] as String);
            return null;
          case 'autoResult':
            final result = PurchaseResult._fromMap(Map<Object?, Object?>.from(args['result'] as Map));
            options._notify(result);
            _onAutoResult?.call(args['placement'] as String, result);
            return null;
          case 'error':
            options.onError?.call(args['message'] as String);
            return null;
        }
      } catch (error) {
        return {'error': error.toString()};
      }
      return null;
    });
  }

  /// Call once at startup: `Miniwall.configure('pk_...')`.
  static Future<void> configure(String apiKey, {String? apiUrl, String? locale, String? colorMode, bool analytics = true, Map<String, Object> attributes = const {}, int? timeoutMs, double? maxFontScale}) {
    _listen();
    return _channel.invokeMethod('configure', {
      'apiKey': apiKey,
      if (apiUrl != null) 'apiUrl': apiUrl,
      if (locale != null) 'locale': locale,
      if (colorMode != null) 'colorMode': colorMode,
      'analytics': analytics,
      'attributes': attributes,
      if (timeoutMs != null) 'timeoutMs': timeoutMs,
      if (maxFontScale != null) 'maxFontScale': maxFontScale,
    });
  }

  /// Adds or changes audience attributes; `null` removes one.
  static Future<void> setAttributes(Map<String, Object?> attributes) => _channel.invokeMethod('setAttributes', attributes);

  /// Shows a screen and completes when it closes.
  static Future<PurchaseResult> present(ScreenSource source, {PresentOptions options = const PresentOptions()}) async {
    _listen();
    final id = '${++_nextId}';
    _presentations[id] = options;
    try {
      final result = await _channel.invokeMethod<Map<Object?, Object?>>('present', {
        'presentationId': id,
        'source': source.toMap(),
        'options': options.toMap(),
      });
      final outcome = PurchaseResult._fromMap(result!);
      options._notify(outcome);
      return outcome;
    } finally {
      _presentations.remove(id);
    }
  }

  /// Starts the placements that show by themselves (dashboard > placement > "Show it": when the app
  /// opens, after a delay, or on an event you report with [track]). Call once after [configure].
  /// [options] (prices, purchase handlers) applies to all of them; [onResult] hears each outcome.
  static Future<void> startAutoPlacements({PresentOptions options = const PresentOptions(), void Function(String placement, PurchaseResult result)? onResult}) {
    _listen();
    _presentations['auto'] = options;
    _onAutoResult = onResult;
    return _channel.invokeMethod('startAutoPlacements', {'options': options.toMap()});
  }

  /// Stops the placements started by [startAutoPlacements] (e.g. on sign-out). They can be started again.
  static Future<void> stopAutoPlacements() {
    _presentations.remove('auto');
    _onAutoResult = null;
    return _channel.invokeMethod('stopAutoPlacements');
  }

  /// Tells Miniwall something happened in the app, e.g. `Miniwall.track('level_completed')`.
  static Future<void> track(String event) => _channel.invokeMethod('track', {'event': event});

  /// Loads placements' screens and images ahead of time.
  static Future<void> preload(List<String> placements) => _channel.invokeMethod('preload', {'placements': placements});

  /// A purchase that finished outside the screen; credited to the screen where buy was tapped.
  static Future<void> reportPurchase({String? packageId, String? paywallId}) =>
      _channel.invokeMethod('reportPurchase', {if (packageId != null) 'packageId': packageId, if (paywallId != null) 'paywallId': paywallId});

  /// Forgets this device's visitor id and counters (e.g. on sign-out).
  static Future<void> reset({List<String> placements = const []}) => _channel.invokeMethod('reset', {'placements': placements});
}
