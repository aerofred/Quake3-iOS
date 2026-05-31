//
//  GamepadCapture.swift
//  Quake3-iOS
//

import GameController

final class GamepadCapture {
    var onInputCaptured: ((String) -> Void)?

    private var connectObserver: NSObjectProtocol?
    private var attachedController: GCController?

    func start() {
        stopHandlers()
        GCController.startWirelessControllerDiscovery(completionHandler: nil)
        attachHandlers(to: GCController.controllers().first)

        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.attachHandlers(to: controller)
        }
    }

    func stop() {
        if let connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
            self.connectObserver = nil
        }
        stopHandlers()
    }

    private func attachHandlers(to controller: GCController?) {
        stopHandlers()
        guard let gamepad = controller?.extendedGamepad else { return }

        attachedController = controller
        gamepad.valueChangedHandler = { [weak self] pad, _ in
            self?.process(gamepad: pad)
        }
    }

    private func stopHandlers() {
        attachedController?.extendedGamepad?.valueChangedHandler = nil
        attachedController = nil
    }

    private func process(gamepad: GCExtendedGamepad) {
        let threshold: Float = 0.55

        if gamepad.buttonA.isPressed { capture("PAD0_A"); return }
        if gamepad.buttonB.isPressed { capture("PAD0_B"); return }
        if gamepad.buttonX.isPressed { capture("PAD0_X"); return }
        if gamepad.buttonY.isPressed { capture("PAD0_Y"); return }
        if gamepad.leftShoulder.isPressed { capture("PAD0_LEFTSHOULDER"); return }
        if gamepad.rightShoulder.isPressed { capture("PAD0_RIGHTSHOULDER"); return }
        if #available(iOS 12.1, tvOS 12.1, *) {
            if gamepad.leftThumbstickButton?.isPressed == true { capture("PAD0_LEFTSTICK_CLICK"); return }
            if gamepad.rightThumbstickButton?.isPressed == true { capture("PAD0_RIGHTSTICK_CLICK"); return }
        }

        if gamepad.dpad.up.isPressed { capture("PAD0_DPAD_UP"); return }
        if gamepad.dpad.down.isPressed { capture("PAD0_DPAD_DOWN"); return }
        if gamepad.dpad.left.isPressed { capture("PAD0_DPAD_LEFT"); return }
        if gamepad.dpad.right.isPressed { capture("PAD0_DPAD_RIGHT"); return }

        if gamepad.leftTrigger.value > threshold { capture("PAD0_LEFTTRIGGER"); return }
        if gamepad.rightTrigger.value > threshold { capture("PAD0_RIGHTTRIGGER"); return }

        let leftX = gamepad.leftThumbstick.xAxis.value
        let leftY = gamepad.leftThumbstick.yAxis.value
        if leftY > threshold { capture("PAD0_LEFTSTICK_UP"); return }
        if leftY < -threshold { capture("PAD0_LEFTSTICK_DOWN"); return }
        if leftX < -threshold { capture("PAD0_LEFTSTICK_LEFT"); return }
        if leftX > threshold { capture("PAD0_LEFTSTICK_RIGHT"); return }

        let rightX = gamepad.rightThumbstick.xAxis.value
        let rightY = gamepad.rightThumbstick.yAxis.value
        if rightY > threshold { capture("PAD0_RIGHTSTICK_UP"); return }
        if rightY < -threshold { capture("PAD0_RIGHTSTICK_DOWN"); return }
        if rightX < -threshold { capture("PAD0_RIGHTSTICK_LEFT"); return }
        if rightX > threshold { capture("PAD0_RIGHTSTICK_RIGHT"); return }

        if #available(iOS 13.0, tvOS 13.0, *) {
            if gamepad.buttonMenu.isPressed { capture("PAD0_START"); return }
            if gamepad.buttonOptions?.isPressed == true { capture("PAD0_BACK"); return }
        }
    }

    private func capture(_ input: String) {
        onInputCaptured?(input)
    }
}
