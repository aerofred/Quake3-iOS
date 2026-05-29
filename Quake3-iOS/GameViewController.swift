//
//  GameViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 7/19/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import GameController

#if os(iOS)
import CoreMotion
#endif

class GameViewController: UIViewController {

    private static var engineRunning = false

    var selectedMap = ""
    var selectedServer: Server?
    var selectedDifficulty = 0
    var botMatch = false
    var hostMultiplayer = false
    var botSkill: Float = 3
    var timeLimit = 0
    var fragLimit = 20
    var bots = [(name: String, skill: Float, icon: String)]()

    private var hasStartedEngine = false

    let defaults = UserDefaults()

    override func viewDidLoad() {
        super.viewDidLoad()
        applySessionIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReturnToMainMenu),
            name: .quakeReturnToMainMenu,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReturnToArenaSelection),
            name: .quakeReturnToArenaSelection,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleReturnToMainMenu() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func handleReturnToArenaSelection() {
        guard let navigationController = navigationController else { return }

        if GameSession.multiplayer,
           let serverBrowserVC = navigationController.viewControllers.last(where: { $0 is ServerBrowserViewController }) {
            navigationController.popToViewController(serverBrowserVC, animated: true)
        } else if let tiersVC = navigationController.viewControllers.last(where: { $0 is TiersListViewController }) {
            navigationController.popToViewController(tiersVC, animated: true)
        } else if let botMatchVC = navigationController.viewControllers.last(where: { $0 is BotMatchViewController }) {
            navigationController.popToViewController(botMatchVC, animated: true)
        } else if let serverBrowserVC = navigationController.viewControllers.last(where: { $0 is ServerBrowserViewController }) {
            navigationController.popToViewController(serverBrowserVC, animated: true)
        } else {
            navigationController.popViewController(animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activateGameView(source: "viewDidAppear")
    }

    func activateAfterPausedMenuNavigation() {
        activateGameView(source: "pausedMenuNavigation")
    }

    private func activateGameView(source: String) {
        _ = source
        let engineWasRunning = GameViewController.engineRunning
        if let appWindow = (UIApplication.shared.delegate as? AppDelegate)?.uiwindow {
            appWindow.windowLevel = .normal
            appWindow.isHidden = false
            appWindow.isUserInteractionEnabled = true
        }
        Sys_SetIOSMainLoopPaused(qboolean(0))
        Sys_SetSDLWindowVisible(qboolean(1))
        if engineWasRunning {
            hideFrontendWindowForRunningEngine()
        }
        applySessionIfNeeded()
        if GameViewController.engineRunning {
            startQuakeEngine()
            return
        }
        guard !hasStartedEngine else { return }
        hasStartedEngine = true
        startQuakeEngine()
    }

    private func hideFrontendWindowForRunningEngine() {
        guard let appWindow = (UIApplication.shared.delegate as? AppDelegate)?.uiwindow else { return }
        appWindow.isUserInteractionEnabled = false
        appWindow.isHidden = true
    }

    private func applySessionIfNeeded() {
        guard !GameSession.map.isEmpty || GameSession.server != nil || GameSession.botMatch else {
            return
        }
        selectedMap = GameSession.map
        selectedDifficulty = GameSession.difficulty
        botMatch = GameSession.botMatch
        hostMultiplayer = GameSession.hostMultiplayer
        botSkill = GameSession.botSkill
        bots = GameSession.bots
        fragLimit = GameSession.fragLimit
        timeLimit = GameSession.timeLimit
        selectedServer = GameSession.server
    }

    private func startQuakeEngine() {
        #if os(tvOS)
        let documentsDir = try! FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path
        #else
        let documentsDir = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path
        #endif

        Sys_SetHomeDir(documentsDir)

        let resourcePath = Bundle.main.resourcePath!
        let mapName = selectedMap.lowercased()
        let playerName = defaults.string(forKey: "playerName") ?? "unnamedPlayer"

        if !botMatch && selectedServer == nil && mapName.isEmpty {
            presentMapAlert(
                title: "Carte introuvable",
                message: "Aucune carte n'a été sélectionnée. Reviens en arrière et choisis une arène."
            )
            return
        }

        if !mapName.isEmpty && !MapCatalog.isMapAvailable(mapName, bundleResourcePath: resourcePath) {
            presentMapAlert(
                title: "Carte non installée",
                message: "La carte \(mapName.uppercased()) n'est pas dans les fichiers baseq3 (pak0.pk3, etc.). Installe les données complètes de Quake III Arena ou choisis une autre carte."
            )
            return
        }

        if GameViewController.engineRunning {
            loadMapInRunningEngine(mapName: mapName, resourcePath: resourcePath)
            return
        }
        GameViewController.engineRunning = true

        var argv: [String?] = [
            resourcePath + "/quake3",
            "+set", "fs_basepath", resourcePath,
            "+set", "com_basegame", "baseq3",
            "+set", "dedicated", "0",
            "+name", playerName
        ]

        appendMapLaunchCommands(to: &argv, mapName: mapName)

        if let server = selectedServer {
            argv.append(contentsOf: [
                "+connect", "\(server.ip):\(server.port)"
            ])
        }

        appendControlAndVideoSettings(to: &argv, resourcePath: resourcePath)

        argv.append(nil)

        let argc = Int32(argv.count - 1)
        var cargs = argv.map { $0.flatMap { UnsafeMutablePointer<Int8>(strdup($0)) } }

        scheduleInitialBotCommandsIfNeeded(mapName: mapName)
        Sys_Startup(argc, &cargs)
        for ptr in cargs {
            free(UnsafeMutablePointer(mutating: ptr))
        }
    }

    private func loadMapInRunningEngine(mapName: String, resourcePath: String) {
        guard !mapName.isEmpty else {
            return
        }
        _ = resourcePath
        Cbuf_AddText("disconnect\n")
        Cbuf_AddText("wait 2\n")

        if botMatch {
            Cbuf_AddText("set sv_pure 0\n")
            Cbuf_AddText("set bot_enable 1\n")
            Cbuf_AddText("set sv_maxclients \(maxClientCount())\n")
            Cbuf_AddText("set ui_singlePlayerActive 0\n")
            Cbuf_AddText("set singleplayer 0\n")
            Cbuf_AddText("set g_gametype 0\n")
            Cbuf_AddText("map \(mapName)\n")
            scheduleBotCommands(delay: 4.0)
            Cbuf_AddText("set timelimit \(timeLimit)\n")
            Cbuf_AddText("set fraglimit \(fragLimit)\n")
        } else if hostMultiplayer {
            Cbuf_AddText("set sv_pure 0\n")
            Cbuf_AddText("set bot_enable 0\n")
            Cbuf_AddText("set sv_maxclients 8\n")
            Cbuf_AddText("set ui_singlePlayerActive 0\n")
            Cbuf_AddText("set singleplayer 0\n")
            Cbuf_AddText("set g_gametype 0\n")
            Cbuf_AddText("set sv_hostname \"Quake3 iOS Host\"\n")
            Cbuf_AddText("map \(mapName)\n")
        } else if selectedServer == nil {
            let skill = clampedSinglePlayerSkill()
            Cbuf_AddText("set sv_pure 0\n")
            Cbuf_AddText("set bot_enable 1\n")
            Cbuf_AddText("set sv_maxclients \(maxClientCount())\n")
            Cbuf_AddText("set ui_singlePlayerActive 0\n")
            Cbuf_AddText("set singleplayer 0\n")
            Cbuf_AddText("set g_gametype \(singlePlayerGameType(for: mapName))\n")
            Cbuf_AddText("set g_spSkill \(skill)\n")
            Cbuf_AddText("map \(mapName)\n")
            scheduleBotCommands(delay: 4.0, overrideSkill: skill)
        } else if let selectedServer {
            Cbuf_AddText("connect \(selectedServer.ip):\(selectedServer.port)\n")
        }
    }

    private func appendMapLaunchCommands(to argv: inout [String?], mapName: String) {
        guard !mapName.isEmpty else { return }

        if botMatch {
            argv.append(contentsOf: [
                "+set", "sv_pure", "0",
                "+set", "bot_enable", "1",
                "+set", "sv_maxclients", String(maxClientCount()),
                "+set", "ui_singlePlayerActive", "0",
                "+set", "singleplayer", "0",
                "+set", "g_gametype", "0",
                "+map", mapName
            ])
            argv.append(contentsOf: [
                "+set", "timelimit", String(timeLimit),
                "+set", "fraglimit", String(fragLimit)
            ])
        } else if hostMultiplayer {
            argv.append(contentsOf: [
                "+set", "sv_pure", "0",
                "+set", "bot_enable", "0",
                "+set", "sv_maxclients", "8",
                "+set", "ui_singlePlayerActive", "0",
                "+set", "singleplayer", "0",
                "+set", "g_gametype", "0",
                "+set", "sv_hostname", "Quake3 iOS Host",
                "+map", mapName
            ])
        } else if selectedServer == nil {
            // Même chemin que Bot Match (+map) : +spmap laissait le client sur le menu Quake.
            let skill = clampedSinglePlayerSkill()
            argv.append(contentsOf: [
                "+set", "sv_maxclients", String(maxClientCount()),
                "+set", "bot_enable", "1",
                "+set", "ui_singlePlayerActive", "0",
                "+set", "singleplayer", "0",
                "+set", "g_gametype", String(singlePlayerGameType(for: mapName)),
                "+set", "g_spSkill", String(skill),
                "+map", mapName,
                "+set", "sv_pure", "0",
                "+set", "r_uiFullScreen", "0"
            ])
        }
    }

    private func scheduleInitialBotCommandsIfNeeded(mapName: String) {
        guard selectedServer == nil, !hostMultiplayer, !mapName.isEmpty else { return }
        let overrideSkill = botMatch ? nil : clampedSinglePlayerSkill()
        scheduleBotCommands(delay: 8.0, overrideSkill: overrideSkill)
    }

    private func scheduleBotCommands(delay: TimeInterval, overrideSkill: Int? = nil) {
        let commands = addBotCommands(overrideSkill: overrideSkill)
        guard !commands.isEmpty else { return }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + delay) {
            for command in commands {
                CL_QueueAddBotCommand(command.name, Int32(command.skill))
            }
        }
    }

    private func addBotCommands(overrideSkill: Int? = nil) -> [(name: String, skill: Int)] {
        bots.compactMap { bot in
            let name = bot.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let skill = overrideSkill ?? Int(bot.skill.rounded())
            return (name: name, skill: max(1, min(5, skill)))
        }
    }

    private func clampedSinglePlayerSkill() -> Int {
        max(1, min(5, selectedDifficulty))
    }

    private func maxClientCount() -> Int {
        max(8, min(12, addBotCommands().count + 1))
    }

    private func singlePlayerGameType(for mapName: String) -> Int {
        mapName.lowercased().contains("tourney") ? 1 : 0
    }

    private func appendControlAndVideoSettings(to argv: inout [String?], resourcePath: String) {
        _ = resourcePath
        argv.append(contentsOf: ["+set", "r_useOpenGLES", "1", "+set", "r_mode", "-1"])

        let screenBounds = UIScreen.main.bounds
        let screenScale = UIScreen.main.scale
        let screenSize = CGSize(
            width: screenBounds.size.width * screenScale,
            height: screenBounds.size.height * screenScale
        )

        argv.append(contentsOf: [
            "+set", "r_customwidth", "\(Int(screenSize.width))",
            "+set", "r_customheight", "\(Int(screenSize.height))",
            "+set", "s_sdlSpeed", "44100",
            "+set", "r_useHiDPI", "1",
            "+set", "r_fullscreen", "1",
            "+set", "in_joystick", "1",
            "+set", "in_joystickUseAnalog", "1",
            "+set", "j_yaw_axis", "0",
            "+set", "j_side_axis", "4",
            "+set", "j_side", "0",
            "+set", "j_forward_axis", "1",
            "+set", "j_forward", "-2",
            "+set", "cl_run", "1",
            "+set", "j_yaw", "1",
            "+set", "sensitivity", "10",
            "+set", "touch_move_sensitivity", touchSensitivityValue(forKey: "touchMoveSensitivity", defaultValue: 1.0),
            "+set", "touch_look_sensitivity", touchSensitivityValue(forKey: "touchLookSensitivity", defaultValue: 1.0),
            "+bind", "PAD0_RIGHTTRIGGER", "\"+attack\"",
            "+bind", "PAD0_LEFTSTICK_UP", "\"+forward\"",
            "+bind", "PAD0_LEFTSTICK_DOWN", "\"+back\"",
            "+bind", "PAD0_LEFTSTICK_LEFT", "\"+moveleft\"",
            "+bind", "PAD0_LEFTSTICK_RIGHT", "\"+moveright\"",
            "+bind", "PAD0_RIGHTSTICK_UP", "\"+lookup\"",
            "+bind", "PAD0_RIGHTSTICK_DOWN", "\"+lookdown\"",
            "+bind", "PAD0_RIGHTSTICK_LEFT", "\"+left\"",
            "+bind", "PAD0_RIGHTSTICK_RIGHT", "\"+right\"",
            "+bind", "PAD0_A", "\"+moveup\"",
            "+bind", "PAD0_LEFTSHOULDER", "\"weapnext\"",
            "+bind", "PAD0_RIGHTSHOULDER", "\"weapprev\""
        ])

        #if DEBUG
        argv.append(contentsOf: ["+set", "developer", "1"])
        #endif
    }

    private func touchSensitivityValue(forKey key: String, defaultValue: Double) -> String {
        let value = defaults.object(forKey: key) == nil ? defaultValue : defaults.double(forKey: key)
        return String(format: "%.3f", max(0.25, min(3.0, value)))
    }

    private func presentMapAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
}
