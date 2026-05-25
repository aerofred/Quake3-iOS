//
//  TiersListViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 7/28/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import UIKit

class TiersListViewController: UIViewController {
    
    @IBOutlet weak var tiersList: UITableView!
    
    let tiers = ["Tier 0 - Introduction",
                 "Tier 1 - Trainee",
                 "Tier 2 - Skilled",
                 "Tier 3 - Combat",
                 "Tier 4 - Warrior",
                 "Tier 5 - Veteran",
                 "Tier 6 - Master"]
    
    let maps:[[(map: String, name: String)]] = [[(map: "q3dm0", name: "Q3DM0: Introduction (Crash)")],
                                                [(map: "q3dm1", name: "Q3DM1: Arena Gate (Ranger)"),
                                                 (map: "q3dm2", name: "Q3DM2: House of Pain (Phobos)"),
                                                 (map: "q3dm3", name: "Q3DM3: Arena of Death (Mynx, Orbb)"),
                                                 (map: "q3tourney1", name: "Q3TOURNEY1: Power Station 0218 (Sarge)")],
                                                [(map: "q3dm4", name: "Q3DM4: The Place of Many Deaths (Orbb, Bitterman, Grunt)"),
                                                 (map: "q3dm5", name: "Q3DM5: The Forgotten Place (Hossman, Daemia)"),
                                                 (map: "q3dm6", name: "Q3DM6: The Camping Grounds (Daemia, Orbb, Bitterman, Hossman, Grunt)"),
                                                 (map: "q3tourney2", name: "Q3TOURNEY2: The Proving Grounds (Hunter)")],
                                                [(map: "q3dm7", name: "Q3DM7: Temple of Retribution (Daemia, Wrack, Grunt, Slash)"),
                                                 (map: "q3dm8", name: "Q3DM8: Brimstone Abbey (Gorre, Bitterman, Angel, Slash)"),
                                                 (map: "q3dm9", name: "Q3DM9: Hero's Keep (Angel, Gorre, Wrack, Slash)"),
                                                 (map: "q3tourney3", name: "Q3TOURNEY3: Hell's Gate (Klesk)")],
                                                [(map: "q3dm10", name: "Q3DM10: The Nameless Place (Wrack, Tank Jr., Angel)"),
                                                 (map: "q3dm11", name: "Q3DM11: Deva Station (Tank Jr., Patriot, Biker, Lucy)"),
                                                 (map: "q3dm12", name: "Q3DM12: The Dredwerkz (Slash, Gorre, Lucy, Biker, Patriot)"),
                                                 (map: "q3tourney4", name: "Q3TOURNEY4: Vertical Vengeance (Anarki)")],
                                                [(map: "q3dm13", name: "Q3DM13: Lost World (Stripe, Razor, Visor)"),
                                                 (map: "q3dm14", name: "Q3DM14: Grim Dungeons (Stripe, Visor, Razor, Keel)"),
                                                 (map: "q3dm15", name: "Q3DM15: Demon Keep (Stripe, Razor, Keel)"),
                                                 (map: "q3tourney5", name: "Q3TOURNEY5: Fatal Instinct (Uriel)")],
                                                [(map: "q3dm16", name: "Q3DM16: Bouncy Map (Cadaver, Bones, Doom)"),
                                                 (map: "q3dm17", name: "Q3DM17: The Longest Yard (Major, Sorlag, Doom)"),
                                                 (map: "q3dm18", name: "Q3DM18: Space Chamber (Major, Sorlag, Cadaver, Bones, Keel)"),
                                                 (map: "q3dm19", name: "Q3DM19: Apocalypse Void (Sorlag, Cadaver, Doom)")],
                                                [(map: "q3tourney6", name: "Q3TOURNEY6: The Very End of You (Xaero)")]]

    var selectedMap = ""
    var selectedBotNames: [String] = []

    private var displayTiers: [String] = []
    private var displayMaps: [[(map: String, name: String)]] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        rebuildMapList()

        tiersList.mask = nil
        tiersList.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NSLog("[Q3Quit] TiersListViewController viewDidAppear window=%@ tableInteractive=%d viewInteractive=%d",
              String(describing: view.window),
              tiersList.isUserInteractionEnabled,
              view.isUserInteractionEnabled)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        NSLog("[Q3Quit] TiersListViewController touchesBegan count=%d", touches.count)
    }

    private func rebuildMapList() {
        guard let resourcePath = Bundle.main.resourcePath else {
            displayTiers = tiers
            displayMaps = maps
            return
        }

        let installed = MapCatalog.availableMaps(bundleResourcePath: resourcePath)
        displayTiers = []
        displayMaps = []

        for (index, tier) in tiers.enumerated() {
            let available = maps[index].filter { installed.contains($0.map.lowercased()) }
            if !available.isEmpty {
                displayTiers.append(tier)
                displayMaps.append(available)
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        NSLog("[Q3Quit] TiersListViewController prepare segue=%@ selectedMap=%@ destination=%@",
              segue.identifier ?? "nil",
              selectedMap,
              String(describing: type(of: segue.destination)))
        guard segue.identifier == "DifficultySegue",
              let difficultyVC = segue.destination as? DifficultyViewController else {
            return
        }
        difficultyVC.selectedMap = selectedMap
        difficultyVC.selectedBotNames = selectedBotNames
    }

    private func opponentNames(from mapTitle: String) -> [String] {
        guard let open = mapTitle.lastIndex(of: "("),
              let close = mapTitle[open...].firstIndex(of: ")") else {
            return []
        }

        return mapTitle[mapTitle.index(after: open)..<close]
            .split(separator: ",")
            .map { canonicalBotName(String($0).trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.isEmpty }
    }

    private func canonicalBotName(_ displayName: String) -> String {
        guard let resourcePath = Bundle.main.resourcePath else {
            return displayName
        }

        let normalizedDisplay = normalizedBotName(displayName)
        return BotCatalog.availableBots(bundleResourcePath: resourcePath)
            .first { normalizedBotName($0.name) == normalizedDisplay }?
            .name ?? displayName.replacingOccurrences(of: " ", with: "")
    }

    private func normalizedBotName(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

extension TiersListViewController : UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        NSLog("[Q3Quit] TiersListViewController didSelect section=%d row=%d", indexPath.section, indexPath.row)
        let selectedEntry = displayMaps[indexPath.section][indexPath.row]
        selectedMap = selectedEntry.map
        selectedBotNames = opponentNames(from: selectedEntry.name)
        if Sys_IsIOSMainLoopPaused().rawValue != 0,
           let difficultyVC = storyboard?.instantiateViewController(withIdentifier: "DifficultyViewController") as? DifficultyViewController {
            NSLog("[Q3Quit] TiersListViewController push DifficultyViewController without animation selectedMap=%@ bots=%@", selectedMap, selectedBotNames.joined(separator: ","))
            difficultyVC.selectedMap = selectedMap
            difficultyVC.selectedBotNames = selectedBotNames
            navigationController?.pushViewController(difficultyVC, animated: false)
            return
        }
        NSLog("[Q3Quit] TiersListViewController perform DifficultySegue selectedMap=%@", selectedMap)
        performSegue(withIdentifier: "DifficultySegue", sender: self)
    }
    
}

extension TiersListViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayMaps[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tiersList.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = displayMaps[indexPath.section][indexPath.row].name
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return displayTiers[section]
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return displayMaps.count
    }
}
