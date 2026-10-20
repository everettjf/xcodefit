import SwiftUI

@main struct XcodeSizeApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            ContentView().environment(model).environment(\.locale, model.language.locale).id(model.language).tint(.blue)
        }
        .defaultSize(width: 1260, height: 820)
        .windowStyle(.automatic)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.text("Settings…")) { model.settingsPresented = true }.keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu(L10n.text("Scan")) {
                Button(L10n.text("Rescan")) { model.startScan() }.keyboardShortcut("r", modifiers: .command).disabled(model.isScanning || model.isCleaning)
                Button(L10n.text("Stop Scan")) { model.cancelScan() }.disabled(!model.isScanning)
                Button(L10n.text("Add Scan Location…")) { model.addFolderPresented = true }.disabled(model.isScanning || model.isCleaning)
            }
            CommandGroup(after: .sidebar) {
                Button(L10n.text("Show / Hide Inspector")) { model.inspectorVisible.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
            }
        }
    }
}
