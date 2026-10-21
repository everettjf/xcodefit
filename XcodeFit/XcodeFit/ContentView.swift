import SwiftUI
import AppKit

extension StorageCategory {
    var tint: Color {
        switch self {
        case .installations: FitPalette.purple
        case .components: FitPalette.pink
        case .builds: FitPalette.sky
        case .caches: FitPalette.teal
        case .packages: FitPalette.peach
        case .archives: FitPalette.purple
        case .simulators: FitPalette.sky
        case .previews: FitPalette.teal
        case .deviceSupport: FitPalette.pink
        case .logs: FitPalette.gold
        case .other: FitPalette.pink
        }
    }
}

struct ContentView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 250, max: 310)
        } detail: {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    switch model.destination {
                    case .overview: OverviewView()
                    case .coverage: CoverageView()
                    case .history: HistoryView()
                    default: StorageListView()
                    }
                    ScanStatusBar()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if model.inspectorVisible, let item = model.focused {
                    Divider()
                    ItemInspector(item: item)
                        .frame(width: 285)
                }
            }
            .background(FitPalette.canvas)
            .navigationTitle(model.destination.title)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if model.isScanning {
                        Button { model.cancelScan() } label: { Label(L10n.text("Stop Scan"), systemImage: "stop.circle") }
                    } else {
                        Button { model.startScan() } label: { Label(L10n.text("Rescan"), systemImage: "arrow.clockwise") }
                            .keyboardShortcut("r", modifiers: .command)
                            .disabled(model.isCleaning)
                    }
                    Button { model.addFolderPresented = true } label: { Label(L10n.text("Add Location"), systemImage: "folder.badge.plus") }.disabled(model.isCleaning || model.isScanning)
                    Button { model.inspectorVisible.toggle() } label: { Label(L10n.text("Inspector"), systemImage: "sidebar.right") }
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 680)
        .sheet(item: $model.plan) { plan in CleanupReviewView(plan: plan) }
        .sheet(isPresented: $model.addFolderPresented) { AddFolderView() }
        .sheet(isPresented: $model.archiveRetentionPresented) { ArchiveRetentionView() }
        .sheet(isPresented: $model.settingsPresented) { PreferencesView() }
        .sheet(isPresented: Binding(get: { model.results != nil }, set: { if !$0 { model.results = nil } })) { CleanupResultsView() }
        .sheet(item: $model.browseURL) { url in FolderBrowserView(root: url) }
        .alert(L10n.text("Unable to Complete the Operation"), isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button(L10n.text("OK"), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .task { if model.snapshot == nil && !model.isScanning { model.startScan() } }
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct SidebarView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image("FitMascot").resizable().scaledToFit().frame(width: 49, height: 49).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("XcodeFit").font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(FitPalette.purple)
                    Text(L10n.text("Developer Storage")).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }.padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 5)
            List(selection: $model.destination) {
                Section(L10n.text("Workspace")) {
                    Label(L10n.text("Overview"), systemImage: "square.grid.2x2").tag(AppModel.Destination.overview)
                    Label(L10n.text("Browse by Project"), systemImage: "folder").tag(AppModel.Destination.projects)
                    Label(L10n.text("Clean Up"), systemImage: "sparkles").tag(AppModel.Destination.cleanup)
                }
                Section(L10n.text("Developer Files")) {
                    ForEach(StorageCategory.allCases) { category in
                        HStack(spacing: 9) {
                            Image(systemName: category.symbol).foregroundStyle(category.tint).frame(width: 24, height: 25).background(category.wash, in: RoundedRectangle(cornerRadius: 7))
                            Text(category.title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 2)
                            if model.size(category) > 0 { Text(StorageFormatting.bytes(model.size(category))).font(.system(size: 10, design: .rounded)).foregroundStyle(.secondary).monospacedDigit() }
                        }.tag(AppModel.Destination.category(category)).help(category.title)
                    }
                }
                Section(L10n.text("Manage")) {
                    Label(L10n.text("Protected Locations"), systemImage: "shield.lefthalf.filled").tag(AppModel.Destination.protected)
                    Label(L10n.text("Cleanup History"), systemImage: "clock.arrow.circlepath").tag(AppModel.Destination.history)
                    Label(L10n.text("Scan Coverage"), systemImage: "scope").tag(AppModel.Destination.coverage)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            Divider().padding(.horizontal, 14)
            HStack {
                Image(systemName: "internaldrive").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("Local Disk")).font(.system(size: 11, weight: .medium))
                    Text(L10n.text("%@ available", String(describing: (StorageFormatting.bytes(model.availableBytes))))).font(.system(size: 10)).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Button { model.settingsPresented = true } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).help(L10n.text("Settings"))
            }.padding(16)
        }
        .background(FitPalette.sidebar)
        .onChange(of: model.destination) { _, _ in model.search = ""; model.focusedID = nil }
    }
}

struct OverviewView: View {
    @Environment(AppModel.self) private var model
    private let grid = [GridItem(.flexible()), GridItem(.flexible())]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(L10n.text("Make room for your next build."))
                            .font(.system(size: 26, weight: .semibold, design: .rounded)).tracking(-0.7)
                        Text(L10n.text("Understand what Xcode stores. Choose what to keep."))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    Image("FitMascot").resizable().scaledToFit().frame(width: 86, height: 86)
                        .background(FitPalette.peachWash, in: RoundedRectangle(cornerRadius: 25))
                        .overlay(RoundedRectangle(cornerRadius: 25).strokeBorder(FitPalette.peach.opacity(0.25)))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 19) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.isScanning ? L10n.text("Counting identified storage") : L10n.text("Identified Xcode Storage")).font(.system(size: 12)).foregroundStyle(.secondary)
                            Text(StorageFormatting.bytes(model.total)).font(.system(size: 43, weight: .semibold, design: .rounded)).foregroundStyle(FitPalette.purple).tracking(-1.8).monospacedDigit().contentTransition(.numericText())
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 7) {
                            Text(L10n.text("Storage items: %@", String(describing: (model.items.count)))).font(.system(size: 12, weight: .medium)).monospacedDigit()
                            Button { model.navigate(.coverage) } label: {
                                Label(model.hasIncompleteScan ? L10n.text("Some locations are incomplete") : L10n.text("View Scan Coverage"), systemImage: model.hasIncompleteScan ? "exclamationmark.circle" : "scope")
                            }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(model.hasIncompleteScan ? .orange : .secondary)
                        }
                    }
                    GeometryReader { geometry in
                        HStack(spacing: 3) {
                            ForEach(model.categoryTotals.filter { $0.1 > 0 }, id: \.0) { category, bytes in
                                RoundedRectangle(cornerRadius: 6).fill(category.tint.gradient)
                                    .frame(width: max(2, (geometry.size.width - 30) * CGFloat(bytes) / CGFloat(max(1, model.total))))
                                    .help("\(category.title) · \(StorageFormatting.bytes(bytes))")
                            }
                        }
                    }.frame(height: 16)
                    HStack(spacing: 14) {
                        ForEach(Array(model.categoryTotals.filter { $0.1 > 0 }.prefix(4)), id: \.0) { category, _ in
                            HStack(spacing: 5) { Circle().fill(category.tint).frame(width: 5, height: 5); Text(category.title).font(.system(size: 10)).foregroundStyle(.secondary) }
                        }
                    }
                }
                .padding(23)
                .background(LinearGradient(colors: [FitPalette.skyWash, FitPalette.lilacWash], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(FitPalette.purple.opacity(0.2)))
                HStack(spacing: 14) {
                    Image(systemName: "sparkles").foregroundStyle(FitPalette.teal).font(.system(size: 23)).padding(10).background(FitPalette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("A cleaner development environment, on your terms.")).font(.system(size: 13, weight: .medium))
                        Text(L10n.text("Standard or Deep. Review every cleanup before it runs.")) .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Choose a Cleanup")) { model.navigate(.cleanup) }.buttonStyle(.borderedProminent).controlSize(.regular)
                }.padding(16).background(FitPalette.mintWash, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(FitPalette.teal.opacity(0.2)))
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text(L10n.text("Storage Breakdown")).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(L10n.text("Largest first")).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                    LazyVGrid(columns: grid, spacing: 11) {
                        ForEach(model.categoryTotals, id: \.0) { category, size in
                            Button { model.navigate(.category(category)) } label: {
                                HStack(spacing: 13) {
                                    Image(systemName: category.symbol).font(.system(size: 18)).foregroundStyle(category.tint).frame(width: 40, height: 42).background(category.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(category.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                                        Text(L10n.text("Items: %@", String(describing: (model.count(category))))).font(.system(size: 10)).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Text(StorageFormatting.bytes(size)).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(size > 0 ? .primary : .tertiary).monospacedDigit()
                                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                                }.padding(15).background(category.wash, in: RoundedRectangle(cornerRadius: 17))
                                    .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(category.tint.opacity(0.22)))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Text(L10n.text("Allocated sizes are deduplicated by file identity. APFS shared blocks, snapshots, and Trash affect actual space reclaimed."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(30).frame(maxWidth: 1100, alignment: .leading).frame(maxWidth: .infinity)
        }
    }
}

struct StorageListView: View {
    @Environment(AppModel.self) private var model
    private var isCleanup: Bool { model.destination == .cleanup }
    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.destination.title).font(.system(size: 23, weight: .semibold, design: .rounded)).tracking(-0.5)
                    Spacer()
                    Text(L10n.text("Items: %@ · %@", String(describing: (model.visibleItems.count)), String(describing: (StorageFormatting.bytes(model.visibleItems.reduce(0) { $0 + $1.size }))))).font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
                }
                if isCleanup { CleanupTierPicker() }
                else if case .category(let category) = model.destination { Text(category.purpose).font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                else if model.destination == .projects { Text(L10n.text("Browse identified projects and archived apps. The inspector shows source paths and identification details.")) .font(.system(size: 12)).foregroundStyle(.secondary) }
                else if model.destination == .protected { Text(L10n.text("These locations and their contents are excluded from cleanup. Right-click an item to remove protection.")) .font(.system(size: 12)).foregroundStyle(.secondary) }
                if isCleanup && model.snapshot != nil && (model.environment.toolsBusy || !model.environment.processStateKnown) {
                    HStack(alignment: .center) {
                        Label(model.environment.toolsBusy ? L10n.text("Development tools detected: %@. Close them, then refresh to enable cleanup.", String(describing: (model.environment.runningTools.joined(separator: ", ")))) : L10n.text("Development-tool status is unknown. Cleanup is paused."), systemImage: "pause.circle")
                            .font(.system(size: 11)).foregroundStyle(.orange)
                        Spacer(minLength: 0)
                        Button(model.refreshingTools ? L10n.text("Refreshing…") : L10n.text("Refresh Status")) { model.refreshToolState() }
                            .controlSize(.small).disabled(model.isScanning || model.isCleaning || model.refreshingTools)
                    }
                }
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField(L10n.text("Search names, projects, or paths"), text: $model.search).textFieldStyle(.plain)
                    }.font(.system(size: 12)).padding(7).background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 7)).frame(maxWidth: 285)
                    Spacer()
                    if isCleanup {
                        if model.tier == .deep {
                            Button(L10n.text("Manage Archives…")) { model.archiveRetentionPresented = true }.disabled(!model.canClean)
                        }
                        Button(L10n.text("Select Recommended")) { model.applyRecommendations() }.disabled(!model.canClean)
                        Button(L10n.text("Clear Selection")) { model.selected = [] }.disabled(model.selected.isEmpty)
                    }
                    Picker(L10n.text("Sort"), selection: $model.sort) { ForEach(AppModel.Sort.allCases) { Text($0.title).tag($0) } }.labelsHidden().frame(width: 145)
                }.controlSize(.small)
            }.padding(22)
            Divider()
            if model.visibleItems.isEmpty {
                ContentUnavailableView {
                    Label(model.isScanning ? L10n.text("Discovering Developer Files") : L10n.text("No Items Here Yet"), systemImage: model.isScanning ? "externaldrive.badge.magnifyingglass" : "folder")
                } description: {
                    Text(model.isScanning ? L10n.text("Results appear as the scan progresses. You can browse other categories while scanning.") : L10n.text("Adjust your search, choose another cleanup tier, or add a custom scan location."))
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(model.visibleItems, selection: $model.focusedID) {
                    TableColumn("") { item in
                        if isCleanup {
                            Toggle(L10n.text("Select %@", String(describing: (item.name))), isOn: Binding(get: { model.selected.contains(item.id) }, set: { _ in model.toggleSelection(item) }))
                                .toggleStyle(.checkbox).labelsHidden().disabled(model.blockReason(item) != nil).help(model.blockReason(item) ?? L10n.text("Add to the cleanup selection"))
                        } else { Image(systemName: item.category.symbol).foregroundStyle(item.category.tint) }
                    }.width(22)
                    TableColumn(L10n.text("Name / Owner")) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 5) {
                                Text(item.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                if model.isProtected(item) { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(.secondary) }
                            }
                            Text(item.subtitle.isEmpty ? PathRules.compact(item.url.deletingLastPathComponent()) : item.subtitle)
                                .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }.padding(.vertical, 7).help(item.url.path)
                    }.width(min: 170, ideal: 275)
                    TableColumn(L10n.text("Allocated Size")) { item in
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(StorageFormatting.bytes(item.size)).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                            if !item.complete { Text(L10n.text("Partial Result")).font(.system(size: 9)).foregroundStyle(.orange) }
                        }.frame(maxWidth: .infinity, alignment: .trailing)
                    }.width(90)
                    TableColumn(L10n.text("Date")) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            if let date = item.date { Text(date, format: .dateTime.year().month(.twoDigits).day(.twoDigits)).font(.system(size: 11)).lineLimit(1) }
                            else { Text(L10n.text("Unknown")).font(.system(size: 11)).foregroundStyle(.secondary) }
                            Text(item.dateLabel).font(.system(size: 9)).foregroundStyle(.tertiary)
                        }
                    }.width(105)
                    TableColumn(L10n.text("Status")) { item in
                        Text(status(item)).font(.system(size: 10)).foregroundStyle(item.blockedReason != nil || model.isProtected(item) ? Color.secondary : item.manualOnly ? Color.orange : Color.secondary)
                            .lineLimit(1).help(model.blockReason(item) ?? item.action.title)
                    }.width(85)
                }
                .alternatingRowBackgrounds(.disabled)
                .contextMenu(forSelectionType: String.self) { ids in
                    if let item = model.items.first(where: { ids.contains($0.id) }) {
                        Button(L10n.text("Browse Contents")) { model.browseURL = item.url }
                        Button(L10n.text("Show in Finder")) { model.reveal(item.url) }
                        Button(L10n.text("Copy Full Path")) { model.copyPath(item.url) }
                        Divider()
                        Button(model.isProtected(item) ? L10n.text("Remove Protection") : L10n.text("Protect Location")) { model.toggleProtection(item) }.disabled(model.isCleaning)
                    }
                } primaryAction: { ids in
                    if let item = model.items.first(where: { ids.contains($0.id) }) { model.browseURL = item.url }
                }
            }
            if isCleanup {
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.text("Selected: %@ · %@", String(describing: (model.selected.count)), String(describing: (StorageFormatting.bytes(model.selectedBytes))))).font(.system(size: 12, weight: .medium)).monospacedDigit()
                        Text(L10n.text("Review first. Moving to Trash does not immediately free space.")).font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(L10n.text("Review Cleanup…")) { model.review() }.buttonStyle(.borderedProminent).disabled(model.selected.isEmpty || !model.canClean)
                }.padding(.horizontal, 22).padding(.vertical, 14)
            }
        }
    }
    private func status(_ item: StorageItem) -> String {
        if model.isProtected(item) { return L10n.text("Protected") }
        if !item.complete { return L10n.text("Incomplete Scan") }
        if item.blockedReason != nil { return L10n.text("Protected / Read Only") }
        if item.action == .readOnly { return L10n.text("Read Only") }
        if item.manualOnly { return L10n.text("Select Manually") }
        return model.recommended(item) ? L10n.text("Recommended") : L10n.text("Keep")
    }
}

struct CleanupTierPicker: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 9) {
            ForEach(CleanupTier.allCases) { tier in
                Button { model.changeTier(tier) } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Image(systemName: tier.symbol).font(.system(size: 17)).foregroundStyle(tier == .regular ? FitPalette.teal : FitPalette.purple).padding(8).background(FitPalette.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                            Text(tier.title).font(.system(size: 12, weight: .semibold))
                            Spacer(minLength: 0)
                            Image(systemName: model.tier == tier ? "checkmark.circle.fill" : "circle").foregroundStyle(model.tier == tier ? (tier == .regular ? FitPalette.teal : FitPalette.purple) : .secondary)
                        }
                        Text(tier.subtitle).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(tier == .regular ? FitPalette.mintWash : FitPalette.lilacWash, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(model.tier == tier ? (tier == .regular ? FitPalette.teal : FitPalette.purple) : FitPalette.border, lineWidth: model.tier == tier ? 2 : 1))
                }.buttonStyle(.plain).disabled(model.isCleaning)
            }
        }
    }
}

struct ItemInspector: View {
    @Environment(AppModel.self) private var model
    let item: StorageItem
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 21) {
                VStack(alignment: .leading, spacing: 11) {
                    Image(systemName: item.category.symbol).font(.system(size: 29)).foregroundStyle(item.category.tint.gradient).padding(15).background(item.category.wash, in: RoundedRectangle(cornerRadius: 19))
                    Text(item.name).font(.system(size: 18, weight: .semibold, design: .rounded)).textSelection(.enabled)
                    Text(item.category.title).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(StorageFormatting.bytes(item.size)).font(.system(size: 30, weight: .medium, design: .rounded)).monospacedDigit()
                    Text(L10n.text("Allocated size · File system entries: %@", String(describing: (item.measurement.files.formatted())))).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Divider()
                inspectorSection(L10n.text("Purpose & Cleanup Impact"), text: item.purpose)
                if let archive = item.archive { ArchiveInspectorView(item: item, metadata: archive).id(item.id) }
                if item.measurement.containsReleaseSymbols && item.archive == nil {
                    Text(L10n.text("Contains release symbols. Standard Clean excludes this entire folder; rebuilding may not recover matching UUIDs.")).font(.system(size: 11)).foregroundStyle(.orange)
                }
                inspectorSection(L10n.text("Owner"), text: item.owner)
                inspectorSection(L10n.text("Identification"), text: item.evidence)
                VStack(alignment: .leading, spacing: 7) {
                    Text(L10n.text("Location")).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    Text(PathRules.compact(item.url)).font(.system(size: 10, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button { model.reveal(item.url) } label: { Label("Finder", systemImage: "arrow.up.forward.square") }
                        Button { model.copyPath(item.url) } label: { Image(systemName: "document.on.document") }.help(L10n.text("Copy Path"))
                    }.controlSize(.small)
                }
                Divider()
                HStack { Text(L10n.text("Logical Size")); Spacer(); Text(StorageFormatting.bytes(item.measurement.logical)).monospacedDigit() }.font(.system(size: 11)).foregroundStyle(.secondary)
                if item.measurement.hardLinks > 0 { Text(L10n.text("Duplicate file identities already counted elsewhere: %@", String(describing: (item.measurement.hardLinks)))).font(.system(size: 10)).foregroundStyle(.secondary) }
                if let reason = model.blockReason(item) { Label(reason, systemImage: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                else { Label(item.action.title, systemImage: item.action.isPermanent ? "exclamationmark.triangle" : "trash").font(.system(size: 11)).foregroundStyle(item.action.isPermanent ? .orange : .secondary) }
                Button(L10n.text("Browse Contents…")) { model.browseURL = item.url }.frame(maxWidth: .infinity)
                Button { model.toggleProtection(item) } label: { Label(model.isProtected(item) ? L10n.text("Remove Protection") : L10n.text("Protect Location"), systemImage: model.isProtected(item) ? "lock.open" : "lock") }.disabled(model.isCleaning)
            }.padding(23)
        }.background(FitPalette.card)
    }
    private func inspectorSection(_ label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            Text(text).font(.system(size: 12)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ScanStatusBar: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 9) {
                if model.isScanning || model.isCleaning { ProgressView().controlSize(.small).scaleEffect(0.65).frame(width: 14, height: 14) }
                else { Image(systemName: model.hasIncompleteScan ? "exclamationmark.circle" : "checkmark.circle").foregroundStyle(model.hasIncompleteScan ? .orange : .secondary) }
                if model.isFixture { Text(L10n.text("Test folders · Not actual developer data")).foregroundStyle(.orange) }
                Text(model.isScanning || model.isCleaning ? model.progress : model.snapshot?.cancelled == true ? L10n.text("Scan canceled · Partial results") : L10n.text("Items: %@ · Allocated size · Deduplicated by file identity", String(describing: (model.items.count)))).lineLimit(1).truncationMode(.middle)
                Spacer(minLength: 8)
                if let date = model.snapshot?.date, !model.isScanning { Text(date, style: .time).monospacedDigit() }
                if model.isCleaning { Button(L10n.text("Stop Remaining Operations")) { model.cancelCleanup() }.buttonStyle(.plain) }
            }.font(.system(size: 10)).foregroundStyle(.secondary).padding(.horizontal, 18).frame(height: 31)
        }
    }
}
