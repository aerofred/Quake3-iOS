//
//  GamepadConfigViewController.swift
//  Quake3-iOS
//

import UIKit

final class GamepadConfigViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case settings
        case movement
        case looking
        case weapons
        case misc

        var title: String? {
            switch self {
            case .settings: return "Settings"
            case .movement: return GamepadActionSection.movement.rawValue
            case .looking: return GamepadActionSection.looking.rawValue
            case .weapons: return GamepadActionSection.weapons.rawValue
            case .misc: return GamepadActionSection.misc.rawValue
            }
        }

        var gamepadSection: GamepadActionSection? {
            switch self {
            case .movement: return .movement
            case .looking: return .looking
            case .weapons: return .weapons
            case .misc: return .misc
            default: return nil
            }
        }
    }

    private enum SettingsRow: Int, CaseIterable {
        case sensitivity
        case deadZone
        case reset
    }

    private let config = GamepadConfig.shared
    private let capture = GamepadCapture()
    private let backButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let captureBanner = UILabel()
    private var bannerHeightConstraint: NSLayoutConstraint?

    private var waitingForCommand: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gamepad"
        view.backgroundColor = .groupTableViewBackground

        configureBackButton()
        configureBanner()
        configureTableView()
        configureCapture()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FrontendUI.activate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            cancelCapture()
            if Sys_IsIOSMainLoopPaused().rawValue != 0 {
                config.applyToRunningEngine()
            }
        }
    }

    private func configureBackButton() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setTitle("BACK", for: .normal)
        backButton.setTitleColor(.red, for: .normal)
        backButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 28) ?? .boldSystemFont(ofSize: 28)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        view.addSubview(backButton)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20)
        ])
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    private func configureBanner() {
        captureBanner.translatesAutoresizingMaskIntoConstraints = false
        captureBanner.textAlignment = .center
        captureBanner.numberOfLines = 0
        captureBanner.font = .boldSystemFont(ofSize: 15)
        captureBanner.textColor = .orange
        captureBanner.backgroundColor = UIColor.orange.withAlphaComponent(0.12)
        captureBanner.isHidden = true
        captureBanner.layer.cornerRadius = 8
        captureBanner.clipsToBounds = true

        view.addSubview(captureBanner)
        let heightConstraint = captureBanner.heightAnchor.constraint(equalToConstant: 0)
        bannerHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            captureBanner.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            captureBanner.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            captureBanner.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            heightConstraint
        ])
    }

    private func updateBannerLayout(visible: Bool, text: String? = nil) {
        if let text {
            captureBanner.text = text
        }
        captureBanner.isHidden = !visible
        guard let bannerHeightConstraint else { return }
        if visible {
            let width = view.bounds.width - 32
            let targetWidth = max(200, width)
            let height = captureBanner.sizeThatFits(CGSize(width: targetWidth, height: .greatestFiniteMagnitude)).height
            bannerHeightConstraint.constant = max(36, height + 16)
        } else {
            bannerHeightConstraint.constant = 0
        }
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .onDrag
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: captureBanner.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureCapture() {
        capture.onInputCaptured = { [weak self] input in
            guard let self, let command = self.waitingForCommand else { return }
            self.config.setBinding(input: input, command: command)
            self.cancelCapture()
            self.tableView.reloadData()
        }
    }

    private func actions(for section: Section) -> [GamepadAction] {
        guard let gamepadSection = section.gamepadSection else { return [] }
        return GamepadConfig.allActions.filter { $0.section == gamepadSection }
    }

    private func beginCapture(for command: String, label: String) {
        waitingForCommand = command
        capture.start()
        updateBannerLayout(
            visible: true,
            text: "Press a gamepad button or move a stick for \"\(label)\""
        )
        tableView.reloadData()
    }

    private func cancelCapture() {
        waitingForCommand = nil
        capture.stop()
        updateBannerLayout(visible: false)
        tableView.reloadData()
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        if sender.tag == SettingsRow.sensitivity.rawValue {
            config.sensitivity = sender.value
        } else if sender.tag == SettingsRow.deadZone.rawValue {
            config.deadZone = sender.value
        }
        tableView.reloadRows(at: [IndexPath(row: sender.tag, section: Section.settings.rawValue)], with: .none)
    }

    @objc private func resetDefaults() {
        let alert = UIAlertController(
            title: "Reset Gamepad",
            message: "Restore default button and stick mappings?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive) { [weak self] _ in
            self?.cancelCapture()
            self?.config.resetToDefaults()
            self?.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func presentActionSheet(for action: GamepadAction, indexPath: IndexPath) {
        let sheet = UIAlertController(title: action.label, message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Press to Bind", style: .default) { [weak self] _ in
            self?.beginCapture(for: action.command, label: action.label)
        })

        sheet.addAction(UIAlertAction(title: "Clear Binding", style: .destructive) { [weak self] _ in
            self?.config.clearBinding(for: action.command)
            self?.tableView.reloadRows(at: [indexPath], with: .automatic)
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.cancelCapture()
        })

        if let popover = sheet.popoverPresentationController,
           let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }

        present(sheet, animated: true)
    }

    private func makeSliderCell(
        title: String,
        value: Float,
        minimum: Float,
        maximum: Float,
        tag: Int
    ) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16)

        let valueLabel = UILabel()
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.text = tag == SettingsRow.sensitivity.rawValue
            ? String(format: "%.1f", value)
            : String(format: "%.2f", value)
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let labelRow = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        labelRow.axis = .horizontal
        labelRow.spacing = 8

        let slider = UISlider()
        slider.minimumValue = minimum
        slider.maximumValue = maximum
        slider.value = value
        slider.tag = tag
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)

        let stack = UIStackView(arrangedSubviews: [labelRow, slider])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        cell.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])

        return cell
    }
}

extension GamepadConfigViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section)?.title
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .settings:
            return SettingsRow.allCases.count
        default:
            return actions(for: section).count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        switch section {
        case .settings:
            switch SettingsRow(rawValue: indexPath.row) {
            case .sensitivity:
                return makeSliderCell(
                    title: "Look Sensitivity",
                    value: config.sensitivity,
                    minimum: 1,
                    maximum: 20,
                    tag: SettingsRow.sensitivity.rawValue
                )
            case .deadZone:
                return makeSliderCell(
                    title: "Stick Dead Zone",
                    value: config.deadZone,
                    minimum: 0.05,
                    maximum: 0.5,
                    tag: SettingsRow.deadZone.rawValue
                )
            case .reset:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = "Reset to Defaults"
                cell.textLabel?.textColor = .red
                cell.textLabel?.textAlignment = .center
                return cell
            case .none:
                return UITableViewCell()
            }

        default:
            let action = actions(for: section)[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: "GamepadBindingCell")
                ?? UITableViewCell(style: .value1, reuseIdentifier: "GamepadBindingCell")

            cell.textLabel?.text = action.label
            cell.detailTextLabel?.text = config.displayName(for: config.input(for: action.command))
            cell.detailTextLabel?.textColor = .gray
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default

            if waitingForCommand == action.command {
                cell.backgroundColor = UIColor.orange.withAlphaComponent(0.15)
            } else {
                cell.backgroundColor = nil
            }

            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = Section(rawValue: indexPath.section) else { return }

        if section == .settings, SettingsRow(rawValue: indexPath.row) == .reset {
            resetDefaults()
            return
        }

        guard section != .settings else { return }

        let action = actions(for: section)[indexPath.row]
        presentActionSheet(for: action, indexPath: indexPath)
    }
}
