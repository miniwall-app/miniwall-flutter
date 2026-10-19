# Flutter: unit tests

`miniwall_flutter_test.dart` tests `lib/miniwall_flutter.dart` with the `miniwall` MethodChannel mocked: the arguments of every call to native,
how `present` parses results, and how requests from native (purchase, restore, action, answer, openUrl, error, autoResult) reach the Dart
handlers, including errors, unknown presentations and `stopAutoPlacements`. No device needed.

```bash
cd sdks/flutter
flutter pub get
flutter test            # runs test/ (these) and nothing else; example/ has its own widget test
```

Status: written without a Flutter SDK (cloud has none), so it has not been run. If a test fails, first check the Flutter version
(`handlePlatformMessage` / `setMockMethodCallHandler` on `TestDefaultBinaryMessenger`, Flutter 3.22+).
The real native side is tested by `example/integration_test` (see its README).
