#if DEBUG
import Foundation

/// Only enabled by an explicit development launch argument. Never reads real developer data.
enum DebugFixture {
    static func make() throws -> URL {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("XcodeSizeUIFixture-" + UUID().uuidString).resolvingSymlinksInPath()
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
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in walker { try fm.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -200 * 86400)], ofItemAtPath: url.path) }
        }
        return root
    }
}
#endif
