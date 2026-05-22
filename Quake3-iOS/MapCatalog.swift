//
//  MapCatalog.swift
//  Quake3-iOS
//

import Foundation
import ZIPFoundation

enum MapCatalog {

    private static var cachedMaps: Set<String>?

    /// Noms de cartes (ex. q3dm18) dont le fichier maps/<nom>.bsp existe dans les .pk3.
    static func availableMaps(bundleResourcePath: String) -> Set<String> {
        if let cachedMaps {
            return cachedMaps
        }

        var maps = Set<String>()
        let baseq3URL = URL(fileURLWithPath: bundleResourcePath).appendingPathComponent("baseq3")

        guard let pk3URLs = try? FileManager.default.contentsOfDirectory(
            at: baseq3URL,
            includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension.lowercased() == "pk3" }) else {
            cachedMaps = maps
            return maps
        }

        for pk3URL in pk3URLs {
            guard let archive = Archive(url: pk3URL, accessMode: .read) else { continue }
            for entry in archive where !entry.path.hasSuffix("/") {
                let path = entry.path.lowercased()
                guard path.hasPrefix("maps/"), path.hasSuffix(".bsp") else { continue }
                let fileName = (path as NSString).lastPathComponent
                let mapName = (fileName as NSString).deletingPathExtension
                maps.insert(mapName)
            }
        }

        cachedMaps = maps
        return maps
    }

    static func isMapAvailable(_ map: String, bundleResourcePath: String) -> Bool {
        availableMaps(bundleResourcePath: bundleResourcePath).contains(map.lowercased())
    }

    static func resetCache() {
        cachedMaps = nil
    }
}
