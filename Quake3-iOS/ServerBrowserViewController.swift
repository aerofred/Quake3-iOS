//
//  ServerBrowserViewController.swift
//  Quake3-iOS
//
//  Created by Tom Kidd on 8/4/18.
//  Copyright © 2018 Tom Kidd. All rights reserved.
//

import UIKit
import Darwin

protocol ServerFilterProtocol {
    func setGameTypeFilter(gameTypeFilter:String, gameTypeFilterTitle: String)
    func setModFilter(modFilter:String, modFilterTitle: String)
    func setSortOption(sortOption: String, sortOptionTitle: String)
    func setShowFull(showFull: Bool)
    func setShowEmpty(showEmpty: Bool)
}

class ServerBrowserViewController: UIViewController {
    
    private var currentGame: Game?
    private var coordinator: Coordinator?
    private var servers = [Server]()
    private var filteredServers = [Server]()
    private var selectedServer: Server?
    var gameTypeFilter = ""
    var gameTypeFilterTitle = "Any"
    var modFilter = ""
    var modFilterTitle = "Any"
    var sortOption = "ping"
    var sortOptionTitle = "Ping"
    var showEmpty = true
    var showFull = true
    var busy = false
    private let hostButton = UIButton(type: .system)
    private let joinIPButton = UIButton(type: .system)
    private let fetchButton = UIButton(type: .system)
    private let localIPLabel = UILabel()

    @IBOutlet weak var serversList: UITableView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var activityInfo: UILabel!
    @IBOutlet weak var fightButton: UIButton!
    @IBOutlet weak var serverInfoButton: UIButton!
    @IBOutlet weak var filterButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let game = Game(type: .quake3, launchArguments: "+connect")
        currentGame = game
        coordinator = game.type.coordinator
        coordinator?.delegate = self
        serversList.register(UINib(nibName: "ServerListViewCell", bundle: nil), forCellReuseIdentifier: "cell")
        serversList.mask = nil

        activityIndicator.stopAnimating()
        activityInfo.text = "Tap FETCH to search servers"

        #if os(iOS)
        filterButton.titleLabel?.font = UIFont.fontAwesome(ofSize: 18, style: .solid)
        #endif
        #if os(tvOS)
        filterButton.titleLabel?.font = UIFont.fontAwesome(ofSize: 36, style: .solid)
        #endif
        filterButton.setTitle(String.fontAwesomeIcon(name: .filter), for: .normal)
        installHostButton()
        installJoinIPButton()
        installFetchButton()
        installLocalIPLabel()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "StartMultiplayerGameSegue", let server = selectedServer {
            GameSession.configureForMultiplayer(server: server)
            (segue.destination as! GameViewController).selectedServer = server
        } else if segue.identifier == "ServerInfoSegue" {
            (segue.destination as! ServerInfoViewController).server = selectedServer
        } else if segue.identifier == "ServerFilterSegue" {
            (segue.destination as! ServerFilterViewController).delegate = self
            (segue.destination as! ServerFilterViewController).sortOptionTitle = self.sortOptionTitle
            (segue.destination as! ServerFilterViewController).modFilterTitle = self.modFilterTitle
            (segue.destination as! ServerFilterViewController).gameTypeFilterTitle = self.gameTypeFilterTitle
            (segue.destination as! ServerFilterViewController).showEmpty = self.showEmpty
            (segue.destination as! ServerFilterViewController).showFull = self.showFull
        }
    }
    
    @IBAction func exitToServerBrowser(segue: UIStoryboardSegue) {
    }
    
    @IBAction func getServerInfo(_ sender: UIButton) {
        coordinator?.status(forServer: selectedServer!)
    }

    private func installHostButton() {
        hostButton.translatesAutoresizingMaskIntoConstraints = false
        styleTopButton(hostButton, title: "HOST")
        hostButton.addTarget(self, action: #selector(hostButtonTapped), for: .touchUpInside)
        view.addSubview(hostButton)

        NSLayoutConstraint.activate([
            hostButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            hostButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    private func installJoinIPButton() {
        joinIPButton.translatesAutoresizingMaskIntoConstraints = false
        styleTopButton(joinIPButton, title: "JOIN IP")
        joinIPButton.addTarget(self, action: #selector(joinIPButtonTapped), for: .touchUpInside)
        view.addSubview(joinIPButton)

        NSLayoutConstraint.activate([
            joinIPButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 6),
            joinIPButton.trailingAnchor.constraint(equalTo: hostButton.leadingAnchor, constant: -18)
        ])
    }

    private func installFetchButton() {
        fetchButton.translatesAutoresizingMaskIntoConstraints = false
        fetchButton.setTitle("FETCH", for: .normal)
        fetchButton.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        fetchButton.setTitleColor(.black, for: .normal)
        fetchButton.addTarget(self, action: #selector(fetchButtonTapped), for: .touchUpInside)

        if let statusStack = activityInfo.superview as? UIStackView {
            statusStack.insertArrangedSubview(fetchButton, at: 0)
        } else {
            view.addSubview(fetchButton)
            NSLayoutConstraint.activate([
                fetchButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
                fetchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
            ])
        }
    }

    private func installLocalIPLabel() {
        localIPLabel.translatesAutoresizingMaskIntoConstraints = false
        localIPLabel.text = "IP: \(localIPAddress() ?? "unavailable")"
        localIPLabel.textColor = .black
        localIPLabel.font = UIFont(name: "AvenirNextCondensed-Bold", size: 17) ?? UIFont.boldSystemFont(ofSize: 17)
        localIPLabel.adjustsFontSizeToFitWidth = true
        localIPLabel.minimumScaleFactor = 0.65
        view.addSubview(localIPLabel)

        NSLayoutConstraint.activate([
            localIPLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            localIPLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 42),
            localIPLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            localIPLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    private func styleTopButton(_ button: UIButton, title: String) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont(name: "AvenirNext-Bold", size: 28) ?? UIFont.boldSystemFont(ofSize: 28)
        button.setTitleColor(UIColor(red: 1, green: 0.009361755543, blue: 0, alpha: 1), for: .normal)
        button.setTitleShadowColor(.black, for: .normal)
        button.titleLabel?.shadowOffset = CGSize(width: 1, height: 1)
    }

    @objc private func fetchButtonTapped() {
        startServerFetch()
    }

    private func startServerFetch() {
        guard !busy, let masterServer = masterServerAddress() else {
            return
        }

        selectedServer = nil
        servers.removeAll()
        filteredServers.removeAll()
        serversList.reloadData()
        fightButton.isHidden = true
        serverInfoButton.isHidden = true
        activityInfo.text = "Fetching servers..."
        activityIndicator.startAnimating()
        fetchButton.isEnabled = false

        coordinator?.getServersList(host: masterServer.host, port: masterServer.port)
    }

    private func masterServerAddress() -> (host: String, port: String)? {
        guard let masterServer = SupportedGames.quake3.masterServersList.first else {
            return nil
        }

        let components = masterServer.components(separatedBy: ":")
        guard let host = components.first, let port = components.last, !host.isEmpty, !port.isEmpty else {
            return nil
        }
        return (host, port)
    }

    @objc private func hostButtonTapped() {
        let maps = hostedMapChoices()
        guard !maps.isEmpty else {
            return
        }

        let alert = UIAlertController(title: "Host Game", message: "Choose a map", preferredStyle: .actionSheet)
        for map in maps {
            alert.addAction(UIAlertAction(title: map.uppercased(), style: .default) { [weak self] _ in
                self?.startHostedGame(map: map)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = hostButton
        alert.popoverPresentationController?.sourceRect = hostButton.bounds
        present(alert, animated: true)
    }

    private func hostedMapChoices() -> [String] {
        let resourcePath = Bundle.main.resourcePath ?? ""
        let maps = MapCatalog.availableMaps(bundleResourcePath: resourcePath).sorted()
        if maps.isEmpty {
            return ["q3dm1"]
        }
        let stockMaps = maps.filter { $0.hasPrefix("q3dm") || $0.hasPrefix("q3tourney") }
        return stockMaps.isEmpty ? maps : stockMaps
    }

    private func startHostedGame(map: String) {
        guard let gameVC = storyboard?.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController else {
            return
        }

        let mapName = map.lowercased()
        GameSession.configureForHostedMultiplayer(map: mapName)
        gameVC.selectedMap = mapName
        gameVC.hostMultiplayer = true

        let isMainLoopPaused = Sys_IsIOSMainLoopPaused().rawValue != 0
        navigationController?.pushViewController(gameVC, animated: !isMainLoopPaused)
        if isMainLoopPaused {
            navigationController?.view.setNeedsLayout()
            navigationController?.view.layoutIfNeeded()
            gameVC.activateAfterPausedMenuNavigation()
        }
    }

    @objc private func joinIPButtonTapped() {
        let localPrefix = localNetworkPrefix()
        let savedAddress = UserDefaults.standard.string(forKey: "lastJoinIPAddress")
        let defaultText = compactJoinAddress(savedAddress, localPrefix: localPrefix)
        let placeholder = localPrefix.map { "\($0).42" } ?? "192.168.1.42"
        let alert = UIAlertController(
            title: "Join IP",
            message: localPrefix.map { "Enter the last number for \($0).x, or a full IP" } ?? "Enter the host iPhone IP and port",
            preferredStyle: .alert
        )
        alert.addTextField { textField in
            textField.placeholder = "\(placeholder):27960"
            textField.text = defaultText
            textField.keyboardType = .numbersAndPunctuation
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Connect", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text else { return }
            self?.connectToManualAddress(text)
        })
        present(alert, animated: true)
    }

    private func connectToManualAddress(_ address: String) {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        let hostInput = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let port = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespacesAndNewlines) : "27960"
        let host = expandedLANAddress(from: hostInput)
        guard !host.isEmpty, !port.isEmpty else { return }

        UserDefaults.standard.set("\(host):\(port)", forKey: "lastJoinIPAddress")
        startManualJoin(server: Q3Server(ip: host, port: port))
    }

    private func expandedLANAddress(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("."),
              let octet = Int(trimmed),
              (0...255).contains(octet),
              let prefix = localNetworkPrefix() else {
            return trimmed
        }

        return "\(prefix).\(octet)"
    }

    private func compactJoinAddress(_ address: String?, localPrefix: String?) -> String? {
        guard let address = address, let localPrefix = localPrefix else {
            return address
        }

        let parts = address.split(separator: ":", maxSplits: 1).map(String.init)
        guard let host = parts.first, host.hasPrefix("\(localPrefix).") else {
            return address
        }

        let lastOctet = String(host.dropFirst(localPrefix.count + 1))
        guard Int(lastOctet) != nil else {
            return address
        }

        if parts.count > 1, parts[1] != "27960" {
            return "\(lastOctet):\(parts[1])"
        }
        return lastOctet
    }

    private func localNetworkPrefix() -> String? {
        guard let address = localIPAddress() else { return nil }
        var octets = address.split(separator: ".").map(String.init)
        guard octets.count == 4 else { return nil }
        octets.removeLast()
        return octets.joined(separator: ".")
    }

    private func startManualJoin(server: Server) {
        guard let gameVC = storyboard?.instantiateViewController(withIdentifier: "GameViewController") as? GameViewController else {
            return
        }

        GameSession.configureForMultiplayer(server: server)
        gameVC.selectedServer = server

        let isMainLoopPaused = Sys_IsIOSMainLoopPaused().rawValue != 0
        navigationController?.pushViewController(gameVC, animated: !isMainLoopPaused)
        if isMainLoopPaused {
            navigationController?.view.setNeedsLayout()
            navigationController?.view.layoutIfNeeded()
            gameVC.activateAfterPausedMenuNavigation()
        }
    }

    private func localIPAddress() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }

        var fallbackAddress: String?
        var pointer = interfaces
        while pointer != nil {
            guard let interface = pointer?.pointee,
                  interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) else {
                pointer = pointer?.pointee.ifa_next
                continue
            }

            let name = String(cString: interface.ifa_name)
            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(
                interface.ifa_addr,
                socklen_t(interface.ifa_addr.pointee.sa_len),
                &hostname,
                socklen_t(hostname.count),
                nil,
                0,
                NI_NUMERICHOST
            )

            if result == 0 {
                let address = String(cString: hostname)
                if name == "en0" {
                    return address
                }
                if name != "lo0" && fallbackAddress == nil {
                    fallbackAddress = address
                }
            }

            pointer = pointer?.pointee.ifa_next
        }

        return fallbackAddress
    }
    

}

extension ServerBrowserViewController: CoordinatorDelegate {
    func didStartFetchingServersList(for coordinator: Coordinator) {
        print("didStartFetchingServersList")
        DispatchQueue.main.async {
            self.busy = true
        }
    }
    
    func didFinishFetchingServersList(for coordinator: Coordinator) {
        print("didFinishFetchingServersList")        
        coordinator.fetchServersInfo()
    }
    
    func didFinishFetchingServersInfo(for coordinator: Coordinator) {
        print("didFinishFetchingServersInfo")
        DispatchQueue.main.async {
            self.busy = false
            self.activityIndicator.stopAnimating()
            self.fetchButton.isEnabled = true
            var filterString = ""
            if self.servers.count != self.filteredServers.count {
                filterString = " (\(self.filteredServers.count) shown)"
            }
            self.activityInfo.text = "\(self.servers.count) servers found\(filterString)"
        }
    }
    
    private func filterServers() {
        
        self.filteredServers = []
        
        for server in self.servers {
            
            var gameTypeMatch = true
            var modMatch = true
            var sizeMatch = true
            
            if !self.gameTypeFilter.isEmpty {
                if server.gametype != self.gameTypeFilter {
                    gameTypeMatch = false
                }
            }
            
            if !self.modFilter.isEmpty {
                if server.mod != self.modFilter {
                    modMatch = false
                }
            }
            
            if let currentPlayers = Int(server.currentPlayers), let maxPlayers = Int(server.maxPlayers) {
                if !showFull {
                    if currentPlayers == maxPlayers {
                        sizeMatch = false
                    }
                }
                
                if !showEmpty {
                    if currentPlayers == 0 {
                        sizeMatch = false
                    }
                }
            }

            if gameTypeMatch && modMatch && sizeMatch {
                self.filteredServers.append(server)
            }
            
        }
        
        self.filteredServers = self.filteredServers.sorted(by: { (s1, s2) -> Bool in
            
            if self.sortOption == "ping" {
                
                let s1ping = Int(s1.ping)!
                let s2ping = Int(s2.ping)!
                
                return s2ping > s1ping
            } else if self.sortOption == "servername" {
                return s2.name > s1.name
            } else if self.sortOption == "gametype" {
                return s2.gametype > s1.gametype
            }
            
            return true
        })
        
        self.serversList.reloadData()
        
        if !busy {
            var filterString = ""
            if self.servers.count != self.filteredServers.count {
                filterString = " (\(self.filteredServers.count) shown)"
            }
            self.activityInfo.text = "\(self.servers.count) servers found\(filterString)"
        }        

    }
    
    func coordinator(_ coordinator: Coordinator, didFinishFetchingInfoFor server: Server) {
        DispatchQueue.main.async {
            self.servers.append(server)
            
            print("gametype: \(server.gametype) map: \(server.map) mod: \(server.mod)")
            
            self.filterServers()
        }
        print("didFinishFetchingInfoFor \(server.name)")
    }
    
    func coordinator(_ coordinator: Coordinator, didFinishFetchingStatusFor server: Server) {
        DispatchQueue.main.async {
            self.selectedServer = server
            self.performSegue(withIdentifier: "ServerInfoSegue", sender: self)
        }
        print("didFinishFetchingStatusFor")
    }
    
    func coordinator(_ coordinator: Coordinator, didFailWith error: SQLError) {
        print("didFailWith \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.busy = false
            self.activityIndicator.stopAnimating()
            self.fetchButton.isEnabled = true
            self.activityInfo.text = "Server fetch failed"
        }
    }
    
    
}

extension ServerBrowserViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedServer = filteredServers[indexPath.row]
        fightButton.isHidden = false
        serverInfoButton.isHidden = false
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        #if os(iOS)
        return 100
        #endif
        #if os(tvOS)
        return 200
        #endif
    }
}

extension ServerBrowserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredServers.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ServerListViewCell
        let server = filteredServers[indexPath.row]
        
        cell.serverName.text = server.name
        cell.ping.text = server.ping
        if let ping = Int(server.ping) {
            if ping <= 60 {
                cell.ping.textColor = UIColor.green
            } else if ping <= 100 {
                cell.ping.textColor = UIColor.orange
            } else {
                cell.ping.textColor = UIColor.red
            }
        }
        cell.gameType.text = server.gametype
        cell.ipAddress.text = "\(server.ip):\(server.port)"
        cell.mapName.text = server.map
        cell.modName.text = server.mod
        cell.playerCount.text = "(\(server.currentPlayers)/\(server.maxPlayers))"

        return cell
    }
    
    
}

extension ServerBrowserViewController: ServerFilterProtocol {
    func setShowFull(showFull: Bool) {
        self.showFull = showFull
        self.filterServers()
    }
    
    func setShowEmpty(showEmpty: Bool) {
        self.showEmpty = showEmpty
        self.filterServers()
    }
    
    func setGameTypeFilter(gameTypeFilter: String, gameTypeFilterTitle: String) {
        self.gameTypeFilter = gameTypeFilter
        self.gameTypeFilterTitle = gameTypeFilterTitle
        self.filterServers()
    }
    
    func setModFilter(modFilter: String, modFilterTitle: String) {
        self.modFilter = modFilter
        self.modFilterTitle = modFilterTitle
        self.filterServers()
    }
    
    func setSortOption(sortOption: String, sortOptionTitle: String) {
        self.sortOption = sortOption
        self.sortOptionTitle = sortOptionTitle
        self.filterServers()
    }
}
