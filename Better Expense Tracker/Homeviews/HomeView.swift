import SwiftUI
import SwiftData

struct HomeView: View {

    // Live queries from SwiftData — update automatically when data changes
    @Query(sort: \CategoryModel.sortOrder) var categories: [CategoryModel]
    @Query var transactions: [Transaction]
    @Environment(\.modelContext) var modelContext

    // Edit mode: when true, X badges and + tiles appear
    @State private var editMode = false

    // True while a tile is being dragged — used to freeze the ScrollView so it
    // doesn't fight the reorder gesture.
    @State private var isReordering = false

    // Which category tile was tapped (opens AddAmountView)
    @State private var selectedCategory: CategoryModel? = nil

    // Which category X was tapped (opens DeleteCategoryView)
    @State private var categoryToDelete: CategoryModel? = nil

    // Which category tile was tapped in edit mode (opens edit sheet)
    @State private var categoryToEdit: CategoryModel? = nil

    // Which section's + was tapped (nil = not adding, true = outcome, false = income)
    @State private var addingCategoryIsOutcome: Bool? = nil

    // Shared date-range state (synced across Home, Transactions, Projects)
    @EnvironmentObject private var period: SharedPeriodState

    // Prevents seeding default categories more than once
    @AppStorage("hasSeededCategories") private var hasSeededCategories = false

    let padding: CGFloat = 16
    let spacing: CGFloat = 16
    let minTileWidth: CGFloat = 90
    let maxTileWidth: CGFloat = 160

    // Split categories into the two groups
    var outcomeCategories: [CategoryModel] { categories.filter { $0.isOutcome } }
    var incomeCategories:  [CategoryModel] { categories.filter { !$0.isOutcome } }

    // Start of the current period
    // Transactions filtered to the current period
    var monthTransactions: [Transaction] {
        transactions.filter { $0.date >= period.periodStart && $0.date < period.periodEnd }
    }

    var body: some View {
        GeometryReader { geometry in
                let availableWidth = geometry.size.width - (padding * 2)
                let columnCount = max(1, Int(availableWidth / (minTileWidth + spacing)))
                let tileWidth = min(maxTileWidth, (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
                let tileHeight = tileWidth * 4 / 3

                ZStack(alignment: .top) {
                    // ScrollView always fills the full available space.
                    // safeAreaInset pushes content below the navigator when it is visible.
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            CategorySection(
                                title: "Spending",
                                categories: outcomeCategories,
                                transactions: monthTransactions,
                                columnCount: columnCount,
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                                spacing: spacing,
                                editMode: editMode,
                                isReordering: $isReordering,
                                onTileTap:       { selectedCategory = $0 },
                                onTileEdit:      { categoryToEdit = $0 },
                                onTileLongPress: { withAnimation(.spring(response: 0.3)) { editMode = true } },
                                onTileDelete:    { categoryToDelete = $0 },
                                onAddTap:        { addingCategoryIsOutcome = true }
                            )

                            CategorySection(
                                title: "Income",
                                categories: incomeCategories,
                                transactions: monthTransactions,
                                columnCount: columnCount,
                                tileWidth: tileWidth,
                                tileHeight: tileHeight,
                                spacing: spacing,
                                editMode: editMode,
                                isReordering: $isReordering,
                                onTileTap:       { selectedCategory = $0 },
                                onTileEdit:      { categoryToEdit = $0 },
                                onTileLongPress: { withAnimation(.spring(response: 0.3)) { editMode = true } },
                                onTileDelete:    { categoryToDelete = $0 },
                                onAddTap:        { addingCategoryIsOutcome = false }
                            )
                        }
                        .padding(.horizontal, padding)
                        .padding(.bottom, padding)
                        .padding(.top, padding)
                    }
                    .scrollClipDisabled()
                    .scrollDisabled(isReordering)
                    // Push scroll content down by the navigator + tabs height when visible
                    .safeAreaInset(edge: .top, spacing: 0) {
                        Color.clear.frame(height: editMode ? 0 : 96)
                            .animation(.spring(response: 0.3), value: editMode)
                    }
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
                            .padding(16)
                        }
                    }

                    // Navigator + range tabs float on top, fade out in edit mode
                    VStack(spacing: 0) {
                        if period.selectedRange == .month {
                            MonthPeriodNavigatorBar(selectedMonth: $period.selectedMonth)
                        } else {
                            PeriodNavigatorBar(
                                onPrevious: { period.periodOffset -= 1 },
                                onNext:     { period.periodOffset = min(0, period.periodOffset + 1) },
                                hideChevrons: period.selectedRange == .custom
                            ) {
                                Text(period.periodLabel)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .onTapGesture {
                                        if period.selectedRange == .week {
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
                        }
                        SharedDateRangeTabs(selected: $period.selectedRange, onRangeChange: { },
                                            onCustomTap: { period.showCustomRangePicker = true })
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .background(.background)
                    .opacity(editMode ? 0 : 1)
                    .allowsHitTesting(!editMode)
                    .animation(.spring(response: 0.3), value: editMode)
                }
            }
            .onAppear { seedIfNeeded() }

        // Sheet: week picker
        .sheet(isPresented: $period.showWeekPicker) {
            WeekPickerSheet(selectedWeekStart: $period.pickerWeekStart, isPresented: $period.showWeekPicker)
                .presentationDetents([.medium])
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

        // Sheet: custom date range picker
        .sheet(isPresented: $period.showCustomRangePicker) {
            CustomDateRangeSheet(startDate: $period.customStart, endDate: $period.customEnd, isPresented: $period.showCustomRangePicker)
                .presentationDetents([.medium])
                .onDisappear { period.selectedRange = .custom }
        }

        // Sheet: add a transaction to an existing category
        .sheet(item: $selectedCategory) { category in
            AddAmountView(
                categoryName:           category.name,
                categorySymbol:         category.symbol,
                categoryColor:          category.categoryColor,
                isIncome:               !category.isOutcome,
                defaultActiveTaxNames:  category.defaultActiveTaxNames,
                defaultTipRate:         category.defaultTipRate,
                isGasoline:             category.isGasoline,
                categoryTaxPerLiter:    category.gasolineTaxPerLiter
            )
            .presentationDetents([.large])
        }

        // Sheet: confirm deleting a category
        .sheet(item: $categoryToDelete) { category in
            DeleteCategoryView(category: category)
                .presentationDetents([.large])
        }

        // Sheet: add new outcome category
        .sheet(
            isPresented: Binding(
                get: { addingCategoryIsOutcome == true },
                set: { if !$0 { addingCategoryIsOutcome = nil } }
            )
        ) {
            AddCategoryView(isOutcome: true)
                .presentationDetents([.large])
        }

        // Sheet: add new income category
        .sheet(
            isPresented: Binding(
                get: { addingCategoryIsOutcome == false },
                set: { if !$0 { addingCategoryIsOutcome = nil } }
            )
        ) {
            AddCategoryView(isOutcome: false)
                .presentationDetents([.large])
        }

        // Sheet: edit an existing category
        .sheet(item: $categoryToEdit) { category in
            AddCategoryView(isOutcome: category.isOutcome, editingCategory: category)
                .presentationDetents([.large])
        }

    }

    // Seeds default categories the very first time the app runs
    func seedIfNeeded() {
        guard !hasSeededCategories, categories.isEmpty else { return }
        hasSeededCategories = true

        let outcomeDefaults: [(String, String, String)] = [
            ("Grocery",   "basket.fill",  "yellow"),
            ("Transport", "car.fill",     "blue"),
            ("Health",    "heart.fill",   "red"),
            ("Shopping",  "bag.fill",     "purple"),
            ("Eat out",   "fork.knife",   "orange"),
            ("Travel",    "airplane",     "green"),
        ]
        for (i, (name, symbol, color)) in outcomeDefaults.enumerated() {
            modelContext.insert(CategoryModel(name: name, symbol: symbol, colorName: color, isOutcome: true, sortOrder: i))
        }

        let incomeDefaults: [(String, String, String)] = [
            ("Salary", "dollarsign.circle.fill", "green"),
        ]
        for (i, (name, symbol, color)) in incomeDefaults.enumerated() {
            modelContext.insert(CategoryModel(name: name, symbol: symbol, colorName: color, isOutcome: false, sortOrder: i))
        }
    }
}

// ============================================================
// MARK: - CategorySection
// ============================================================
// One section (either Outcome or Income) containing its tile grid.
//
// Reordering ("floating tile") lives entirely inside this view. A drag can
// only ever rearrange tiles within the same section — Spending and Income
// tiles can never cross over.

struct CategorySection: View {
    let title: String
    let categories: [CategoryModel]
    let transactions: [Transaction]
    let columnCount: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let spacing: CGFloat
    let editMode: Bool
    @Binding var isReordering: Bool
    let onTileTap: (CategoryModel) -> Void
    let onTileEdit: (CategoryModel) -> Void
    let onTileLongPress: () -> Void
    let onTileDelete: (CategoryModel) -> Void
    let onAddTap: () -> Void

    @Environment(\.modelContext) private var modelContext

    // Local ordered copy of the categories, used for live reflow while dragging.
    @State private var items: [CategoryModel] = []

    // Collapse / expand
    @State private var isCollapsed = false
    @State private var gridHeight: CGFloat = 0

    // Drag state
    // floatingName — name of the tile currently in flight (nil = none)
    // pickupCenter — the tile's slot centre in grid coordinates at lift time
    // floatOffset  — cumulative finger translation since lift
    @State private var floatingName: String? = nil
    @State private var pickupCenter: CGPoint = .zero
    @State private var floatOffset: CGSize = .zero

    // Unique coordinate-space name per section instance
    private var coordSpace: String { "catGrid_\(title)" }

    private var contentWidth: CGFloat {
        CGFloat(columnCount) * tileWidth + CGFloat(max(columnCount - 1, 0)) * spacing
    }

    // Fingerprint used to resync `items` when categories change outside a drag.
    private var orderSignature: [String] {
        categories.map { "\($0.name)#\($0.sortOrder)" }
    }

    func total(for name: String) -> Double {
        transactions.filter { $0.categoryName == name }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            // Clipped collapse wrapper — the floating overlay is placed OUTSIDE
            // this frame so it is never cut off by .clipped().
            ZStack(alignment: .top) {
                grid
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { gridHeight = geo.size.height }
                                .onChange(of: geo.size.height) { _, h in gridHeight = h }
                        }
                    )
                    .opacity(isCollapsed ? 0 : 1)
                    .animation(.easeInOut(duration: 0.5), value: isCollapsed)
            }
            // Animate height to 0 when collapsed.
            // We use a wide mask (never clips left/right shadows) instead of
            // .clipped(). 10pt of extra space is added above (for X badges at
            // y:-6) and below (for the tile drop-shadow radius) via the
            // padding / negative-padding pairs, which keep layout size unchanged.
            .padding(.top, 10)
            .padding(.bottom, 10)
            .frame(height: isCollapsed ? 0 : (gridHeight > 0 ? gridHeight + 20 : 0), alignment: .top)
            .animation(.easeInOut(duration: 0.5), value: isCollapsed)
            .mask(alignment: .top) {
                Rectangle()
                    .frame(
                        width: 100_000,
                        height: isCollapsed ? 0 : (gridHeight > 0 ? gridHeight + 20 : 0)
                    )
                    .animation(.easeInOut(duration: 0.5), value: isCollapsed)
            }
            .padding(.top, -10)
            .padding(.bottom, -10)
        }
        // The floating tile overlay sits on the outer VStack so it is above
        // the clipped collapse frame and can render anywhere within the section.
        .overlay(alignment: .topLeading) {
            floatingOverlay
        }
        .onAppear { if items.isEmpty { items = categories } }
        .onChange(of: orderSignature) { _, _ in
            if floatingName == nil { items = categories }
        }
    }

    // MARK: Header

    private var header: some View {
        Button { isCollapsed.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.largeTitle).bold()
                    .foregroundColor(.primary)

                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                    .animation(.easeInOut(duration: 0.25), value: isCollapsed)

                if isCollapsed {
                    Text("Tap to show")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }

                Spacer()
            }
            .padding(.leading, 20)
        }
        .buttonStyle(.plain)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: columnCount),
            spacing: spacing
        ) {
            ForEach(items) { category in
                tile(for: category)
            }

            if editMode || items.isEmpty {
                addTile
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .coordinateSpace(name: coordSpace)
    }

    // MARK: Individual tile

    private func tile(for category: CategoryModel) -> some View {
        CategoryButton(
            categoryName:    category.name,
            categorySymbol:  category.symbol,
            categoryAmount:  total(for: category.name),
            backgroundColor: category.categoryColor,
            tileWidth:       tileWidth,
            tileHeight:      tileHeight,
            editMode:        editMode,
            onDeleteTap:     { onTileDelete(category) },
            onTap: {
                guard floatingName == nil else { return }
                if editMode { onTileEdit(category) } else { onTileTap(category) }
            },
            onLongPress: {
                guard floatingName == nil, !editMode else { return }
                onTileLongPress()
            }
        )
        // Ghost placeholder while floating — stays in layout to hold the gap.
        .opacity(floatingName == category.name ? 0 : 1)
        // In edit mode, attach the drag gesture directly. Because CategoryButton
        // now uses .onTapGesture/.onLongPressGesture (no UIKit Button in the
        // hit path) there is no gesture conflict.
        .gesture(editMode ? dragGesture(for: category) : nil)
    }

    private var addTile: some View {
        Button { onAddTap() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: tileWidth, height: tileHeight)
                Image(systemName: "plus")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Floating overlay

    // Rendered on the outer VStack so it is above the clipped collapse frame.
    // pickupCenter is in grid-local coords; we offset by headerHeight to
    // account for the section title row that sits above the grid.
    @ViewBuilder
    private var floatingOverlay: some View {
        if let floatingName,
           let cat = items.first(where: { $0.name == floatingName }) {
            CategoryButton(
                categoryName:    cat.name,
                categorySymbol:  cat.symbol,
                categoryAmount:  total(for: cat.name),
                backgroundColor: cat.categoryColor,
                tileWidth:       tileWidth,
                tileHeight:      tileHeight,
                editMode:        false,
                onDeleteTap:     {},
                onTap:           {},
                onLongPress:     {}
            )
            .scaleEffect(1.08)
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
            .position(
                x: pickupCenter.x + floatOffset.width,
                y: pickupCenter.y + floatOffset.height + headerHeight
            )
            .allowsHitTesting(false)
            .zIndex(999)
        }
    }

    // Approximate height of the header row (largeTitle + spacing).
    private var headerHeight: CGFloat { 52 }

    // MARK: Drag gesture

    private func dragGesture(for category: CategoryModel) -> some Gesture {
        // LongPressGesture lifts the tile after 0.35 s; DragGesture then tracks
        // the finger. Because CategoryButton no longer contains a UIKit Button,
        // there is nothing competing with this gesture.
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace)))
            .onChanged { value in
                switch value {
                case .second(true, let drag):
                    if floatingName == nil {
                        // Lift moment: record the tile's current slot centre.
                        let idx = items.firstIndex { $0.name == category.name } ?? 0
                        pickupCenter = slotCenter(for: idx)
                        floatOffset = .zero
                        floatingName = category.name
                        isReordering = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    if let drag {
                        floatOffset = drag.translation
                        reflow(fingerAt: drag.location)
                    }
                default:
                    break
                }
            }
            .onEnded { _ in commitAndDrop() }
    }

    // Shift items so the dragged tile occupies the slot nearest the finger.
    private func reflow(fingerAt point: CGPoint) {
        guard let floatingName,
              let from = items.firstIndex(where: { $0.name == floatingName }) else { return }
        let to = nearestSlot(for: point)
        guard to != from else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            let moved = items.remove(at: from)
            items.insert(moved, at: min(to, items.count))
        }
    }

    // Write final sortOrder values to SwiftData and drop the floating tile.
    private func commitAndDrop() {
        if floatingName != nil {
            for (i, cat) in items.enumerated() {
                cat.sortOrder = i
            }
            try? modelContext.save()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            floatingName = nil
            floatOffset = .zero
        }
        isReordering = false
    }

    // MARK: Geometry helpers

    // Centre of a grid slot in the named coordinate space.
    private func slotCenter(for index: Int) -> CGPoint {
        let cols = max(columnCount, 1)
        let col = index % cols
        let row = index / cols
        return CGPoint(
            x: CGFloat(col) * (tileWidth + spacing) + tileWidth / 2,
            y: CGFloat(row) * (tileHeight + spacing) + tileHeight / 2
        )
    }

    // Index of the slot whose centre is nearest the given point.
    private func nearestSlot(for point: CGPoint) -> Int {
        guard !items.isEmpty else { return 0 }
        let col = min(max(Int(point.x / (tileWidth + spacing)), 0), columnCount - 1)
        let row = max(Int(point.y / (tileHeight + spacing)), 0)
        return min(row * columnCount + col, items.count - 1)
    }
}

// ============================================================
// MARK: - Calendar helper
// ============================================================

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let comps = dateComponents([.year, .month], from: date)
        return self.date(from: comps) ?? date
    }
}




#Preview {
    let container = try! ModelContainer(
        for: Transaction.self, CategoryModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let outcomeDefaults: [(String, String, String)] = [
        ("Grocery",   "basket.fill",              "yellow"),
        ("Transport", "car.fill",                 "blue"),
        ("Health",    "heart.fill",               "red"),
        ("Shopping",  "bag.fill",                 "purple"),
        ("Eat out",   "fork.knife",               "orange"),
        ("Travel",    "airplane",                 "green"),
    ]
    for (i, (name, symbol, color)) in outcomeDefaults.enumerated() {
        ctx.insert(CategoryModel(name: name, symbol: symbol, colorName: color, isOutcome: true, sortOrder: i))
    }
    ctx.insert(CategoryModel(name: "Salary", symbol: "dollarsign.circle.fill", colorName: "green", isOutcome: false, sortOrder: 0))
    return HomeView().modelContainer(container)
}
