import SwiftUI

struct UpdateStatusView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var updates = model.updates
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text(L10n.text("Current version: %@", updates.currentVersion)).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                if updates.isChecking { ProgressView().controlSize(.small) }
            }
            switch updates.state {
            case .idle:
                Text(L10n.text("Check GitHub for the latest XcodeFit release."))
            case .checking:
                Text(L10n.text("Checking for updates…"))
            case .current:
                Label(L10n.text("You’re up to date."), systemImage: "checkmark.circle")
            case .available(let release):
                Label(L10n.text("XcodeFit %@ is available.", release.version), systemImage: "arrow.down.circle")
                    .fontWeight(.semibold).foregroundStyle(FitPalette.accent)
                Link(L10n.text("Open Download Page"), destination: release.pageURL).buttonStyle(.borderedProminent)
                Text(L10n.text("Using Homebrew? Run brew update, then brew upgrade --cask xcodefit."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
            case .failed(let failure):
                Text(failure.message).foregroundStyle(.secondary)
            }
            if let date = updates.lastChecked {
                HStack(spacing: 4) {
                    Text(L10n.text("Last successful check:"))
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                }.font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Toggle(L10n.text("Automatically check for updates"), isOn: $updates.automaticallyChecks)
                .onChange(of: updates.automaticallyChecks) { _, enabled in
                    if enabled { Task { await updates.check(automatically: true) } }
                }
            Text(L10n.text("Checks GitHub at launch or when returning to the app, at most once a day. No file data is sent. Updates are never installed automatically."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            Button(L10n.text("Check for Updates…")) { Task { await updates.check() } }.disabled(updates.isChecking)
        }.font(.system(size: 12)).textSelection(.enabled)
    }
}

struct UpdateCheckView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                Image("FitMascot").resizable().scaledToFit().frame(width: 62, height: 62)
                Text(L10n.text("XcodeFit Updates")).font(.system(size: 22, weight: .bold, design: .rounded))
            }
            UpdateStatusView()
            HStack { Spacer(); Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.defaultAction) }
        }.padding(26).frame(width: 500).background(FitPalette.canvas)
    }
}
