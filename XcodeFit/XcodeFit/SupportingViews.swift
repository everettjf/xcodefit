import SwiftUI
import AppKit

struct CleanupReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let plan: CleanupPlan
    @State private var acknowledgeLoss = false
    @State private var acknowledgePermanent = false
    private var allowed: Bool { (!plan.hasIrreplaceableData || acknowledgeLoss) && (!plan.hasPermanentActions || acknowledgePermanent) }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "checklist").font(.system(size: 25)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Review Cleanup")).font(.system(size: 21, weight: .semibold))
                    Text(L10n.text("%@ · Items: %@ · %@ allocated", String(describing: (plan.tier.title)), String(describing: (plan.items.count)), String(describing: (StorageFormatting.bytes(plan.bytes))))).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(plan.items) { item in
                        HStack(alignment: .top, spacing: 11) {
                            Image(systemName: item.category.symbol).foregroundStyle(item.category.tint).frame(width: 20)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack { Text(item.name).fontWeight(.medium); Spacer(); Text(StorageFormatting.bytes(item.size)).monospacedDigit() }
                                if !item.subtitle.isEmpty { Text(item.subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary) }
                                Text(PathRules.compact(item.url)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                                Text(item.action.title).font(.system(size: 11, weight: .medium)).foregroundStyle(item.action.isPermanent ? .orange : .blue)
                                Text(item.purpose).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }.font(.system(size: 12)).padding(.vertical, 12)
                        Divider()
                    }
                }
            }.frame(maxHeight: 330)
            VStack(alignment: .leading, spacing: 11) {
                Label(L10n.text("Moving files to Trash does not immediately free space. Files and development tools will be checked again before cleanup."), systemImage: "info.circle")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if plan.hasIrreplaceableData {
                    Toggle(L10n.text("I have backed up the archives, release symbols, source changes, and local test data, or no longer need them."), isOn: $acknowledgeLoss).font(.system(size: 12))
                }
                if plan.hasPermanentActions {
                    Toggle(L10n.text("I understand that simctl permanently removes the selected devices or runtimes. These actions cannot be undone."), isOn: $acknowledgePermanent).font(.system(size: 12))
                }
            }
            HStack {
                Text(L10n.text("Xcode and simulators will not be forcibly closed.")).font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Cancel"), role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(L10n.text("Clean Selection (%@)", String(describing: (plan.items.count))), role: .destructive) { model.executePlan(plan) }.buttonStyle(.borderedProminent).tint(.red).disabled(!allowed || !model.canClean)
            }
        }.padding(27).frame(width: 650)
    }
}

struct CleanupResultsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    private var records: [CleanupRecord] { model.results ?? [] }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(L10n.text("Cleanup Results"), systemImage: "checkmark.circle").font(.system(size: 21, weight: .semibold))
            HStack(spacing: 24) {
                summary(L10n.text("Moved to Trash"), outcome: .trashed)
                summary(L10n.text("Permanently Removed"), outcome: .removed)
                summary(L10n.text("Skipped / Failed"), outcome: nil)
            }
            Text(L10n.text("Allocated size is not the same as reclaimed space. Trash, APFS shared blocks, snapshots, and background activity affect disk availability."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let change = model.capacityChange {
                Text(L10n.text("Observed change in available space: %@%@", String(describing: (change >= 0 ? "+" : "−")), String(describing: (StorageFormatting.bytes(abs(change))))))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(records) { record in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: record.outcome == .trashed || record.outcome == .removed ? "checkmark.circle.fill" : "exclamationmark.circle").foregroundStyle(record.outcome == .failed ? .red : record.outcome == .skipped ? .orange : .green)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.name).font(.system(size: 12, weight: .medium))
                                Text(record.message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
            }.frame(maxHeight: 270)
            HStack {
                Button(L10n.text("View Cleanup History")) { model.results = nil; model.navigate(.history); dismiss() }
                Spacer()
                Button(L10n.text("Done")) { model.results = nil; dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(27).frame(width: 600)
    }
    private func summary(_ title: String, outcome: CleanupRecord.Outcome?) -> some View {
        let values = records.filter { outcome == nil ? $0.outcome == .skipped || $0.outcome == .failed : $0.outcome == outcome }
        return VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(L10n.text("Items: %@ · %@", String(describing: (values.count)), String(describing: (StorageFormatting.bytes(values.reduce(0) { $0 + $1.bytes }))))).font(.system(size: 15, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}

struct CoverageView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("Every byte has a place.")) .font(.system(size: 25, weight: .semibold, design: .rounded))
                    Text(L10n.text("Review standard locations, custom folders, and inaccessible data. Totals include only identified, readable content.")) .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if let snapshot = model.snapshot {
                    HStack(spacing: 16) {
                        Label(snapshot.cancelled ? L10n.text("Canceled · Partial results") : L10n.text("Scan finished"), systemImage: snapshot.cancelled ? "stop.circle" : "checkmark.circle")
                        Text(L10n.text("Scan locations: %@", String(describing: (snapshot.scannedRoots.count))))
                        Text(L10n.text("Needs attention: %@", String(describing: (snapshot.notices.filter(\.isError).count))))
                    }.font(.system(size: 12)).foregroundStyle(snapshot.cancelled ? .orange : .secondary)
                    sectionTitle(L10n.text("Standard & Discovered Locations"))
                    ForEach(snapshot.scannedRoots, id: \.self) { path in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "folder").foregroundStyle(.blue)
                            Text(path).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    sectionTitle(L10n.text("Scan Notes & Incomplete Locations"))
                    ForEach(snapshot.notices) { notice in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: notice.isError ? "exclamationmark.circle" : "info.circle").foregroundStyle(notice.isError ? .orange : .secondary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(notice.path).font(.system(size: 11, weight: .medium)).textSelection(.enabled)
                                Text(notice.message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }.padding(.vertical, 3)
                    }
                } else { Text(model.isScanning ? L10n.text("Scanning. Coverage will appear when the scan finishes.") : L10n.text("No scan yet.")).foregroundStyle(.secondary) }
                sectionTitle(L10n.text("Custom Scan Locations"))
                Text(L10n.text("Xcode supports relative and custom build paths. Add their actual folders to include them in the scan.")) .font(.system(size: 12)).foregroundStyle(.secondary)
                ForEach(model.customRoots) { root in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) { Text(root.kind.title); Text(root.url.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary) }
                        Spacer()
                        Button(L10n.text("Remove Location")) { model.removeRoot(root) }.disabled(model.isScanning || model.isCleaning)
                    }.font(.system(size: 12))
                }
                Button(L10n.text("Add Scan Location…")) { model.addFolderPresented = true }.disabled(model.isScanning || model.isCleaning)
            }.padding(30).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private func sectionTitle(_ title: String) -> some View { Text(title).font(.system(size: 13, weight: .semibold)).padding(.top, 6) }
}

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Text(L10n.text("Cleanup History")).font(.system(size: 23, weight: .semibold, design: .rounded))
                Text(L10n.text("The latest 1,000 item results are kept. Files moved to Trash can be inspected and restored in Finder while they remain there.")) .font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(24)
            Divider()
            if model.history.isEmpty {
                ContentUnavailableView(L10n.text("No Cleanup History Yet"), systemImage: "clock.arrow.circlepath", description: Text(L10n.text("Cleanup paths, methods, and results will appear here.")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.history) { record in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: symbol(record.outcome)).foregroundStyle(record.outcome == .failed ? .red : .secondary)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(record.name).font(.system(size: 12, weight: .medium))
                                Spacer()
                                Text(record.date, format: .dateTime.year().month().day().hour().minute()).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Text(record.path).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                            Text(record.message).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                            HStack {
                                Text("\(record.action) · \(StorageFormatting.bytes(record.bytes))").font(.system(size: 10)).foregroundStyle(.secondary)
                                Spacer()
                                if let trashPath = record.trashPath {
                                    Button(L10n.text("Show in Trash")) { model.reveal(URL(fileURLWithPath: trashPath)) }.controlSize(.mini)
                                }
                            }
                        }
                    }.padding(.vertical, 9)
                }.listStyle(.inset)
            }
        }
    }
    private func symbol(_ outcome: CleanupRecord.Outcome) -> String { switch outcome { case .trashed: "trash"; case .removed: "checkmark.circle"; case .skipped: "forward.end"; case .failed: "exclamationmark.circle" } }
}

struct AddFolderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CustomRootKind = .derivedData
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            Label(L10n.text("Add Scan Location"), systemImage: "folder.badge.plus").font(.system(size: 20, weight: .semibold))
            Text(L10n.text("Choose the folder's purpose to classify it correctly. Unrecognized data stays read-only. Adding a location never starts cleanup.")) .font(.system(size: 12)).foregroundStyle(.secondary)
            Picker(L10n.text("Folder Type"), selection: $kind) { ForEach(CustomRootKind.allCases) { Text($0.title).tag($0) } }
            Text(L10n.text("Archives and exports require explicit selection in Deep Clean. For Swift builds, choose the package's .build folder.")) .font(.system(size: 11)).foregroundStyle(.secondary)
            HStack { Spacer(); Button(L10n.text("Cancel"), role: .cancel) { dismiss() }; Button(L10n.text("Choose Folder…")) { model.addFolder(kind: kind) }.buttonStyle(.borderedProminent) }
        }.padding(26).frame(width: 480)
    }
}

struct PreferencesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pendingLanguage = AppLanguage.current
    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 23) {
            Text(L10n.text("Settings")).font(.system(size: 21, weight: .semibold))
            Form {
                Section(L10n.text("Interface Language")) {
                    Picker(L10n.text("Language"), selection: $pendingLanguage) {
                        ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                    }.disabled(model.isCleaning)
                    Text(L10n.text("English is the default. Changes apply when you click Done and start a new scan."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    Text(L10n.text("File names, paths, project names, and tool identifiers are never translated."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Section(L10n.text("Software Updates")) { UpdateStatusView() }
                Section(L10n.text("Retention Rules")) {
                    Stepper(L10n.text("Keep logs for at least %@ days", String(describing: (model.settings.logDays))), value: $model.settings.logDays, in: 7...365, step: 1)
                    Stepper(L10n.text("Standard Clean: builds and dependencies idle for %@ days", String(describing: (model.settings.idleDays))), value: $model.settings.idleDays, in: 30...730, step: 1)
                    Stepper(L10n.text("Recent DeviceSupport versions to keep per platform: %@", String(describing: (model.settings.keepDeviceSupportVersions))), value: $model.settings.keepDeviceSupportVersions, in: 1...10)
                }
                Section(L10n.text("Cleanup Methods")) {
                    LabeledContent(L10n.text("Regular Files"), value: L10n.text("Move to Trash"))
                    LabeledContent(L10n.text("Devices & Runtimes"), value: L10n.text("Apple simctl · Explicit confirmation"))
                    Text(L10n.text("No automatic cleanup, forced app termination, or emptying Trash. Retention rules affect recommendations; review is always required.")) .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            HStack { Spacer(); Button(L10n.text("Done")) { model.settingsPresented = false; dismiss(); model.saveSettings(language: pendingLanguage) }.keyboardShortcut(.defaultAction).disabled(model.isCleaning) }
        }.padding(24).frame(width: 630, height: 680)
    }
}

struct FolderBrowserView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let root: URL
    @State private var current: URL?
    @State private var entries: [DirectoryEntry] = []
    @State private var loading = true
    @State private var error: String?
    private var location: URL { current ?? root }
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Button { current = location.deletingLastPathComponent() } label: { Image(systemName: "chevron.left") }.disabled(location == root || loading).help(L10n.text("Parent Folder"))
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.lastPathComponent).font(.system(size: 18, weight: .semibold))
                    Text(PathRules.compact(location)).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                }
                Spacer()
                Button("Finder") { model.reveal(location) }
            }
            Text(L10n.text("Browse the contents without counting them twice. Files inside an installation are not cleaned separately.")) .font(.system(size: 11)).foregroundStyle(.secondary)
            if loading { ProgressView(L10n.text("Calculating folder sizes…")).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else if let error { ContentUnavailableView(L10n.text("Cannot Browse This Location"), systemImage: "folder.badge.questionmark", description: Text(error)).frame(maxWidth: .infinity, maxHeight: .infinity) }
            else {
                List(entries) { entry in
                    Button {
                        if entry.isDirectory { current = entry.url } else { model.reveal(entry.url) }
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: entry.isDirectory ? "folder" : "doc").foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name).font(.system(size: 12, weight: .medium))
                                Text(entry.explanation).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(StorageFormatting.bytes(entry.measurement.allocated)).monospacedDigit().font(.system(size: 12, design: .rounded))
                                if entry.measurement.unreadable > 0 { Text(L10n.text("Partial Result")).font(.system(size: 10)).foregroundStyle(.orange) }
                            }
                            Image(systemName: entry.isDirectory ? "chevron.right" : "arrow.up.forward").font(.system(size: 9)).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }.buttonStyle(.plain)
                }.listStyle(.inset)
            }
            HStack { Text(L10n.text("Allocated size · Child folders deduplicated by file identity")).font(.system(size: 10)).foregroundStyle(.secondary); Spacer(); Button(L10n.text("Done")) { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(22).frame(width: 740, height: 570)
        .task(id: location) {
            loading = true; error = nil
            let url = location
            let worker = Task.detached(priority: .utility) { try DirectoryBrowser.children(of: url) }
            await withTaskCancellationHandler {
                do {
                    let result = try await worker.value
                    if !Task.isCancelled { entries = result; loading = false }
                } catch { if !Task.isCancelled { self.error = error.localizedDescription; loading = false } }
            } onCancel: { worker.cancel() }
        }
    }
}
