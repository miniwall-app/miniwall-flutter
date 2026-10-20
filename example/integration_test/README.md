# Flutter: integration test

`miniwall_native_test.dart` runs the Dart API against the real iOS/Android SDK on a simulator, emulator or phone. It starts a small
local server (inside the test) that plays the Miniwall delivery API, so it needs no account or network.

```bash
cd example
flutter create --platforms=ios,android --org app.miniwall --project-name miniwall_flutter_example .   # once, see ../README.md
flutter pub get
flutter test integration_test -d <device id>        # flutter devices
```

Covers: configure, present, a toast that closes by itself, `view`/`close` events with `platform`, frequency cap, holdout and audience
skips, load errors, the offline cache, auto placements start/stop.

Does not cover (a Flutter test cannot reach into the native screen): choosing a plan, Subscribe, Restore, questions, flow + Back.
Those run in the Maestro flows (`e2e/maestro/*.yaml` of the React Native repository, the sample apps share the same ids) and in the native UI tests.

Android needs cleartext http to loopback: `android/app/src/debug/AndroidManifest.xml` enables it for debug builds. Status: written without
a Flutter SDK, not run yet.
