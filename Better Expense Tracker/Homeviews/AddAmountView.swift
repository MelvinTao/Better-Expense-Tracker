import SwiftUI
import SwiftData

// ============================================================
// MARK: - StoredTaxRate  (shared with AddCategoryView)
// ============================================================
// Represents a configured tax type. Stored as JSON in AppStorage.
// Different from TaxRate in Transaction.swift — that one also stores
// the calculated dollar amount paid. This one is just for the UI layer.
struct StoredTaxRate: Codable, Equatable {
    var name: String   // e.g. "GST", "CPP", "EI"
    var rate: Double   // as a decimal, e.g. 0.05 means 5%
}

// Formats a rate as a percentage string with exactly 2 decimal places.
// Uses String(format:) to avoid floating-point inconsistency:
//   0.05 → "5.00%"    0.07 → "7.00%"    0.189783 → "18.98%"
func formatRate(_ rate: Double) -> String {
    String(format: "%.2f%%", rate * 100)
}

// ============================================================
// MARK: - AddAmountView
// ============================================================

struct AddAmountView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    let categoryName: String
    let categorySymbol: String
    let categoryColor: CategoryColor    // drives all accent colors in this sheet
    let isIncome: Bool                  // determines which tax formula is used on save
    let defaultActiveTaxNames: [String] // pre-fills which taxes are on for this category
    let defaultTipRate: Double          // pre-fills the tip selection

    // Gasoline-specific — non-nil when the category has isGasoline = true
    var isGasoline: Bool = false
    var categoryTaxPerLiter: Double = 0.0   // the ¢/L tax configured on the category

    // When non-nil, the view mutates this existing transaction instead of inserting a new one
    var editingTransaction: Transaction? = nil

    // Amount input stored as String so we control display exactly
    // (e.g. "12." is valid while typing — a Double would lose the trailing dot)
    @State private var inputString = "0"
    @State private var noteText = ""
    @State private var selectedDate = Date.now
    // Selected project code — at most one project + one sub-code
    @State private var selectedProjectCode: String? = nil
    @State private var selectedSubCode: String? = nil

    // Tax state
    @State private var activeTaxRates: [StoredTaxRate] = []
    @State private var showTaxEditor = false

    // Tip state
    @State private var selectedTipRate: Double = 0.0
    @State private var showTipEditor = false

    // UI
    @State private var showDatePicker = false
    @State private var showProjectCodeInput = false

    // Gasoline price-per-liter slider (range: 100.99 – 300.99, step 1.00)
    // Stored value is the integer whole-cent part (e.g. 189 → 189.99 ¢/L)
    @State private var gasolinePriceStep: Double = 89   // default: 189.99

    // Persisted lists — same AppStorage key = AddAmountView and AddCategoryView share the same data
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""

    // MARK: Computed

    var inputValue: Double { Double(inputString) ?? 0 }

    // Encodes the selected project+sub into the [String] format stored on Transaction
    var projectCodesSaveValue: [String] {
        guard let proj = selectedProjectCode, let sub = selectedSubCode else { return [] }
        return [proj, sub]
    }

    // Gasoline price: step (0–200) maps to 100.99–300.99 ¢/L
    // e.g. step 89 → 189.99, step 0 → 100.99, step 200 → 300.99
    var gasolinePricePerLiter: Double { gasolinePriceStep + 100.99 }

    // AppStorage key is per-category so each gasoline category remembers its own last price
    var gasolinePriceStorageKey: String { "gasolinePrice_\(categoryName)" }

    // Splits the display into (typed, ghost) for two-colour rendering.
    // "typed" is black (primary), "ghost" is the unfilled placeholder in grey (secondary).
    //
    // Empty state (inputString == "0"): typed = "$", ghost = "00.00"
    // After typing "3":                typed = "$3",    ghost = ".00"
    // After typing "37.":              typed = "$37.",  ghost = "00"
    // After typing "37.2":             typed = "$37.2", ghost = "0"
    // After typing "37.21":            typed = "$37.21",ghost = ""
    var amountParts: (typed: String, ghost: String) {
        // Nothing typed yet — show full ghost placeholder
        if inputString == "0" {
            return ("$", "00.00")
        }

        let hasDot = inputString.contains(".")
        let parts = inputString.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
        let intRaw = String(parts.first ?? "0")
        let decRaw = hasDot ? String(parts.count > 1 ? parts[1] : "") : ""

        // Format integer part with thousands separators
        let intVal = Int(intRaw) ?? 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        let formattedInt = formatter.string(from: NSNumber(value: intVal)) ?? intRaw

        if hasDot {
            // Ghost is the remaining unfilled decimal zeros
            let ghostZeros = String(repeating: "0", count: max(0, 2 - decRaw.count))
            return ("$\(formattedInt).\(decRaw)", ghostZeros)
        } else {
            // If only one integer digit typed, show it as "$0X" — leading 0 is ghost
            if intRaw.count == 1 {
                return ("$0\(formattedInt)", ".00")
            }
            return ("$\(formattedInt)", ".00")
        }
    }

    var totalTaxRate: Double { activeTaxRates.reduce(0) { $0 + $1.rate } }
    var totalRate: Double    { totalTaxRate + selectedTipRate }

    // Pre-tax base price (formula depends on income vs outcome)
    var baseAmount: Double {
        if isIncome {
            return (totalTaxRate > 0 && totalTaxRate < 1.0) ? inputValue / (1.0 - totalTaxRate) : inputValue
        } else {
            return totalRate > 0 ? inputValue / (1.0 + totalRate) : inputValue
        }
    }

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {

            // X dismiss button
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)

            // --- Amount display ---
            VStack(spacing: 6) {
                (
                    Text(amountParts.typed)
                        .foregroundColor(.primary)
                    + Text(amountParts.ghost)
                        .foregroundColor(.secondary)
                )
                .font(.system(size: 52, weight: .light, design: .rounded))
                .minimumScaleFactor(0.4).lineLimit(1)
                .padding(.horizontal, 24)

                // Tax/tip breakdown — only shown when at least one is active
                if !activeTaxRates.isEmpty || selectedTipRate > 0 {
                    HStack(spacing: 16) {
                        ForEach(activeTaxRates, id: \.name) { tax in
                            VStack(spacing: 1) {
                                Text(tax.name).font(.caption2).foregroundColor(.secondary)
                                Text("$\(baseAmount * tax.rate, specifier: "%.2f")")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        if selectedTipRate > 0 {
                            VStack(spacing: 1) {
                                Text("Tip \(formatRate(selectedTipRate))").font(.caption2).foregroundColor(.secondary)
                                Text("$\(baseAmount * selectedTipRate, specifier: "%.2f")")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Gasoline live breakdown — liters filled and gas tax for this top-up
                if isGasoline && inputValue > 0 && gasolinePricePerLiter > 0 {
                    let liters = inputValue / (gasolinePricePerLiter / 100.0)
                    let gasTax = liters * (categoryTaxPerLiter / 100.0)
                    HStack(spacing: 20) {
                        VStack(spacing: 1) {
                            Text("Liters").font(.caption2).foregroundColor(.secondary)
                            Text(String(format: "%.2f L", liters))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        VStack(spacing: 1) {
                            Text("Gas tax").font(.caption2).foregroundColor(.secondary)
                            Text(formatCurrency(gasTax))
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.bottom, 8)

            // Note field
            ZStack(alignment: .leading) {
                if noteText.isEmpty {
                    Text("Tap here to enter note").foregroundColor(Color.secondary.opacity(0.5)).font(.callout)
                }
                TextField("", text: $noteText).font(.callout)
            }
            .padding(.horizontal, 24).padding(.vertical, 6)

            // Gasoline price-per-liter slider — only shown for gasoline categories
            if isGasoline {
                VStack(spacing: 8) {
                    Text(String(format: "$%.2f ¢/L", gasolinePricePerLiter))
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    Slider(value: $gasolinePriceStep, in: 0...200, step: 1)
                        .accentColor(categoryColor.color)
                        .padding(.horizontal, 24)

                    HStack {
                        // Minus button: decrease by 1.00
                        Button {
                            gasolinePriceStep = max(0, gasolinePriceStep - 1)
                        } label: {
                            Text("-")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(categoryColor.color.opacity(0.85))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        // Plus button: increase by 1.00
                        Button {
                            gasolinePriceStep = min(200, gasolinePriceStep + 1)
                        } label: {
                            Text("+")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .background(categoryColor.color.opacity(0.85))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 8)
            }

            // Selected project code badge
            if let proj = selectedProjectCode, let sub = selectedSubCode {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("#").font(.caption2).foregroundColor(.secondary)
                        Text(proj).font(.caption.weight(.semibold))
                        Text("•").font(.caption2).foregroundColor(.secondary)
                        Text(sub).font(.caption.weight(.semibold))
                        Button {
                            selectedProjectCode = nil
                            selectedSubCode = nil
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(categoryColor.color.opacity(0.85))
                    .clipShape(Capsule())
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.vertical, 2)
            }

            // Date badge (shown only when date ≠ today)
            if !Calendar.current.isDateInToday(selectedDate) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar").font(.caption).foregroundColor(.secondary)
                    Text(selectedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24).padding(.vertical, 2)
            }

            Spacer()
            Divider().padding(.bottom, 4)

            // --- 4 × 4 Keypad ---
            VStack(spacing: 8) {

                // Row 1: 7  8  9  ⌫ (bold, category color background)
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { handleInput("7") }
                    KeypadButton(label: "8") { handleInput("8") }
                    KeypadButton(label: "9") { handleInput("9") }
                    KeypadButton(label: "⌫", isSpecial: true, fontSize: 20, fontWeight: .medium,
                                 customBackground: categoryColor.color,
                                 systemImage: "delete.backward") { handleDelete() }
                }

                // Row 2: 4  5  6  Date (category color background)
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { handleInput("4") }
                    KeypadButton(label: "5") { handleInput("5") }
                    KeypadButton(label: "6") { handleInput("6") }
                    KeypadButton(label: "Date", isSpecial: true, fontSize: 14,
                                 customBackground: categoryColor.color) { showDatePicker = true }
                }

                // Row 3: 1  2  3  Tax/Tip (category color background)
                // Tap → tax editor, Hold → tip editor
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { handleInput("1") }
                    KeypadButton(label: "2") { handleInput("2") }
                    KeypadButton(label: "3") { handleInput("3") }
                    TaxTipButton(
                        hasActiveTax: !activeTaxRates.isEmpty,
                        hasTip: selectedTipRate > 0,
                        buttonColor: categoryColor.color,
                        onTap: { showTaxEditor = true },
                        onLongPress: { showTipEditor = true }
                    )
                }

                // Row 4: Code  0  .  ✓ (checkmark uses transitionColor when active)
                HStack(spacing: 8) {
                    KeypadButton(label: "Code", isSpecial: true, fontSize: 13,
                                 customBackground: categoryColor.color) { showProjectCodeInput = true }
                    KeypadButton(label: "0") { handleInput("0") }
                    KeypadButton(label: ".") { handleInput(".") }

                    Button { saveTransaction() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(inputValue > 0 ? .white : Color.secondary.opacity(0.4))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(inputValue > 0 ? categoryColor.transitionColor : Color.secondary.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain).disabled(inputValue <= 0)
                }
            }
            .padding(.horizontal, 12).padding(.bottom, 16)
        }
        .onAppear {
            seedDefaultRatesIfNeeded()
            // Load persisted gasoline price for this category
            if isGasoline {
                let stored = UserDefaults.standard.double(forKey: gasolinePriceStorageKey)
                if stored > 0 {
                    // Convert back from stored price (e.g. 189.99) to step (89)
                    gasolinePriceStep = max(0, min(200, (stored - 100.99).rounded()))
                }
            }
            if let tx = editingTransaction {
                // Pre-fill from existing transaction
                inputString = String(format: "%.2f", tx.amount)
                    .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                    .replacingOccurrences(of: "^0+(?=[1-9])", with: "", options: .regularExpression)
                // Use plain string if it ends up empty
                if inputString.isEmpty { inputString = "0" }
                noteText = tx.title == tx.categoryName ? "" : tx.title
                selectedDate = tx.date
                // Restore selected project/sub from the dedicated fields
                selectedProjectCode = tx.projectCode
                selectedSubCode     = tx.projectSubCode
                activeTaxRates = tx.taxRates.map { StoredTaxRate(name: $0.name, rate: $0.rate) }
                selectedTipRate = tx.selectedTipRate
                // Restore gasoline price from the transaction if editing
                if tx.gasoline && tx.pricePerLiter > 0 {
                    gasolinePriceStep = max(0, min(200, (tx.pricePerLiter - 100.99).rounded()))
                }
            } else {
                applyDefaultsFromCategory()
            }
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate, accentColor: categoryColor.color)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTaxEditor) {
            TaxEditorView(activeTaxRates: $activeTaxRates, accentColor: categoryColor.color)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showTipEditor) {
            TipEditorView(selectedTipRate: $selectedTipRate, accentColor: categoryColor.color)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showProjectCodeInput) {
            ProjectCodePickerSheet(
                selectedProjectCode: $selectedProjectCode,
                selectedSubCode: $selectedSubCode,
                accentColor: categoryColor.color
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Helpers

    func handleInput(_ key: String) {
        if key == "." && inputString.contains(".") { return }
        if let di = inputString.firstIndex(of: ".") {
            if inputString.distance(from: di, to: inputString.endIndex) - 1 >= 2 { return }
        }
        if inputString == "0" && key != "." { inputString = key } else { inputString += key }
    }

    func handleDelete() {
        if inputString.count > 1 { inputString.removeLast() } else { inputString = "0" }
    }

    func seedDefaultRatesIfNeeded() {
        if availableTaxRatesJSON.isEmpty {
            let d = [StoredTaxRate(name: "GST", rate: 0.05), StoredTaxRate(name: "PST", rate: 0.07)]
            if let data = try? JSONEncoder().encode(d), let json = String(data: data, encoding: .utf8) {
                availableTaxRatesJSON = json
            }
        }
        if availableTipRatesJSON.isEmpty {
            let d = [0.0, 0.10, 0.12, 0.15, 0.18, 0.20]
            if let data = try? JSONEncoder().encode(d), let json = String(data: data, encoding: .utf8) {
                availableTipRatesJSON = json
            }
        }
    }

    func applyDefaultsFromCategory() {
        guard let data = availableTaxRatesJSON.data(using: .utf8),
              let all = try? JSONDecoder().decode([StoredTaxRate].self, from: data)
        else { return }
        activeTaxRates = all.filter { defaultActiveTaxNames.contains($0.name) }
        selectedTipRate = defaultTipRate
    }

    func saveTransaction() {
        let txRates = activeTaxRates.map { TaxRate(name: $0.name, rate: $0.rate, amount: 0) }
        let tipRates = (try? JSONDecoder().decode([Double].self,
            from: availableTipRatesJSON.data(using: .utf8) ?? Data())) ?? []

        if let tx = editingTransaction {
            // Mutate existing transaction in place
            tx.title = noteText.isEmpty ? tx.categoryName : noteText
            tx.amount = inputValue
            tx.date = selectedDate
            tx.projectCode    = selectedProjectCode
            tx.projectSubCode = selectedSubCode
            tx.taxable = !activeTaxRates.isEmpty
            tx.taxRates = txRates
            tx.tippable = selectedTipRate > 0
            tx.selectedTipRate = tippable ? selectedTipRate : 0.0
            tx.tipAmount = tx.tippable ? tx.baseAmount * selectedTipRate : 0.0
            tx.totalTaxAmount = txRates.reduce(0) { $0 + $1.amount }
        } else if isGasoline {
            saveGasolineTransaction(tipRates: tipRates)
        } else {
            modelContext.insert(Transaction(
                title:             noteText.isEmpty ? categoryName : noteText,
                amount:            inputValue,
                date:              selectedDate,
                categoryName:      categoryName,
                categorySymbol:    categorySymbol,
                projectCodes:      projectCodesSaveValue,
                isIncome:          isIncome,
                taxable:           !activeTaxRates.isEmpty,
                taxRates:          txRates,
                tippable:          selectedTipRate > 0,
                availableTipRates: tipRates,
                selectedTipRate:   selectedTipRate
            ))
        }

        // Persist the last-used gasoline price for this category
        if isGasoline {
            UserDefaults.standard.set(gasolinePricePerLiter, forKey: gasolinePriceStorageKey)
        }

        dismiss()
    }

    // MARK: Gasoline save logic
    // Creates the mother transaction (which shows "X L @ YYY.99 ¢/L") plus
    // N-1 synthetic daily split transactions, all sharing the same groupID.
    private func saveGasolineTransaction(tipRates: [Double]) {
        let cal = Calendar.current
        let fillDate = selectedDate
        let totalAmount = inputValue
        let pricePerL = gasolinePricePerLiter          // e.g. 189.99 ¢/L
        let taxPerL   = categoryTaxPerLiter            // e.g. 30.00 ¢/L (from category)

        // Calculate liters and gasoline tax
        let liters = pricePerL > 0 ? totalAmount / (pricePerL / 100.0) : 0.0
        let gasTaxTotal = liters * (taxPerL / 100.0)

        // Auto-note: "45.3 L @ 189.99 ¢/L"
        let autoNote: String
        if liters > 0 {
            autoNote = String(format: "%.1f L @ %.2f ¢/L", liters, pricePerL)
        } else {
            autoNote = categoryName
        }
        let motherTitle = noteText.isEmpty ? autoNote : noteText

        // Find the most recent prior transaction in this gasoline category
        let descriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.categoryName == categoryName && $0.gasoline == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let prior = try? modelContext.fetch(descriptor)
        // The most recent one that is strictly before our fill date
        let previousFill = prior?.first(where: { $0.date < fillDate })
        let prevDate = previousFill?.date

        // Determine how many days to split across
        let days: Int
        if let prev = prevDate {
            days = max(1, cal.dateComponents([.day], from: cal.startOfDay(for: prev), to: cal.startOfDay(for: fillDate)).day ?? 1)
        } else {
            days = 1  // first fill ever — charge all to the fill day
        }

        let dailyCost = totalAmount / Double(days)
        let dailyTax  = gasTaxTotal / Double(days)

        // Shared group ID for all entries from this fill
        let groupID = UUID().uuidString

        // Insert one transaction per day
        for i in 0..<days {
            // Day 0 = the day after the previous fill (or the fill day itself for a first fill)
            // Day (days-1) = the actual fill date
            let dayOffset = i - (days - 1)  // negative for past days, 0 for fill day
            let txDate: Date
            if days == 1 {
                txDate = fillDate
            } else {
                // Start distributing from the day after the previous fill
                let baseDay = cal.startOfDay(for: fillDate)
                txDate = cal.date(byAdding: .day, value: dayOffset, to: baseDay) ?? fillDate
            }

            let isMother = (i == days - 1)  // last entry = fill day = mother

            let txTitle: String
            if isMother {
                txTitle = motherTitle
            } else {
                // Daily split entries show the fill date as context
                let fmt = DateFormatter()
                fmt.dateFormat = "MMM d"
                txTitle = "Fill \(fmt.string(from: fillDate))"
            }

            let tx = Transaction(
                title:             txTitle,
                amount:            dailyCost,
                date:              txDate,
                categoryName:      categoryName,
                categorySymbol:    categorySymbol,
                projectCodes:      isMother ? projectCodesSaveValue : [],
                isIncome:          false,
                gasoline:          true,
                pricePerLiter:     isMother ? pricePerL : 0.0,
                taxPerLiter:       taxPerL,
                previousFillupDate: prevDate,
                groupID:           groupID,
                isGasolineSplit:   !isMother
            )
            // Manually set gasoline-specific fields not computed in init
            tx.liters = isMother ? liters : 0.0
            tx.gasolineTaxAmount = dailyTax
            tx.dailyGasolineCost = dailyCost
            modelContext.insert(tx)
        }
    }

    // Convenience: whether the transaction has tip (used during edit save)
    private var tippable: Bool { selectedTipRate > 0 }
}

// ============================================================
// MARK: - KeypadButton
// ============================================================

struct KeypadButton: View {
    let label: String
    var isSpecial: Bool = false
    var fontSize: CGFloat = 24
    var fontWeight: Font.Weight = .regular
    var customBackground: Color? = nil  // when set, replaces the default gray background
    var systemImage: String? = nil      // when set, renders an SF symbol instead of text

    let action: () -> Void

    // Text is primary on colored backgrounds, secondary on default gray specials
    var textColor: Color { customBackground != nil ? .primary : (isSpecial ? .secondary : .primary) }

    var body: some View {
        Button { action() } label: {
            Group {
                if let symbol = systemImage {
                    Image(systemName: symbol)
                        .font(.system(size: fontSize, weight: fontWeight))
                } else {
                    Text(label)
                        .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(customBackground ?? Color.secondary.opacity(0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - TaxTipButton
// ============================================================

struct TaxTipButton: View {
    let hasActiveTax: Bool
    let hasTip: Bool
    let buttonColor: Color
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Button {} label: {
            VStack(spacing: 3) {
                Text("Tax/Tip").font(.system(size: 13)).foregroundColor(.primary)
                if hasActiveTax || hasTip {
                    Circle().fill(Color.white.opacity(0.8)).frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(buttonColor).cornerRadius(12)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { onTap() })
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() })
    }
}

// ============================================================
// MARK: - DatePickerSheet
// ============================================================

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Text("Transaction Date").font(.headline)
                Spacer()
                Button("Done") { dismiss() }.bold()
            }
            .padding()
            DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .accentColor(accentColor)  // highlighted date uses category color
                .padding(.horizontal)
            Spacer()
        }
    }
}

// ============================================================
// MARK: - TaxEditorView  (now includes delete feature)
// ============================================================

struct TaxEditorView: View {
    @Binding var activeTaxRates: [StoredTaxRate]
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @State private var showAddTax = false
    @State private var originalRates: [StoredTaxRate] = []
    @State private var deleteMode = false  // long press a tile → X badges appear

    var availableRates: [StoredTaxRate] {
        guard let data = availableTaxRatesJSON.data(using: .utf8),
              let rates = try? JSONDecoder().decode([StoredTaxRate].self, from: data)
        else { return [] }
        return rates
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(availableRates, id: \.name) { tax in
                        ZStack(alignment: .topTrailing) {
                            let isActive = activeTaxRates.contains { $0.name == tax.name }

                            Button {
                                if deleteMode { return }
                                if isActive { activeTaxRates.removeAll { $0.name == tax.name } }
                                else { activeTaxRates.append(tax) }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(formatRate(tax.rate))
                                        .font(.system(size: 42, weight: .bold, design: .rounded))
                                    Text(tax.name).font(.title3)
                                }
                                .foregroundColor(isActive ? .white : .primary)
                                .frame(maxWidth: .infinity).frame(height: 110)
                                .background(isActive ? accentColor : Color.secondary.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.5)
                                    .onEnded { _ in withAnimation(.spring(response: 0.3)) { deleteMode = true } }
                            )

                            if deleteMode {
                                Button {
                                    activeTaxRates.removeAll { $0.name == tax.name }
                                    let updated = availableRates.filter { $0.name != tax.name }
                                    if let data = try? JSONEncoder().encode(updated),
                                       let json = String(data: data, encoding: .utf8) {
                                        availableTaxRatesJSON = json
                                    }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22)).foregroundColor(.red)
                                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                                }
                                .buttonStyle(.plain).offset(x: 6, y: -6)
                            }
                        }
                    }

                    Button { showAddTax = true } label: {
                        Image(systemName: "plus").font(.system(size: 32, weight: .medium)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity).frame(height: 110)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { originalRates = activeTaxRates }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if deleteMode { withAnimation(.spring(response: 0.3)) { deleteMode = false } }
                        else { activeTaxRates = originalRates; dismiss() }
                    } label: {
                        Image(systemName: deleteMode ? "checkmark" : "xmark")
                            .font(.system(size: 20, weight: deleteMode ? .semibold : .medium))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !deleteMode {
                        Button { dismiss() } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTax) { AddTaxView(accentColor: accentColor).presentationDetents([.large]) }
    }
}

// ============================================================
// MARK: - AddTaxView
// ============================================================

struct AddTaxView: View {
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @State private var rateString = "0"
    @State private var taxName = ""

    var rateValue: Double { (Double(rateString) ?? 0) / 100.0 }
    var canConfirm: Bool { !taxName.trimmingCharacters(in: .whitespaces).isEmpty && rateValue > 0 }

    var existingRates: [StoredTaxRate] {
        (try? JSONDecoder().decode([StoredTaxRate].self,
            from: availableTaxRatesJSON.data(using: .utf8) ?? Data())) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20)

            Text("\(rateString)%").font(.system(size: 56, weight: .light, design: .rounded)).padding(.vertical, 16)

            ZStack(alignment: .center) {
                if taxName.isEmpty {
                    Text("Enter Tax Name Here").foregroundColor(Color.secondary.opacity(0.6)).font(.title2)
                }
                TextField("", text: $taxName).multilineTextAlignment(.center).font(.title2)
            }
            .padding(.horizontal, 24).padding(.vertical, 8)

            Spacer()
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { ri("7") }; KeypadButton(label: "8") { ri("8") }; KeypadButton(label: "9") { ri("9") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { ri("4") }; KeypadButton(label: "5") { ri("5") }; KeypadButton(label: "6") { ri("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { ri("1") }; KeypadButton(label: "2") { ri("2") }; KeypadButton(label: "3") { ri("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: ".") { ri(".") }
                    KeypadButton(label: "0") { ri("0") }
                    KeypadButton(label: "delete", isSpecial: true, fontSize: 20, fontWeight: .medium,
                                 systemImage: "delete.backward") { rd() }
                }
                Button { confirmAdd() } label: {
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(canConfirm ? accentColor : Color.gray.opacity(0.4)).cornerRadius(12)
                }
                .buttonStyle(.plain).disabled(!canConfirm)
            }
            .padding(12)
        }
    }

    func confirmAdd() {
        let trimmed = taxName.trimmingCharacters(in: .whitespaces)
        if !existingRates.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            var updated = existingRates
            updated.append(StoredTaxRate(name: trimmed, rate: rateValue))
            if let data = try? JSONEncoder().encode(updated), let json = String(data: data, encoding: .utf8) {
                availableTaxRatesJSON = json
            }
        }
        dismiss()
    }

    func ri(_ key: String) {
        if key == "." && rateString.contains(".") { return }
        if let di = rateString.firstIndex(of: "."), rateString.distance(from: di, to: rateString.endIndex) - 1 >= 2 { return }
        if rateString == "0" && key != "." { rateString = key } else { rateString += key }
    }

    func rd() { if rateString.count > 1 { rateString.removeLast() } else { rateString = "0" } }
}

// ============================================================
// MARK: - TipEditorView
// ============================================================

struct TipEditorView: View {
    @Binding var selectedTipRate: Double
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""
    @State private var deleteMode = false
    @State private var showAddTip = false

    var tipRates: [Double] {
        ((try? JSONDecoder().decode([Double].self, from: availableTipRatesJSON.data(using: .utf8) ?? Data())) ?? []).sorted()
    }

    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if deleteMode { withAnimation(.spring(response: 0.3)) { deleteMode = false } }
                    else { dismiss() }
                } label: {
                    Image(systemName: deleteMode ? "checkmark" : "xmark")
                        .font(.system(size: 20, weight: .medium)).foregroundColor(.primary)
                }
                Spacer()
                if deleteMode { Text("Tap × to remove").font(.caption).foregroundColor(.secondary) }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(tipRates, id: \.self) { rate in
                        TipTileView(
                            rate: rate, isSelected: selectedTipRate == rate,
                            deleteMode: deleteMode, accentColor: accentColor,
                            onTap: { selectedTipRate = rate; dismiss() },
                            onDelete: {
                                let updated = tipRates.filter { $0 != rate }
                                if let data = try? JSONEncoder().encode(updated),
                                   let json = String(data: data, encoding: .utf8) { availableTipRatesJSON = json }
                                if selectedTipRate == rate { selectedTipRate = 0.0 }
                            },
                            onLongPress: { withAnimation(.spring(response: 0.3)) { deleteMode = true } }
                        )
                    }
                    Button { showAddTip = true } label: {
                        Image(systemName: "plus").font(.system(size: 32, weight: .medium)).foregroundColor(.primary)
                            .frame(maxWidth: .infinity).frame(height: 120)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showAddTip) { AddTipView(accentColor: accentColor).presentationDetents([.large]) }
    }
}

// ============================================================
// MARK: - TipTileView  (FIX: explicit height instead of aspectRatio — prevents "..." bug)
// ============================================================

struct TipTileView: View {
    let rate: Double
    let isSelected: Bool
    let deleteMode: Bool
    let accentColor: Color
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if !deleteMode { onTap() }
            } label: {
                Text(formatRate(rate))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)   // explicit height — avoids the "..." truncation bug
                    .background(isSelected ? accentColor : Color.secondary.opacity(0.12))
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() })

            if deleteMode {
                Button { onDelete() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22)).foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain).offset(x: 6, y: -6)
            }
        }
    }
}

// ============================================================
// MARK: - AddTipView
// ============================================================

struct AddTipView: View {
    let accentColor: Color
    @Environment(\.dismiss) var dismiss
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""
    @State private var rateString = "0"

    var rateValue: Double { (Double(rateString) ?? 0) / 100.0 }
    var existingRates: [Double] {
        ((try? JSONDecoder().decode([Double].self, from: availableTipRatesJSON.data(using: .utf8) ?? Data())) ?? [])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20)
            Text("\(rateString)%").font(.system(size: 56, weight: .light, design: .rounded)).padding(.vertical, 24)
            Spacer()
            Divider()
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { ri("7") }; KeypadButton(label: "8") { ri("8") }; KeypadButton(label: "9") { ri("9") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { ri("4") }; KeypadButton(label: "5") { ri("5") }; KeypadButton(label: "6") { ri("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { ri("1") }; KeypadButton(label: "2") { ri("2") }; KeypadButton(label: "3") { ri("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: ".") { ri(".") }
                    KeypadButton(label: "0") { ri("0") }
                    KeypadButton(label: "delete", isSpecial: true, fontSize: 20, fontWeight: .medium,
                                 systemImage: "delete.backward") { rd() }
                }
                Button { confirmAdd() } label: {
                    Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(rateValue > 0 ? accentColor : Color.gray.opacity(0.4)).cornerRadius(12)
                }
                .buttonStyle(.plain).disabled(rateValue <= 0)
            }
            .padding(12)
        }
    }

    func confirmAdd() {
        if !existingRates.contains(rateValue) {
            var updated = existingRates; updated.append(rateValue); updated.sort()
            if let data = try? JSONEncoder().encode(updated), let json = String(data: data, encoding: .utf8) {
                availableTipRatesJSON = json
            }
        }
        dismiss()
    }

    func ri(_ key: String) {
        if key == "." && rateString.contains(".") { return }
        if let di = rateString.firstIndex(of: "."), rateString.distance(from: di, to: rateString.endIndex) - 1 >= 2 { return }
        if rateString == "0" && key != "." { rateString = key } else { rateString += key }
    }

    func rd() { if rateString.count > 1 { rateString.removeLast() } else { rateString = "0" } }
}

// ============================================================
// MARK: - ProjectCodePickerSheet
// ============================================================

struct ProjectCodePickerSheet: View {
    @Binding var selectedProjectCode: String?
    @Binding var selectedSubCode: String?
    let accentColor: Color

    @Query(sort: \ProjectCode.sortOrder) var projectCodes: [ProjectCode]
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var showAddProject = false
    @State private var addSubTarget: ProjectCode? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Select project code")
                    .font(.title3.bold())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()

            // Scrollable project list
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(projectCodes) { project in
                        projectRow(project)
                    }

                    // "# +" add new project
                    Button { showAddProject = true } label: {
                        HStack(alignment: .center, spacing: 0) {
                            Text("#")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            Divider()

            // Bottom action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    selectedProjectCode = nil
                    selectedSubCode = nil
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.secondary.opacity(0.12))
                .foregroundColor(.primary)
                .cornerRadius(14)

                Button("Add") { dismiss() }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selectedProjectCode != nil && selectedSubCode != nil ? accentColor : Color.secondary.opacity(0.2))
                    .foregroundColor(selectedProjectCode != nil && selectedSubCode != nil ? .primary : .secondary)
                    .cornerRadius(14)
                    .disabled(selectedProjectCode == nil || selectedSubCode == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showAddProject) {
            AddProjectCodeSheet(existingNames: projectCodes.map(\.name)) { name in
                let order = (projectCodes.map(\.sortOrder).max() ?? -1) + 1
                modelContext.insert(ProjectCode(name: name, sortOrder: order))
            }
            .presentationDetents([.height(260)])
        }
        .sheet(item: $addSubTarget) { project in
            AddSubCodeSheet(projectName: project.name, existingSubCodes: project.subCodes) { sub in
                project.subCodes.append(sub)
            }
            .presentationDetents([.height(260)])
        }
    }

    // Width of the left gutter that holds "#" or "•" — matches the "# +" at the bottom
    private let gutterWidth: CGFloat = 24

    @ViewBuilder
    private func projectRow(_ project: ProjectCode) -> some View {
        let isProjectSelected = selectedProjectCode == project.name
        VStack(alignment: .leading, spacing: 8) {
            // Project header: gutter "#" | capsule button with name only
            HStack(alignment: .center, spacing: 0) {
                Text("#")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: gutterWidth, alignment: .leading)

                Button {
                    if isProjectSelected {
                        selectedProjectCode = nil
                        selectedSubCode = nil
                    } else {
                        selectedProjectCode = project.name
                        selectedSubCode = nil
                    }
                } label: {
                    Text(project.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isProjectSelected ? .primary : .secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isProjectSelected ? accentColor : Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Sub-code row: gutter "•" | horizontally scrollable sub buttons
            HStack(alignment: .center, spacing: 0) {
                Text("•")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .frame(width: gutterWidth, alignment: .leading)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(project.subCodes, id: \.self) { sub in
                            let isSubSelected = selectedSubCode == sub && selectedProjectCode == project.name
                            Button {
                                if isSubSelected {
                                    selectedSubCode = nil
                                    if selectedProjectCode == project.name {
                                        selectedProjectCode = nil
                                    }
                                } else {
                                    selectedProjectCode = project.name
                                    selectedSubCode = sub
                                }
                            } label: {
                                Text(sub)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(isSubSelected ? .primary : .secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(isSubSelected ? accentColor : Color.secondary.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // "+" add sub-code for this project
                        Button { addSubTarget = project } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    AddAmountView(categoryName: "Grocery", categorySymbol: "basket.fill",
                  categoryColor: .yellow, isIncome: false,
                  defaultActiveTaxNames: [], defaultTipRate: 0.0)
    .modelContainer(for: Transaction.self, inMemory: true)
}
