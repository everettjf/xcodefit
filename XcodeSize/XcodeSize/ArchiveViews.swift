import SwiftUI

struct ArchiveRetentionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var keep = 3
    private var archives: [StorageItem] { model.items.filter { $0.url.pathExtension == "xcarchive" && $0.category == .archives } }
    private var candidates: Set<String> {
        ArchiveRetention.candidates(archives, keeping: keep, protectedPaths: model.protectedPaths)
            .intersection(Set(archives.filter { model.blockReason($0) == nil }.map(\.id)))
    }
    private var groups: [(key: String, values: [StorageItem])] {
        Dictionary(grouping: archives, by: { $0.archive?.groupKey ?? $0.id }).map { (key: $0.key, values: $0.value.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) }.sorted { $0.key < $1.key }
    }
    private func groupTitle(_ item: StorageItem) -> String {
        let identity = [item.archive?.bundleID, item.archive?.platform, item.archive?.team].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return identity.isEmpty ? item.name : identity
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(L10n.text("Archive Retention"), systemImage: "archivebox").font(.system(size: 22, weight: .semibold))
            Text(L10n.text("Each released build needs its own matching symbols. Keep every distributed build you still support. Upload and backup status are unknown.")).font(.system(size: 12)).foregroundStyle(.secondary)
            Picker(L10n.text("Retention Rule"), selection: $keep) {
                ForEach([1, 3, 5], id: \.self) { count in Text(count == 1 ? L10n.text("Keep latest version") : L10n.text("Keep latest %@ versions", String(count))).tag(count) }
                Text(L10n.text("Remove all unprotected archives")).tag(0)
            }
            Text(keep == 0 ? L10n.text("All unprotected archives, including unknown versions, will be selected. After Trash is emptied, their release symbols may be unrecoverable.") : L10n.text("Grouped by app, platform, and signing team. All builds of retained versions stay. Unknown identity or version stays. Protected locations always stay."))
                .font(.system(size: 11)).foregroundStyle(keep == 0 ? Color.orange : Color.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(groups, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 9) {
                            if let first = group.values.first {
                                Text(groupTitle(first))
                                    .font(.system(size: 12, weight: .semibold)).textSelection(.enabled)
                            }
                            ForEach(group.values) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: candidates.contains(item.id) ? "trash" : "archivebox").foregroundStyle(candidates.contains(item.id) ? Color.orange : Color.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name + (item.subtitle.isEmpty ? "" : " · " + item.subtitle)).font(.system(size: 12))
                                        Text(PathRules.compact(item.url)).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Text(StorageFormatting.bytes(item.size)).font(.system(size: 11)).monospacedDigit()
                                    Text(model.isProtected(item) ? L10n.text("Protected") : candidates.contains(item.id) ? L10n.text("Move to Trash") : L10n.text("Keep")).font(.system(size: 10)).frame(width: 85, alignment: .trailing)
                                    Button { model.toggleProtection(item) } label: { Image(systemName: model.isProtected(item) ? "lock.fill" : "lock.open") }.buttonStyle(.borderless).help(L10n.text("Protect Location"))
                                }
                            }
                            Divider()
                        }
                    }
                    if archives.isEmpty { Text(L10n.text("No Items Here Yet")).foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
            }.frame(minHeight: 180, maxHeight: 340)
            Text(L10n.text("Selected: %@ · %@", String(candidates.count), StorageFormatting.bytes(archives.filter { candidates.contains($0.id) }.reduce(0) { $0 + $1.size }))).font(.system(size: 12, weight: .medium)).monospacedDigit()
            HStack {
                Text(L10n.text("Selection only. Review is required before cleanup.")).font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(L10n.text("Cancel"), role: .cancel) { dismiss() }
                Button(L10n.text("Select for Review")) {
                    guard model.tier == .deep, model.canClean else { return }
                    model.selected.subtract(archives.map(\.id)); model.selected.formUnion(candidates)
                    dismiss()
                }.buttonStyle(.borderedProminent).disabled(candidates.isEmpty || model.tier != .deep || !model.canClean)
            }
        }.padding(26).frame(width: 760)
    }
}

struct ArchiveInspectorView: View {
    let item: StorageItem
    let metadata: ArchiveMetadata
    @State private var report: ArchiveSymbolReport?
    @State private var checking = false
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.text("Archive Details")).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            Text([metadata.bundleID, metadata.platform, metadata.version, metadata.build].filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 11)).textSelection(.enabled)
            sizeRow(L10n.text("Products"), item.measurement.productBytes)
            sizeRow(L10n.text("Release Symbols"), item.measurement.symbolBytes)
            sizeRow(L10n.text("Other Archive Data"), max(0, item.size - item.measurement.productBytes - item.measurement.symbolBytes))
            Text(L10n.text("Included in archive size; never counted twice.")).font(.system(size: 10)).foregroundStyle(.secondary)
            if let report {
                Text(report.summary).font(.system(size: 11)).foregroundStyle(report.failures == 0 && !report.binaries.isEmpty && report.missing.isEmpty ? Color.secondary : Color.orange)
                Text(L10n.text("Binary UUIDs: %@ · Symbol UUIDs: %@", String(report.binaries.count), String(report.symbols.count))).font(.system(size: 10)).foregroundStyle(.secondary)
                DisclosureGroup(L10n.text("Missing UUIDs")) {
                    ForEach(report.missing.sorted(), id: \.self) { uuid in Text(uuid).font(.system(size: 9, design: .monospaced)).textSelection(.enabled) }
                }.font(.system(size: 10))
            }
            Button(checking ? L10n.text("Checking Symbols…") : L10n.text("Check Symbol UUIDs")) {
                checking = true
                let url = item.url
                Task {
                    report = await Task.detached(priority: .utility) { ArchiveSymbolReport.inspect(url) }.value
                    checking = false
                }
            }.controlSize(.small).disabled(checking)
        }.id(item.id)
        .onChange(of: item.id) { report = nil; checking = false }
    }
    private func sizeRow(_ title: String, _ bytes: Int64) -> some View {
        HStack { Text(title); Spacer(); Text(StorageFormatting.bytes(bytes)).monospacedDigit() }.font(.system(size: 11))
    }
}
