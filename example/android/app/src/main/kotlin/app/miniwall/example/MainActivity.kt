package app.miniwall.example

import io.flutter.embedding.android.FlutterFragmentActivity

// A ComponentActivity (not FlutterActivity): the Android SDK shows banners and toasts as views inside the host Activity,
// which needs the lifecycle owners only a ComponentActivity provides; otherwise they fall back to a sheet.
class MainActivity : FlutterFragmentActivity()
