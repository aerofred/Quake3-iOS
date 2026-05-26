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
    
    @IBOutlet weak var playerNameField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
                
        playerNameField.text = defaults.string(forKey: "playerName")

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func savePlayerName(_ sender: UIButton) {
        defaults.set(playerNameField.text!, forKey: "playerName")
        let isMainLoopPaused = Sys_IsIOSMainLoopPaused().rawValue != 0
        navigationController?.popViewController(animated: !isMainLoopPaused)
    }

    override func shouldPerformSegue(withIdentifier identifier: String?, sender: Any?) -> Bool {
        guard Sys_IsIOSMainLoopPaused().rawValue != 0,
              let button = sender as? UIButton,
              button.currentTitle == "< BACK" else {
            return true
        }

        navigationController?.popViewController(animated: false)
        return false
    }
    
}
