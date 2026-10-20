# miniwall_flutter

Miniwall for Flutter: screens built in the Miniwall dashboard, rendered natively by the iOS and
Android SDKs. Flutter 3.22+, iOS 16+, Android minSdk 24. Status: preview (not on pub.dev yet). Tested on an Android 15 emulator and an iOS 27 simulator: `flutter analyze`, 19 unit tests, 7 integration tests on both, and the 77-template sweep in light mode, dark mode and at the largest text size on both.

## Install (local, before publishing)

1. `pubspec.yaml`: `miniwall_flutter: { path: <path to this checkout> }`
2. iOS `ios/Podfile`: `pod 'MiniwallCore', :path => '<miniwall-ios checkout>'` and `pod 'MiniwallSDK', :path => '<miniwall-ios checkout>'`; platform `ios, '16.0'`. The plugin pod depends on `MiniwallSDK ~> 0.1`; until that pod is published, the two `:path` lines are required.
3. Android: your `MainActivity` must extend `FlutterFragmentActivity` (a `ComponentActivity`), not `FlutterActivity`; otherwise banners and toasts open as a sheet and a toast never closes by itself.
4. Android: until `app.miniwall:sdk` is on Maven Central, publish it once to your machine (`cd <miniwall-android checkout> && ./gradlew publishToMavenLocal`) and add `mavenLocal()` to the app's `allprojects { repositories { ... } }` (`android/build.gradle`). Do not use `includeBuild` with a current Flutter: the native SDK builds with AGP 8.7.3, Flutter 3.47 apps need AGP 8.11+, and Gradle refuses two AGP versions in one build. The published AAR works in apps on newer AGP and Kotlin.

## Use

```dart
import 'package:miniwall_flutter/miniwall_flutter.dart';

await Miniwall.configure('pk_...');

final result = await Miniwall.present(
  const ScreenSource.placement('upgrade'),
  options: PresentOptions(
    products: {'monthly': const ProductInfo(price: 9.99, currency: 'USD', period: 'month')},
    onPurchase: (packageId, answers) async => buy(packageId), // true = bought
  ),
);
if (result.outcome == 'purchased') unlock();
```

## Placements that show by themselves

```dart
await Miniwall.startAutoPlacements(
  options: PresentOptions(
    products: {'monthly': const ProductInfo(price: 9.99, currency: 'USD', period: 'month')},
    onPurchase: (packageId, answers) async => buy(packageId),
  ),
  onResult: (placement, result) => print('$placement: ${result.outcome}'),
);
await Miniwall.track('level_completed'); // events that placements listen for
await Miniwall.stopAutoPlacements();     // e.g. on sign-out; call startAutoPlacements again to resume
```

`startAutoPlacements` takes the same `PresentOptions` as `present`. If the Flutter engine goes away (hot restart), the
native side stops the auto placements and frees every screen waiting on Dart.

## Handlers

- `onPurchase(String packageId, Answers answers)`: `Future<bool>`. `true` = bought, `false` = cancelled. Throwing shows no success
  and calls `onError`.
- `onRestore()`: `Future<bool>`; without it the Restore button is hidden.
- `onAction(String actionId, Answers answers)`: `Future<bool>`. `false` keeps the screen open; `true` closes it. Throwing keeps the
  screen open and calls `onError`.
- `onAnswer(fieldId, value, answers)`, `onOpenUrl(url)`: notifications; the screen does not wait for them.
- `onError(String message)`: failures the screen reports (load failure, a handler that threw, an unusable link). Dart receives the
  reason as a plain `String`, not an exception.

## Develop

```bash
flutter pub get && flutter analyze && flutter test
```

`example/` is a sample app (see `example/README.md`). It bundles the Miniwall spec's templates (`scripts/fetch-spec.sh` fetches the spec pinned in `SPEC_VERSION` into `.spec/`; `example/tool/sync_templates.sh` copies them in) and builds against `miniwall-ios` and `miniwall-android` checked out next to this repository.
