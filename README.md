# miniwall_flutter

Miniwall for Flutter: screens built in the Miniwall dashboard, rendered natively by the iOS and
Android SDKs. Flutter 3.22+, iOS 16+, Android minSdk 24. Status: preview (not on pub.dev yet). Tested on an Android emulator (integration 7/7, 77 templates); not yet run on iOS.

## Install (local, before publishing)

1. `pubspec.yaml`: `miniwall_flutter: { path: <repo>/sdks/flutter }`
2. iOS `ios/Podfile`: `pod 'MiniwallCore', :path => '<repo>/sdks/ios'` and `pod 'MiniwallSDK', :path => '<repo>/sdks/ios'`; platform `ios, '16.0'`. The plugin pod depends on `MiniwallSDK ~> 0.1`; until that pod is published, the two `:path` lines are required.
3. Android: your `MainActivity` must extend `FlutterFragmentActivity` (a `ComponentActivity`), not `FlutterActivity`; otherwise banners and toasts open as a sheet and a toast never closes by itself.
4. Android `android/settings.gradle` (Kotlin DSL: `settings.gradle.kts`, see `sdks/README.md`): `includeBuild('<repo>/sdks/android') { dependencySubstitution { substitute(module('app.miniwall:sdk')).using(project(':sdk')) } }`.

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
