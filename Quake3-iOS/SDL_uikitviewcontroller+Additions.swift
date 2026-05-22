//
//  SDL2ViewController+Additions.swift
//  Quake2-iOS
//
//  Created by Tom Kidd on 1/28/19.
//

import UIKit

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
        static var _controlsInstalled = false
        static var _pauseMenuPanel: UIView?
        static var _pauseMenuScroll: UIScrollView?
        static var _pauseMenuStack: UIStackView?
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
        }

        layoutOnScreenControls(in: view.bounds)
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
        view.addSubview(escapeButton)
        view.addSubview(f1Button)

        view.bringSubviewToFront(escapeButton)
        view.bringSubviewToFront(prevWeaponButton)
        view.bringSubviewToFront(nextWeaponButton)
        view.bringSubviewToFront(f1Button)
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

        joystickView.frame = CGRect(
            x: safeRect.minX + 50,
            y: safeRect.maxY - joySize.height - 50,
            width: joySize.width,
            height: joySize.height
        )
        fireButton.frame = CGRect(
            x: safeRect.maxX - 155,
            y: safeRect.maxY - 90,
            width: 75,
            height: 75
        )
        jumpButton.frame = CGRect(
            x: safeRect.maxX - 90,
            y: safeRect.maxY - 135,
            width: 75,
            height: 75
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
            ensurePauseMenuPanel()
            Holder._pauseMenuPanel?.isHidden = false
            if let panel = Holder._pauseMenuPanel {
                view.bringSubviewToFront(panel)
            }
        } else {
            Holder._pauseMenuPanel?.isHidden = true
        }
        setGameControlsHidden(visible)
    }

    @objc func toggleControls(_ menuOpen: Bool) {
        if CL_IsPauseMenuOpen() == 0 {
            Holder._pauseMenuPanel?.isHidden = true
        }
        setGameControlsHidden(menuOpen)
    }

    private func setGameControlsHidden(_ menuOpen: Bool) {
        fireButton.isHidden = menuOpen
        jumpButton.isHidden = menuOpen
        joystickView.isHidden = menuOpen
        prevWeaponButton.isHidden = menuOpen
        nextWeaponButton.isHidden = menuOpen
        escapeButton.isHidden = menuOpen
        f1Button.isHidden = menuOpen

        if menuOpen {
            joystickView.delegate = nil
            Key_Event(132, qboolean(0), qboolean(1))
            Key_Event(133, qboolean(0), qboolean(1))
            Key_Event(134, qboolean(0), qboolean(1))
            Key_Event(135, qboolean(0), qboolean(1))
            cl_joyscale_x.0 = 0
            cl_joyscale_x.1 = 0
            cl_joyscale_y.0 = 0
            cl_joyscale_y.1 = 0
        } else {
            joystickView.delegate = self
        }
    }

    private func ensurePauseMenuPanel() {
        if Holder._pauseMenuPanel != nil {
            layoutPauseMenuPanel()
            return
        }

        let panel = UIView()
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        panel.isHidden = true
        panel.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "PAUSE"
        title.textColor = .white
        title.font = UIFont.boldSystemFont(ofSize: 22)
        title.textAlignment = .center

        let titleWrapper = UIView()
        title.translatesAutoresizingMaskIntoConstraints = false
        titleWrapper.addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: titleWrapper.leadingAnchor),
            title.trailingAnchor.constraint(equalTo: titleWrapper.trailingAnchor),
            title.topAnchor.constraint(equalTo: titleWrapper.topAnchor, constant: 4),
            title.bottomAnchor.constraint(equalTo: titleWrapper.bottomAnchor, constant: -4),
            titleWrapper.heightAnchor.constraint(equalToConstant: 36)
        ])
        stack.addArrangedSubview(titleWrapper)

        addPauseMenuButton("Reprendre la partie", to: stack, action: #selector(pauseResumeTapped))
        addPauseMenuButton("Équipe", to: stack, action: #selector(pauseTeamTapped))

        if CL_CanManageBots() != 0 || GameSession.botMatch {
            addPauseMenuButton("Ajouter un bot", to: stack, action: #selector(pauseAddBotTapped))
            addPauseMenuButton("Retirer un bot", to: stack, action: #selector(pauseRemoveBotTapped))
        }

        if CL_CanUseTeamOrders() != 0 {
            addPauseMenuButton("Ordres d'équipe", to: stack, action: #selector(pauseTeamOrdersTapped))
        }

        addPauseMenuButton("Réglages", to: stack, action: #selector(pauseSetupTapped))
        addPauseMenuButton("Infos serveur", to: stack, action: #selector(pauseServerInfoTapped))
        addPauseMenuButton("Redémarrer l'arène", to: stack, action: #selector(pauseRestartTapped))
        addPauseMenuButton("Quitter l'arène", to: stack, action: #selector(pauseLeaveTapped))
        addPauseMenuButton("Quitter le jeu", to: stack, action: #selector(pauseExitGameTapped))

        scroll.addSubview(stack)
        panel.addSubview(scroll)
        view.addSubview(panel)

        let guide = panel.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -12),
            scroll.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            scroll.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
        ])

        Holder._pauseMenuPanel = panel
        Holder._pauseMenuScroll = scroll
        Holder._pauseMenuStack = stack
        layoutPauseMenuPanel()
    }

    private func addPauseMenuButton(_ title: String, to stack: UIStackView, action: Selector) {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        stack.addArrangedSubview(button)
    }

    private func layoutPauseMenuPanel() {
        guard let panel = Holder._pauseMenuPanel else { return }
        panel.frame = view.bounds
    }

    private func keyWindowForPresentation() -> UIWindow? {
        if let window = view.window {
            return window
        }
        return UIApplication.shared.keyWindow
    }

    private func topPresenterForPauseAlerts() -> UIViewController {
        var top: UIViewController = self
        while let presented = top.presentedViewController {
            top = presented
        }
        if let root = keyWindowForPresentation()?.rootViewController {
            var candidate = root
            while let presented = candidate.presentedViewController {
                candidate = presented
            }
            return candidate
        }
        return top
    }

    private func restorePausePanelIfNeeded() {
        guard CL_IsPauseMenuOpen() != 0, let panel = Holder._pauseMenuPanel else { return }
        panel.isHidden = false
        view.bringSubviewToFront(panel)
    }

    private func presentPauseActionSheet(_ alert: UIAlertController) {
        Holder._pauseMenuPanel?.isHidden = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let presenter = self.topPresenterForPauseAlerts()
            if alert.actions.first(where: { $0.style == .cancel }) == nil {
                alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
                    self?.restorePausePanelIfNeeded()
                })
            }
            if let popover = alert.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(
                    x: presenter.view.bounds.midX,
                    y: presenter.view.bounds.midY,
                    width: 1,
                    height: 1
                )
            }
            presenter.present(alert, animated: true)
        }
    }

    private func presentPauseConfirmation(
        title: String,
        confirmTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        Holder._pauseMenuPanel?.isHidden = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
                self?.restorePausePanelIfNeeded()
            })
            alert.addAction(UIAlertAction(title: confirmTitle, style: .destructive) { _ in
                onConfirm()
            })
            self.topPresenterForPauseAlerts().present(alert, animated: true)
        }
    }

    private func pauseServerInfoText() -> String {
        var buffer = [CChar](repeating: 0, count: 512)
        CL_BuildServerInfo(&buffer, Int32(buffer.count))
        return String(cString: buffer)
    }

    @objc private func pauseResumeTapped() {
        CL_ClosePauseMenu()
    }

    @objc private func pauseTeamTapped() {
        let alert = UIAlertController(title: "Choisir une équipe", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Rouge", style: .default) { _ in
            CL_SetTeam("red")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Bleue", style: .default) { _ in
            CL_SetTeam("blue")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Libre", style: .default) { _ in
            CL_SetTeam("free")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Spectateur", style: .default) { _ in
            CL_SetTeam("spectator")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc private func pauseTeamOrdersTapped() {
        let alert = UIAlertController(title: "Ordres d'équipe", message: nil, preferredStyle: .actionSheet)
        let orders = [
            "Tout le monde attaque !",
            "Tout le monde défend !",
            "Suivez-moi",
            "Gardez la position"
        ]
        for order in orders {
            alert.addAction(UIAlertAction(title: order, style: .default) { _ in
                order.withCString { CL_SendTeamOrder($0) }
                self.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc private func pauseSetupTapped() {
        let alert = UIAlertController(title: "Réglages rapides", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Volume jeu 50 %", style: .default) { _ in
            CL_ExecuteConsole("set s_volume 0.5\n")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Volume jeu 80 %", style: .default) { _ in
            CL_ExecuteConsole("set s_volume 0.8\n")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Volume jeu 100 %", style: .default) { _ in
            CL_ExecuteConsole("set s_volume 1\n")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Musique 50 %", style: .default) { _ in
            CL_ExecuteConsole("set s_musicvolume 0.5\n")
            self.restorePausePanelIfNeeded()
        })
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc private func pauseServerInfoTapped() {
        let alert = UIAlertController(
            title: "Infos serveur",
            message: pauseServerInfoText(),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        Holder._pauseMenuPanel?.isHidden = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.topPresenterForPauseAlerts().present(alert, animated: true)
        }
    }

    @objc private func pauseRestartTapped() {
        presentPauseConfirmation(title: "Redémarrer l'arène ?", confirmTitle: "Redémarrer") {
            CL_RestartArena()
        }
    }

    @objc private func pauseLeaveTapped() {
        presentPauseConfirmation(title: "Quitter l'arène ?", confirmTitle: "Quitter") {
            CL_LeaveArena()
        }
    }

    @objc private func pauseExitGameTapped() {
        presentPauseConfirmation(title: "Quitter le jeu ?", confirmTitle: "Quitter") {
            CL_ExitGame()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .quakeReturnToMainMenu, object: nil)
            }
        }
    }

    @objc private func pauseAddBotTapped() {
        let bots = GameSession.bots
        guard !bots.isEmpty else { return }

        let alert = UIAlertController(title: "Ajouter un bot", message: nil, preferredStyle: .actionSheet)
        for bot in bots {
            alert.addAction(UIAlertAction(title: bot.name, style: .default) { _ in
                let skill = Int32(bot.skill.rounded())
                CL_AddBotCommand(bot.name, skill)
                self.restorePausePanelIfNeeded()
            })
        }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { [weak self] _ in
            self?.restorePausePanelIfNeeded()
        })
        presentPauseActionSheet(alert)
    }

    @objc private func pauseRemoveBotTapped() {
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
            alert.addAction(UIAlertAction(title: name, style: .destructive) { _ in
                CL_KickBotByName(name)
                self.restorePausePanelIfNeeded()
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
        layoutPauseMenuPanel()
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
    
    func handleJoyStickPosition(x: CGFloat, y: CGFloat) {

        if y > 0 {
            cl_joyscale_y.0 = Int32(abs(y) * 60)
            Key_Event(132, qboolean(1), qboolean(1))
            Key_Event(133, qboolean(0), qboolean(1))
        } else if y < 0 {
            cl_joyscale_y.1 = Int32(abs(y) * 60)
            Key_Event(132, qboolean(0), qboolean(1))
            Key_Event(133, qboolean(1), qboolean(1))
        } else {
            cl_joyscale_y.0 = 0
            cl_joyscale_y.1 = 0
            Key_Event(132, qboolean(0), qboolean(1))
            Key_Event(133, qboolean(0), qboolean(1))
        }
        
        if x > 0.25 {
            cl_joyscale_x.0 = Int32(abs(y) * 20)
            Key_Event(135, qboolean(1), qboolean(1))
            Key_Event(134, qboolean(0), qboolean(1))
        } else if x < -0.25 {
            cl_joyscale_x.1 = Int32(abs(y) * 20)
            Key_Event(135, qboolean(0), qboolean(1))
            Key_Event(134, qboolean(1), qboolean(1))
        } else {
            cl_joyscale_x.0 = 0
            cl_joyscale_x.1 = 0
            Key_Event(135, qboolean(0), qboolean(1))
            Key_Event(134, qboolean(0), qboolean(1))
        }
        
    }
    
    func handleJoyStick(angle: CGFloat, displacement: CGFloat) {
//        print("angle: \(angle) displacement: \(displacement)")
    }
    
}
