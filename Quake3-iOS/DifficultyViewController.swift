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
        selectedDifficulty = 1
        performSegue(withIdentifier: "GameSegue", sender: self)
    }
    
    @IBAction func difficulty2(_ sender: UIButton) {
        selectedDifficulty = 2
        performSegue(withIdentifier: "GameSegue", sender: self)
    }

    @IBAction func difficulty3(_ sender: UIButton) {
        selectedDifficulty = 3
        performSegue(withIdentifier: "GameSegue", sender: self)
    }

    @IBAction func difficulty4(_ sender: UIButton) {
        selectedDifficulty = 4
        performSegue(withIdentifier: "GameSegue", sender: self)
    }

    @IBAction func difficulty5(_ sender: UIButton) {
        selectedDifficulty = 5
        performSegue(withIdentifier: "GameSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
