//
//  GamepadConfig.swift
//  Quake3-iOS
//

import Foundation

struct GamepadAction: Equatable {
    let command: String
    let label: String
    let section: GamepadActionSection
}

enum GamepadActionSection: String, CaseIterable {
    case movement = "Movement"
    case looking = "Looking"
    case weapons = "Weapons"
    case misc = "Misc"
}

final class GamepadConfig {
    static let shared = GamepadConfig()

    static let bindingsKey = "gamepadBindings"
    static let sensitivityKey = "gamepadSensitivity"
    static let deadZoneKey = "gamepadDeadZone"

    private let defaults = UserDefaults()

    static let defaultBindings: [String: String] = [
        "PAD0_RIGHTTRIGGER": "+attack",
        "PAD0_LEFTSTICK_UP": "+forward",
        "PAD0_LEFTSTICK_DOWN": "+back",
        "PAD0_LEFTSTICK_LEFT": "+moveleft",
        "PAD0_LEFTSTICK_RIGHT": "+moveright",
        "PAD0_RIGHTSTICK_UP": "+lookup",
        "PAD0_RIGHTSTICK_DOWN": "+lookdown",
        "PAD0_RIGHTSTICK_LEFT": "+left",
        "PAD0_RIGHTSTICK_RIGHT": "+right",
        "PAD0_A": "+moveup",
        "PAD0_LEFTSHOULDER": "weapnext",
        "PAD0_RIGHTSHOULDER": "weapprev"
    ]

    static let allActions: [GamepadAction] = [
        GamepadAction(command: "+forward", label: "Walk forward", section: .movement),
        GamepadAction(command: "+back", label: "Backpedal", section: .movement),
        GamepadAction(command: "+moveleft", label: "Step left", section: .movement),
        GamepadAction(command: "+moveright", label: "Step right", section: .movement),
        GamepadAction(command: "+moveup", label: "Jump", section: .movement),
        GamepadAction(command: "+movedown", label: "Crouch", section: .movement),
        GamepadAction(command: "+speed", label: "Run / walk", section: .movement),
        GamepadAction(command: "+left", label: "Turn left", section: .looking),
        GamepadAction(command: "+right", label: "Turn right", section: .looking),
        GamepadAction(command: "+lookup", label: "Look up", section: .looking),
        GamepadAction(command: "+lookdown", label: "Look down", section: .looking),
        GamepadAction(command: "centerview", label: "Center view", section: .looking),
        GamepadAction(command: "+attack", label: "Attack", section: .weapons),
        GamepadAction(command: "weapnext", label: "Next weapon", section: .weapons),
        GamepadAction(command: "weapprev", label: "Previous weapon", section: .weapons),
        GamepadAction(command: "weapon 1", label: "Gauntlet", section: .weapons),
        GamepadAction(command: "weapon 2", label: "Machinegun", section: .weapons),
        GamepadAction(command: "weapon 3", label: "Shotgun", section: .weapons),
        GamepadAction(command: "weapon 4", label: "Grenade launcher", section: .weapons),
        GamepadAction(command: "weapon 5", label: "Rocket launcher", section: .weapons),
        GamepadAction(command: "weapon 6", label: "Lightning", section: .weapons),
        GamepadAction(command: "weapon 7", label: "Railgun", section: .weapons),
        GamepadAction(command: "weapon 8", label: "Plasma gun", section: .weapons),
        GamepadAction(command: "weapon 9", label: "BFG", section: .weapons),
        GamepadAction(command: "+scores", label: "Show scores", section: .misc),
        GamepadAction(command: "+button2", label: "Use item", section: .misc),
        GamepadAction(command: "+button3", label: "Gesture", section: .misc),
        GamepadAction(command: "togglemenu", label: "Toggle menu", section: .misc)
    ]

    static let inputDisplayNames: [String: String] = [
        "PAD0_A": "A",
        "PAD0_B": "B",
        "PAD0_X": "X",
        "PAD0_Y": "Y",
        "PAD0_BACK": "Back",
        "PAD0_GUIDE": "Guide",
        "PAD0_START": "Start",
        "PAD0_LEFTSTICK_CLICK": "L3",
        "PAD0_RIGHTSTICK_CLICK": "R3",
        "PAD0_LEFTSHOULDER": "LB",
        "PAD0_RIGHTSHOULDER": "RB",
        "PAD0_DPAD_UP": "D-Pad Up",
        "PAD0_DPAD_DOWN": "D-Pad Down",
        "PAD0_DPAD_LEFT": "D-Pad Left",
        "PAD0_DPAD_RIGHT": "D-Pad Right",
        "PAD0_LEFTSTICK_UP": "Left Stick Up",
        "PAD0_LEFTSTICK_DOWN": "Left Stick Down",
        "PAD0_LEFTSTICK_LEFT": "Left Stick Left",
        "PAD0_LEFTSTICK_RIGHT": "Left Stick Right",
        "PAD0_RIGHTSTICK_UP": "Right Stick Up",
        "PAD0_RIGHTSTICK_DOWN": "Right Stick Down",
        "PAD0_RIGHTSTICK_LEFT": "Right Stick Left",
        "PAD0_RIGHTSTICK_RIGHT": "Right Stick Right",
        "PAD0_LEFTTRIGGER": "LT",
        "PAD0_RIGHTTRIGGER": "RT"
    ]

    private(set) var bindings: [String: String]

    private init() {
        if let saved = defaults.dictionary(forKey: Self.bindingsKey) as? [String: String] {
            bindings = saved
        } else {
            bindings = Self.defaultBindings
        }
    }

    var sensitivity: Float {
        get {
            if defaults.object(forKey: Self.sensitivityKey) == nil {
                return 10
            }
            return Float(defaults.double(forKey: Self.sensitivityKey))
        }
        set {
            defaults.set(Double(newValue), forKey: Self.sensitivityKey)
        }
    }

    var deadZone: Float {
        get {
            if defaults.object(forKey: Self.deadZoneKey) == nil {
                return 0.15
            }
            return Float(defaults.double(forKey: Self.deadZoneKey))
        }
        set {
            defaults.set(Double(newValue), forKey: Self.deadZoneKey)
        }
    }

    func input(for command: String) -> String? {
        bindings.first(where: { $0.value == command })?.key
    }

    func displayName(for input: String?) -> String {
        guard let input, !input.isEmpty else { return "Unbound" }
        return Self.inputDisplayNames[input] ?? input
    }

    func setBinding(input: String, command: String) {
        for (key, value) in bindings where value == command {
            bindings[key] = ""
        }
        bindings[input] = command
        persist()
    }

    func clearBinding(for command: String) {
        for (key, value) in bindings where value == command {
            bindings[key] = ""
        }
        persist()
    }

    func resetToDefaults() {
        bindings = Self.defaultBindings
        sensitivity = 10
        deadZone = 0.15
        persist()
    }

    func persist() {
        defaults.set(bindings, forKey: Self.bindingsKey)
    }

    func launchArguments() -> [String] {
        var args = [
            "+set", "sensitivity", String(format: "%.1f", sensitivity),
            "+set", "joy_threshold", String(format: "%.2f", deadZone)
        ]

        for (input, command) in bindings where !command.isEmpty {
            args.append(contentsOf: ["+bind", input, "\"\(command)\""])
        }

        return args
    }

    func applyToRunningEngine() {
        var commands = ""
        commands += "seta sensitivity \(String(format: "%.1f", sensitivity))\n"
        commands += "seta joy_threshold \(String(format: "%.2f", deadZone))\n"

        let allInputs = Set(Self.defaultBindings.keys)
            .union(bindings.keys)
            .union(Self.inputDisplayNames.keys)

        for input in allInputs.sorted() {
            let command = bindings[input] ?? ""
            if command.isEmpty {
                commands += "unbind \(input)\n"
            } else {
                commands += "bind \(input) \"\(command)\"\n"
            }
        }

        CL_ExecuteConsole(commands)
    }
}
