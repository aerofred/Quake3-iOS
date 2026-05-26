//
//  DifficultyViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 7/28/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import UIKit

class DifficultyViewController: UIViewController {
    
    var selectedMap = ""
    var selectedMapName = ""
    var selectedBotNames: [String] = []
    var selectedDifficulty = 0
    
    @IBAction func difficulty1(_ sender: UIButton) {
        startGame(difficulty: 1)
    }
    
    @IBAction func difficulty2(_ sender: UIButton) {
        startGame(difficulty: 2)
    }

    @IBAction func difficulty3(_ sender: UIButton) {
        startGame(difficulty: 3)
    }

    @IBAction func difficulty4(_ sender: UIButton) {
        startGame(difficulty: 4)
    }

    @IBAction func difficulty5(_ sender: UIButton) {
        startGame(difficulty: 5)
    }

    private func startGame(difficulty: Int) {
        selectedDifficulty = difficulty
        if Sys_IsIOSMainLoopPaused().rawValue != 0,
           let gameVC = storyboard?.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController {
            GameSession.configureForSinglePlayer(map: selectedMap, difficulty: selectedDifficulty, bots: selectedBotNames)
            gameVC.selectedMap = selectedMap
            gameVC.selectedDifficulty = selectedDifficulty
            gameVC.botMatch = false
            gameVC.bots = selectedBotNames.map { (name: $0, skill: Float(selectedDifficulty), icon: "") }
            navigationController?.pushViewController(gameVC, animated: false)
            navigationController?.view.setNeedsLayout()
            navigationController?.view.layoutIfNeeded()
            gameVC.activateAfterPausedMenuNavigation()
            return
        }
        performSegue(withIdentifier: "GameSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "GameSegue",
              let gameVC = segue.destination as? GameViewController else {
            return
        }
        GameSession.configureForSinglePlayer(map: selectedMap, difficulty: selectedDifficulty, bots: selectedBotNames)
        gameVC.selectedMap = selectedMap
        gameVC.selectedDifficulty = selectedDifficulty
        gameVC.botMatch = false
        gameVC.bots = selectedBotNames.map { (name: $0, skill: Float(selectedDifficulty), icon: "") }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
