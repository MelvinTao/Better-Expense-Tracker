import SwiftUI
import SwiftData

// ============================================================
// MARK: - CachedDateFormatters
// ============================================================
// DateFormatter is very expensive to create, and the FIRST one
// created in the app's lifetime pays a large one-time ICU/locale
// init cost. Reuse shared instances instead of allocating per row.

enum CachedDateFormatters {
    static let dayMonth      = formatter("MMM d")
    static let monthYear     = formatter("MMMM yyyy")
    static let year          = formatter("yyyy")
    static let sectionHeader = formatter("EEEE, MMM d")
    static let rowDate       = formatter("MMM d, EEE")
    static let time12        = formatter("h:mm a")
    static let time24        = formatter("HH:mm")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }
}

// ============================================================
// MARK: - SignedAmountLabel
// ============================================================
// Shows an amount with a chevron.up.2 (income) / chevron.down.2 (spending)
// prefix. Zero shows no icon. `dimmed` renders everything secondary (hidden projects).

private struct SignedAmountLabel: View {
    let amount: Double
    var font: Font = .system(size: 15, design: .rounded)
    var iconSize: CGFloat = 10
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            if amount != 0 {
                Image(systemName: amount > 0 ? "chevron.up.2" : "chevron.down.2")
                    .font(.system(size: iconSize, weight: .semibold))
                    .foregroundColor(dimmed ? .secondary : (amount > 0 ? .green : .red))
            }
            Text(formatCurrency(Swift.abs(amount)))
                .font(font)
                .foregroundColor(dimmed || amount == 0 ? .secondary : .primary)
        }
    }
}

// ============================================================
// MARK: - ProjectView
// ============================================================

struct ProjectView: View {
    @Query(sort: \ProjectCode.sortOrder) var projectCodes: [ProjectCode]
    @Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]
    @Query(sort: \CategoryModel.sortOrder) var categories: [CategoryModel]
    @AppStorage(AppStorageKeys.timeFormatIs24hr) private var is24hr = false
    @Environment(\.modelContext) var modelContext

    // Shared date-range state (synced across Home, Transactions, Projects)
    @EnvironmentObject private var period: SharedPeriodState

    // Edit mode
    @State private var editMode = false

    // Collapsed state per project (name → collapsed)
    @State private var collapsed: [String: Bool] = [:]

    // Drag-to-reorder — disables scroll while dragging
    @State private var isReordering = false

    // Tax/tip breakdown toggle
    @State private var showTaxTip = false

    // Hidden projects — comma-separated name list, survives app restarts
    @AppStorage("projectView.hiddenProjects") private var hiddenProjectsRaw: String = ""
    private var hiddenProjects: Set<String> {
        Set(hiddenProjectsRaw.split(separator: ",").map(String.init))
    }

    // MARK: Period helpers

    var periodTransactions: [Transaction] {
        transactions.filter { $0.date >= period.periodStart && $0.date < period.periodEnd }
    }

    // MARK: Amount helpers (signed: income = +, spending = −)

    func totalAmount(for project: ProjectCode) -> Double {
        periodTransactions
            .filter { $0.projectCode == project.name }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }

    var grandTotal: Double {
        projectCodes
            .filter { !hiddenProjects.contains($0.name) }
            .reduce(0) { $0 + totalAmount(for: $1) }
    }

    var grandTaxTipTotal: Double {
        periodTransactions
            .filter { tx in tx.projectCode.map { !hiddenProjects.contains($0) } ?? true }
            .reduce(0) { sum, tx in
                let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
                return sum + taxAmt + tx.tipAmount
            }
    }

    // MARK: The project list + its base modifiers (gesture added conditionally below)

    private var projectListSection: some View {
        ProjectList(
            projectCodes:       projectCodes,
            allTransactions:    transactions,
            periodTransactions: periodTransactions,
            categories:         categories,
            is24hr:             is24hr,
            editMode:           editMode,
            collapsed:          $collapsed,
            isReordering:       $isReordering,
            modelContext:       modelContext,
            showTaxTip:         $showTaxTip,
            hiddenProjectsRaw:  $hiddenProjectsRaw
        )
        .scrollDisabled(isReordering)
        // Push scroll content below the Done button when in edit mode
        .safeAreaInset(edge: .top, spacing: 0) {
            Color.clear.frame(height: editMode ? 52 : 0)
                .animation(.spring(response: 0.3), value: editMode)
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // Navigator + range tabs — hidden in edit mode
            if !editMode {
                PeriodNavigatorBar(
                    onPrevious:   { period.periodOffset -= 1 },
                    onNext:       { period.periodOffset = min(0, period.periodOffset + 1) },
                    hideChevrons: period.selectedRange == .custom
                ) {
                    Text(period.periodLabel)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .onTapGesture {
                            if period.selectedRange == .month {
                                period.pickerMonth = period.periodStart
                                period.showMonthPicker = true
                            } else if period.selectedRange == .week {
                                period.pickerWeekStart = period.periodStart
                                period.showWeekPicker = true
                            } else if period.selectedRange == .custom {
                                period.showCustomRangePicker = true
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            guard period.periodOffset != 0, period.selectedRange != .custom else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                period.periodOffset = 0
                            }
                        }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                SharedDateRangeTabs(selected: $period.selectedRange, onRangeChange: { },
                                    onCustomTap: { period.showCustomRangePicker = true })
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Project list.
            // The "long-press empty space to enter edit mode" gesture is attached
            // ONLY in non-edit mode. In edit mode it would otherwise keep recognizing
            // touches and starve the + buttons of their taps.
            if editMode {
                projectListSection
            } else {
                projectListSection
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                withAnimation(.spring(response: 0.3)) { editMode = true }
                            }
                    )
            }

            Divider()

            // Total row — tap to toggle tax/tip breakdown
            HStack {
                Text("Total:")
                    .font(.system(size: 26, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    SignedAmountLabel(amount: grandTotal,
                                      font: .system(size: 22, weight: .semibold, design: .rounded),
                                      iconSize: 13)
                    if showTaxTip && grandTaxTipTotal > 0 {
                        Text("/\(formatCurrency(grandTaxTipTotal))")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showTaxTip)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                guard grandTaxTipTotal > 0 else { return }
                withAnimation { showTaxTip.toggle() }
            }
        }
        // Done button overlay in edit mode
        .overlay(alignment: .topTrailing) {
            if editMode {
                Button("Done") {
                    withAnimation(.spring(response: 0.3)) { editMode = false }
                }
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .padding(.top, 8)
                .padding(.trailing, 16)
            }
        }
        .animation(.spring(response: 0.3), value: editMode)
        // Period picker sheets (driven by shared state, shared with Home / Transactions)
        .sheet(isPresented: $period.showMonthPicker) {
            MonthPickerSheet(selectedMonth: $period.pickerMonth, isPresented: $period.showMonthPicker)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $period.showWeekPicker) {
            WeekPickerSheet(selectedWeekStart: $period.pickerWeekStart, isPresented: $period.showWeekPicker)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $period.showCustomRangePicker) {
            CustomDateRangeSheet(startDate: $period.customStart, endDate: $period.customEnd, isPresented: $period.showCustomRangePicker)
                .presentationDetents([.medium])
                .onDisappear { period.selectedRange = .custom }
        }
        .onChange(of: period.pickerWeekStart) { _, newMonday in
            let cal = Calendar.current
            let now = Date.now
            let weekdayNow = cal.component(.weekday, from: now)
            let offsetNow = (weekdayNow + 5) % 7
            let thisMonday = cal.startOfDay(for: cal.date(byAdding: .day, value: -offsetNow, to: now)!)
            let weeks = cal.dateComponents([.weekOfYear], from: thisMonday, to: newMonday).weekOfYear ?? 0
            period.periodOffset = weeks
        }
        .onChange(of: period.pickerMonth) { _, newDate in
            let cal = Calendar.current
            let now = cal.date(from: cal.dateComponents([.year, .month], from: Date()))!
            let chosen = cal.date(from: cal.dateComponents([.year, .month], from: newDate))!
            let months = cal.dateComponents([.month], from: now, to: chosen).month ?? 0
            period.periodOffset = min(0, months)
        }
    }
}

// ============================================================
// MARK: - DrillContext
// ============================================================
// Snapshot of the transactions to show in the drill-down sheet.
// Computed once at tap time so the sheet renders immediately.

private struct DrillContext: Identifiable {
    let id = UUID()
    let title: String
    let transactions: [Transaction]
}

// ============================================================
// MARK: - ProjectList
// ============================================================
// Owns all drag state so it can render the floating overlay
// above the scroll content without being clipped.

private struct ProjectList: View {
    let projectCodes: [ProjectCode]
    let allTransactions: [Transaction]      // full list for rename / delete cascade
    let periodTransactions: [Transaction]
    let categories: [CategoryModel]
    let is24hr: Bool
    let editMode: Bool
    @Binding var collapsed: [String: Bool]
    @Binding var isReordering: Bool
    let modelContext: ModelContext
    @Binding var showTaxTip: Bool
    @Binding var hiddenProjectsRaw: String

    // ── ONE sheet drives every modal in this view, so none can swallow another ──
    enum ActiveSheet: Identifiable {
        case drill(DrillContext)
        case addProject
        case addSubCode(ProjectCode)
        case renameProject(ProjectCode)
        case renameSubCode(ProjectCode, String)

        var id: String {
            switch self {
            case .drill(let ctx):              return "drill-\(ctx.id)"
            case .addProject:                  return "addProject"
            case .addSubCode(let p):           return "addSubCode-\(p.name)"
            case .renameProject(let p):        return "renameProject-\(p.name)"
            case .renameSubCode(let p, let s): return "renameSubCode-\(p.name)-\(s)"
            }
        }
    }
    @State private var activeSheet: ActiveSheet? = nil

    /// Parsed set of hidden project names.
    private var hiddenProjects: Set<String> {
        Set(hiddenProjectsRaw.split(separator: ",").map(String.init))
    }

    // ── Swipe-to-delete state (only one row open at a time) ──────
    @State private var swipedProjectName: String? = nil   // project header swiped open
    @State private var swipedSubKey: String? = nil        // sub-code row swiped open (PROJ/SUB)

    // Delete confirmation
    @State private var projectToDelete: ProjectCode? = nil
    @State private var subToDelete: (ProjectCode, String)? = nil
    @State private var showDeleteProjectAlert = false
    @State private var showDeleteSubAlert = false

    private let deleteButtonWidth: CGFloat = 80

    // Local copy for live reflow while dragging projects
    @State private var items: [ProjectCode] = []

    // ── Project drag state ───────────────────────────────────────
    @State private var floatingName: String? = nil
    @State private var pickupY: CGFloat = 0
    @State private var floatOffset: CGSize = .zero
    @State private var rowMidY: [String: CGFloat] = [:]
    @State private var rowHeight: [String: CGFloat] = [:]

    // ── Sub-code drag state (key = "projectName/subCode") ────────
    @State private var floatingSubKey: String? = nil
    @State private var pickupSubY: CGFloat = 0
    @State private var floatSubOffset: CGSize = .zero
    @State private var subRowMidY: [String: CGFloat] = [:]
    @State private var subRowHeight: [String: CGFloat] = [:]
    @State private var subItems: [String: [String]] = [:]   // projectName → [subCode]

    private let coordSpace = "projectList"
    private let gutterWidth: CGFloat = 28

    // Fingerprint to resync local state when data changes outside a drag.
    // Includes sub-codes so add / rename / delete of a sub-code resyncs too.
    private var orderSignature: [String] {
        projectCodes.map { "\($0.name)#\($0.sortOrder)#\($0.subCodes.joined(separator: "|"))" }
    }

    // Sub-key helpers
    private func subKey(_ projectName: String, _ sub: String) -> String { "\(projectName)/\(sub)" }
    private func subKeyProject(_ key: String) -> String { String(key.split(separator: "/", maxSplits: 1).first ?? "") }
    private func subKeyCode(_ key: String) -> String { String(key.split(separator: "/", maxSplits: 1).last ?? "") }

    // MARK: Amount helpers (signed: income = +, spending = −)

    func amount(for subCode: String, in projectName: String) -> Double {
        periodTransactions
            .filter { $0.projectCode == projectName && $0.projectSubCode == subCode }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    func totalAmount(for project: ProjectCode) -> Double {
        periodTransactions
            .filter { $0.projectCode == project.name }
            .reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }
    func taxTip(for subCode: String, in projectName: String) -> Double {
        periodTransactions
            .filter { $0.projectCode == projectName && $0.projectSubCode == subCode }
            .reduce(0) { sum, tx in
                let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
                return sum + taxAmt + tx.tipAmount
            }
    }
    func totalTaxTip(for project: ProjectCode) -> Double {
        periodTransactions
            .filter { $0.projectCode == project.name }
            .reduce(0) { sum, tx in
                let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
                return sum + taxAmt + tx.tipAmount
            }
    }

    // MARK: Add-project button (used in edit mode and empty state)

    private var addProjectButton: some View {
        Button { activeSheet = .addProject } label: {
            HStack(alignment: .center, spacing: 0) {
                Text("#")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: gutterWidth, alignment: .leading)
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // "# +" above all rows in edit mode
                    if editMode {
                        addProjectButton.transition(.opacity)
                    }

                    ForEach(items) { project in
                        projectBlock(project)
                    }

                    // Empty-state prompt
                    if projectCodes.isEmpty {
                        addProjectButton
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
                // Tap empty space to close an open delete button.
                // Attached only in non-edit mode so it never competes with the + buttons.
                .background {
                    if !editMode {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { dismissSwipes() }
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: editMode)
            }
            .coordinateSpace(name: coordSpace)

            // Floating drag overlays
            floatingOverlay
            subFloatingOverlay
        }
        .onAppear {
            if items.isEmpty { items = projectCodes }
            for p in projectCodes where subItems[p.name] == nil { subItems[p.name] = p.subCodes }
        }
        .onChange(of: orderSignature) { _, _ in
            if floatingName == nil { items = projectCodes }
            for p in projectCodes {
                let draggingThisProject = floatingSubKey.map { subKeyProject($0) } == p.name
                if !draggingThisProject { subItems[p.name] = p.subCodes }
            }
        }
        // ── Delete confirmations (alerts coexist fine with the sheet) ──
        .alert("Delete \"\(projectToDelete?.name ?? "")\"?",
               isPresented: $showDeleteProjectAlert,
               presenting: projectToDelete) { project in
            Button("Delete", role: .destructive) { deleteProject(project) }
            Button("Cancel", role: .cancel) {}
        } message: { project in
            Text("This will remove the project code and all its sub-codes. Transactions tagged with \"\(project.name)\" will keep their data but will no longer have a project code assigned.")
        }
        .alert("Delete sub-code \"\(subToDelete?.1 ?? "")\"?",
               isPresented: $showDeleteSubAlert,
               presenting: subToDelete) { pair in
            Button("Delete", role: .destructive) { deleteSubCode(pair.1, from: pair.0) }
            Button("Cancel", role: .cancel) {}
        } message: { pair in
            Text("Transactions tagged with \"\(pair.0.name) / \(pair.1)\" will keep their data but will no longer have a sub-code assigned.")
        }
        // ── THE single sheet for drill + all add/rename modals ──
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .drill(let ctx):
                ProjectTransactionSheet(
                    title:        ctx.title,
                    transactions: ctx.transactions,
                    categories:   categories,
                    is24hr:       is24hr
                )
            case .addProject:
                AddProjectCodeSheet(existingNames: projectCodes.map(\.name)) { name in
                    let order = projectCodes.map(\.sortOrder).max().map { $0 + 1 } ?? 0
                    modelContext.insert(ProjectCode(name: name.uppercased(), sortOrder: order))
                    try? modelContext.save()
                }
                .presentationDetents([.height(260)])
            case .addSubCode(let project):
                AddSubCodeSheet(projectName: project.name, existingSubCodes: project.subCodes) { subName in
                    project.subCodes.append(subName.uppercased())
                    try? modelContext.save()
                }
                .presentationDetents([.height(260)])
            case .renameProject(let project):
                RenameSheet(title: "Rename Project", current: project.name) { newName in
                    let old = project.name
                    let new = newName.uppercased()
                    project.name = new
                    for tx in allTransactions where tx.projectCode == old {
                        tx.projectCode = new
                    }
                    try? modelContext.save()
                }
                .presentationDetents([.height(260)])
            case .renameSubCode(let project, let sub):
                RenameSheet(title: "Rename Sub-code", current: sub) { newName in
                    let newSub = newName.uppercased()
                    if let idx = project.subCodes.firstIndex(of: sub) {
                        project.subCodes[idx] = newSub
                    }
                    for tx in allTransactions
                        where tx.projectCode == project.name && tx.projectSubCode == sub {
                        tx.projectSubCode = newSub
                    }
                    try? modelContext.save()
                }
                .presentationDetents([.height(260)])
            }
        }
    }

    // MARK: Delete helpers

    private func deleteProject(_ project: ProjectCode) {
        for tx in allTransactions where tx.projectCode == project.name {
            tx.projectCode    = nil
            tx.projectSubCode = nil
        }
        modelContext.delete(project)
        try? modelContext.save()
        swipedProjectName = nil
        collapsed.removeValue(forKey: project.name)
        subItems.removeValue(forKey: project.name)
        items.removeAll { $0.name == project.name }
    }

    private func deleteSubCode(_ sub: String, from project: ProjectCode) {
        for tx in allTransactions where tx.projectCode == project.name && tx.projectSubCode == sub {
            tx.projectSubCode = nil
        }
        project.subCodes.removeAll { $0 == sub }
        try? modelContext.save()
        swipedSubKey = nil
        subItems[project.name]?.removeAll { $0 == sub }
    }

    /// Close any open swipe-to-delete row.
    private func dismissSwipes() {
        guard swipedProjectName != nil || swipedSubKey != nil else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            swipedProjectName = nil
            swipedSubKey = nil
        }
    }

    /// Pill-style swipe delete — mirrors the floating native .swipeActions look.
    private func deletePill(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
                .frame(width: deleteButtonWidth)
        }
        .buttonStyle(.plain)
    }

    // MARK: Project block (header + sub-rows)

    @ViewBuilder
    private func projectBlock(_ project: ProjectCode) -> some View {
        let isCollapsed = !editMode && (collapsed[project.name] ?? true)
        let isHidden = hiddenProjects.contains(project.name)
        let total = totalAmount(for: project)
        let isFloating = floatingName == project.name

        VStack(alignment: .leading, spacing: 0) {
            // Header row — swipe left to reveal the delete pill
            let isSwiped = !editMode && swipedProjectName == project.name
            ZStack(alignment: .trailing) {
                deletePill {
                    projectToDelete = project
                    showDeleteProjectAlert = true
                }

                HStack(alignment: .center, spacing: 0) {
                    // "#" gutter — drag handle in edit mode (blocked while a sub-code drags)
                    Text("#")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: gutterWidth, alignment: .leading)
                        .padding(.leading, 20)
                        .gesture(editMode && floatingSubKey == nil ? dragGesture(for: project) : nil)

                    // Name button — tap to expand/collapse, or rename in edit mode
                    Button {
                        if editMode {
                            activeSheet = .renameProject(project)
                        } else if isSwiped {
                            withAnimation(.spring(response: 0.3)) { swipedProjectName = nil }
                        } else {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                collapsed[project.name] = !(collapsed[project.name] ?? true)
                                swipedSubKey = nil
                            }
                        }
                    } label: {
                        HStack(alignment: .center) {
                            Text(project.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor((isHidden && !editMode) ? .secondary : .primary)

                            if !editMode {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                                    .animation(.easeInOut(duration: 0.25), value: isCollapsed)
                                    .padding(.leading, 4)

                                // Eye toggle — hide/show this project from the grand total
                                Image(systemName: isHidden ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 5)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            var updated = hiddenProjects
                                            if updated.contains(project.name) { updated.remove(project.name) }
                                            else { updated.insert(project.name) }
                                            hiddenProjectsRaw = updated.sorted().joined(separator: ",")
                                        }
                                    }
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Amount — tap to drill into this project's transactions
                    let projTaxTip = totalTaxTip(for: project)
                    Button {
                        guard !editMode else { return }
                        activeSheet = .drill(DrillContext(
                            title: project.name,
                            transactions: periodTransactions.filter { $0.projectCode == project.name }
                        ))
                    } label: {
                        VStack(alignment: .trailing, spacing: 1) {
                            SignedAmountLabel(amount: total,
                                              font: .system(size: 15, weight: .medium, design: .rounded),
                                              dimmed: isHidden && !editMode)
                            if showTaxTip && projTaxTip > 0 {
                                Text("/\(formatCurrency(projTaxTip))")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(.secondary)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: showTaxTip)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .disabled(editMode || total == 0)
                }
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
                .offset(x: isSwiped ? -deleteButtonWidth : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSwiped)
                .gesture(
                    !editMode ? DragGesture(minimumDistance: 15)
                        .onEnded { value in
                            let dx = value.translation.width
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if dx < -30 {
                                    swipedProjectName = project.name
                                    swipedSubKey = nil
                                } else if dx > 20, swipedProjectName == project.name {
                                    swipedProjectName = nil
                                }
                            }
                        }
                    : nil
                )
            }
            .clipped()

            // Sub-code rows — local subItems for live reflow while dragging
            if !isCollapsed {
                let currentSubs = subItems[project.name] ?? project.subCodes
                ForEach(currentSubs, id: \.self) { sub in
                    subCodeRow(sub, project: project)
                }

                if editMode {
                    Button { activeSheet = .addSubCode(project) } label: {
                        HStack(alignment: .center, spacing: 0) {
                            Text("•")
                                .font(.system(size: 17))
                                .foregroundColor(.secondary)
                                .frame(width: gutterWidth, alignment: .leading)
                                .padding(.leading, 20)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
        }
        // Measure this block's midY/height in the list coordinate space
        .background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named(coordSpace))
                Color.clear
                    .onAppear {
                        rowMidY[project.name]  = frame.midY
                        rowHeight[project.name] = frame.height
                    }
                    .onChange(of: frame.midY)   { _, v in rowMidY[project.name]  = v }
                    .onChange(of: frame.height) { _, v in rowHeight[project.name] = v }
            }
        )
        .opacity(isFloating ? 0 : 1)   // ghost while floating
    }

    // MARK: Sub-code row

    @ViewBuilder
    private func subCodeRow(_ sub: String, project: ProjectCode) -> some View {
        let key = subKey(project.name, sub)
        let isFloatingSub = floatingSubKey == key
        let isHidden = hiddenProjects.contains(project.name)
        let isSwipedSub = !editMode && swipedSubKey == key

        ZStack(alignment: .trailing) {
            deletePill {
                subToDelete = (project, sub)
                showDeleteSubAlert = true
            }

            HStack(alignment: .center, spacing: 0) {
                // "•" gutter — drag handle for sub-code reorder in edit mode
                Text("•")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .frame(width: gutterWidth, alignment: .leading)
                    .padding(.leading, 20)
                    .gesture(editMode && floatingName == nil ? subDragGesture(for: sub, in: project) : nil)

                Button {
                    if editMode { activeSheet = .renameSubCode(project, sub) }
                } label: {
                    Text(sub)
                        .font(.system(size: 15))
                        .foregroundColor((isHidden && !editMode) ? .secondary : .primary)
                }
                .buttonStyle(.plain)
                .disabled(!editMode)

                Spacer()

                // Amount — tap to drill into this sub-code's transactions
                let subAmt = amount(for: sub, in: project.name)
                let subTaxTip = taxTip(for: sub, in: project.name)
                Button {
                    guard !editMode else { return }
                    activeSheet = .drill(DrillContext(
                        title: "\(project.name) / \(sub)",
                        transactions: periodTransactions.filter { $0.projectCode == project.name && $0.projectSubCode == sub }
                    ))
                } label: {
                    VStack(alignment: .trailing, spacing: 1) {
                        SignedAmountLabel(amount: subAmt, dimmed: isHidden && !editMode)
                        if showTaxTip && subTaxTip > 0 {
                            Text("/\(formatCurrency(subTaxTip))")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundColor(.secondary)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showTaxTip)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .disabled(editMode || subAmt == 0)
            }
            .padding(.vertical, 6)
            .background(
                GeometryReader { geo in
                    let frame = geo.frame(in: .named(coordSpace))
                    Color.clear
                        .onAppear {
                            subRowMidY[key]  = frame.midY
                            subRowHeight[key] = frame.height
                        }
                        .onChange(of: frame.midY)   { _, v in subRowMidY[key]  = v }
                        .onChange(of: frame.height) { _, v in subRowHeight[key] = v }
                }
            )
            .background(Color(UIColor.systemBackground))
            .offset(x: isSwipedSub ? -deleteButtonWidth : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSwipedSub)
            .gesture(!editMode ? DragGesture(minimumDistance: 15).onEnded { value in
                let dx = value.translation.width
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    if dx < -30 {
                        swipedSubKey = key
                        swipedProjectName = nil
                    } else if dx > 20, swipedSubKey == key {
                        swipedSubKey = nil
                    }
                }
            } : nil)
        }
        .clipped()
        .compositingGroup()   // flatten so the opacity transition can't reveal the delete pill behind
        .opacity(isFloatingSub ? 0 : 1)
    }

    // MARK: Floating overlay (project drag)

    @ViewBuilder
    private var floatingOverlay: some View {
        if let name = floatingName,
           let project = items.first(where: { $0.name == name }) {

            let total = totalAmount(for: project)
            let h = rowHeight[name] ?? 44

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    Text("#")
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: gutterWidth, alignment: .leading)
                        .padding(.leading, 20)
                    Text(project.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                    SignedAmountLabel(amount: total, font: .system(size: 15, weight: .medium, design: .rounded))
                        .padding(.trailing, 20)
                }
                .padding(.vertical, 10)

                ForEach(project.subCodes, id: \.self) { sub in
                    HStack(alignment: .center, spacing: 0) {
                        Text("•")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                            .frame(width: gutterWidth, alignment: .leading)
                            .padding(.leading, 20)
                        Text(sub)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                        Spacer()
                        SignedAmountLabel(amount: amount(for: sub, in: project.name))
                            .padding(.trailing, 20)
                    }
                    .padding(.vertical, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
            .scaleEffect(1.03)
            .frame(height: h)
            .position(x: UIScreen.main.bounds.width / 2, y: pickupY + floatOffset.height)
            .allowsHitTesting(false)
            .zIndex(999)
        }
    }

    // MARK: Sub floating overlay (sub-code drag)

    @ViewBuilder
    private var subFloatingOverlay: some View {
        if let key = floatingSubKey {
            let sub = subKeyCode(key)
            let projName = subKeyProject(key)
            let h = subRowHeight[key] ?? 32

            HStack(alignment: .center, spacing: 0) {
                Text("•")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                    .frame(width: gutterWidth, alignment: .leading)
                    .padding(.leading, 20)
                Text(sub)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                Spacer()
                SignedAmountLabel(amount: amount(for: sub, in: projName))
                    .padding(.trailing, 20)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
            .scaleEffect(1.03)
            .frame(height: h)
            .position(x: UIScreen.main.bounds.width / 2, y: pickupSubY + floatSubOffset.height)
            .allowsHitTesting(false)
            .zIndex(998)
        }
    }

    // MARK: Sub drag gesture

    private func subDragGesture(for sub: String, in project: ProjectCode) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace)))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                let key = subKey(project.name, sub)
                if floatingSubKey == nil {
                    if subItems[project.name] == nil { subItems[project.name] = project.subCodes }
                    pickupSubY     = subRowMidY[key] ?? 0
                    floatSubOffset = .zero
                    floatingSubKey = key
                    isReordering   = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                if let drag {
                    floatSubOffset = drag.translation
                    reflowSub(fingerY: drag.location.y, in: project)
                }
            }
            .onEnded { _ in commitAndDropSub(in: project) }
    }

    private func reflowSub(fingerY: CGFloat, in project: ProjectCode) {
        guard let key = floatingSubKey,
              subKeyProject(key) == project.name,
              var subs = subItems[project.name],
              let from = subs.firstIndex(of: subKeyCode(key)) else { return }

        let projectSubs = subs
        let to = projectSubs.indices.min(by: {
            let kA = subKey(project.name, projectSubs[$0])
            let kB = subKey(project.name, projectSubs[$1])
            return abs((subRowMidY[kA] ?? 0) - fingerY) < abs((subRowMidY[kB] ?? 0) - fingerY)
        }) ?? from

        guard to != from else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let moved = subs.remove(at: from)
            subs.insert(moved, at: to)
            subItems[project.name] = subs
        }
    }

    private func commitAndDropSub(in project: ProjectCode) {
        if floatingSubKey != nil, let newOrder = subItems[project.name] {
            project.subCodes = newOrder
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            floatingSubKey = nil
            floatSubOffset = .zero
        }
        isReordering = false
    }

    // MARK: Project drag gesture

    private func dragGesture(for project: ProjectCode) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace)))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if floatingName == nil {
                    pickupY      = rowMidY[project.name] ?? 0
                    floatOffset  = .zero
                    floatingName = project.name
                    isReordering = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                if let drag {
                    floatOffset = drag.translation
                    reflow(fingerY: drag.location.y)
                }
            }
            .onEnded { _ in commitAndDrop() }
    }

    private func reflow(fingerY: CGFloat) {
        guard let name = floatingName,
              let from = items.firstIndex(where: { $0.name == name }) else { return }

        let to = items.indices.min(by: {
            abs((rowMidY[items[$0].name] ?? 0) - fingerY) <
            abs((rowMidY[items[$1].name] ?? 0) - fingerY)
        }) ?? from

        guard to != from else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let moved = items.remove(at: from)
            items.insert(moved, at: to)
        }
    }

    private func commitAndDrop() {
        if floatingName != nil {
            for (i, p) in items.enumerated() { p.sortOrder = i }
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            floatingName = nil
            floatOffset  = .zero
        }
        isReordering = false
    }
}

// ============================================================
// MARK: - ProjectTransactionSheet
// ============================================================
// All transactions matching a project (and optional sub-code) for the
// current period, using the same TransactionListView style.

struct ProjectTransactionSheet: View {
    let title: String
    let transactions: [Transaction]
    let categories: [CategoryModel]
    let is24hr: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var allTransactions: [Transaction]

    @State private var transactionToEdit: Transaction? = nil
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteAlert = false
    @State private var showDeleteGroupAlert = false
    @State private var showTaxTip = false

    var total: Double { transactions.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) } }

    var taxTipTotal: Double {
        transactions.reduce(0) { sum, tx in
            let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
            return sum + taxAmt + tx.tipAmount
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button("Done") { dismiss() }.font(.body)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            List {
                ForEach(grouped, id: \.header) { group in
                    Text(group.header)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    ForEach(group.items) { tx in
                        let cat = categories.first { $0.name == tx.categoryName }
                        TransactionRow(transaction: tx, category: cat, is24hr: is24hr, showTaxTip: false)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .onTapGesture { transactionToEdit = tx }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    transactionToDelete = tx
                                    if tx.groupID != nil { showDeleteGroupAlert = true }
                                    else { showDeleteAlert = true }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Text("Total:").font(.system(size: 20, weight: .bold))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    SignedAmountLabel(amount: total,
                                      font: .system(size: 17, weight: .semibold, design: .rounded),
                                      iconSize: 11)
                    if showTaxTip && taxTipTotal > 0 {
                        Text("/\(formatCurrency(taxTipTotal))")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(.secondary)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: showTaxTip)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                guard taxTipTotal > 0 else { return }
                withAnimation { showTaxTip.toggle() }
            }
        }
        .sheet(item: $transactionToEdit) { tx in
            let cat = categories.first { $0.name == tx.categoryName }
            AddAmountView(
                categoryName:          tx.categoryName,
                categorySymbol:        tx.categorySymbol,
                categoryColor:         cat?.categoryColor ?? .gray,
                isIncome:              tx.isIncome,
                defaultActiveTaxNames: tx.taxRates.map { $0.name },
                defaultTipRate:        tx.selectedTipRate,
                isGasoline:            cat?.isGasoline ?? false,
                categoryTaxPerLiter:   cat?.gasolineTaxPerLiter ?? 0.0,
                editingTransaction:    tx
            )
            .presentationDetents([.large])
        }
        .alert("Delete Transaction?", isPresented: $showDeleteAlert, presenting: transactionToDelete) { tx in
            Button("Delete", role: .destructive) { modelContext.delete(tx) }
            Button("Cancel", role: .cancel) {}
        } message: { tx in
            Text("\"\(tx.title)\" will be permanently deleted.")
        }
        .alert("Delete Linked Transactions?", isPresented: $showDeleteGroupAlert, presenting: transactionToDelete) { tx in
            Button("Delete All Linked", role: .destructive) {
                if let gid = tx.groupID {
                    allTransactions.filter { $0.groupID == gid }.forEach { modelContext.delete($0) }
                }
            }
            Button("Delete Only This One", role: .destructive) { modelContext.delete(tx) }
            Button("Cancel", role: .cancel) {}
        } message: { tx in
            let count = tx.groupID.map { gid in allTransactions.filter { $0.groupID == gid }.count } ?? 1
            Text("This fill-up was split into \(count) daily transactions. Delete all \(count), or just this one?")
        }
    }

    var grouped: [(header: String, items: [Transaction])] {
        var dict: [String: [Transaction]] = [:]
        let cal = Calendar.current
        for tx in transactions {
            let key: String
            if cal.isDateInToday(tx.date)           { key = "Today" }
            else if cal.isDateInYesterday(tx.date)  { key = "Yesterday" }
            else                                    { key = CachedDateFormatters.sectionHeader.string(from: tx.date) }
            dict[key, default: []].append(tx)
        }
        return dict.map { (header: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { ($0.items.first?.date ?? .distantPast) > ($1.items.first?.date ?? .distantPast) }
    }
}

// ============================================================
// MARK: - AddProjectCodeSheet
// ============================================================

struct AddProjectCodeSheet: View {
    let existingNames: [String]
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var isValid: Bool {
        let trimmed = name.uppercased().trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !existingNames.map { $0.uppercased() }.contains(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Project")
                .font(.title2.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("Project code")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                TextField("e.g. PHOTO", text: $name)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .onChange(of: name) { _, new in
                        let filtered = String(new.uppercased().filter { ($0.isLetter && $0.isASCII) || $0.isNumber || $0 == "-" }.prefix(10))
                        if filtered != new { name = filtered }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(14)

                Button("Add") {
                    onAdd(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isValid ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isValid ? .white : .secondary)
                .cornerRadius(14)
                .disabled(!isValid)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - AddSubCodeSheet
// ============================================================

struct AddSubCodeSheet: View {
    let projectName: String
    let existingSubCodes: [String]
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var isValid: Bool {
        let trimmed = name.uppercased().trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && !existingSubCodes.map { $0.uppercased() }.contains(trimmed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("New Sub-code").font(.title2.bold())
                Text("under \(projectName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("Sub-code name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                TextField("e.g. CAMERA", text: $name)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .onChange(of: name) { _, new in
                        let filtered = String(new.uppercased().filter { ($0.isLetter && $0.isASCII) || $0.isNumber || $0 == "-" }.prefix(10))
                        if filtered != new { name = filtered }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(14)

                Button("Add") {
                    onAdd(name.trimmingCharacters(in: .whitespaces))
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isValid ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isValid ? .white : .secondary)
                .cornerRadius(14)
                .disabled(!isValid)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - RenameSheet
// ============================================================

struct RenameSheet: View {
    let title: String
    let current: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal, 24)
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)

                TextField(current, text: $name)
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .onChange(of: name) { _, new in
                        let filtered = String(new.uppercased().filter { ($0.isLetter && $0.isASCII) || $0.isNumber || $0 == "-" }.prefix(10))
                        if filtered != new { name = filtered }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
            }

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundColor(.primary)
                    .cornerRadius(14)

                Button("Save") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    onSave(trimmed.isEmpty ? current : trimmed)
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isValid ? Color.blue : Color.secondary.opacity(0.2))
                .foregroundColor(isValid ? .white : .secondary)
                .cornerRadius(14)
                .disabled(!isValid)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
        .buttonStyle(.plain)
        .onAppear { name = current }
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, CategoryModel.self, ProjectCode.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let p1 = ProjectCode(name: "PHOTO", sortOrder: 0, subCodes: ["CAMERA", "LENS", "FILM"])
    let p2 = ProjectCode(name: "3D-PRINT", sortOrder: 1, subCodes: ["PRINTER", "FILAMENT"])
    let p3 = ProjectCode(name: "AUDIO", sortOrder: 2, subCodes: ["MIC", "INTERFACE", "CABLES"])
    ctx.insert(p1); ctx.insert(p2); ctx.insert(p3)
    return ProjectView()
        .modelContainer(container)
        .environmentObject(SharedPeriodState())
}
