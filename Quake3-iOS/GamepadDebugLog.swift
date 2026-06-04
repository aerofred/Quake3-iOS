//
//  GamepadDebugLog.swift
//  Quake3-iOS
//

import Foundation
import GameController

/// Console logs for gamepad debugging. Filter Xcode console with `[Gamepad]`.
enum GamepadDebugLog {
    /// Set UserDefaults `gamepadDebugLogs` to false to silence.
    static var enabled: Bool {
        if UserDefaults.standard.object(forKey: "gamepadDebugLogs") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "gamepadDebugLogs")
    }

    private static var lastThrottled: [String: TimeInterval] = [:]

    static func log(_ message: String) {
        guard enabled else { return }
        NSLog("[Gamepad] %@", message)
    }

    static func logThrottled(_ key: String, interval: TimeInterval = 1.0, _ message: String) {
        guard enabled else { return }
        let now = Date().timeIntervalSinceReferenceDate
        if let last = lastThrottled[key], now - last < interval {
            return
        }
        lastThrottled[key] = now
        NSLog("[Gamepad] %@", message)
    }

    static func describe(_ controller: GCController) -> String {
        var parts: [String] = []
        if let name = controller.vendorName, !name.isEmpty {
            parts.append("vendor=\(name)")
        }
        parts.append("playerIndex=\(controller.playerIndex.rawValue)")
        if controller.extendedGamepad != nil {
            parts.append("profile=extended")
        } else if controller.microGamepad != nil {
            parts.append("profile=micro")
        } else {
            parts.append("profile=none")
        }
        return parts.joined(separator: ", ")
    }
}
