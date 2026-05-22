//
//  GameSession.swift
//  Quake3-iOS
//

import Foundation

/// Paramètres de la prochaine partie, définis avant la navigation vers GameViewController.
enum GameSession {
    static var map = ""
    static var difficulty = 2
    static var botMatch = false
    static var botSkill: Float = 3
    static var bots: [(name: String, skill: Float, icon: String)] = []
    static var fragLimit = 20
    static var timeLimit = 0
    static var server: Server?

    static func configureForSinglePlayer(map: String, difficulty: Int) {
        botMatch = false
        server = nil
        bots = []
        self.map = map
        self.difficulty = max(1, min(5, difficulty))
    }

    static func configureForBotMatch(
        map: String,
        skill: Float,
        bots: [(name: String, skill: Float, icon: String)],
        fragLimit: Int,
        timeLimit: Int
    ) {
        botMatch = true
        server = nil
        self.map = map
        botSkill = skill
        self.bots = bots
        self.fragLimit = fragLimit
        self.timeLimit = timeLimit
    }

    static func configureForMultiplayer(server: Server) {
        botMatch = false
        map = ""
        bots = []
        self.server = server
    }
}
