## 0.1.0

- First preview: `Miniwall.configure`, `present`, `preload`, `startAutoPlacements`, `track`, `setAttributes`, `reportPurchase`, `reset`.
- Screens are drawn by the native iOS and Android SDKs.
- Android: use a `FlutterFragmentActivity` as the host Activity; with any other Activity a banner or toast opens as a sheet (the SDK logs a warning).
- The native SDKs show a screen after waiting at most 1.5 s for its custom fonts (see their changelogs).
