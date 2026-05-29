//
//  ServerFilterViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 8/5/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import UIKit

class ServerFilterViewController: UIViewController {
    
    var delegate:ServerFilterProtocol?
    
    var gameTypeFilterTitle = "Any"
    var modFilterTitle = "Any"
    var sortOptionTitle = "Ping"
    var showEmpty = true
    var showFull = true
    var localOnly = false
    private let localOnlySwitch = UISwitch()
    private let localOnlyButton = UIButton(type: .system)
    
    @IBOutlet weak var sortByButton: UIButton!
    @IBOutlet weak var modButton: UIButton!
    @IBOutlet weak var gameTypeButton: UIButton!
#if os(iOS)
    @IBOutlet weak var showEmptySwitch: UISwitch!
    @IBOutlet weak var showFullSwitch: UISwitch!
#endif
#if os(tvOS)
    @IBOutlet weak var showEmptyButton: UIButton!
    @IBOutlet weak var showFullButton: UIButton!
#endif
    let gameTypes = ["Any": "", "Deathmatch": "ffa", "Team Deathmatch": "tdm", "Tournament": "tourney", "Capture the Flag": "ctf"]
    let modTypes = ["Any",
                    "baseq3",
                    "arena",
                    "cpma",
                    "defrag",
                    "excessiveplus",
                    "osp"]
    let sortOptions = ["Ping": "ping", "Server Name": "servername", "Game Type": "gametype"]

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sortByButton.setTitle(sortOptionTitle, for: .normal)
        modButton.setTitle(modFilterTitle, for: .normal)
        gameTypeButton.setTitle(gameTypeFilterTitle, for: .normal)
        #if os(iOS)
        showFullSwitch.setOn(showFull, animated: false)
        showEmptySwitch.setOn(showEmpty, animated: false)
        installLocalOnlySwitch()
        #endif
        #if os(tvOS)
        showFullButton.setTitle(showFull ? "Yes" : "No", for: .normal)
        showEmptyButton.setTitle(showEmpty ? "Yes" : "No", for: .normal)
        installLocalOnlyButton()
        #endif
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func sortBy(_ sender: UIButton) {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        
        let sortOptionKeys = Array(sortOptions.keys)
        for sortOption in sortOptionKeys {
            alert.addAction(UIAlertAction(title: sortOption, style: .default, handler: { (action) in
                sender.setTitle(action.title, for: .normal)
                self.delegate?.setSortOption(sortOption: self.sortOptions[action.title!]!, sortOptionTitle: action.title!)
            }))
        }
        
        self.present(alert, animated: true, completion: nil)

    }
    
    
    @IBAction func gameType(_ sender: UIButton) {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        
        let gameTypeKeys = Array(gameTypes.keys)
        for gameType in gameTypeKeys {
            alert.addAction(UIAlertAction(title: gameType, style: .default, handler: { (action) in
                sender.setTitle(action.title, for: .normal)
                self.delegate?.setGameTypeFilter(gameTypeFilter: self.gameTypes[action.title!]!, gameTypeFilterTitle: action.title!)
            }))
        }
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBAction func modType(_ sender: UIButton) {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        
        for modType in modTypes {
            alert.addAction(UIAlertAction(title: modType, style: .default, handler: { (action) in
                sender.setTitle(action.title, for: .normal)
                self.delegate?.setModFilter(modFilter: action.title! == "Any" ? "" : action.title!, modFilterTitle: action.title!)
            }))
        }
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    #if os(iOS)
    @IBAction func showEmpty(_ sender: UISwitch) {
        delegate?.setShowEmpty(showEmpty: sender.isOn)
    }
    
    @IBAction func showFull(_ sender: UISwitch) {
        delegate?.setShowFull(showFull: sender.isOn)
    }

    private func installLocalOnlySwitch() {
        let label = UILabel()
        label.text = "Local Only:"
        label.font = UIFont(name: "AvenirNextCondensed-Regular", size: 17) ?? UIFont.systemFont(ofSize: 17)

        localOnlySwitch.setOn(localOnly, animated: false)
        localOnlySwitch.onTintColor = UIColor(red: 0.870588243, green: 0.08931028656, blue: 0, alpha: 1)
        localOnlySwitch.addTarget(self, action: #selector(localOnlyChanged(_:)), for: .valueChanged)

        let row = UIStackView(arrangedSubviews: [label, localOnlySwitch])
        row.translatesAutoresizingMaskIntoConstraints = false
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        view.addSubview(row)

        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            row.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 220)
        ])
    }

    @objc private func localOnlyChanged(_ sender: UISwitch) {
        delegate?.setLocalOnly(localOnly: sender.isOn)
    }
    #endif
    
    #if os(tvOS)
    @IBAction func showEmpty(_ sender: Any) {
        showEmpty = !showEmpty
        delegate?.setShowEmpty(showEmpty: showEmpty)
        showEmptyButton.setTitle(showEmpty ? "Yes" : "No", for: .normal)
    }
    
    @IBAction func showFull(_ sender: Any) {
        showFull = !showFull
        delegate?.setShowFull(showFull: showFull)
        showFullButton.setTitle(showFull ? "Yes" : "No", for: .normal)
    }

    private func installLocalOnlyButton() {
        localOnlyButton.translatesAutoresizingMaskIntoConstraints = false
        localOnlyButton.setTitle(localOnly ? "Local Only: Yes" : "Local Only: No", for: .normal)
        localOnlyButton.addTarget(self, action: #selector(localOnlyButtonTapped(_:)), for: .primaryActionTriggered)
        view.addSubview(localOnlyButton)

        NSLayoutConstraint.activate([
            localOnlyButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            localOnlyButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 220)
        ])
    }

    @objc private func localOnlyButtonTapped(_ sender: UIButton) {
        localOnly.toggle()
        delegate?.setLocalOnly(localOnly: localOnly)
        sender.setTitle(localOnly ? "Local Only: Yes" : "Local Only: No", for: .normal)
    }
    #endif

}
