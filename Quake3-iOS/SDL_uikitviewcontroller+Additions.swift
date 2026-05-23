//
//  SDL2ViewController+Additions.swift
//  Quake2-iOS
//
//  Created by Tom Kidd on 1/28/19.
//

import UIKit

fileprivate final class PauseMenuViewController: UIViewController {
    weak var gameController: SDL_uikitviewcontroller?

    private let gridStack = UIStackView()
    private var buttonTargets: [PauseMenuButtonTarget] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        view.isUserInteractionEnabled = true

        let title = UILabel()
        title.text = "PAUSE"
        title.textColor = .white
        title.font = UIFont.boldSystemFont(ofSize: 20)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        gridStack.axis = .vertical
        gridStack.spacing = 6
        gridStack.distribution = .fillEqually
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(gridStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            title.heightAnchor.constraint(equalToConstant: 28),

            gridStack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 6),
            gridStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            gridStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            gridStack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -6)
        ])

        rebuildButtons()
    }

    override var prefersStatusBarHidden: Bool { true }

    func rebuildButtons() {
        for row in gridStack.arrangedSubviews {
            gridStack.removeArrangedSubview(row)
            row.removeFromSuperview()
        }
        buttonTargets.removeAll()

        struct MenuItem {
            let title: String
            let action: () -> Void
        }

        var items: [MenuItem] = [
            MenuItem(title: "Reprendre", action: { [weak self] in self?.gameController?.pauseResumeTapped() }),
            MenuItem(title: "Équipe", action: { [weak self] in self?.gameController?.pauseTeamTapped() })
        ]
        if CL_CanManageBots() != 0 {
            items.append(MenuItem(title: "Ajouter bot", action: { [weak self] in self?.gameController?.pauseAddBotTapped() }))
            items.append(MenuItem(title: "Retirer bot", action: { [weak self] in self?.gameController?.pauseRemoveBotTapped() }))
        }
        if CL_CanUseTeamOrders() != 0 {
            items.append(MenuItem(title: "Ordres équipe", action: { [weak self] in self?.gameController?.pauseTeamOrdersTapped() }))
        }
        items.append(contentsOf: [
            MenuItem(title: "Réglages", action: { [weak self] in self?.gameController?.pauseSetupTapped() }),
            MenuItem(title: "Infos serveur", action: { [weak self] in self?.gameController?.pauseServerInfoTapped() }),
            MenuItem(title: "Redémarrer", action: { [weak self] in self?.gameController?.pauseRestartTapped() }),
            MenuItem(title: "Quitter arène", action: { [weak self] in self?.gameController?.pauseLeaveTapped() }),
            MenuItem(title: "Quitter jeu", action: { [weak self] in self?.gameController?.pauseExitGameTapped() })
        ])

        let columns = 2
        var rowStack: UIStackView?
        for (index, item) in items.enumerated() {
            if index % columns == 0 {
                rowStack = UIStackView()
                rowStack?.axis = .horizontal
                rowStack?.spacing = 6
                rowStack?.distribution = .fillEqually
                gridStack.addArrangedSubview(rowStack!)
            }
            let target = PauseMenuButtonTarget(item.action)
            buttonTargets.append(target)
            rowStack?.addArrangedSubview(makeButton(title: item.title, target: target))
        }
        if items.count % columns == 1 {
            rowStack?.addArrangedSubview(UIView())
        }
    }

    private func makeButton(title: String, target: PauseMenuButtonTarget) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 8
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 6, bottom: 4, right: 6)
        button.isUserInteractionEnabled = true
        button.addTarget(target, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    @objc private func buttonTouchDown(_ sender: UIButton) {
        sender.backgroundColor = UIColor.white.withAlphaComponent(0.28)
    }

    @objc private func buttonTouchUp(_ sender: UIButton) {
        sender.backgroundColor = UIColor.white.withAlphaComponent(0.12)
    }
}

fileprivate final class PauseMenuButtonTarget: NSObject {
    let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func tapped() {
        action()
    }
}

fileprivate final class PauseBotPickerViewController: UIViewController {
    struct PendingBot {
        let name: String
        let skill: Float
    }

    var onCancelled: (() -> Void)?
    var onBotsConfirmed: (([PendingBot]) -> Void)?

    private let bots: [BotCatalog.Bot]
    private let bundleResourcePath: String
    private let documentsDir: String
    private let scrollView = UIScrollView()
    private let gridStack = UIStackView()
    private let quantityLabel = UILabel()
    private let okButton = UIButton(type: .system)
    private var buttonTargets: [PauseMenuButtonTarget] = []
    private var selectedBot: BotCatalog.Bot?
    private var skill: Float = 3
    private var quantity = 1
    private var skillButtons: [UIButton] = []
    private var botButtons: [UIButton] = []

    init(bots: [BotCatalog.Bot], bundleResourcePath: String, documentsDir: String) {
        self.bots = bots
        self.bundleResourcePath = bundleResourcePath
        self.documentsDir = documentsDir
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        view.isUserInteractionEnabled = true

        let title = UILabel()
        title.text = "AJOUTER BOT"
        title.textColor = .white
        title.font = UIFont.boldSystemFont(ofSize: 20)
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true

        gridStack.axis = .vertical
        gridStack.spacing = 8
        gridStack.translatesAutoresizingMaskIntoConstraints = false

        let controls = makeControls()
        controls.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(title)
        view.addSubview(scrollView)
        view.addSubview(controls)
        scrollView.addSubview(gridStack)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: guide.topAnchor, constant: 8),
            title.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            title.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            title.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: controls.topAnchor, constant: -8),

            gridStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            gridStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            gridStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            gridStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            gridStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            controls.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 12),
            controls.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            controls.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            controls.heightAnchor.constraint(equalToConstant: 96)
        ])

        buildBotButtons()
        updateSelectionUI()
        updateSkillUI()
        updateQuantityUI()
    }

    private func buildBotButtons() {
        let columns = 4
        var row: UIStackView?

        for (index, bot) in bots.enumerated() {
            if index % columns == 0 {
                row = UIStackView()
                row?.axis = .horizontal
                row?.spacing = 8
                row?.distribution = .fillEqually
                gridStack.addArrangedSubview(row!)
            }

            let button = makeBotButton(bot)
            botButtons.append(button)
            let target = PauseMenuButtonTarget { [weak self] in
                self?.selectedBot = bot
                self?.updateSelectionUI()
            }
            buttonTargets.append(target)
            button.addTarget(target, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)
            row?.addArrangedSubview(button)
        }

        if let row, bots.count % columns != 0 {
            for _ in 0..<(columns - bots.count % columns) {
                row.addArrangedSubview(UIView())
            }
        }
    }

    private func makeBotButton(_ bot: BotCatalog.Bot) -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        button.layer.borderWidth = 1
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 92).isActive = true

        button.setTitle(bot.name, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setImage(
            BotCatalog.loadIconImage(
                for: bot,
                bundleResourcePath: bundleResourcePath,
                documentsDir: documentsDir
            ),
            for: .normal
        )
        button.imageView?.contentMode = .scaleAspectFit
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 4, bottom: 4, right: 4)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 24, right: 18)
        button.titleEdgeInsets = UIEdgeInsets(top: 58, left: -54, bottom: 0, right: 0)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.6
        return button
    }

    private func makeControls() -> UIStackView {
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 8
        root.distribution = .fillEqually

        let skillRow = UIStackView()
        skillRow.axis = .horizontal
        skillRow.spacing = 6
        skillRow.distribution = .fillEqually
        for value in 1...5 {
            let button = makeControlButton(title: "\(value)")
            let target = PauseMenuButtonTarget { [weak self] in
                self?.skill = Float(value)
                self?.updateSkillUI()
            }
            buttonTargets.append(target)
            button.addTarget(target, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)
            skillButtons.append(button)
            skillRow.addArrangedSubview(button)
        }

        let actionRow = UIStackView()
        actionRow.axis = .horizontal
        actionRow.spacing = 8
        actionRow.distribution = .fill

        let cancel = makeControlButton(title: "Annuler")
        let cancelTarget = PauseMenuButtonTarget { [weak self] in
            self?.dismiss(animated: false) {
                self?.onCancelled?()
            }
        }
        buttonTargets.append(cancelTarget)
        cancel.addTarget(cancelTarget, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)

        let minus = makeControlButton(title: "-")
        let minusTarget = PauseMenuButtonTarget { [weak self] in
            guard let self else { return }
            self.quantity = max(1, self.quantity - 1)
            self.updateQuantityUI()
        }
        buttonTargets.append(minusTarget)
        minus.addTarget(minusTarget, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)

        quantityLabel.textColor = .white
        quantityLabel.textAlignment = .center
        quantityLabel.font = UIFont.boldSystemFont(ofSize: 18)
        quantityLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let plus = makeControlButton(title: "+")
        let plusTarget = PauseMenuButtonTarget { [weak self] in
            guard let self else { return }
            self.quantity += 1
            self.updateQuantityUI()
        }
        buttonTargets.append(plusTarget)
        plus.addTarget(plusTarget, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)

        okButton.setTitle("OK", for: .normal)
        styleControlButton(okButton)
        let okTarget = PauseMenuButtonTarget { [weak self] in
            self?.confirm()
        }
        buttonTargets.append(okTarget)
        okButton.addTarget(okTarget, action: #selector(PauseMenuButtonTarget.tapped), for: .touchUpInside)

        actionRow.addArrangedSubview(cancel)
        actionRow.addArrangedSubview(minus)
        actionRow.addArrangedSubview(quantityLabel)
        actionRow.addArrangedSubview(plus)
        actionRow.addArrangedSubview(okButton)

        root.addArrangedSubview(skillRow)
        root.addArrangedSubview(actionRow)
        return root
    }

    private func makeControlButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        styleControlButton(button)
        return button
    }

    private func styleControlButton(_ button: UIButton) {
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.65
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 8
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor
        button.layer.borderWidth = 1
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
    }

    private func updateSelectionUI() {
        okButton.isEnabled = selectedBot != nil
        okButton.alpha = selectedBot == nil ? 0.45 : 1.0

        for (index, button) in botButtons.enumerated() {
            let selected = bots[index] == selectedBot
            button.backgroundColor = selected ? UIColor.red.withAlphaComponent(0.35) : UIColor.white.withAlphaComponent(0.10)
            button.layer.borderColor = selected ? UIColor.red.cgColor : UIColor.white.withAlphaComponent(0.20).cgColor
            button.layer.borderWidth = selected ? 2 : 1
        }
    }

    private func updateSkillUI() {
        for (index, button) in skillButtons.enumerated() {
            let selected = Int(skill) == index + 1
            button.backgroundColor = selected ? UIColor.red.withAlphaComponent(0.35) : UIColor.white.withAlphaComponent(0.12)
            button.layer.borderColor = selected ? UIColor.red.cgColor : UIColor.white.withAlphaComponent(0.20).cgColor
        }
    }

    private func updateQuantityUI() {
        quantityLabel.text = "\(quantity)"
    }

    private func confirm() {
        guard let selectedBot else { return }
        var pending: [PendingBot] = []
        pending.reserveCapacity(quantity)
        for _ in 0..<quantity {
            pending.append(PendingBot(name: selectedBot.name, skill: skill))
        }
        dismiss(animated: false) { [weak self] in
            self?.onBotsConfirmed?(pending)
        }
    }
}

/// Fenêtre UIKit du menu (AppDelegate) au-dessus du rendu SDL pour les écrans storyboard in-game.
fileprivate enum InGameNativeUI {
    private static var savedSDLWindowLevel = UIWindow.Level.normal
    private static weak var sdlWindow: UIWindow?
    private static var overlayWindow: UIWindow?
    private static var overlayRootViewController: UIViewController?
    static var isActive = false

    static func appDelegate() -> AppDelegate? {
        UIApplication.shared.delegate as? AppDelegate
    }

    static func topViewController(from root: UIViewController) -> UIViewController {
        var top = root
        if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
            top = visible
        }
        while let presented = top.presentedViewController {
            top = presented
            if let nav = top as? UINavigationController, let visible = nav.visibleViewController {
                top = visible
            }
        }
        return top
    }

    static func presenter() -> UIViewController? {
        if let overlayRootViewController {
            return topViewController(from: overlayRootViewController)
        }
        guard let app = appDelegate() else { return nil }
        return topViewController(from: app.rootNavigationController)
    }

    static func activate(sdlGameWindow: UIWindow?) {
        if !isActive {
            if let sdlGameWindow = sdlGameWindow {
                savedSDLWindowLevel = sdlGameWindow.windowLevel
                sdlWindow = sdlGameWindow
            }
        }
        isActive = true

        let root = UIViewController()
        root.view.backgroundColor = .clear
        root.view.isUserInteractionEnabled = true
        root.modalPresentationStyle = .fullScreen
        overlayRootViewController = root

        let window: UIWindow
        if #available(iOS 13.0, *) {
            if let scene = sdlGameWindow?.windowScene
                ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
                ?? UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first {
                window = UIWindow(windowScene: scene)
            } else {
                window = UIWindow(frame: UIScreen.main.bounds)
            }
        } else {
            window = UIWindow(frame: UIScreen.main.bounds)
        }

        sdlGameWindow?.isUserInteractionEnabled = false
        window.frame = sdlGameWindow?.bounds ?? UIScreen.main.bounds
        window.rootViewController = root
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true
        window.windowLevel = UIWindow.Level(
            rawValue: max(UIWindow.Level.alert.rawValue, sdlGameWindow?.windowLevel.rawValue ?? UIWindow.Level.normal.rawValue) + 1
        )
        window.makeKeyAndVisible()
        overlayWindow = window
    }

    static func deactivate() {
        guard isActive else { return }

        isActive = false
        overlayRootViewController?.dismiss(animated: false)
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayRootViewController = nil
        overlayWindow = nil

        sdlWindow?.isUserInteractionEnabled = true
        sdlWindow?.windowLevel = savedSDLWindowLevel
        sdlWindow?.makeKeyAndVisible()
        sdlWindow = nil
    }

    static func present(
        _ viewController: UIViewController,
        from sdlGameWindow: UIWindow?,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        activate(sdlGameWindow: sdlGameWindow)
        presenter()?.present(viewController, animated: animated, completion: completion)
    }
}

extension Notification.Name {
    static let quakeReturnToMainMenu = Notification.Name("QuakeReturnToMainMenu")
}

extension SDL_uikitviewcontroller {
    
    // A method of getting around the fact that Swift extensions cannot have stored properties
    // https://medium.com/@valv0/computed-properties-and-extensions-a-pure-swift-approach-64733768112c
    struct Holder {
        static var _fireButton = UIButton()
        static var _jumpButton = UIButton()
        static var _joystickView = JoyStickView(frame: .zero)
        static var _tildeButton = UIButton()
        static var _expandButton = UIButton()
        static var _escapeButton = UIButton()
        static var _buttonStack = UIStackView(frame: .zero)
        static var _buttonStackExpanded = false
        static var _f1Button = UIButton()
        static var _prevWeaponButton = UIButton()
        static var _nextWeaponButton = UIButton()
        static var _lookButton = LookTouchPad(frame: .zero)
        static var _controlsInstalled = false
        fileprivate static weak var _pauseMenuViewController: PauseMenuViewController?
        static weak var _pauseMenuGameController: SDL_uikitviewcontroller?
        static var _pauseMenuShowing = false
    }
    
    var fireButton:UIButton {
        get {
            return Holder._fireButton
        }
        set(newValue) {
            Holder._fireButton = newValue
        }
    }
    
    var jumpButton:UIButton {
        get {
            return Holder._jumpButton
        }
        set(newValue) {
            Holder._jumpButton = newValue
        }
    }
    
    var joystickView:JoyStickView {
        get {
            return Holder._joystickView
        }
        set(newValue) {
            Holder._joystickView = newValue
        }
    }

    var tildeButton:UIButton {
        get {
            return Holder._tildeButton
        }
        set(newValue) {
            Holder._tildeButton = newValue
        }
    }

    var escapeButton:UIButton {
        get {
            return Holder._escapeButton
        }
        set(newValue) {
            Holder._escapeButton = newValue
        }
    }

    var expandButton:UIButton {
        get {
            return Holder._expandButton
        }
        set(newValue) {
            Holder._expandButton = newValue
        }
    }
    
    var buttonStack:UIStackView {
        get {
            return Holder._buttonStack
        }
        set(newValue) {
            Holder._buttonStack = newValue
        }
    }

    var buttonStackExpanded:Bool {
        get {
            return Holder._buttonStackExpanded
        }
        set(newValue) {
            Holder._buttonStackExpanded = newValue
        }
    }
    
    var f1Button:UIButton {
        get {
            return Holder._f1Button
        }
        set(newValue) {
            Holder._f1Button = newValue
        }
    }
    
    var prevWeaponButton:UIButton {
        get {
            return Holder._prevWeaponButton
        }
        set(newValue) {
            Holder._prevWeaponButton = newValue
        }
    }

    var nextWeaponButton:UIButton {
        get {
            return Holder._nextWeaponButton
        }
        set(newValue) {
            Holder._nextWeaponButton = newValue
        }
    }

    var lookButton: LookTouchPad {
        get { Holder._lookButton }
        set { Holder._lookButton = newValue }
    }

    private func styleOverlayButton(_ button: UIButton, title: String, fontSize: CGFloat = 13) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: fontSize)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 6
        button.alpha = 0.75
    }

    @objc func installOnScreenControls() {
        guard view.window != nil else { return }
        guard view.bounds.width > 64, view.bounds.height > 64 else { return }
        updateSafeAreaInsetsForEngine()

        if !Holder._controlsInstalled {
            Holder._controlsInstalled = true
            createOnScreenControlViews()
            applyTouchJoystickCvars()
        }

        layoutOnScreenControls(in: view.bounds)
    }

    private func applyTouchJoystickCvars() {
        CL_ExecuteConsole(
            "j_yaw_axis 0; j_side_axis 4; j_side 0; j_forward_axis 1; j_forward -2; j_yaw 1; cl_run 1; sensitivity 10\n"
        )
    }

    private func createOnScreenControlViews() {
        let rect = view.bounds

        fireButton = UIButton(frame: CGRect(x: rect.width - 155, y: rect.height - 90, width: 75, height: 75))
        fireButton.setTitle("FIRE", for: .normal)
        fireButton.setBackgroundImage(UIImage(named: "JoyStickBase"), for: .normal)
        fireButton.addTarget(self, action: #selector(self.firePressed), for: .touchDown)
        fireButton.addTarget(self, action: #selector(self.fireReleased), for: .touchUpInside)
        fireButton.alpha = 0.5

        jumpButton = UIButton(frame: CGRect(x: rect.width - 90, y: rect.height - 135, width: 75, height: 75))
        jumpButton.setTitle("JUMP", for: .normal)
        jumpButton.setBackgroundImage(UIImage(named: "JoyStickBase"), for: .normal)
        jumpButton.addTarget(self, action: #selector(self.jumpPressed), for: .touchDown)
        jumpButton.addTarget(self, action: #selector(self.jumpReleased), for: .touchUpInside)
        jumpButton.alpha = 0.5

        lookButton = LookTouchPad(frame: CGRect(x: rect.width - 70, y: rect.height - 70, width: 62, height: 62))
        lookButton.onLookDelta = { dx, dy in
            let t = Int32(Sys_Milliseconds())
            CL_MouseEvent(Int32(dx * 16.0), Int32(dy * 16.0), t, qboolean(0))
        }

        let joySize = CGSize(width: 100, height: 100)
        joystickView = JoyStickView(frame: CGRect(
            x: 50,
            y: rect.height - joySize.height - 50,
            width: joySize.width,
            height: joySize.height
        ))
        joystickView.delegate = self
        joystickView.movable = false
        joystickView.alpha = 0.5
        joystickView.baseAlpha = 0.5
        joystickView.handleTintColor = .darkGray

        escapeButton = UIButton(type: .custom)
        styleOverlayButton(escapeButton, title: "ESC")
        escapeButton.addTarget(self, action: #selector(self.escapePressed), for: .touchDown)
        escapeButton.addTarget(self, action: #selector(self.escapeReleased), for: .touchUpInside)
        escapeButton.isHidden = false

        f1Button = UIButton(frame: CGRect(x: rect.width - 40, y: 10, width: 30, height: 30))
        f1Button.setTitle(" F1 ", for: .normal)
        f1Button.addTarget(self, action: #selector(self.f1Pressed), for: .touchDown)
        f1Button.addTarget(self, action: #selector(self.f1Released), for: .touchUpInside)
        f1Button.layer.borderColor = UIColor.white.cgColor
        f1Button.layer.borderWidth = 1
        f1Button.alpha = 0.5

        prevWeaponButton = UIButton(type: .custom)
        styleOverlayButton(prevWeaponButton, title: "‹", fontSize: 28)
        prevWeaponButton.addTarget(self, action: #selector(self.prevWeaponPressed), for: .touchDown)
        prevWeaponButton.addTarget(self, action: #selector(self.prevWeaponReleased), for: .touchUpInside)

        nextWeaponButton = UIButton(type: .custom)
        styleOverlayButton(nextWeaponButton, title: "›", fontSize: 28)
        nextWeaponButton.addTarget(self, action: #selector(self.nextWeaponPressed), for: .touchDown)
        nextWeaponButton.addTarget(self, action: #selector(self.nextWeaponReleased), for: .touchUpInside)

        view.addSubview(prevWeaponButton)
        view.addSubview(nextWeaponButton)
        view.addSubview(joystickView)
        view.addSubview(fireButton)
        view.addSubview(jumpButton)
        view.addSubview(lookButton)
        view.addSubview(escapeButton)
        view.addSubview(f1Button)

        view.bringSubviewToFront(escapeButton)
        view.bringSubviewToFront(prevWeaponButton)
        view.bringSubviewToFront(nextWeaponButton)
        view.bringSubviewToFront(f1Button)
        view.bringSubviewToFront(lookButton)
    }

    private func updateSafeAreaInsetsForEngine() {
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let insets = view.safeAreaInsets
        Sys_SetSafeAreaInsets(
            Int32((insets.top * scale).rounded()),
            Int32((insets.left * scale).rounded()),
            Int32((insets.bottom * scale).rounded()),
            Int32((insets.right * scale).rounded())
        )
    }

    /// Zone utilisable pour l’UI native (plein écran, hors rendu Q3 4:3).
    private func nativeOverlayRect(in rect: CGRect) -> CGRect {
        let insets = view.safeAreaInsets
        let safeRect = rect.inset(by: insets)
        return safeRect.width > 64 && safeRect.height > 64 ? safeRect : rect
    }

    /// Contrôles tactiles sur tout l’écran ; seul le moteur Q3 reste en 4:3.
    private func layoutOnScreenControls(in rect: CGRect) {
        updateSafeAreaInsetsForEngine()

        let safeRect = nativeOverlayRect(in: rect)
        let joySize = CGSize(width: 100, height: 100)
        let margin: CGFloat = 8
        let controlMargin: CGFloat = 22
        let menuSize = CGSize(width: 52, height: 44)
        let weaponSize = CGSize(width: 48, height: 64)
        let actionSize: CGFloat = 75
        let lookSize: CGFloat = 58
        let stackGap: CGFloat = 10

        joystickView.frame = CGRect(
            x: safeRect.minX + 50,
            y: safeRect.maxY - joySize.height - 50,
            width: joySize.width,
            height: joySize.height
        )

        fireButton.frame = CGRect(
            x: safeRect.maxX - 155,
            y: safeRect.maxY - 90,
            width: actionSize,
            height: actionSize
        )
        jumpButton.frame = CGRect(
            x: safeRect.maxX - 90,
            y: safeRect.maxY - 135,
            width: actionSize,
            height: actionSize
        )

        let clusterMinX = min(fireButton.frame.minX, jumpButton.frame.minX)
        let clusterMaxX = max(fireButton.frame.maxX, jumpButton.frame.maxX)
        let clusterMinY = min(fireButton.frame.minY, jumpButton.frame.minY)
        lookButton.frame = CGRect(
            x: clusterMinX + (clusterMaxX - clusterMinX - lookSize) / 2,
            y: clusterMinY - stackGap - lookSize,
            width: lookSize,
            height: lookSize
        )
        escapeButton.frame = CGRect(
            x: safeRect.minX + controlMargin,
            y: safeRect.minY + controlMargin,
            width: menuSize.width,
            height: menuSize.height
        )
        f1Button.frame = CGRect(
            x: safeRect.maxX - 30 - controlMargin,
            y: safeRect.minY + controlMargin,
            width: 30,
            height: 30
        )
        prevWeaponButton.frame = CGRect(
            x: safeRect.minX + margin,
            y: safeRect.midY - weaponSize.height / 2,
            width: weaponSize.width,
            height: weaponSize.height
        )
        nextWeaponButton.frame = CGRect(
            x: safeRect.maxX - weaponSize.width - margin,
            y: safeRect.midY - weaponSize.height / 2,
            width: weaponSize.width,
            height: weaponSize.height
        )
    }

    // Legacy entry points kept for Objective-C callers.
    @objc func fireButton(rect: CGRect) -> UIButton { fireButton }
    @objc func jumpButton(rect: CGRect) -> UIButton { jumpButton }
    @objc func joyStick(rect: CGRect) -> JoyStickView { joystickView }
    @objc func buttonStack(rect: CGRect) -> UIStackView { buttonStack }
    @objc func f1Button(rect: CGRect) -> UIButton { f1Button }
    @objc func prevWeaponButton(rect: CGRect) -> UIButton { prevWeaponButton }
    @objc func nextWeaponButton(rect: CGRect) -> UIButton { nextWeaponButton }

    
    @objc func firePressed(sender: UIButton!) {
        Key_Event(137, qboolean(1), qboolean(1))
    }
    
    @objc func fireReleased(sender: UIButton!) {
        Key_Event(137, qboolean(0), qboolean(1))
    }
    
    @objc func jumpPressed(sender: UIButton!) {
        Key_Event(32, qboolean(1), qboolean(1))
    }
    
    @objc func jumpReleased(sender: UIButton!) {
        Key_Event(32, qboolean(0), qboolean(1))
    }
    
    @objc func tildePressed(sender: UIButton!) {
//        Key_Event(32, qboolean(1), qboolean(1))
    }
    
    @objc func tildeReleased(sender: UIButton!) {
//        Key_Event(32, qboolean(0), qboolean(1))
    }
    
    @objc func escapePressed(sender: UIButton!) {
        Key_Event(27, qboolean(1), qboolean(1))
    }
    
    @objc func escapeReleased(sender: UIButton!) {
        Key_Event(27, qboolean(0), qboolean(1))
    }
        
    @objc func f1Pressed(sender: UIButton!) {
        Key_Event(145, qboolean(1), qboolean(1))
    }
    
    @objc func f1Released(sender: UIButton!) {
        Key_Event(145, qboolean(0), qboolean(1))
    }
    
    @objc func prevWeaponPressed(sender: UIButton!) {
        Key_Event(183, qboolean(1), qboolean(1))
    }
    
    @objc func prevWeaponReleased(sender: UIButton!) {
        Key_Event(183, qboolean(0), qboolean(1))
    }
    
    @objc func nextWeaponPressed(sender: UIButton!) {
        Key_Event(184, qboolean(1), qboolean(1))
    }
    
    @objc func nextWeaponReleased(sender: UIButton!) {
        Key_Event(184, qboolean(0), qboolean(1))
    }

    
    func Key_Event(_ key: Int32, _ down: qboolean, _ special: qboolean) {
        CL_KeyEvent(key, down, UInt32(Sys_Milliseconds()))
    }

    @objc func setPauseMenuVisible(_ visible: Bool) {
        if visible {
            showPauseOverlay()
        } else {
            hidePauseOverlay()
            InGameNativeUI.deactivate()
        }
        setGameControlsHidden(visible)
    }

    @objc func toggleControls(_ menuOpen: Bool) {
        // Ne pas rappeler showPauseOverlay ici : Sys_ToggleControls tourne chaque frame
        // et remettait le menu pause par-dessus l'écran « Ajouter bot ».
        setGameControlsHidden(menuOpen || CL_IsPauseMenuOpen() != 0)
    }

    private func setGameControlsHidden(_ menuOpen: Bool) {
        fireButton.isHidden = menuOpen
        jumpButton.isHidden = menuOpen
        lookButton.isHidden = menuOpen
        joystickView.isHidden = menuOpen
        prevWeaponButton.isHidden = menuOpen
        nextWeaponButton.isHidden = menuOpen
        escapeButton.isHidden = menuOpen
        f1Button.isHidden = menuOpen

        if menuOpen {
            joystickView.delegate = nil
            resetTouchJoystickAxes()
        } else {
            joystickView.delegate = self
        }
    }

    private func showPauseOverlay() {
        guard !Holder._pauseMenuShowing else { return }
        if presentedViewController is PauseMenuViewController {
            Holder._pauseMenuShowing = true
            return
        }
        guard view.window != nil else {
            DispatchQueue.main.async { [weak self] in
                self?.showPauseOverlay()
            }
            return
        }

        Holder._pauseMenuGameController = self
        Holder._pauseMenuShowing = true

        let pauseVC = PauseMenuViewController()
        pauseVC.gameController = self
        pauseVC.modalPresentationStyle = .overFullScreen
        pauseVC.modalTransitionStyle = .crossDissolve
        Holder._pauseMenuViewController = pauseVC
        present(pauseVC, animated: false)
    }

    /// Retire l’UI du menu pause sans fermer l’état pause moteur (cl_paused / KEYCATCH_UI).
    private func dismissPauseMenuUI(animated: Bool = false, completion: (() -> Void)? = nil) {
        Holder._pauseMenuShowing = false
        Holder._pauseMenuViewController = nil

        guard let presented = presentedViewController else {
            completion?()
            return
        }

        if let pauseVC = presented as? PauseMenuViewController {
            if pauseVC.presentedViewController != nil {
                pauseVC.dismiss(animated: false)
            }
            dismiss(animated: animated, completion: completion)
        } else {
            completion?()
        }
    }

    private func hidePauseOverlay() {
        dismissPauseMenuUI()
    }

    private func restorePausePanelIfNeeded() {
        guard CL_IsPauseMenuOpen() != 0 else { return }
        if presentedViewController is PauseMenuViewController {
            return
        }
        InGameNativeUI.deactivate()
        Holder._pauseMenuShowing = false
        showPauseOverlay()
    }

    private func finishPauseMenuSubflow() {
        restorePausePanelIfNeeded()
    }

    private func pauseAlertPresenter() -> UIViewController {
        if InGameNativeUI.isActive, let native = InGameNativeUI.presenter() {
            var top = native
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }
        if let pauseVC = Holder._pauseMenuViewController {
            var top: UIViewController = pauseVC
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }
        if let pauseVC = presentedViewController as? PauseMenuViewController {
            var top: UIViewController = pauseVC
            while let presented = top.presentedViewController {
                top = presented
            }
            return top
        }
        var top: UIViewController = self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }

    private func presentPauseActionSheet(_ alert: UIAlertController) {
        if alert.actions.first(where: { $0.style == .cancel }) == nil {
            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
                self?.restorePausePanelIfNeeded()
            })
        }
        let presenter = pauseAlertPresenter()
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        presenter.present(alert, animated: true)
    }

    private func presentPauseConfirmation(
        title: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { _ in
            onConfirm()
        })
        pauseAlertPresenter().present(alert, animated: true)
    }

    private func quakeConsole(_ command: String) {
        var text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.hasSuffix("\n") {
            text += "\n"
        }
        CL_ExecuteConsole(text)
    }

    private func isTeamGametype() -> Bool {
        CL_GetCvarInt("g_gametype") >= 3
    }

    private func makeBotPickerViewController() -> PauseBotPickerViewController? {
        guard let resourcePath = Bundle.main.resourcePath else { return nil }
        #if os(tvOS)
        let documentsDir = (try? FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path) ?? ""
        #else
        let documentsDir = (try? FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path) ?? ""
        #endif
        let bots = BotCatalog.availableBots(bundleResourcePath: resourcePath)
        guard !bots.isEmpty else { return nil }
        return PauseBotPickerViewController(bots: bots, bundleResourcePath: resourcePath, documentsDir: documentsDir)
    }

    private func executeAddBotsViaConsole(_ bots: [PauseBotPickerViewController.PendingBot], team: String) {
        var delay = 1000
        for bot in bots {
            let skill = max(1, min(5, Int(bot.skill.rounded())))
            quakeConsole("addbot \(bot.name) \(skill) \(team) \(delay)")
            delay += 1500
        }
    }

    private func presentTeamSelectionForAddBots(_ bots: [PauseBotPickerViewController.PendingBot]) {
        let alert = UIAlertController(title: "Équipe du bot", message: nil, preferredStyle: .actionSheet)
        let teams = [("Libre", "free"), ("Rouge", "red"), ("Bleue", "blue")]
        for (title, team) in teams {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.executeAddBotsViaConsole(bots, team: team)
                self?.finishPauseMenuSubflow()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.finishPauseMenuSubflow()
        })
        presentPauseActionSheet(alert)
    }

    private func pauseServerInfoText() -> String {
        var buffer = [CChar](repeating: 0, count: 512)
        CL_BuildServerInfo(&buffer, Int32(buffer.count))
        return String(cString: buffer)
    }

    @objc func pauseResumeTapped() {
        CL_ClosePauseMenu()
    }

    @objc func pauseTeamTapped() {
        let alert = UIAlertController(title: "Choisir une équipe", message: nil, preferredStyle: .actionSheet)
        let teams = [("Rouge", "red"), ("Bleue", "blue"), ("Libre", "free"), ("Spectateur", "spectator")]
        for (title, team) in teams {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.quakeConsole("cmd team \(team)")
                self?.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc func pauseTeamOrdersTapped() {
        let alert = UIAlertController(title: "Ordres d'équipe", message: nil, preferredStyle: .actionSheet)
        let orders = [
            "Tout le monde attaque !",
            "Tout le monde défend !",
            "Suivez-moi",
            "Gardez la position"
        ]
        for order in orders {
            alert.addAction(UIAlertAction(title: order, style: .default) { [weak self] _ in
                let escaped = order.replacingOccurrences(of: "\"", with: "\\\"")
                self?.quakeConsole("say_team \"\(escaped)\"")
                self?.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc func pauseSetupTapped() {
        let alert = UIAlertController(title: "Réglages rapides", message: nil, preferredStyle: .actionSheet)
        let settings = [
            ("Volume jeu 50 %", "set s_volume 0.5"),
            ("Volume jeu 80 %", "set s_volume 0.8"),
            ("Volume jeu 100 %", "set s_volume 1"),
            ("Musique 50 %", "set s_musicvolume 0.5")
        ]
        for (title, command) in settings {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.quakeConsole(command)
                self?.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc func pauseServerInfoTapped() {
        let alert = UIAlertController(
            title: "Infos serveur",
            message: pauseServerInfoText(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        pauseAlertPresenter().present(alert, animated: true)
    }

    @objc func pauseRestartTapped() {
        presentPauseConfirmation(title: "Redémarrer l'arène ?", confirmTitle: "Redémarrer") { [weak self] in
            CL_ClosePauseMenu()
            self?.quakeConsole("map_restart 0")
        }
    }

    @objc func pauseLeaveTapped() {
        presentPauseConfirmation(title: "Quitter l'arène ?", confirmTitle: "Quitter") { [weak self] in
            CL_ClosePauseMenu()
            self?.quakeConsole("disconnect")
        }
    }

    @objc func pauseExitGameTapped() {
        presentPauseConfirmation(title: "Quitter le jeu ?", confirmTitle: "Quitter") { [weak self] in
            CL_ClosePauseMenu()
            self?.quakeConsole("disconnect")
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .quakeReturnToMainMenu, object: nil)
            }
        }
    }

    @objc func pauseAddBotTapped() {
        guard CL_CanManageBots() != 0 else { return }
        guard let botPicker = makeBotPickerViewController() else { return }

        botPicker.modalPresentationStyle = .overFullScreen
        botPicker.onCancelled = { [weak self] in
            self?.finishPauseMenuSubflow()
        }
        botPicker.onBotsConfirmed = { [weak self] bots in
            guard let self = self else { return }
            if self.isTeamGametype() {
                self.presentTeamSelectionForAddBots(bots)
            } else {
                self.executeAddBotsViaConsole(bots, team: "free")
                self.finishPauseMenuSubflow()
            }
        }

        dismissPauseMenuUI { [weak self] in
            guard let self = self else { return }

            self.setGameControlsHidden(true)
            self.present(botPicker, animated: false)
        }
    }

    @objc func pauseRemoveBotTapped() {
        let count = Int(CL_ConnectedBotCount())
        guard count > 0 else { return }

        var names: [String] = []
        names.reserveCapacity(count)
        for index in 0..<count {
            var buffer = [CChar](repeating: 0, count: 64)
            let found = CL_ConnectedBotName(Int32(index), &buffer, Int32(buffer.count))
            if found != 0 {
                names.append(String(cString: buffer))
            }
        }
        guard !names.isEmpty else { return }

        let alert = UIAlertController(title: "Retirer un bot", message: nil, preferredStyle: .actionSheet)
        for name in names {
            alert.addAction(UIAlertAction(title: name, style: .destructive) { [weak self] _ in
                CL_KickBotByName(name)
                self?.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    open override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateSafeAreaInsetsForEngine()
        if Holder._controlsInstalled {
            layoutOnScreenControls(in: view.bounds)
        }
    }

    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSafeAreaInsetsForEngine()
        if Holder._controlsInstalled {
            layoutOnScreenControls(in: view.bounds)
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installOnScreenControls()
    }
    
    
    
}

extension SDL_uikitviewcontroller: JoystickDelegate {

    /// j_forward_axis = 1, j_yaw_axis = 0 (horizontal stick = turn left/right).
    private static let joyAxisForward = 1
    private static let joyAxisYaw = 0
    private static let joyMoveGain: CGFloat = 1.35
    private static let joyDeadZone: CGFloat = 0.08
    private static let joyResponseExponent: CGFloat = 1.0

    private func resetTouchJoystickAxes() {
        let t = Int32(Sys_Milliseconds())
        CL_JoystickEvent(Int32(SDL_uikitviewcontroller.joyAxisYaw), 0, t)
        CL_JoystickEvent(Int32(SDL_uikitviewcontroller.joyAxisForward), 0, t)
    }

    private func applyJoystickResponse(_ value: CGFloat) -> CGFloat {
        let v = max(-1.0, min(1.0, value))
        let absV = abs(v)
        if absV < SDL_uikitviewcontroller.joyDeadZone {
            return 0
        }
        let scaled = (absV - SDL_uikitviewcontroller.joyDeadZone)
            / (1.0 - SDL_uikitviewcontroller.joyDeadZone)
        let curved = pow(scaled, SDL_uikitviewcontroller.joyResponseExponent)
        return v < 0 ? -curved : curved
    }

    func handleJoyStickPosition(x: CGFloat, y: CGFloat) {
        let yaw = applyJoystickResponse(x)
        let forward = applyJoystickResponse(y)
        let t = Int32(Sys_Milliseconds())

        // j_forward=-2, cl_run=1 (see applyTouchJoystickCvars).
        let forwardScaled = -forward * 127.0 * SDL_uikitviewcontroller.joyMoveGain
        let forwardAxis = Int32(max(-127, min(127, forwardScaled.rounded())))
        let yawAxis = Int32(-yaw * 127.0)

        CL_JoystickEvent(Int32(SDL_uikitviewcontroller.joyAxisYaw), yawAxis, t)
        CL_JoystickEvent(Int32(SDL_uikitviewcontroller.joyAxisForward), forwardAxis, t)
    }

    func handleJoyStick(angle: CGFloat, displacement: CGFloat) {
    }

}
