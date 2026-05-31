//
//  GamepadConfigViewController.swift
//  Quake3-iOS
//

import UIKit

final class GamepadConfigViewController: UIViewController {
    private let config = GamepadConfig.shared
    private let capture = GamepadCapture()
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let captureBanner = UILabel()
    private let sensitivitySlider = UISlider()
    private let deadZoneSlider = UISlider()
    private let sensitivityValueLabel = UILabel()
    private let deadZoneValueLabel = UILabel()

    private var waitingForCommand: String?
    private var sections: [GamepadActionSection] = GamepadActionSection.allCases

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Gamepad"
        view.backgroundColor = .groupTableViewBackground
        configureTableView()
        configureCapture()
        updateCaptureBanner()
        updateSliderLabels()
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

    private func configureHeader() -> UIView {
        let sensitivityTitle = makeSectionLabel("Look Sensitivity")
        configureSlider(
            sensitivitySlider,
            min: 1,
            max: 20,
            value: config.sensitivity,
            action: #selector(sliderChanged(_:))
        )

        let deadZoneTitle = makeSectionLabel("Stick Dead Zone")
        configureSlider(
            deadZoneSlider,
            min: 0.05,
            max: 0.5,
            value: config.deadZone,
            action: #selector(sliderChanged(_:))
        )

        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset to Defaults", for: .normal)
        resetButton.setTitleColor(.red, for: .normal)
        resetButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        resetButton.addTarget(self, action: #selector(resetDefaults), for: .touchUpInside)

        captureBanner.textAlignment = .center
        captureBanner.numberOfLines = 0
        captureBanner.font = .boldSystemFont(ofSize: 16)
        captureBanner.textColor = .orange
        captureBanner.isHidden = true

        let headerStack = UIStackView(arrangedSubviews: [
            captureBanner,
            sensitivityTitle,
            makeSliderRow(title: "Sensitivity", slider: sensitivitySlider, valueLabel: sensitivityValueLabel),
            deadZoneTitle,
            makeSliderRow(title: "Dead Zone", slider: deadZoneSlider, valueLabel: deadZoneValueLabel),
            resetButton
        ])
        headerStack.axis = .vertical
        headerStack.spacing = 10
        headerStack.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        headerStack.isLayoutMarginsRelativeArrangement = true
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.addSubview(headerStack)
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: container.topAnchor),
            headerStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            headerStack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            headerStack.widthAnchor.constraint(equalTo: container.widthAnchor)
        ])
        return container
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        let header = configureHeader()
        header.layoutIfNeeded()
        let targetWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let headerHeight = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        header.frame = CGRect(x: 0, y: 0, width: targetWidth, height: headerHeight)
        tableView.tableHeaderView = header

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        let targetWidth = tableView.bounds.width
        guard targetWidth > 0 else { return }
        let height = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        if header.frame.height != height || header.frame.width != targetWidth {
            header.frame = CGRect(x: 0, y: 0, width: targetWidth, height: height)
            tableView.tableHeaderView = header
        }
    }

    private func configureCapture() {
        capture.onInputCaptured = { [weak self] input in
            guard let self, let command = self.waitingForCommand else { return }
            self.config.setBinding(input: input, command: command)
            self.cancelCapture()
            self.tableView.reloadData()
        }
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .boldSystemFont(ofSize: 20)
        return label
    }

    private func configureSlider(_ slider: UISlider, min: Float, max: Float, value: Float, action: Selector) {
        slider.minimumValue = min
        slider.maximumValue = max
        slider.value = value
        slider.addTarget(self, action: action, for: .valueChanged)
    }

    private func makeSliderRow(title: String, slider: UISlider, valueLabel: UILabel) -> UIStackView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15)

        valueLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        valueLabel.textAlignment = .right
        valueLabel.widthAnchor.constraint(equalToConstant: 48).isActive = true

        let top = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        top.axis = .horizontal

        let row = UIStackView(arrangedSubviews: [top, slider])
        row.axis = .vertical
        row.spacing = 4
        return row
    }

    private func actions(for section: GamepadActionSection) -> [GamepadAction] {
        GamepadConfig.allActions.filter { $0.section == section }
    }

    private func beginCapture(for command: String, label: String) {
        waitingForCommand = command
        capture.start()
        captureBanner.isHidden = false
        captureBanner.text = "Press a gamepad button or move a stick for \"\(label)\""
    }

    private func cancelCapture() {
        waitingForCommand = nil
        capture.stop()
        captureBanner.isHidden = true
        captureBanner.text = nil
    }

    private func updateCaptureBanner() {
        captureBanner.isHidden = waitingForCommand == nil
    }

    private func updateSliderLabels() {
        sensitivityValueLabel.text = String(format: "%.1f", sensitivitySlider.value)
        deadZoneValueLabel.text = String(format: "%.2f", deadZoneSlider.value)
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        config.sensitivity = sensitivitySlider.value
        config.deadZone = deadZoneSlider.value
        updateSliderLabels()
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
            self?.sensitivitySlider.value = self?.config.sensitivity ?? 10
            self?.deadZoneSlider.value = self?.config.deadZone ?? 0.15
            self?.updateSliderLabels()
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

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = tableView
            popover.sourceRect = tableView.rectForRow(at: indexPath)
        }

        present(sheet, animated: true)
    }
}

extension GamepadConfigViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].rawValue
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        actions(for: sections[section]).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let action = actions(for: sections[indexPath.section])[indexPath.row]
        let identifier = "GamepadCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .value1, reuseIdentifier: identifier)

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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let action = actions(for: sections[indexPath.section])[indexPath.row]
        presentActionSheet(for: action, indexPath: indexPath)
    }
}
