// Sample app: the same scenario as the iOS sample app.
// Keys and Semantics identifiers are stable on purpose, for integration tests and UI automation.
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:miniwall_flutter/miniwall_flutter.dart';

import 'templates.dart';

void main() => runApp(const ExampleApp());

const defaultPlacement = 'onboarding';
const defaultEvent = 'level_completed';

/// Prices come from your app (store or server); Miniwall only renders them.
const products = <String, ProductInfo>{
  'monthly': ProductInfo(price: 9.99, currency: 'USD', period: 'month'),
  'annual': ProductInfo(
    price: 79.99,
    currency: 'USD',
    period: 'year',
    offerPrice: 0,
    offerPeriod: {'unit': 'day', 'count': 7},
  ),
};

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Miniwall sample',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
        home: const HomePage(),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _apiKey = TextEditingController(); // a publishable key: Dashboard > Install
  final _placement = TextEditingController(text: defaultPlacement);
  final _event = TextEditingController(text: defaultEvent);
  final _template = TextEditingController();
  bool _configured = false;
  bool _autoOn = false;
  String _log = 'Enter an API key, then tap Configure.';

  @override
  void initState() {
    super.initState();
    for (final c in [_apiKey, _placement, _event, _template]) {
      c.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addObserver(this);
    // Template sweep: a cold start from `miniwall-example://present?tpl=<name>` (tool/sweep-templates.sh).
    final launched = templateFromRoute(PlatformDispatcher.instance.defaultRouteName);
    if (launched != null) WidgetsBinding.instance.addPostFrameCallback((_) => _presentTemplate(launched));
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final name = templateFromRoute(routeInformation.uri.toString());
    if (name == null) return false;
    unawaited(_presentTemplate(name));
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(Miniwall.stopAutoPlacements());
    _apiKey.dispose();
    _placement.dispose();
    _event.dispose();
    _template.dispose();
    super.dispose();
  }

  void _say(String text) {
    if (mounted) setState(() => _log = text);
  }

  PresentOptions _options() => PresentOptions(
        products: products,
        // Fake purchase: pretend the store took 0.8 s and said yes. Replace with your billing library.
        onPurchase: (packageId, answers) async {
          _say('Buying $packageId...');
          await Future<void>.delayed(const Duration(milliseconds: 800));
          return true;
        },
        // Fake restore: nothing to restore.
        onRestore: () async {
          _say('Restoring...');
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return false;
        },
        onAction: (actionId, answers) async {
          _say('Action $actionId, answers $answers');
          return true;
        },
        onError: (message) => _say('Error: $message'),
      );

  Future<void> _run(Future<void> Function() body) async {
    try {
      await body();
    } catch (e) {
      _say('Error: $e');
    }
  }

  Future<void> _configure() => _run(() async {
        await Miniwall.configure(_apiKey.text.trim());
        setState(() => _configured = true);
        _say('Configured.');
      });

  Future<void> _present() => _run(() async {
        final result = await Miniwall.present(ScreenSource.placement(_placement.text), options: _options());
        _say('${result.outcome} ${result.packageId ?? result.actionId ?? result.reason ?? ''}'.trim());
      });

  /// Presents a template of the library without a server (the template sweep). Configures with a throwaway key, no analytics.
  Future<void> _presentTemplate(String name) => _run(() async {
        final screen = await loadTemplate(name);
        if (screen == null) {
          _say('error:template $name is not in the app assets (run tool/sync_templates.sh)');
          return;
        }
        if (!_configured) {
          await Miniwall.configure('pk_example', analytics: false, timeoutMs: 3000);
          setState(() => _configured = true);
        }
        final welcome = await loadTemplate('welcome');
        final options = _options();
        _say('presenting $name');
        final result = await Miniwall.present(
          ScreenSource.json(screen),
          options: PresentOptions(
            products: options.products,
            onPurchase: options.onPurchase,
            onRestore: options.onRestore,
            onAction: options.onAction,
            onError: options.onError,
            style: styleFor(name),
            screens: welcome == null ? const {} : {'${welcome['id']}': welcome},
          ),
        );
        _say('${result.outcome} ${result.packageId ?? result.actionId ?? result.reason ?? ''}'.trim());
      });

  Future<void> _preload() => _run(() async {
        await Miniwall.preload([_placement.text]);
        _say('Preloaded ${_placement.text}.');
      });

  Future<void> _startAuto() => _run(() async {
        await Miniwall.startAutoPlacements(
          options: _options(),
          onResult: (placement, result) => _say('auto $placement: ${result.outcome}'),
        );
        setState(() => _autoOn = true);
        _say('Auto placements started.');
      });

  Future<void> _stopAuto() => _run(() async {
        await Miniwall.stopAutoPlacements();
        setState(() => _autoOn = false);
        _say('Auto placements stopped.');
      });

  Future<void> _track() => _run(() async {
        await Miniwall.track(_event.text);
        _say('Tracked ${_event.text}.');
      });

  @override
  Widget build(BuildContext context) {
    final hasKey = _apiKey.text.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Miniwall sample')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field('api-key-input', 'API key', _apiKey, hint: 'pk_...'),
            _button('configure-button', 'Configure', hasKey ? _configure : null),
            _field('placement-input', 'Placement', _placement),
            _button('present-button', 'Present "${_placement.text}"', _configured && _placement.text.isNotEmpty ? _present : null),
            _button('preload-button', 'Preload', _configured && _placement.text.isNotEmpty ? _preload : null),
            const Divider(height: 24),
            _button('auto-start-button', 'Start auto placements', _configured && !_autoOn ? _startAuto : null),
            _button('auto-stop-button', 'Stop auto placements', _autoOn ? _stopAuto : null),
            _field('event-input', 'Event name', _event),
            _button('track-button', 'Track "${_event.text}"', _configured && _event.text.isNotEmpty ? _track : null),
            const Divider(height: 24),
            _field('template-input', 'Template (offline, bundled)', _template, hint: 'calm-money'),
            _button('present-template-button', 'Present template', _template.text.isNotEmpty ? () => _presentTemplate(_template.text.trim()) : null),
            const Divider(height: 24),
            Semantics(
              identifier: 'result-text',
              liveRegion: true,
              label: 'Result',
              child: Text(_log, key: const Key('result-text'), style: const TextStyle(fontFamily: 'monospace')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String id, String label, TextEditingController controller, {String? hint}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          identifier: id,
          child: TextField(
            key: Key(id),
            controller: controller,
            autocorrect: false,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
          ),
        ),
      );

  Widget _button(String id, String label, VoidCallback? onPressed) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          identifier: id,
          child: FilledButton(key: Key(id), onPressed: onPressed, child: Text(label)),
        ),
      );
}
