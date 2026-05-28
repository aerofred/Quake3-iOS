//
//  OptionsViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 8/8/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import UIKit

class OptionsViewController: UIViewController {
    
    let defaults = UserDefaults()
    
    @IBOutlet weak var playerNameLabel: UILabel!
    @IBOutlet weak var playerNameField: UITextField!
    private let moveSensitivityKey = "touchMoveSensitivity"
    private let lookSensitivityKey = "touchLookSensitivity"
    private let moveSlider = UISlider()
    private let lookSlider = UISlider()
    private let moveValueLabel = UILabel()
    private let lookValueLabel = UILabel()
    private var positionSliders: [String: UISlider] = [:]
    private var positionValueLabels: [String: UILabel] = [:]
    private let layoutPreviewView = UIView()
    private var previewControls: [String: UIView] = [:]
    private var dragStartOffsets: [String: CGPoint] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
                
        playerNameField.text = defaults.string(forKey: "playerName")
        installTouchControls()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updatePreviewLayout()
    }
    
    @IBAction func savePlayerName(_ sender: UIButton) {
        defaults.set(playerNameField.text!, forKey: "playerName")
        saveTouchSettings()
        let isMainLoopPaused = Sys_IsIOSMainLoopPaused().rawValue != 0
        navigationController?.popViewController(animated: !isMainLoopPaused)
    }

    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        guard Sys_IsIOSMainLoopPaused().rawValue != 0,
              let button = sender as? UIButton,
              button.currentTitle == "BACK" else {
            return true
        }

        navigationController?.popViewController(animated: false)
        return false
    }
    
}

private extension OptionsViewController {

    struct TouchPositionControl {
        let title: String
        let keyPrefix: String
    }

    var touchPositionControls: [TouchPositionControl] {
        [
            TouchPositionControl(title: "Joystick", keyPrefix: "touchJoystick"),
            TouchPositionControl(title: "Fire", keyPrefix: "touchFire"),
            TouchPositionControl(title: "Jump", keyPrefix: "touchJump"),
            TouchPositionControl(title: "Look", keyPrefix: "touchLook")
        ]
    }

    func installTouchControls() {
        moveSlider.minimumValue = 0.25
        moveSlider.maximumValue = 3.0
        moveSlider.value = Float(defaults.double(forKey: moveSensitivityKey, defaultValue: 1.0))
        moveSlider.addTarget(self, action: #selector(touchSettingsChanged(_:)), for: .valueChanged)

        lookSlider.minimumValue = 0.25
        lookSlider.maximumValue = 3.0
        lookSlider.value = Float(defaults.double(forKey: lookSensitivityKey, defaultValue: 1.0))
        lookSlider.addTarget(self, action: #selector(touchSettingsChanged(_:)), for: .valueChanged)
        detachPlayerNameControlsFromStoryboard()

        let stack = UIStackView(arrangedSubviews: [
            makePlayerNameRow(),
            makeSectionTitle("Sensitivity"),
            makeSliderRow(title: "Move Joystick Sensitivity", slider: moveSlider, valueLabel: moveValueLabel),
            makeSliderRow(title: "Look Button Sensitivity", slider: lookSlider, valueLabel: lookValueLabel),
            makeSectionTitle("Position"),
            makeLayoutPreview()
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        for control in touchPositionControls {
            stack.addArrangedSubview(makePositionGroup(control))
        }
        stack.addArrangedSubview(makeResetPositionsButton())

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 62),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        updateTouchLabels()
    }

    func detachPlayerNameControlsFromStoryboard() {
        let movedViews: [UIView] = [playerNameLabel, playerNameField]
        for constraint in view.constraints {
            let firstView = constraint.firstItem as? UIView
            let secondView = constraint.secondItem as? UIView
            if movedViews.contains(where: { $0 === firstView }) || movedViews.contains(where: { $0 === secondView }) {
                constraint.isActive = false
            }
        }

        for constraint in playerNameField.constraints {
            constraint.isActive = false
        }
    }

    func makePlayerNameRow() -> UIStackView {
        playerNameLabel.textColor = .red
        playerNameLabel.font = UIFont(name: "AvenirNextCondensed-Bold", size: 25) ?? UIFont.boldSystemFont(ofSize: 25)
        playerNameLabel.adjustsFontSizeToFitWidth = true
        playerNameLabel.minimumScaleFactor = 0.65

        playerNameField.font = UIFont.systemFont(ofSize: 16)

        let row = UIStackView(arrangedSubviews: [playerNameLabel, playerNameField])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center

        playerNameLabel.setContentHuggingPriority(.required, for: .horizontal)
        playerNameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return row
    }

    func makeSectionTitle(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.textColor = .red
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.65
        return label
    }

    func makeSliderRow(title: String, slider: UISlider, valueLabel: UILabel) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .red
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.65

        valueLabel.textColor = .red
        valueLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let labelRow = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labelRow.axis = .horizontal
        labelRow.spacing = 12
        labelRow.alignment = .firstBaseline

        let row = UIStackView(arrangedSubviews: [labelRow, slider])
        row.axis = .vertical
        row.spacing = 6
        return row
    }

    func makePositionGroup(_ control: TouchPositionControl) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = control.title
        titleLabel.textColor = .red
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)

        let xKey = "\(control.keyPrefix)OffsetX"
        let yKey = "\(control.keyPrefix)OffsetY"
        let xSlider = makePositionSlider(forKey: xKey)
        let ySlider = makePositionSlider(forKey: yKey)
        let xValueLabel = makePositionValueLabel(forKey: xKey)
        let yValueLabel = makePositionValueLabel(forKey: yKey)

        let group = UIStackView(arrangedSubviews: [
            titleLabel,
            makeSliderRow(title: "X", slider: xSlider, valueLabel: xValueLabel),
            makeSliderRow(title: "Y", slider: ySlider, valueLabel: yValueLabel)
        ])
        group.axis = .vertical
        group.spacing = 6
        return group
    }

    func makeLayoutPreview() -> UIView {
        layoutPreviewView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        layoutPreviewView.layer.borderColor = UIColor.red.withAlphaComponent(0.8).cgColor
        layoutPreviewView.layer.borderWidth = 1
        layoutPreviewView.clipsToBounds = true
        layoutPreviewView.heightAnchor.constraint(equalToConstant: 190).isActive = true

        previewControls["touchJoystick"] = makePreviewControl(title: "JOY", keyPrefix: "touchJoystick", isRound: true)
        previewControls["touchFire"] = makePreviewControl(title: "FIRE", keyPrefix: "touchFire", isRound: true)
        previewControls["touchJump"] = makePreviewControl(title: "JUMP", keyPrefix: "touchJump", isRound: true)
        previewControls["touchLook"] = makePreviewControl(title: "LOOK", keyPrefix: "touchLook", isRound: true)

        for control in previewControls.values {
            layoutPreviewView.addSubview(control)
        }

        return layoutPreviewView
    }

    func makePreviewControl(title: String, keyPrefix: String, isRound: Bool) -> UIView {
        let label = UILabel()
        label.text = title
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.boldSystemFont(ofSize: 11)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        label.layer.borderColor = UIColor.white.cgColor
        label.layer.borderWidth = 1
        label.alpha = 0.8
        label.accessibilityIdentifier = keyPrefix
        label.isUserInteractionEnabled = true

        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragPreviewControl(_:)))
        label.addGestureRecognizer(pan)

        if isRound {
            label.layer.cornerRadius = 18
            label.clipsToBounds = true
        }

        return label
    }

    func previewScale() -> CGFloat {
        guard layoutPreviewView.bounds.width > 0, view.bounds.width > 0, view.bounds.height > 0 else {
            return 1
        }

        return max(0.1, min(
            layoutPreviewView.bounds.width / view.bounds.width,
            layoutPreviewView.bounds.height / view.bounds.height
        ))
    }

    func positionOffset(for keyPrefix: String) -> CGPoint {
        CGPoint(
            x: CGFloat(positionSliders["\(keyPrefix)OffsetX"]?.value ?? 0),
            y: CGFloat(positionSliders["\(keyPrefix)OffsetY"]?.value ?? 0)
        )
    }

    func setPositionOffset(_ offset: CGPoint, for keyPrefix: String) {
        positionSliders["\(keyPrefix)OffsetX"]?.value = Float(max(-240, min(240, offset.x)))
        positionSliders["\(keyPrefix)OffsetY"]?.value = Float(max(-240, min(240, offset.y)))
    }

    func previewFrame(_ frame: CGRect, keyPrefix: String, in rect: CGRect, scale: CGFloat) -> CGRect {
        let offset = positionOffset(for: keyPrefix)
        var adjusted = frame.offsetBy(dx: offset.x * scale, dy: offset.y * scale)
        adjusted.origin.x = max(rect.minX, min(rect.maxX - adjusted.width, adjusted.origin.x))
        adjusted.origin.y = max(rect.minY, min(rect.maxY - adjusted.height, adjusted.origin.y))
        return adjusted
    }

    func updatePreviewLayout() {
        let bounds = layoutPreviewView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scale = previewScale()
        let rect = bounds.insetBy(dx: 8, dy: 8)
        let joySize = CGSize(width: 100 * scale, height: 100 * scale)
        let actionSize: CGFloat = 75 * scale
        let lookSize: CGFloat = 58 * scale
        let stackGap: CGFloat = 10 * scale

        let defaultJoystickFrame = CGRect(
            x: rect.minX + 50 * scale,
            y: rect.maxY - joySize.height - 50 * scale,
            width: joySize.width,
            height: joySize.height
        )
        previewControls["touchJoystick"]?.frame = previewFrame(defaultJoystickFrame, keyPrefix: "touchJoystick", in: rect, scale: scale)

        let defaultFireFrame = CGRect(
            x: rect.maxX - 155 * scale,
            y: rect.maxY - 90 * scale,
            width: actionSize,
            height: actionSize
        )
        previewControls["touchFire"]?.frame = previewFrame(defaultFireFrame, keyPrefix: "touchFire", in: rect, scale: scale)

        let defaultJumpFrame = CGRect(
            x: rect.maxX - 90 * scale,
            y: rect.maxY - 135 * scale,
            width: actionSize,
            height: actionSize
        )
        previewControls["touchJump"]?.frame = previewFrame(defaultJumpFrame, keyPrefix: "touchJump", in: rect, scale: scale)

        let clusterMinX = min(defaultFireFrame.minX, defaultJumpFrame.minX)
        let clusterMaxX = max(defaultFireFrame.maxX, defaultJumpFrame.maxX)
        let clusterMinY = min(defaultFireFrame.minY, defaultJumpFrame.minY)
        let defaultLookFrame = CGRect(
            x: clusterMinX + (clusterMaxX - clusterMinX - lookSize) / 2,
            y: clusterMinY - stackGap - lookSize,
            width: lookSize,
            height: lookSize
        )
        previewControls["touchLook"]?.frame = previewFrame(defaultLookFrame, keyPrefix: "touchLook", in: rect, scale: scale)

        for control in previewControls.values {
            control.layer.cornerRadius = min(control.bounds.width, control.bounds.height) / 2
        }
    }

    func makePositionSlider(forKey key: String) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = -240
        slider.maximumValue = 240
        slider.value = Float(defaults.double(forKey: key, defaultValue: 0.0))
        slider.addTarget(self, action: #selector(touchSettingsChanged(_:)), for: .valueChanged)
        positionSliders[key] = slider
        return slider
    }

    func makePositionValueLabel(forKey key: String) -> UILabel {
        let label = UILabel()
        label.textColor = .red
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .right
        label.widthAnchor.constraint(equalToConstant: 56).isActive = true
        positionValueLabels[key] = label
        return label
    }

    func makeResetPositionsButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("RESET POSITIONS", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.addTarget(self, action: #selector(resetTouchPositions), for: .touchUpInside)
        return button
    }

    @objc func touchSettingsChanged(_ sender: UISlider) {
        updateTouchLabels()
        saveTouchSettings()
    }

    @objc func dragPreviewControl(_ recognizer: UIPanGestureRecognizer) {
        guard let control = recognizer.view,
              let keyPrefix = control.accessibilityIdentifier else {
            return
        }

        switch recognizer.state {
        case .began:
            dragStartOffsets[keyPrefix] = positionOffset(for: keyPrefix)
        case .changed, .ended:
            let start = dragStartOffsets[keyPrefix] ?? positionOffset(for: keyPrefix)
            let translation = recognizer.translation(in: layoutPreviewView)
            let scale = previewScale()
            setPositionOffset(
                CGPoint(
                    x: start.x + translation.x / scale,
                    y: start.y + translation.y / scale
                ),
                for: keyPrefix
            )
            updateTouchLabels()
            saveTouchSettings()
        default:
            break
        }
    }

    @objc func resetTouchPositions() {
        for slider in positionSliders.values {
            slider.value = 0
        }
        updateTouchLabels()
        saveTouchSettings()
    }

    func updateTouchLabels() {
        moveValueLabel.text = String(format: "%.2f", moveSlider.value)
        lookValueLabel.text = String(format: "%.2f", lookSlider.value)

        for (key, label) in positionValueLabels {
            let value = positionSliders[key]?.value ?? 0
            label.text = String(format: "%.0f", value)
        }

        updatePreviewLayout()
    }

    func saveTouchSettings() {
        defaults.set(Double(moveSlider.value), forKey: moveSensitivityKey)
        defaults.set(Double(lookSlider.value), forKey: lookSensitivityKey)
        for (key, slider) in positionSliders {
            defaults.set(Double(slider.value), forKey: key)
        }

        if Sys_IsIOSMainLoopPaused().rawValue != 0 {
            CL_ExecuteConsole("seta touch_move_sensitivity \(moveSlider.value); seta touch_look_sensitivity \(lookSlider.value)\n")
        }
        NotificationCenter.default.post(name: .quakeTouchControlsChanged, object: nil)
    }
}

private extension UserDefaults {
    func double(forKey key: String, defaultValue: Double) -> Double {
        if object(forKey: key) == nil {
            return defaultValue
        }
        return double(forKey: key)
    }
}
