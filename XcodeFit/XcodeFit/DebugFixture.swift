#if DEBUG
import Foundation

/// Only enabled by an explicit development launch argument. Never reads real developer data.
enum DebugFixture {
    static func make() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("XcodeFitUIFixture-" + UUID().uuidString).resolvingSymlinksInPath()
        let files: [(String, Int)] = [
            ("Library/Developer/Xcode/DerivedData/Atlas-hash/Build/Products/Atlas.app/Contents/MacOS/Atlas", 1048576),
            ("Library/Developer/Xcode/DerivedData/Atlas-hash/Index.noindex/DataStore/index", 262144),
            ("Library/Developer/Xcode/DerivedData/Atlas-hash/SourcePackages/checkouts/package/source.swift", 32768),
            ("Library/Developer/Xcode/DerivedData/ModuleCache.noindex/modules.pcm", 524288),
            ("Library/Developer/Xcode/DerivedData/CompilationCache.noindex/cas", 262144),
            ("Library/Developer/Xcode/Archives/2025-01-01/Atlas.xcarchive/dSYMs/Atlas.app.dSYM/Contents/Resources/DWARF/Atlas", 131072),
            ("Library/Developer/Xcode/iOS DeviceSupport/17.0/symbols", 32768),
            ("Library/Developer/Xcode/iOS DeviceSupport/18.0/symbols", 32768),
            ("Library/Developer/Xcode/iOS DeviceSupport/19.0/symbols", 32768),
            ("Library/Developer/Xcode/UserData/CodeSnippets/keep.codesnippet", 1024),
            ("Library/Developer/Xcode/iOS Device Logs/old.log", 4096)
        ]
        for (path, size) in files {
            let url = root.appendingPathComponent(path)
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(repeating: 65, count: size).write(to: url)
        }
        let plist: [String: Any] = ["WorkspacePath": root.appendingPathComponent("Projects/Atlas.xcodeproj").path]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: root.appendingPathComponent("Library/Developer/Xcode/DerivedData/Atlas-hash/info.plist"))
        for (index, version) in ["1.9", "1.10", "2.0", "2.1", "2.1"].enumerated() {
            let archive = root.appendingPathComponent("Library/Developer/Xcode/Archives/2025-01-01/Atlas-" + String(index) + ".xcarchive")
            let product = archive.appendingPathComponent("Products/Applications/Atlas.app")
            let dwarf = archive.appendingPathComponent("dSYMs/Atlas.app.dSYM/Contents/Resources/DWARF")
            try fm.createDirectory(at: product, withIntermediateDirectories: true)
            try fm.createDirectory(at: dwarf, withIntermediateDirectories: true)
            try fm.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: product.appendingPathComponent("Atlas"))
            try fm.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: dwarf.appendingPathComponent("Atlas"))
            let properties: [String: Any] = ["ApplicationPath": "Applications/Atlas.app", "CFBundleIdentifier": "com.example.Atlas", "CFBundleShortVersionString": version, "CFBundleVersion": String(100 + index), "Team": "EXAMPLE"]
            try PropertyListSerialization.data(fromPropertyList: ["Name": "Atlas", "ApplicationProperties": properties, "CreationDate": Date(timeIntervalSinceNow: Double(index - 10) * 86400)], format: .xml, options: 0).write(to: archive.appendingPathComponent("Info.plist"))
            try PropertyListSerialization.data(fromPropertyList: ["DTPlatformName": "macosx"], format: .xml, options: 0).write(to: product.appendingPathComponent("Info.plist"))
        }
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in walker { try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -200 * 86400)], ofItemAtPath: url.path) }
        }
        return root
    }
}
#endif
