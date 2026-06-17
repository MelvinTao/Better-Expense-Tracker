import SwiftUI
import SwiftData

// ============================================================
// MARK: - TransactionsView
// ============================================================

struct TransactionsView: View {
    @Query(sort: \CategoryModel.sortOrder) var categories: [CategoryModel]
    @Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]
    @AppStorage(AppStorageKeys.timeFormatIs24hr) private var is24hr = false
    @Environment(\.modelContext) var modelContext

    // Shared date-range state (synced across Home, Transactions, Projects)
    @EnvironmentObject private var period: SharedPeriodState

    // Filter chips — empty set means "All"
    @State private var selectedCategoryNames: Set<String> = []

    // Long-press to toggle tax/tip visibility in chart and list rows
    @State private var showTaxTip = false

    // Edit / delete transaction sheets
    @State private var transactionToEdit: Transaction? = nil
    @State private var transactionToDelete: Transaction? = nil
    @State private var showDeleteAlert = false
    @State private var showDeleteGroupAlert = false

    // MARK: - Period filtering

    var periodTransactions: [Transaction] {
        transactions.filter { $0.date >= period.periodStart && $0.date < period.periodEnd }
    }

    var filteredTransactions: [Transaction] {
        if selectedCategoryNames.isEmpty { return periodTransactions }
        return periodTransactions.filter { selectedCategoryNames.contains($0.categoryName) }
    }

    // MARK: - Chart buckets

    var chartBuckets: [(Date, [Transaction])] {
        let cal = Calendar.current
        let start = period.periodStart
        let allTx = filteredTransactions

        switch period.selectedRange {
        case .week:
            return (0..<7).map { day in
                let bucketStart = cal.date(byAdding: .day, value: day, to: start)!
                let bucketEnd   = cal.date(byAdding: .day, value: 1, to: bucketStart)!
                return (bucketStart, allTx.filter { $0.date >= bucketStart && $0.date < bucketEnd })
            }
        case .month:
            let daysInMonth = cal.range(of: .day, in: .month, for: start)?.count ?? 30
            return (0..<daysInMonth).map { day in
                let bucketStart = cal.date(byAdding: .day, value: day, to: start)!
                let bucketEnd   = cal.date(byAdding: .day, value: 1, to: bucketStart)!
                return (bucketStart, allTx.filter { $0.date >= bucketStart && $0.date < bucketEnd })
            }
        case .year:
            return (0..<12).map { month in
                let bucketStart = cal.date(byAdding: .month, value: month, to: start)!
                let bucketEnd   = cal.date(byAdding: .month, value: 1, to: bucketStart)!
                return (bucketStart, allTx.filter { $0.date >= bucketStart && $0.date < bucketEnd })
            }
        case .custom:
            let days = max(1, cal.dateComponents([.day], from: period.periodStart, to: period.periodEnd).day ?? 1)
            return (0..<days).map { day in
                let bucketStart = cal.date(byAdding: .day, value: day, to: start)!
                let bucketEnd   = cal.date(byAdding: .day, value: 1, to: bucketStart)!
                return (bucketStart, allTx.filter { $0.date >= bucketStart && $0.date < bucketEnd })
            }
        }
    }

    var currentBucketIndex: Int? {
        guard period.periodOffset == 0 else { return nil }
        let now = Date.now
        return chartBuckets.firstIndex { bucket in
            let cal = Calendar.current
            let bucketEnd: Date
            switch period.selectedRange {
            case .week, .custom: bucketEnd = cal.date(byAdding: .day,   value: 1, to: bucket.0)!
            case .month:         bucketEnd = cal.date(byAdding: .day,   value: 1, to: bucket.0)!
            case .year:          bucketEnd = cal.date(byAdding: .month, value: 1, to: bucket.0)!
            }
            return now >= bucket.0 && now < bucketEnd
        }
    }

    // MARK: - Summary averages

    func distinctPeriodCount(isIncome: Bool) -> Int {
        let cal = Calendar.current
        let relevant = transactions.filter { $0.isIncome == isIncome }
        let keys: Set<String> = Set(relevant.map { tx in
            switch period.selectedRange {
            case .week:   return "\(cal.component(.year, from: tx.date))-\(cal.component(.weekOfYear, from: tx.date))"
            case .month:  return "\(cal.component(.year, from: tx.date))-\(cal.component(.month, from: tx.date))"
            case .year:   return "\(cal.component(.year, from: tx.date))"
            case .custom: return "custom"
            }
        })
        return max(1, keys.count)
    }

    var Outcome: Double {
        let total = transactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        return total / Double(distinctPeriodCount(isIncome: false))
    }

    var Income: Double {
        let total = transactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        return total / Double(distinctPeriodCount(isIncome: true))
    }

    // Tax + tip totals for the current period (all categories, no filter)
    var periodOutcomeTaxTip: Double {
        periodTransactions.filter { !$0.isIncome }.reduce(0) { sum, tx in
            let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
            return sum + taxAmt + tx.tipAmount
        }
    }

    var periodIncomeTaxTip: Double {
        periodTransactions.filter { $0.isIncome }.reduce(0) { sum, tx in
            let taxAmt = tx.gasoline ? tx.gasolineTaxAmount : tx.totalTaxAmount
            return sum + taxAmt + tx.tipAmount
        }
    }

    // Period totals (not averaged) for the net card
    var periodOutcomeTotal: Double {
        periodTransactions.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    var periodIncomeTotal: Double {
        periodTransactions.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    var periodNet: Double { periodIncomeTotal - periodOutcomeTotal }

    var periodNetTaxTip: Double { periodIncomeTaxTip - periodOutcomeTaxTip }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // Period navigator bar
            PeriodNavigatorBar(
                onPrevious: { period.periodOffset -= 1 },
                onNext:     { period.periodOffset = min(0, period.periodOffset + 1) },
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

            SharedDateRangeTabs(selected: $period.selectedRange, onRangeChange: { },
                                onCustomTap: { period.showCustomRangePicker = true })
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            // Summary cards
            HStack(spacing: 10) {
                SummaryCard(title: "Avg Spent", amount: Outcome, taxTipAmount: periodOutcomeTaxTip, isOutcome: true, showTaxTip: showTaxTip)
                SummaryCard(title: "Avg Earned", amount: Income, taxTipAmount: periodIncomeTaxTip, isOutcome: false, showTaxTip: showTaxTip)
                SummaryCard(title: "Net", amount: periodNet, taxTipAmount: periodNetTaxTip, isOutcome: false, showTaxTip: showTaxTip, isNet: true)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            CategoryFilterBar(
                categories: categories,
                selectedNames: $selectedCategoryNames
            )

            // Histogram — swipe left/right changes period; long-press toggles tax/tip
            HistogramView(
                buckets: chartBuckets,
                currentBucketIndex: currentBucketIndex,
                categories: categories,
                showTaxTip: showTaxTip
            )
            .frame(height: 160)
            .padding(.horizontal, 12)
            .gesture(DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < 0 {
                        period.periodOffset -= 1
                    } else {
                        period.periodOffset = min(0, period.periodOffset + 1)
                    }
                }
            )
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in withAnimation { showTaxTip.toggle() } }
            )
            .padding(.bottom, 8)

            Divider()

            // Transaction list
            TransactionListView(
                transactions: filteredTransactions,
                categories: categories,
                is24hr: is24hr,
                showTaxTip: showTaxTip,
                onTap: { transactionToEdit = $0 },
                onDelete: { tx in
                    transactionToDelete = tx
                    if tx.groupID != nil {
                        showDeleteGroupAlert = true
                    } else {
                        showDeleteAlert = true
                    }
                }
            )
        }
        // Period picker sheets
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
        // Transaction edit sheet
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
        // Standard single-transaction delete
        .alert("Delete Transaction?", isPresented: $showDeleteAlert, presenting: transactionToDelete) { tx in
            Button("Delete", role: .destructive) { modelContext.delete(tx) }
            Button("Cancel", role: .cancel) {}
        } message: { tx in
            Text("\"\(tx.title)\" will be permanently deleted.")
        }
        // Gasoline group delete
        .alert("Delete Linked Transactions?", isPresented: $showDeleteGroupAlert, presenting: transactionToDelete) { tx in
            Button("Delete All Linked", role: .destructive) {
                if let gid = tx.groupID {
                    transactions.filter { $0.groupID == gid }.forEach { modelContext.delete($0) }
                }
            }
            Button("Delete Only This One", role: .destructive) { modelContext.delete(tx) }
            Button("Cancel", role: .cancel) {}
        } message: { tx in
            let count = tx.groupID.map { gid in transactions.filter { $0.groupID == gid }.count } ?? 1
            Text("This fill-up was split into \(count) daily transactions. Delete all \(count), or just this one?")
        }
    }
}

// ============================================================
// MARK: - CategoryFilterBar
// ============================================================

struct CategoryFilterBar: View {
    let categories: [CategoryModel]
    @Binding var selectedNames: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" chip
                let allSelected = selectedNames.isEmpty
                Button { selectedNames = [] } label: {
                    Text("All")
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(allSelected ? Color.primary : Color.secondary.opacity(0.12))
                        .foregroundColor(allSelected ? Color(UIColor.systemBackground) : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Category chips
                ForEach(categories) { cat in
                    let selected = selectedNames.contains(cat.name)
                    Button {
                        if selected { selectedNames.remove(cat.name) }
                        else { selectedNames.insert(cat.name) }
                    } label: {
                        Text(cat.name)
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(selected ? cat.categoryColor.color : Color.secondary.opacity(0.12))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}

// ============================================================
// MARK: - SummaryCard
// ============================================================

struct SummaryCard: View {
    let title: String
    let amount: Double
    let taxTipAmount: Double
    let isOutcome: Bool
    let showTaxTip: Bool
    var isNet: Bool = false

    var bgColor: Color {
        if isNet {
            return amount >= 0
                ? Color(red: 0.831, green: 0.933, blue: 0.851)
                : Color(red: 0.976, green: 0.863, blue: 0.863)
        }
        return isOutcome
            ? Color(red: 0.976, green: 0.863, blue: 0.863)
            : Color(red: 0.831, green: 0.933, blue: 0.851)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(String(format: "$%.2f", Swift.abs(amount)))
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
            if showTaxTip && taxTipAmount != 0 {
                Text(String(format: "+$%.2f tax", Swift.abs(taxTipAmount)))
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bgColor)
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: showTaxTip)
    }
}

// ============================================================
// MARK: - HistogramView
// ============================================================
// Layout: a left Y-axis label column (44pt wide) + the chart canvas.
// The chart area is split into equal top half (spending, bars grow UP from midline)
// and bottom half (income, bars grow DOWN from midline).
// Each half uses its own independent scale so both always fill their half.

struct HistogramView: View {
    let buckets: [(Date, [Transaction])]
    let currentBucketIndex: Int?
    let categories: [CategoryModel]
    let showTaxTip: Bool

    // Y-axis label width
    private let axisWidth: CGFloat = 44

    // Max total outcome/income across all buckets (for scaling)
    // When showTaxTip is on, income bars extend beyond tx.amount by tax+tip, so account for that.
    var maxOutcome: Double {
        let v = buckets.map { $0.1.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }.max() ?? 0
        return v > 0 ? v : 1
    }
    var maxIncome: Double {
        let v = buckets.map { $0.1.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }.max() ?? 0
        return v > 0 ? v : 1
    }

    // Nice round label values for each half (3 ticks: 0, mid, max)
    func niceMax(_ raw: Double) -> Double {
        let magnitude = pow(10, floor(log10(raw)))
        let normalised = raw / magnitude
        let nice: Double
        if normalised <= 1.5      { nice = 1.5 }
        else if normalised <= 2.0 { nice = 2.0 }
        else if normalised <= 2.5 { nice = 2.5 }
        else if normalised <= 5.0 { nice = 5.0 }
        else                       { nice = 10.0 }
        return nice * magnitude
    }

    var body: some View {
        GeometryReader { geo in
            let chartWidth = geo.size.width - axisWidth
            let chartHeight = geo.size.height

            ZStack(alignment: .leading) {
                // ── Y-axis labels ─────────────────────────────────
                let niceOut = niceMax(maxOutcome)
                let niceIn  = niceMax(maxIncome)
                let topPad: CGFloat = 6   // breathing room at top/bottom edges

                VStack(spacing: 0) {
                    // Income top label (max income, shown at very top)
                    Text(formatAxisAmt(niceIn))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: axisWidth - 4, alignment: .trailing)
                        .frame(height: topPad, alignment: .center)

                    Spacer()

                    // Income mid label
                    Text(formatAxisAmt(niceIn / 2))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: axisWidth - 4, alignment: .trailing)

                    // Zero label at midline
                    Text("0")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: axisWidth - 4, alignment: .trailing)
                        .padding(.vertical, 1)

                    // Outcome mid label (half of max spending)
                    Text(formatAxisAmt(niceOut / 2))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: axisWidth - 4, alignment: .trailing)

                    Spacer()

                    // Outcome bottom label (max spending, shown at very bottom)
                    Text(formatAxisAmt(niceOut))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: axisWidth - 4, alignment: .trailing)
                        .frame(height: topPad, alignment: .center)
                }
                .frame(width: axisWidth, height: chartHeight)

                // ── Bars canvas ───────────────────────────────────
                Canvas { context, size in
                    guard !buckets.isEmpty else { return }

                    let niceOutScale = niceMax(maxOutcome)
                    let niceInScale  = niceMax(maxIncome)

                    // Available pixel height for each half, minus edge padding
                    let halfH = size.height / 2 - topPad
                    let outScale = halfH / niceOutScale   // px per dollar (outcome)
                    let inScale  = halfH / niceInScale    // px per dollar (income)

                    let mid = size.height / 2
                    let barSpacing: CGFloat = buckets.count > 14 ? 1 : 2
                    let totalSpacing = barSpacing * CGFloat(buckets.count - 1)
                    let barWidth = max(2, (size.width - totalSpacing) / CGFloat(buckets.count))

                    for (idx, bucket) in buckets.enumerated() {
                        let x = CGFloat(idx) * (barWidth + barSpacing)
                        let isHighlighted = idx == currentBucketIndex || currentBucketIndex == nil
                        let opacity: Double = isHighlighted ? 1.0 : 0.45

                        // Sort by category sortOrder so lowest order = closest to baseline
                        func sortOrder(for tx: Transaction) -> Int {
                            categories.first { $0.name == tx.categoryName }?.sortOrder ?? 999
                        }
                        let outcomeTx = bucket.1.filter { !$0.isIncome }
                            .sorted { sortOrder(for: $0) < sortOrder(for: $1) }
                        let incomeTx = bucket.1.filter { $0.isIncome }
                            .sorted { sortOrder(for: $0) < sortOrder(for: $1) }

                        // Income bars — grow upward from mid
                        // Category color near baseline; grey extension further away at the top.
                        var iy = mid
                        for tx in incomeTx {
                            let cat = categories.first { $0.name == tx.categoryName }
                            let baseH   = CGFloat(tx.amount) * inScale
                            let taxTipH = CGFloat(tx.totalTaxAmount + tx.tipAmount) * inScale

                            // Draw category color (near midline)
                            let baseRect = CGRect(x: x, y: iy - baseH, width: barWidth, height: max(baseH, 0))
                            context.fill(Path(baseRect),
                                with: .color((cat?.categoryColor.color ?? .gray).opacity(opacity)))
                            iy -= baseH

                            // Draw grey extension at the far end (top)
                            if showTaxTip && taxTipH > 0 {
                                let tr = CGRect(x: x, y: iy - taxTipH, width: barWidth, height: max(taxTipH, 1))
                                context.fill(Path(tr), with: .color(Color.gray.opacity(0.45 * opacity)))
                                iy -= taxTipH
                            }
                        }

                        // Outcome bars — grow downward from mid
                        // Total bar height = tx.amount (unchanged whether tax/tip shown or not).
                        // When showTaxTip: overdraw the top (baseline-side) chunk in grey.
                        var oy = mid
                        for tx in outcomeTx {
                            let cat = categories.first { $0.name == tx.categoryName }
                            let totalH  = CGFloat(tx.amount) * outScale
                            // Gasoline tax is stored in gasolineTaxAmount (not baked into baseAmount),
                            // so use that directly; all other outcomes use amount - baseAmount.
                            let taxAmt  = tx.gasoline ? tx.gasolineTaxAmount : (tx.amount - tx.baseAmount)
                            let taxTipH = CGFloat(taxAmt) * outScale

                            // Draw full bar in category color
                            let fullRect = CGRect(x: x, y: oy, width: barWidth, height: max(totalH, 0))
                            context.fill(Path(fullRect),
                                with: .color((cat?.categoryColor.color ?? .gray).opacity(opacity)))

                            // Overdraw the top (baseline-side) chunk in grey for tax/tip
                            if showTaxTip && taxTipH > 0 {
                                let greyRect = CGRect(x: x, y: oy, width: barWidth, height: max(taxTipH, 1))
                                context.fill(Path(greyRect), with: .color(Color.gray.opacity(0.45 * opacity)))
                            }

                            oy += totalH
                        }
                    }

                    // Midline baseline
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: mid))
                    path.addLine(to: CGPoint(x: size.width, y: mid))
                    context.stroke(path, with: .color(Color.secondary.opacity(0.35)), lineWidth: 1)
                }
                .frame(width: chartWidth, height: chartHeight)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(8)
                .padding(.leading, axisWidth)
            }
        }
    }

    private func formatAxisAmt(_ v: Double) -> String {
        if v >= 1000 { return String(format: "$%.0fk", v / 1000) }
        return String(format: "$%.0f", v)
    }
}

// ============================================================
// MARK: - TransactionListView
// ============================================================

struct TransactionListView: View {
    let transactions: [Transaction]
    let categories: [CategoryModel]
    let is24hr: Bool
    let showTaxTip: Bool
    let onTap: (Transaction) -> Void
    let onDelete: (Transaction) -> Void

    // Group transactions by a period key string for section headers
    // Sorted newest-first within each group
    var grouped: [(header: String, items: [Transaction])] {
        var dict: [String: [Transaction]] = [:]
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"

        for tx in transactions {
            let key: String
            if cal.isDateInToday(tx.date) {
                key = "Today"
            } else if cal.isDateInYesterday(tx.date) {
                key = "Yesterday"
            } else {
                key = fmt.string(from: tx.date)
            }
            dict[key, default: []].append(tx)
        }

        // Sort sections newest-first using the first transaction's date in each group
        return dict.map { (header: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { groupA, groupB in
                let dateA = groupA.items.first?.date ?? Date.distantPast
                let dateB = groupB.items.first?.date ?? Date.distantPast
                return dateA > dateB
            }
    }

    var body: some View {
        List {
            ForEach(grouped, id: \.header) { group in
                // Section header as a plain list row — no material background
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
                    TransactionRow(
                        transaction: tx,
                        category: cat,
                        is24hr: is24hr,
                        showTaxTip: showTaxTip
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .onTapGesture { onTap(tx) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { onDelete(tx) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }

                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

// ============================================================
// MARK: - TransactionRow
// ============================================================

struct TransactionRow: View {
    let transaction: Transaction
    let category: CategoryModel?
    let is24hr: Bool
    let showTaxTip: Bool

    var catColor: CategoryColor { category?.categoryColor ?? .gray }

    var dateString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, EEE"
        return fmt.string(from: transaction.date)
    }

    var timeString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = is24hr ? "HH:mm" : "h:mm a"
        return fmt.string(from: transaction.date)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {

            // LEFT: Category icon square
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(catColor.transitionColor)
                    .frame(width: 50, height: 50)

                // Category symbol centered
                Image(systemName: transaction.categorySymbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .overlay(alignment: .topTrailing) {
                // Direction chevron pinned to top-right corner
                // spending = down (money leaving), income = up (money coming in)
                Image(systemName: transaction.isIncome ? "chevron.up.2" : "chevron.down.2")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(catColor.color.opacity(0.85))
                    .padding(4)
            }

            // CENTER: Amount + note
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "$%.2f", transaction.amount))
                    .font(.system(size: 17, weight: .semibold, design: .rounded))

                // Note — hide if it's the same as the category name
                if transaction.title != transaction.categoryName {
                    Text(transaction.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // RIGHT: Date/time + project codes + tax/tip breakdown
            VStack(alignment: .trailing, spacing: 3) {
                Text(dateString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Project code chips
                if !transaction.projectCodes.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(transaction.projectCodes, id: \.self) { code in
                            Text(code)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Tax/tip breakdown (only when showTaxTip == true)
                if showTaxTip {
                    ForEach(transaction.taxRates, id: \.name) { tax in
                        Text("\(tax.name) \(String(format: "$%.2f", tax.amount))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    if transaction.tipAmount > 0 {
                        Text("Tip \(String(format: "$%.2f", transaction.tipAmount))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    // Gasoline tax — shown in ¢/L terms, amount per this transaction
                    if transaction.gasoline && transaction.gasolineTaxAmount > 0 {
                        Text("Gas tax \(String(format: "$%.2f", transaction.gasolineTaxAmount))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    TransactionsView().modelContainer(ContentView_Preview.previewContainer)
}
