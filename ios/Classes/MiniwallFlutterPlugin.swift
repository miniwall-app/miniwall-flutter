import Flutter
import MiniwallSDK
import UIKit

/// Flutter plugin: forwards calls to `MiniwallBridge` and the screen's requests back to Dart.
public final class MiniwallFlutterPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    private var auto: MiniwallBridge?
    /// Requests waiting for Dart (purchase, restore, action). Emptied with "no" when the engine goes away.
    private var waiting: [Int: (Any?) -> Void] = [:]
    private var nextWaiting = 0

    /// Requests the screen does not wait for.
    private static let fireAndForget: Set<String> = ["answer", "openUrl", "error", "autoResult"]

    init(channel: FlutterMethodChannel) { self.channel = channel }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "miniwall", binaryMessenger: registrar.messenger())
        let instance = MiniwallFlutterPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.publish(instance)
    }

    /// The engine is going away (hot restart, view controller released): stop auto placements and free every waiting screen.
    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        tearDown()
        channel.setMethodCallHandler(nil)
    }

    private func tearDown() {
        makeBridge(presentationId: "").stopAutoPlacements([:])
        auto = nil
        let replies = Array(waiting.values)
        waiting.removeAll()
        for reply in replies { reply(nil) }
    }

    /// An error or a missing handler on the Dart side. Purchase and restore turn it into `{error}` (the native onError
    /// fires and the screen shows no false success); an action also gets `{error}` (the screen stays open); others get nil.
    private static func failure(_ method: String, _ message: String) -> Any? {
        switch method {
        case "purchase", "restore", "action": return ["error": message]
        default: return nil
        }
    }

    private func makeBridge(presentationId: String) -> MiniwallBridge {
        MiniwallBridge { [weak self] method, arguments, reply in
            guard let self else { return reply(nil) }
            var args = arguments
            args["presentationId"] = presentationId
            if Self.fireAndForget.contains(method) {
                self.channel.invokeMethod(method, arguments: args)
                return reply(nil)
            }
            self.nextWaiting += 1
            let id = self.nextWaiting
            self.waiting[id] = reply
            self.channel.invokeMethod(method, arguments: args) { [weak self] value in
                // Already answered "no" by tearDown: ignore a late reply.
                guard let reply = self?.waiting.removeValue(forKey: id) else { return }
                if let error = value as? FlutterError {
                    reply(Self.failure(method, error.message ?? error.code))
                } else if (value as? NSObject) === FlutterMethodNotImplemented {
                    reply(Self.failure(method, "Miniwall: \(method) is not handled on the Dart side"))
                } else {
                    reply(value)
                }
            }
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let bridge = makeBridge(presentationId: args["presentationId"] as? String ?? "")
        switch call.method {
        case "configure": bridge.configure(args); result(nil)
        case "setAttributes": bridge.setAttributes(args); result(nil)
        case "reportPurchase": bridge.reportPurchase(args); result(nil)
        case "reset": bridge.reset(args); result(nil)
        case "track": bridge.track(args); result(nil)
        case "startAutoPlacements":
            let autoBridge = makeBridge(presentationId: "auto")
            auto = autoBridge
            autoBridge.startAutoPlacements(args)
            result(nil)
        case "stopAutoPlacements":
            bridge.stopAutoPlacements(args)
            auto = nil
            result(nil)
        case "preload": bridge.preload(args) { result(nil) }
        case "present":
            bridge.present(args) { value, error in
                if let error { result(FlutterError(code: "miniwall_error", message: error.localizedDescription, details: nil)) } else { result(value) }
                _ = bridge
            }
        default: result(FlutterMethodNotImplemented)
        }
    }
}
