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
    var selectedDifficulty = 0
    
    @IBAction func difficulty1(_ sender: UIButton) {
        NSLog("[Q3Quit] DifficultyViewController difficulty1 tapped selectedMap=%@", selectedMap)
        startGame(difficulty: 1)
    }
    
    @IBAction func difficulty2(_ sender: UIButton) {
        NSLog("[Q3Quit] DifficultyViewController difficulty2 tapped selectedMap=%@", selectedMap)
        startGame(difficulty: 2)
    }

    @IBAction func difficulty3(_ sender: UIButton) {
        NSLog("[Q3Quit] DifficultyViewController difficulty3 tapped selectedMap=%@", selectedMap)
        startGame(difficulty: 3)
    }

    @IBAction func difficulty4(_ sender: UIButton) {
        NSLog("[Q3Quit] DifficultyViewController difficulty4 tapped selectedMap=%@", selectedMap)
        startGame(difficulty: 4)
    }

    @IBAction func difficulty5(_ sender: UIButton) {
        NSLog("[Q3Quit] DifficultyViewController difficulty5 tapped selectedMap=%@", selectedMap)
        startGame(difficulty: 5)
    }

    private func startGame(difficulty: Int) {
        selectedDifficulty = difficulty
        if Sys_IsIOSMainLoopPaused().rawValue != 0,
           let gameVC = storyboard?.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController {
            NSLog("[Q3Quit] DifficultyViewController push GameViewController without animation selectedMap=%@ difficulty=%d", selectedMap, selectedDifficulty)
            GameSession.configureForSinglePlayer(map: selectedMap, difficulty: selectedDifficulty)
            gameVC.selectedMap = selectedMap
            gameVC.selectedDifficulty = selectedDifficulty
            gameVC.botMatch = false
            navigationController?.pushViewController(gameVC, animated: false)
            navigationController?.view.setNeedsLayout()
            navigationController?.view.layoutIfNeeded()
            gameVC.activateAfterPausedMenuNavigation()
            return
        }
        performSegue(withIdentifier: "GameSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        NSLog("[Q3Quit] DifficultyViewController prepare segue=%@ selectedMap=%@ difficulty=%d destination=%@",
              segue.identifier ?? "nil",
              selectedMap,
              selectedDifficulty,
              String(describing: type(of: segue.destination)))
        guard segue.identifier == "GameSegue",
              let gameVC = segue.destination as? GameViewController else {
            return
        }
        GameSession.configureForSinglePlayer(map: selectedMap, difficulty: selectedDifficulty)
        gameVC.selectedMap = selectedMap
        gameVC.selectedDifficulty = selectedDifficulty
        gameVC.botMatch = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NSLog("[Q3Quit] DifficultyViewController viewDidAppear selectedMap=%@ window=%@ viewInteractive=%d",
              selectedMap,
              String(describing: view.window),
              view.isUserInteractionEnabled)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
