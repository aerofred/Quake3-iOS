//
//  BotCatalog.swift
//  Quake3-iOS
//

import Foundation
import UIKit
import ZIPFoundation

enum BotCatalog {

    struct Bot: Hashable {
        let name: String
        let model: String

        var icon: String {
            BotCatalog.documentsIconPath(forModel: model)
        }
    }

    private static var cachedBots: [Bot]?

    static func availableBots(bundleResourcePath: String) -> [Bot] {
        if let cachedBots {
            return cachedBots
        }

        var byName: [String: Bot] = [:]
        for pk3URL in pk3URLs(bundleResourcePath: bundleResourcePath) {
            guard let archive = Archive(url: pk3URL, accessMode: .read) else { continue }

            if let botEntry = findEntry(in: archive, path: "scripts/bots.txt") {
                mergeBots(parseBotBlocks(from: readEntry(botEntry, from: archive)), into: &byName)
            }

            for botEntry in archive where !botEntry.path.hasSuffix("/") {
                let path = botEntry.path.lowercased()
                guard path.hasPrefix("scripts/"), path.hasSuffix(".bot") else { continue }
                mergeBots(parseBotBlocks(from: readEntry(botEntry, from: archive)), into: &byName)
            }
        }

        let bots = byName.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        cachedBots = bots
        return bots
    }

    static func resetCache() {
        cachedBots = nil
    }

    static func documentsIconPath(forModel model: String) -> String {
        let pakPath = playerIconPakPath(forModel: model)
        guard pakPath.hasPrefix("models/players/") else {
            return pakPath
        }
        return "graphics/" + pakPath.dropFirst("models/players/".count)
    }

    static func playerIconPakPath(forModel model: String) -> String {
        let parts = model.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if parts.count >= 2 {
            return "models/players/\(parts[0])/icon_\(parts[1]).tga"
        }
        let base = parts.first ?? model
        return "models/players/\(base)/icon_default.tga"
    }

    static func loadIconImage(
        for bot: Bot,
        bundleResourcePath: String,
        documentsDir: String
    ) -> UIImage? {
        let destination = documentsIconPath(forModel: bot.model)
        let destinationURL = URL(fileURLWithPath: documentsDir).appendingPathComponent(destination)

        if FileManager.default.fileExists(atPath: destinationURL.path),
           let image = UIImage.image(fromTGAFile: destinationURL.path) as? UIImage {
            return image
        }

        let pakPath = playerIconPakPath(forModel: bot.model)
        guard extractFromPk3(
            pakPath: pakPath,
            destinationPath: destination,
            bundleResourcePath: bundleResourcePath,
            documentsDir: documentsDir
        ) else {
            return nil
        }

        return UIImage.image(fromTGAFile: destinationURL.path) as? UIImage
    }

    // MARK: - Private

    private static func pk3URLs(bundleResourcePath: String) -> [URL] {
        let baseq3URL = URL(fileURLWithPath: bundleResourcePath).appendingPathComponent("baseq3")
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: baseq3URL,
            includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension.lowercased() == "pk3" }) else {
            return []
        }
        return urls.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private static func readEntry(_ entry: Entry, from archive: Archive) -> String {
        var data = Data()
        do {
            _ = try archive.extract(entry, consumer: { chunk in
                data.append(chunk)
            })
        } catch {
            return ""
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func mergeBots(_ blocks: [[String: String]], into byName: inout [String: Bot]) {
        for block in blocks {
            guard let name = block["name"], !name.isEmpty else { continue }
            let model = block["model"] ?? name.lowercased()
            byName[name] = Bot(name: name, model: model)
        }
    }

    private static func parseBotBlocks(from content: String) -> [[String: String]] {
        var blocks: [[String: String]] = []
        var index = content.startIndex

        while index < content.endIndex {
            guard skip(to: "{", in: content, index: &index) else { break }
            index = content.index(after: index)

            var block: [String: String] = [:]
            while index < content.endIndex {
                skipWhitespace(in: content, index: &index)
                if index < content.endIndex, content[index] == "}" {
                    index = content.index(after: index)
                    break
                }
                guard let key = readToken(in: content, index: &index)?.lowercased() else { break }
                guard let value = readToken(in: content, index: &index) else { break }
                block[key] = value
            }

            if block["name"] != nil {
                blocks.append(block)
            }
        }

        return blocks
    }

    private static func skip(to character: Character, in content: String, index: inout String.Index) -> Bool {
        while index < content.endIndex {
            if content[index] == character {
                return true
            }
            index = content.index(after: index)
        }
        return false
    }

    private static func skipWhitespace(in content: String, index: inout String.Index) {
        while index < content.endIndex, content[index].isWhitespace {
            index = content.index(after: index)
        }
    }

    private static func readToken(in content: String, index: inout String.Index) -> String? {
        skipWhitespace(in: content, index: &index)
        guard index < content.endIndex else { return nil }

        let start = index
        while index < content.endIndex, !content[index].isWhitespace {
            index = content.index(after: index)
        }
        let token = String(content[start..<index])
        return token.isEmpty ? nil : token
    }

    @discardableResult
    private static func extractFromPk3(
        pakPath: String,
        destinationPath: String,
        bundleResourcePath: String,
        documentsDir: String
    ) -> Bool {
        let destinationURL = URL(fileURLWithPath: documentsDir).appendingPathComponent(destinationPath)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return true
        }

        try? FileManager.default.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        for pk3URL in pk3URLs(bundleResourcePath: bundleResourcePath) {
            guard let archive = Archive(url: pk3URL, accessMode: .read) else { continue }
            if let botEntry = findEntry(in: archive, path: pakPath) {
                do {
                    _ = try archive.extract(botEntry, to: destinationURL)
                    return true
                } catch {
                    continue
                }
            }
        }

        return false
    }

    private static func findEntry(in archive: Archive, path: String) -> Entry? {
        archive.first { $0.path.caseInsensitiveCompare(path) == .orderedSame }
    }
}
