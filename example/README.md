# miniwall_flutter example

Same scenario as `the iOS sample app`: configure, present a placement, preload, auto placements, track, fake purchase, fake restore.
Keys for UI tests: `api-key-input`, `configure-button`, `placement-input`, `present-button`, `preload-button`,
`auto-start-button`, `auto-stop-button`, `event-input`, `track-button`, `result-text` (`Key('...')`, also `Semantics.identifier`).

The platform folders were written by hand (no Flutter SDK was available), so `ios/Runner.xcodeproj` and the storyboards are missing. `flutter create` adds the missing files and keeps these:

```bash
cd example
flutter create --platforms=ios,android --org app.miniwall --project-name miniwall_flutter_example .   # keeps existing files
flutter pub get
```

`flutter create` also writes `settings.gradle.kts`, `build.gradle.kts` and `app/build.gradle.kts` next to the Groovy files kept here; delete those three.
The Android build needs Gradle 8.14+ (the wrapper here), and `android/gradle.properties` sets `skipDependencyChecks=true` because the native SDK
(the `miniwall-android` checkout) still uses AGP 8.7.3 and Kotlin 2.0.21, below the minimum Flutter 3.47 checks for. `flutter build apk` and `flutter test integration_test`
then work on an emulator (run on Android emulator: 7 of 7 integration tests pass; iOS not run yet).

Then point the native SDKs at the repo (see `../README.md`): `ios/Podfile` and `android/settings.gradle` already point at the
native SDKs (check out `miniwall-ios` and `miniwall-android` next to this repository). Run: `flutter run` (iOS simulator needs a Mac with Xcode 15+; Android needs minSdk 24).

## Template sweep

`lib/templates.dart` presents any template of the library by name, offline (the counterpart of `-tpl` in `the iOS sample app`): type its name in
the "Template" field, or open `miniwall-example://present?tpl=<name>` (Android intent filter and iOS URL scheme are in the manifest and
`Info.plist`). Copy the files in first: `tool/sync_templates.sh` (they are the spec's fixtures, not committed; the open spec has ten example templates, `MINIWALL_SPEC_DIR` points at a bigger folder). The sweep script of the Android sample app
walks all of them and takes a screenshot of each. Not run yet: needs a simulator or emulator.
