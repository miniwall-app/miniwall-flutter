# Flutter: unit tests

`miniwall_flutter_test.dart` tests `lib/miniwall_flutter.dart` with the `miniwall` MethodChannel mocked: the arguments of every call to native,
how `present` parses results, and how requests from native (purchase, restore, action, answer, openUrl, error, autoResult) reach the Dart
handlers, including errors, unknown presentations and `stopAutoPlacements`. No device needed.

```bash
flutter pub get
flutter test
```

If a test fails, first check the Flutter version (`handlePlatformMessage` / `setMockMethodCallHandler` on `TestDefaultBinaryMessenger`, Flutter 3.22+).
The real native side is tested with a sample app that is not in this repository.
