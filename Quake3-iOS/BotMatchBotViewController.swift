//
//  BotMatchBotViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 12/4/19.
//  Copyright © 2019 Tom Kidd. All rights reserved.
//

import UIKit

class BotMatchBotViewController: UIViewController {

    @IBOutlet weak var botGrid: UICollectionView!
    @IBOutlet weak var okButton: UIButton!
        
    @IBOutlet weak var skill1Button: UIButton!
    @IBOutlet weak var skill2Button: UIButton!
    @IBOutlet weak var skill3Button: UIButton!
    @IBOutlet weak var skill4Button: UIButton!
    @IBOutlet weak var skill5Button: UIButton!
    
    @IBOutlet weak var quantityLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var subtractButton: UIButton!

    var delegate: BotMatchProtocol?

    /// Mode pause in-game : envoie les bots choisis au callback au lieu du delegate Bot Match.
    struct PendingBot {
        let name: String
        let skill: Float
    }
    var onBotsConfirmed: (([PendingBot]) -> Void)?
    var onCancelled: (() -> Void)?

    var difficulty: Float = 3.0
    var selectedBot = ""
    var selectedIcon = ""
    var botQuantity = 1

    private var catalogBots: [BotCatalog.Bot] {
        guard let resourcePath = Bundle.main.resourcePath else { return [] }
        return BotCatalog.availableBots(bundleResourcePath: resourcePath)
    }

    private var bots: [(name: String, icon: String)] {
        catalogBots.map { ($0.name, $0.icon) }
    }

    private func botAt(_ index: Int) -> BotCatalog.Bot? {
        guard index >= 0, index < catalogBots.count else { return nil }
        return catalogBots[index]
    }

    private var documentsDirectory: String {
        #if os(tvOS)
        return (try? FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path) ?? ""
        #else
        return (try? FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path) ?? ""
        #endif
    }
    var skills:[String: Float] = ["0.0": 0.0,
                                  "0.5": 0.5,
                                  "1.0": 1.0,
                                  "1.5": 1.5,
                                  "2.0": 2.0,
                                  "2.5": 2.5,
                                  "3.0": 3.0,
                                  "3.5": 3.5,
                                  "4.0": 4.0,
                                  "4.5": 4.5,
                                  "5.0": 5.0]

    override func viewDidLoad() {
        super.viewDidLoad()
        okButton.isEnabled = false
        view.isUserInteractionEnabled = true
        botGrid.isUserInteractionEnabled = true
        botGrid.allowsSelection = true
        botGrid.dataSource = self
        botGrid.delegate = self

        #if os(tvOS)
        let documentsDir = try! FileManager().url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path
        #else
        let documentsDir = try! FileManager().url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).path
        #endif

        var skill1URL = URL(fileURLWithPath: documentsDir)
        skill1URL.appendPathComponent("graphics/menu/art/skill1.tga")
        skill1Button.setImage(UIImage.image(fromTGAFile: skill1URL.path) as? UIImage, for: .normal)
        skill1Button.layer.borderColor = UIColor.red.cgColor
        
        var skill2URL = URL(fileURLWithPath: documentsDir)
        skill2URL.appendPathComponent("graphics/menu/art/skill2.tga")
        skill2Button.setImage(UIImage.image(fromTGAFile: skill2URL.path) as? UIImage, for: .normal)
        skill2Button.layer.borderColor = UIColor.red.cgColor

        var skill3URL = URL(fileURLWithPath: documentsDir)
        skill3URL.appendPathComponent("graphics/menu/art/skill3.tga")
        skill3Button.setImage(UIImage.image(fromTGAFile: skill3URL.path) as? UIImage, for: .normal)
        skill3Button.layer.borderColor = UIColor.red.cgColor
        skill3Button.layer.borderWidth = 2

        var skill4URL = URL(fileURLWithPath: documentsDir)
        skill4URL.appendPathComponent("graphics/menu/art/skill4.tga")
        skill4Button.setImage(UIImage.image(fromTGAFile: skill4URL.path) as? UIImage, for: .normal)
        skill4Button.layer.borderColor = UIColor.red.cgColor

        var skill5URL = URL(fileURLWithPath: documentsDir)
        skill5URL.appendPathComponent("graphics/menu/art/skill5.tga")
        skill5Button.setImage(UIImage.image(fromTGAFile: skill5URL.path) as? UIImage, for: .normal)
        skill5Button.layer.borderColor = UIColor.red.cgColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        botGrid.reloadData()
    }
    
    @IBAction func skill(_ sender: UIButton) {
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
        
        let skillKeys = Array(skills.keys).sorted()
        for skill in skillKeys {
            alert.addAction(UIAlertAction(title: skill, style: .default, handler: { (action) in
                sender.setTitle(action.title, for: .normal)
                self.difficulty = self.skills[action.title!]!
            }))
        }
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBAction func cancel(_ sender: UIButton) {
        let cancelled = onCancelled
        dismiss(animated: true) {
            cancelled?()
        }
    }

    @IBAction func ok(_ sender: UIButton) {
        guard !selectedBot.isEmpty else { return }

        if let onBotsConfirmed {
            var pending: [PendingBot] = []
            pending.reserveCapacity(botQuantity)
            for _ in 0..<botQuantity {
                pending.append(PendingBot(name: selectedBot, skill: difficulty))
            }
            let confirmed = onBotsConfirmed
            dismiss(animated: true) {
                confirmed(pending)
            }
            return
        }

        for _ in 0..<botQuantity {
            delegate?.addBot(bot: selectedBot, difficulty: difficulty, icon: selectedIcon)
        }

        dismiss(animated: true, completion: nil)
    }
    
    func clearSkills(_ sender: UIButton) {
        skill1Button.layer.borderWidth = 0
        skill2Button.layer.borderWidth = 0
        skill3Button.layer.borderWidth = 0
        skill4Button.layer.borderWidth = 0
        skill5Button.layer.borderWidth = 0
        sender.layer.borderWidth = 1
    }

    @IBAction func skill1(_ sender: UIButton) {
        self.difficulty = 1
        clearSkills(sender)
    }
    
    @IBAction func skill2(_ sender: UIButton) {
        self.difficulty = 2
        clearSkills(sender)
    }
    
    @IBAction func skill3(_ sender: UIButton) {
        self.difficulty = 3
        clearSkills(sender)
    }
    
    @IBAction func skill4(_ sender: UIButton) {
        self.difficulty = 4
        clearSkills(sender)
    }
    
    @IBAction func skill5(_ sender: UIButton) {
        self.difficulty = 5
        clearSkills(sender)
    }
    
    @IBAction func incrementBotQuantity(_ sender: UIButton) {
        botQuantity += 1
        quantityLabel.text = String(botQuantity)
    }
    
    @IBAction func decrementBotQuantity(_ sender: UIButton) {
        if botQuantity > 1 {
            botQuantity -= 1
            quantityLabel.text = String(botQuantity)
        }
    }
    

    
}

extension BotMatchBotViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        bots.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BotCollectionViewCell
        let bot = bots[indexPath.row]
        let resourcePath = Bundle.main.resourcePath ?? ""

        if let catalogBot = botAt(indexPath.row),
           let image = BotCatalog.loadIconImage(
               for: catalogBot,
               bundleResourcePath: resourcePath,
               documentsDir: documentsDirectory
           ) {
            cell.botAvatar.contentMode = .scaleAspectFit
            cell.botAvatar.image = image
        } else {
            cell.botAvatar.image = nil
        }

        cell.botName.text = bot.name

        if bots[indexPath.row].name == selectedBot {
            cell.botAvatar.layer.borderColor = UIColor.red.cgColor
            cell.botAvatar.layer.borderWidth = 1
        } else {
            cell.botAvatar.layer.borderColor = UIColor.black.cgColor
            cell.botAvatar.layer.borderWidth = 0
        }


        return cell
    }
}

extension BotMatchBotViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let cell = collectionView.cellForItem(at: indexPath) as! BotCollectionViewCell
        self.selectedBot = bots[indexPath.row].name
        self.selectedIcon = bots[indexPath.row].icon
        okButton.isEnabled = true
        cell.botAvatar.layer.borderColor = UIColor.red.cgColor
        cell.botAvatar.layer.borderWidth = 1
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            (cell as! BotCollectionViewCell).botAvatar.layer.borderColor = UIColor.black.cgColor
            (cell as! BotCollectionViewCell).botAvatar.layer.borderWidth = 0
        }
    }
}

extension BotMatchBotViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: 64, height: 100)
    }
}
