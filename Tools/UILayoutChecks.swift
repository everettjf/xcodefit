import SwiftUI
import AppKit

private struct FramesKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
@MainActor private final class Measurements { var frames: [String: CGRect] = [:] }

private struct MeasuredHistory: View {
    let measurements: Measurements
    var body: some View {
        VStack(spacing: 0) {
            HistoryView().background {
                GeometryReader { geometry in Color.clear.preference(key: FramesKey.self, value: ["history": geometry.frame(in: .named("workspace"))]) }
            }
            ScanStatusBar().background {
                GeometryReader { geometry in Color.clear.preference(key: FramesKey.self, value: ["status": geometry.frame(in: .named("workspace"))]) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: "workspace")
        .onPreferenceChange(FramesKey.self) { frames in
            MainActor.assumeIsolated { measurements.frames = frames }
        }
    }
}
@main struct UILayoutChecks {
    @MainActor static func main() {
        precondition(CommandLine.arguments.contains("--ui-fixture"), "Use isolated test preferences")
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = AppModel()
        model.snapshot = ScanSnapshot()
        var checks = 0
        for hasHistory in [false, true] {
            model.history = hasHistory ? [CleanupRecord(name: "Fixture", path: "/test/fixture", action: "Move to Trash", bytes: 4096, outcome: .skipped, message: "Test record")] : []
            for size in [NSSize(width: 850, height: 628), NSSize(width: 1048, height: 774), NSSize(width: 1670, height: 966)] {
                let measurements = Measurements()
                let hosting = NSHostingView(rootView: MeasuredHistory(measurements: measurements).environment(model))
                hosting.sizingOptions = []
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
                window.contentView = hosting
                window.setContentSize(size)
                window.orderBack(nil)
                let deadline = Date(timeIntervalSinceNow: 0.3)
                while Date() < deadline {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
                    hosting.layoutSubtreeIfNeeded()
                }
                guard let history = measurements.frames["history"], let status = measurements.frames["status"] else { fatalError("No layout measurements") }
                precondition(abs(history.minY) < 1, "History must begin at the top: \(history)")
                precondition(abs(history.width - hosting.bounds.width) < 1, "History must fill available width: \(history)")
                precondition(abs(status.maxY - hosting.bounds.height) < 1, "Status must stay at the bottom: \(status) in \(size)")
                precondition(abs(history.maxY - status.minY) < 1, "History and status must be adjacent")
                print("PASS history=\(hasHistory ? "populated" : "empty") \(Int(size.width))x\(Int(size.height)) history=\(history) status=\(status)")
                checks += 1
                window.orderOut(nil)
            }
        }
        print("\(checks) native layout checks passed")
    }
}
