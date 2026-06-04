//
//  GamepadInputManager.swift
//  Quake3-iOS
//

import GameController
import UIKit

/// Sends physical controller input to the Quake 3 engine via `CL_KeyEvent` / `CL_JoystickEvent`.
/// Does not touch movement axes unless a connected controller is actively used.
final class GamepadInputManager {
    static let shared = GamepadInputManager()

    var isConfigCaptureActive = false
    private(set) var isPhysicalStickActive = false
    /// Set by the on-screen move joystick while the player is dragging it.
    var onScreenMoveJoystickEngaged = false

    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var attachedController: GCController?
    private var keyNums: [String: Int32] = [:]
    private var pressedKeys = Set<Int32>()
    private var stickKeysDown = Set<Int32>()
    private var isManagingMoveAxes = false
    private var loggedMissingKeys = Set<String>()
    private var didLogInputBlocked = false
    private var isRunning = false
    private var discoveryTimer: Timer?
    private var didLogInitialKeyMap = false
    /// GC=0 but SDL opened the pad — engine handles input via IN_PadMove + PAD0 binds.
    private var usingSDLEnginePath = false
    private var engineDebugTimer: Timer?
    private var pollTimer: Timer?
    private static var didPrepareAtLaunch = false
    private var aggressiveDiscoveryPollsRemaining = 60

    private let moveAxisYaw = 0
    private let moveAxisForward = 1
    private let moveGain: Float = 127

    private init() {
        reloadKeyNumbers()
    }

    func reloadKeyNumbers() {
        keyNums.removeAll()
        loggedMissingKeys.removeAll()
        var missing: [String] = []
        for name in GamepadConfig.inputDisplayNames.keys.sorted() {
            if let keynum = keyNumber(for: name) {
                keyNums[name] = keynum
            } else {
                missing.append(name)
            }
        }
        GamepadDebugLog.log(
            "reloadKeyNumbers: mapped=\(keyNums.count) missing=\(missing.count)"
            + (missing.isEmpty ? "" : " [\(missing.joined(separator: ", "))]")
        )
        if !didLogInitialKeyMap {
            didLogInitialKeyMap = true
            for (name, keynum) in keyNums where ["PAD0_A", "PAD0_RIGHTTRIGGER", "PAD0_LEFTSTICK_LEFT"].contains(name) {
                let command = GamepadConfig.shared.bindings[name] ?? "(no bind)"
                GamepadDebugLog.log("\(name) -> keynum=\(keynum) bind=\(command)")
            }
        }
    }

    /// Prime GameController before the game view exists (pairing / GCControllerDidConnect).
    @objc static func prepareAtApplicationLaunch() {
        guard !didPrepareAtLaunch else { return }
        didPrepareAtLaunch = true
        if #available(iOS 14.5, *) {
            GCController.shouldMonitorBackgroundEvents = true
        }
        let primed = GCController.controllers().count
        GamepadDebugLog.log("launch: primed GameController framework (controllers=\(primed))")
        shared.installObserversIfNeeded()
        GCController.startWirelessControllerDiscovery {
            GamepadDebugLog.log(
                "launch: wireless discovery finished, GC=\(GCController.controllers().count) — ouverture SDL en partie (start)"
            )
        }
    }

    func start() {
        isRunning = true
        Self.prepareAtApplicationLaunch()
        aggressiveDiscoveryPollsRemaining = 60
        GamepadDebugLog.log("start() — scanning for controllers")
        installObserversIfNeeded()
        probeSDLJoysticks(context: "start")
        GCController.startWirelessControllerDiscovery { [weak self] in
            guard let self else { return }
            GamepadDebugLog.log(
                "wireless discovery done: GC=\(GCController.controllers().count) SDL=\(Sys_SDLJoystickCount())"
            )
            if !self.tryActivateSDLEnginePath(context: "discovery") {
                self.attachHandlersToConnectedControllers()
            }
        }
        reloadKeyNumbers()
        installObserversIfNeeded()
        logDualShockNoteIfNeeded()
        logInputSources(context: "start")
        if !tryActivateSDLEnginePath(context: "start") {
            attachHandlersToConnectedControllers()
        }
        scheduleSDLOpenIfNeeded(context: "delayed-0.3s", delay: 0.3)
        scheduleSDLOpenIfNeeded(context: "delayed-1.5s", delay: 1.5)
        startDiscoveryTimerIfNeeded()
    }

    /// Releases held keys/axes when the pause overlay is shown (handler stays connected).
    func pauseForOverlay() {
        releaseManagedKeys()
        releaseMoveAxesIfManaging()
        isPhysicalStickActive = false
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        GamepadDebugLog.log("stop() — arrêt complet GamepadInputManager")
        stopDiscoveryTimer()
        stopEngineDebugTimer()
        stopPollTimer()
        detachHandler()
        releaseManagedKeys()
        releaseMoveAxesIfManaging()
    }

    private func scheduleSDLOpenIfNeeded(context: String, delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            guard !self.usingSDLEnginePath, Sys_SDLGamepadOpened() == 0 else { return }
            _ = self.tryActivateSDLEnginePath(context: context)
            if !self.usingSDLEnginePath {
                self.attachHandlersToConnectedControllers()
            }
        }
    }

    private func logInputSources(context: String) {
        let gcCount = GCController.controllers().count
        let sdlCount = Sys_SDLJoystickCount()
        GamepadDebugLog.log("\(context): GCController.controllers()=\(gcCount) Sys_SDLJoystickCount=\(sdlCount)")
        if gcCount == 0 && sdlCount == 0 {
            GamepadDebugLog.log(
                "\(context): no controller visible to iOS — pair in Settings > Bluetooth, use a real device (not Simulator), then relaunch"
            )
        }
        for (index, controller) in GCController.controllers().enumerated() {
            GamepadDebugLog.log("\(context): controller[\(index)] \(GamepadDebugLog.describe(controller))")
        }
    }

    private func startDiscoveryTimerIfNeeded() {
        guard discoveryTimer == nil else { return }
        if usingSDLEnginePath || Sys_SDLGamepadOpened() > 0 {
            return
        }
        let interval: TimeInterval = aggressiveDiscoveryPollsRemaining > 0 ? 0.5 : 2.0
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, !self.usingSDLEnginePath else { return }
            if self.aggressiveDiscoveryPollsRemaining > 0 {
                self.aggressiveDiscoveryPollsRemaining -= 1
            }
            self.logInputSources(context: "poll")
            if self.tryActivateSDLEnginePath(context: "poll") {
                return
            }
            self.attachHandlersToConnectedControllers()
        }
    }

    private func stopDiscoveryTimer() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
    }

    private func installObserversIfNeeded() {
        guard connectObserver == nil else { return }

        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            GamepadDebugLog.log("GCControllerDidConnect: \(GamepadDebugLog.describe(controller))")
            guard let self else { return }
            guard self.isRunning else {
                GamepadDebugLog.log("connect: reportée — moteur pas encore en partie (évite crash zone)")
                return
            }
            if !self.tryActivateSDLEnginePath(context: "connect") {
                self.attachHandler(to: controller)
            }
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            GamepadDebugLog.log("GCControllerDidDisconnect: \(GamepadDebugLog.describe(controller))")
            if self?.attachedController === controller {
                self?.detachHandler()
            }
        }

        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            GamepadDebugLog.logThrottled("app-active", interval: 2, "UIApplication.didBecomeActive — rescanning controllers")
            GCController.startWirelessControllerDiscovery(completionHandler: nil)
            self.logInputSources(context: "active")
            if !self.tryActivateSDLEnginePath(context: "active") {
                self.attachHandlersToConnectedControllers()
            }
        }
    }

    private func removeObservers() {
        if let connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
            self.connectObserver = nil
        }
        if let disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
            self.disconnectObserver = nil
        }
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    private func logDualShockNoteIfNeeded() {
        GamepadDebugLog.log(
            "iOS: si SDL_NumJoysticks>=1 on utilise le moteur SDL (fiable); sinon GameController + polling Swift."
        )
    }

    private func probeSDLJoysticks(context: String) {
        IN_IosRefreshJoystick(qboolean(0))
        GamepadDebugLog.log("\(context): SDL probe count=\(Sys_SDLJoystickCount()) (GC prioritaire, ouverture SDL différée)")
    }

    private func openSDLJoystickIfNeeded(context: String) {
        _ = tryActivateSDLEnginePath(context: context)
    }

    private func isEngineMemoryReady() -> Bool {
        Sys_IsEngineMemoryReady() != qboolean(0)
    }

    private func applyEngineBindingsIfReady(_ context: String) {
        guard isRunning, isEngineMemoryReady() else {
            GamepadDebugLog.logThrottled(
                "binds-defer",
                interval: 2,
                "\(context): binds/SDL open reportés (moteur pas prêt)"
            )
            return
        }
        GamepadConfig.shared.applyToRunningEngine()
    }

    /// SDL gamepad input works reliably on iOS for DS4; GC `valueChangedHandler` often stays silent without GCEventViewController.
    @discardableResult
    private func tryActivateSDLEnginePath(context: String) -> Bool {
        IN_IosRefreshJoystick(qboolean(0))
        let sdlCount = Sys_SDLJoystickCount()
        guard sdlCount > 0 else {
            GamepadDebugLog.logThrottled(
                "sdl-none",
                interval: 4,
                "\(context): SDL_NumJoysticks=0 — attente manette"
            )
            return false
        }

        if usingSDLEnginePath, Sys_SDLGamepadOpened() > 0 {
            return true
        }

        guard isRunning, isEngineMemoryReady() else {
            GamepadDebugLog.logThrottled(
                "sdl-defer",
                interval: 2,
                "\(context): SDL open reporté (isRunning=\(isRunning) zone=\(isEngineMemoryReady()))"
            )
            return false
        }

        detachSwiftInputHandler()
        Sys_SetNativeGamepadActive(qboolean(0))
        IN_IosRefreshJoystick(qboolean(1))
        let opened = Sys_SDLGamepadOpened()
        let inJoy = CL_GetCvarInt("in_joystick")
        let useAnalog = CL_GetCvarInt("in_joystickUseAnalog")
        GamepadDebugLog.log(
            "\(context): SDL open SDL=\(sdlCount) opened=\(opened) in_joystick=\(inJoy) in_joystickUseAnalog=\(useAnalog) GC=\(GCController.controllers().count)"
        )

        guard opened > 0 else {
            return false
        }

        usingSDLEnginePath = true
        let path = opened == 2 ? "SDL_GameController" : "SDL_Joystick"
        GamepadDebugLog.log("\(context): chemin moteur \(path) actif (PAD0 binds / IN_PadMove)")
        applyEngineBindingsIfReady(context)
        startEngineDebugTimerIfNeeded()
        stopDiscoveryTimer()
        return true
    }

    private func detachSwiftInputHandler() {
        stopPollTimer()
        attachedController?.extendedGamepad?.valueChangedHandler = nil
        releaseManagedKeys()
        releaseMoveAxesIfManaging()
    }

    private func stopPollTimer() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func startPollTimer(for gamepad: GCExtendedGamepad) {
        stopPollTimer()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.handleGamepad(gamepad)
        }
    }

    private func startEngineDebugTimerIfNeeded() {
        guard engineDebugTimer == nil else { return }
        engineDebugTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, self.usingSDLEnginePath || Sys_SDLGamepadOpened() > 0 else { return }
            var buffer = [CChar](repeating: 0, count: 256)
            IN_IosDebugPadState(&buffer, Int32(buffer.count))
            let message = String(cString: buffer)
            if !message.isEmpty {
                GamepadDebugLog.log(message)
            }
        }
    }

    private func stopEngineDebugTimer() {
        engineDebugTimer?.invalidate()
        engineDebugTimer = nil
    }

    private func refreshAttachedHandlerIfNeeded() {
        if tryActivateSDLEnginePath(context: "refresh") {
            return
        }
        guard let controller = attachedController, let gamepad = controller.extendedGamepad else { return }
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            self?.handleGamepad(pad)
        }
        startPollTimer(for: gamepad)
        applyEngineBindingsIfReady("refresh")
        handleGamepad(gamepad)
    }

    private func attachHandlersToConnectedControllers() {
        if usingSDLEnginePath {
            return
        }
        if tryActivateSDLEnginePath(context: "attachHandlers") {
            return
        }
        if attachedController != nil {
            GamepadDebugLog.logThrottled(
                "already-attached",
                interval: 2,
                "attachHandlers: refresh \(GamepadDebugLog.describe(attachedController!))"
            )
            refreshAttachedHandlerIfNeeded()
            return
        }
        for controller in GCController.controllers() {
            if attachHandler(to: controller) {
                return
            }
        }
        if !usingSDLEnginePath {
            GamepadDebugLog.logThrottled(
                "attach-none",
                interval: 3,
                "attachHandlers: no GC controller (SDL path may still work if opened>0)"
            )
        }
    }

    @discardableResult
    private func attachHandler(to controller: GCController) -> Bool {
        if attachedController != nil {
            GamepadDebugLog.logThrottled(
                "attach-skip-busy",
                interval: 2,
                "attachHandler: skip, already attached to \(GamepadDebugLog.describe(attachedController!))"
            )
            return false
        }
        if let gamepad = controller.extendedGamepad {
            return attachExtendedGamepad(gamepad, to: controller)
        }

        GamepadDebugLog.log(
            "attachHandler: FAILED no extendedGamepad for \(GamepadDebugLog.describe(controller))"
        )
        openSDLJoystickIfNeeded(context: "attach-failed")
        return false
    }

    private func attachExtendedGamepad(_ gamepad: GCExtendedGamepad, to controller: GCController) -> Bool {
        attachedController = controller

        if tryActivateSDLEnginePath(context: "attach") {
            return true
        }

        didLogInputBlocked = false
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            self?.handleGamepad(pad)
        }
        startPollTimer(for: gamepad)
        GamepadDebugLog.log(
            "attachHandler: GC polling Swift \(GamepadDebugLog.describe(controller)) (SDL indisponible)"
        )
        applyEngineBindingsIfReady("attach-gc")
        stopDiscoveryTimer()
        handleGamepad(gamepad)
        return true
    }

    private func detachHandler() {
        if let attachedController {
            GamepadDebugLog.log("detachHandler: \(GamepadDebugLog.describe(attachedController))")
        }
        stopPollTimer()
        attachedController?.extendedGamepad?.valueChangedHandler = nil
        attachedController = nil
        usingSDLEnginePath = false
        Sys_SetNativeGamepadActive(qboolean(0))
        releaseManagedKeys()
        releaseMoveAxesIfManaging()
        isPhysicalStickActive = false
        if isRunning {
            startDiscoveryTimerIfNeeded()
        }
    }

    private func handleGamepad(_ gamepad: GCExtendedGamepad) {
        guard shouldProcessInput() else {
            releaseManagedKeys()
            releaseMoveAxesIfManaging()
            return
        }

        logGamepadActivity(gamepad)
        processButtons(gamepad)
        processTriggers(gamepad)
        processLeftStick(gamepad)
        processRightStick(gamepad)
    }

    private func shouldProcessInput() -> Bool {
        if isConfigCaptureActive {
            logInputBlockedOnce("config capture active")
            return false
        }
        if CL_IsPauseMenuOpen() != 0 {
            logInputBlockedOnce("pause menu open")
            return false
        }
        let catcher = Key_GetCatcher()
        // Align with cl_keys.c (iOS): +commands still run in CA_ACTIVE unless console/chat catcher.
        let blockMask: Int32 = 0x0001 | 0x0004 // KEYCATCH_CONSOLE | KEYCATCH_MESSAGE
        if (catcher & blockMask) != 0 {
            logInputBlockedOnce("Key_GetCatcher=\(catcher) (console/message)")
            return false
        }
        return true
    }

    private func logInputBlockedOnce(_ reason: String) {
        guard !didLogInputBlocked else { return }
        didLogInputBlocked = true
        GamepadDebugLog.logThrottled("input-blocked", interval: 0.5, "input ignored: \(reason)")
    }

    private func logGamepadActivity(_ gamepad: GCExtendedGamepad) {
        let lx = gamepad.leftThumbstick.xAxis.value
        let ly = gamepad.leftThumbstick.yAxis.value
        let rx = gamepad.rightThumbstick.xAxis.value
        let ry = gamepad.rightThumbstick.yAxis.value
        let stickActive = abs(lx) > 0.08 || abs(ly) > 0.08 || abs(rx) > 0.08 || abs(ry) > 0.08
        if stickActive {
            GamepadDebugLog.logThrottled(
                "stick",
                interval: 0.35,
                String(format: "sticks L(%.2f,%.2f) R(%.2f,%.2f)", lx, ly, rx, ry)
            )
        }
        if gamepad.buttonA.isPressed {
            GamepadDebugLog.logThrottled("btn-a", interval: 0.5, "button A pressed")
        }
        if gamepad.rightTrigger.value > 0.08 {
            GamepadDebugLog.logThrottled(
                "rt",
                interval: 0.35,
                String(format: "rightTrigger=%.2f", gamepad.rightTrigger.value)
            )
        }
    }

    private func processButtons(_ gamepad: GCExtendedGamepad) {
        setPadKey("PAD0_A", down: gamepad.buttonA.isPressed)
        setPadKey("PAD0_B", down: gamepad.buttonB.isPressed)
        setPadKey("PAD0_X", down: gamepad.buttonX.isPressed)
        setPadKey("PAD0_Y", down: gamepad.buttonY.isPressed)
        setPadKey("PAD0_LEFTSHOULDER", down: gamepad.leftShoulder.isPressed)
        setPadKey("PAD0_RIGHTSHOULDER", down: gamepad.rightShoulder.isPressed)

        if #available(iOS 12.1, tvOS 12.1, *) {
            setPadKey("PAD0_LEFTSTICK_CLICK", down: gamepad.leftThumbstickButton?.isPressed == true)
            setPadKey("PAD0_RIGHTSTICK_CLICK", down: gamepad.rightThumbstickButton?.isPressed == true)
        }

        setPadKey("PAD0_DPAD_UP", down: gamepad.dpad.up.isPressed)
        setPadKey("PAD0_DPAD_DOWN", down: gamepad.dpad.down.isPressed)
        setPadKey("PAD0_DPAD_LEFT", down: gamepad.dpad.left.isPressed)
        setPadKey("PAD0_DPAD_RIGHT", down: gamepad.dpad.right.isPressed)

        if #available(iOS 13.0, tvOS 13.0, *) {
            setPadKey("PAD0_START", down: gamepad.buttonMenu.isPressed)
            setPadKey("PAD0_BACK", down: gamepad.buttonOptions?.isPressed == true)
        }
    }

    private func processTriggers(_ gamepad: GCExtendedGamepad) {
        let threshold = deadZone()
        setPadKey("PAD0_LEFTTRIGGER", down: gamepad.leftTrigger.value > threshold)
        setPadKey("PAD0_RIGHTTRIGGER", down: gamepad.rightTrigger.value > threshold)
    }

    private func processLeftStick(_ gamepad: GCExtendedGamepad) {
        let threshold = deadZone()
        let rawX = gamepad.leftThumbstick.xAxis.value
        let rawY = gamepad.leftThumbstick.yAxis.value
        let x = applyDeadzone(rawX, threshold: threshold)
        let y = applyDeadzone(rawY, threshold: threshold)

        isPhysicalStickActive = abs(x) > 0.01 || abs(y) > 0.01

        // Strafe: digital keys (+moveleft / +moveright).
        updateStickKey("PAD0_LEFTSTICK_LEFT", down: rawX < -threshold)
        updateStickKey("PAD0_LEFTSTICK_RIGHT", down: rawX > threshold)

        guard isPhysicalStickActive else {
            updateStickKey("PAD0_LEFTSTICK_UP", down: false)
            updateStickKey("PAD0_LEFTSTICK_DOWN", down: false)
            releaseMoveAxesIfManaging()
            return
        }

        // Forward/back: analog axis 1 (j_forward_axis) — Y+ = stick up = avancer.
        let sensitivity = max(0.25, CL_GetCvarFloat("touch_move_sensitivity"))
        let forward = Int32(max(-127, min(127, (y * moveGain * sensitivity).rounded())))
        sendMoveAxes(yaw: 0, forward: forward)
        isManagingMoveAxes = true
    }

    private func processRightStick(_ gamepad: GCExtendedGamepad) {
        let threshold = deadZone()
        let x = gamepad.rightThumbstick.xAxis.value
        let y = gamepad.rightThumbstick.yAxis.value

        updateStickKey("PAD0_RIGHTSTICK_UP", down: y > threshold)
        updateStickKey("PAD0_RIGHTSTICK_DOWN", down: y < -threshold)
        updateStickKey("PAD0_RIGHTSTICK_LEFT", down: x < -threshold)
        updateStickKey("PAD0_RIGHTSTICK_RIGHT", down: x > threshold)
    }

    private func sendMoveAxes(yaw: Int32, forward: Int32) {
        GamepadDebugLog.logThrottled(
            "move-axes",
            interval: 0.35,
            "CL_JoystickEvent axis0(yaw)=\(yaw) axis1(forward)=\(forward) touchEngaged=\(onScreenMoveJoystickEngaged)"
        )
        let time = Int32(Sys_Milliseconds())
        CL_JoystickEvent(Int32(moveAxisYaw), yaw, time)
        CL_JoystickEvent(Int32(moveAxisForward), forward, time)
    }

    private func setPadKey(_ name: String, down: Bool) {
        guard let keynum = keyNums[name] else {
            if !loggedMissingKeys.contains(name) {
                loggedMissingKeys.insert(name)
                GamepadDebugLog.log("setPadKey: no keynum for \(name) (Key_StringToKeynum failed?)")
            }
            return
        }
        if down {
            let command = GamepadConfig.shared.bindings[name] ?? "(no bind in GamepadConfig)"
            GamepadDebugLog.logThrottled("key-\(name)", interval: 0.4, "CL_KeyEvent \(name) keynum=\(keynum) down bind=\(command)")
        }
        setKey(keynum, down: down)
    }

    private func updateStickKey(_ name: String, down: Bool) {
        guard let keynum = keyNums[name] else { return }
        let wasDown = stickKeysDown.contains(keynum)
        guard down != wasDown else { return }

        if down {
            stickKeysDown.insert(keynum)
        } else {
            stickKeysDown.remove(keynum)
        }
        setKey(keynum, down: down)
    }

    private func setKey(_ keynum: Int32, down: Bool) {
        let wasDown = pressedKeys.contains(keynum)
        guard down != wasDown else { return }

        if down {
            pressedKeys.insert(keynum)
        } else {
            pressedKeys.remove(keynum)
        }

        CL_KeyEvent(
            keynum,
            down ? qboolean(1) : qboolean(0),
            UInt32(Sys_Milliseconds())
        )
    }

    private func releaseManagedKeys() {
        for keynum in stickKeysDown {
            CL_KeyEvent(keynum, qboolean(0), UInt32(Sys_Milliseconds()))
        }
        stickKeysDown.removeAll()

        for keynum in pressedKeys {
            CL_KeyEvent(keynum, qboolean(0), UInt32(Sys_Milliseconds()))
        }
        pressedKeys.removeAll()
    }

    private func releaseMoveAxesIfManaging() {
        guard isManagingMoveAxes else { return }
        // Sending zero here cancels the touch joystick, which shares axes 0 and 1.
        if !onScreenMoveJoystickEngaged {
            sendMoveAxes(yaw: 0, forward: 0)
        }
        isManagingMoveAxes = false
        isPhysicalStickActive = false
    }

    private func deadZone() -> Float {
        let configured = GamepadConfig.shared.deadZone
        let cvarValue = CL_GetCvarFloat("joy_threshold")
        if cvarValue > 0.01 {
            return max(configured, cvarValue)
        }
        return configured
    }

    private func applyDeadzone(_ value: Float, threshold: Float) -> Float {
        if abs(value) < threshold {
            return 0
        }
        let sign: Float = value < 0 ? -1 : 1
        let scaled = (abs(value) - threshold) / max(0.01, 1 - threshold)
        return sign * min(1, scaled)
    }

    private func keyNumber(for name: String) -> Int32? {
        var mutable = Array(name.utf8CString)
        return mutable.withUnsafeMutableBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return nil }
            let keynum = Key_StringToKeynum(base)
            return keynum >= 0 ? keynum : nil
        }
    }
}
