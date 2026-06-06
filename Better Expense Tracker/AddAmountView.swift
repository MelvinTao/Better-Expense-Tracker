import SwiftUI
import SwiftData


// ============================================================
// MARK: - StoredTaxRate
// ============================================================
// Represents a tax type that the user has configured (e.g. GST, PST).
// This is different from TaxRate in Transaction.swift — that one also
// stores the calculated dollar amount paid. This one is just for the UI.
// 'Codable' lets us convert it to/from JSON for storage in UserDefaults.
struct StoredTaxRate: Codable, Equatable {
    var name: String   // e.g. "GST", "PST", "Carbon Tax"
    var rate: Double   // as a decimal, e.g. 0.05 means 5%
}


// ============================================================
// MARK: - Helper: format a rate as a percentage string
// ============================================================
// 0.05  → "5%"
// 0.125 → "12.5%"
func formatRate(_ rate: Double) -> String {
    let pct = rate * 100
    // If the percentage is a whole number, don't show decimal places
    if pct == Double(Int(pct)) {
        return "\(Int(pct))%"
    } else {
        return String(format: "%.1f%%", pct)
    }
}


// ============================================================
// MARK: - AddAmountView  (Image 1)
// ============================================================
// The main sheet that slides up when the user taps a category tile.
// Contains: amount display, note field, and a 4x4 keypad.
// Keypad layout:
//   7  8  9  ⌫
//   4  5  6  Date
//   1  2  3  Tax/Tip
//  Code 0  .   ✓

struct AddAmountView: View {
    
    // MARK: Environment
    @Environment(\.modelContext) var modelContext
    @Environment(\.dismiss) var dismiss
    
    // MARK: Inputs from HomeView
    let categoryName: String
    let categorySymbol: String
    
    // MARK: Amount input
    // We use a String so we control exact display (e.g. "12." keeps the trailing dot)
    @State private var inputString = "0"
    
    // MARK: Note
    @State private var noteText = ""
    
    // MARK: Date
    @State private var selectedDate = Date.now
    @State private var showDatePicker = false
    
    // MARK: Project code
    @State private var projectCode = ""
    @State private var showProjectCodeInput = false
    
    // MARK: Tax state for THIS transaction
    // activeTaxRates = the taxes currently toggled ON for this specific entry
    @State private var activeTaxRates: [StoredTaxRate] = []
    @State private var showTaxEditor = false
    
    // MARK: Tip state for THIS transaction
    @State private var selectedTipRate: Double = 0.0
    @State private var showTipEditor = false
    
    // MARK: Persisted available rates
    // @AppStorage stores these as JSON strings in UserDefaults.
    // They persist between app launches and are shared across all views
    // that use the same key string — no manual syncing needed.
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""
    
    
    // MARK: Computed helpers
    
    // Convert the input string to a Double for math/saving
    var inputValue: Double { Double(inputString) ?? 0 }
    
    // Sum of all active tax rates, e.g. GST 5% + PST 7% = 0.12
    var totalTaxRate: Double { activeTaxRates.reduce(0) { $0 + $1.rate } }
    
    // Total rate including tip
    var totalRate: Double { totalTaxRate + selectedTipRate }
    
    // Base price before any tax or tip
    // Formula: amount = base * (1 + totalRate) → base = amount / (1 + totalRate)
    var baseAmount: Double { totalRate > 0 ? inputValue / (1 + totalRate) : inputValue }
    
    
    // MARK: Body
    var body: some View {
        VStack(spacing: 0) {
            
            // --- X button (top left) ---
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)
            
            // --- Amount display ---
            VStack(spacing: 6) {
                Text("$\(inputString)")
                    .font(.system(size: 52, weight: .light, design: .rounded))
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(.horizontal, 24)
                
                // Show tax/tip breakdown only when at least one is active
                if !activeTaxRates.isEmpty || selectedTipRate > 0 {
                    HStack(spacing: 16) {
                        ForEach(activeTaxRates, id: \.name) { tax in
                            VStack(spacing: 1) {
                                Text(tax.name)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(baseAmount * tax.rate, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        if selectedTipRate > 0 {
                            VStack(spacing: 1) {
                                Text("Tip \(formatRate(selectedTipRate))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("$\(baseAmount * selectedTipRate, specifier: "%.2f")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 8)
            
            // --- Note field ---
            // ZStack lets us show placeholder text while the field is empty
            ZStack(alignment: .leading) {
                if noteText.isEmpty {
                    Text("Tap here to enter note")
                        .foregroundColor(Color.secondary.opacity(0.6))
                        .font(.callout)
                }
                TextField("", text: $noteText)
                    .font(.callout)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 6)
            
            // --- Project code indicator (only shown after one is entered) ---
            if !projectCode.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(projectCode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    // Tap to clear the project code
                    Button { projectCode = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 2)
            }
            
            // --- Date indicator (only shown when date is not today) ---
            if !Calendar.current.isDateInToday(selectedDate) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 2)
            }
            
            Spacer()
            Divider().padding(.bottom, 4)
            
            // --- 4 x 4 Keypad ---
            VStack(spacing: 8) {
                
                // Row 1: 7  8  9  ⌫
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { handleInput("7") }
                    KeypadButton(label: "8") { handleInput("8") }
                    KeypadButton(label: "9") { handleInput("9") }
                    KeypadButton(label: "⌫", isSpecial: true) { handleDelete() }
                }
                
                // Row 2: 4  5  6  Date
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { handleInput("4") }
                    KeypadButton(label: "5") { handleInput("5") }
                    KeypadButton(label: "6") { handleInput("6") }
                    KeypadButton(label: "Date", isSpecial: true, fontSize: 14) {
                        showDatePicker = true
                    }
                }
                
                // Row 3: 1  2  3  Tax/Tip
                // Tap Tax/Tip → tax editor
                // Hold Tax/Tip → tip editor
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { handleInput("1") }
                    KeypadButton(label: "2") { handleInput("2") }
                    KeypadButton(label: "3") { handleInput("3") }
                    TaxTipButton(
                        hasActiveTax: !activeTaxRates.isEmpty,
                        hasTip: selectedTipRate > 0,
                        onTap: { showTaxEditor = true },
                        onLongPress: { showTipEditor = true }
                    )
                }
                
                // Row 4: Code  0  .  ✓
                HStack(spacing: 8) {
                    KeypadButton(label: "Code", isSpecial: true, fontSize: 13) {
                        showProjectCodeInput = true
                    }
                    KeypadButton(label: "0") { handleInput("0") }
                    KeypadButton(label: ".") { handleInput(".") }
                    
                    // Small checkmark — saves the transaction
                    Button {
                        saveTransaction()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(inputValue > 0 ? .white : Color.secondary.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(inputValue > 0 ? Color.green : Color.secondary.opacity(0.15))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputValue <= 0)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
        
        // MARK: First launch setup
        .onAppear {
            // If no tax rates have been configured yet, seed with BC defaults
            if availableTaxRatesJSON.isEmpty {
                let defaults = [
                    StoredTaxRate(name: "GST", rate: 0.05),
                    StoredTaxRate(name: "PST", rate: 0.07)
                ]
                encodeAndSaveTax(defaults)
            }
            // If no tip rates have been configured yet, seed with common options
            if availableTipRatesJSON.isEmpty {
                encodeAndSaveTip([0.0, 0.10, 0.12, 0.15, 0.18, 0.20])
            }
        }
        
        // MARK: Sheets
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(selectedDate: $selectedDate)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTaxEditor) {
            TaxEditorView(activeTaxRates: $activeTaxRates)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showTipEditor) {
            TipEditorView(selectedTipRate: $selectedTipRate)
                .presentationDetents([.large])
        }
        // Project code input — alert with a text field
        .alert("Project Code", isPresented: $showProjectCodeInput) {
            TextField("e.g. PROJ-2026-A", text: $projectCode)
            Button("Done") {}
            Button("Clear", role: .destructive) { projectCode = "" }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    
    // MARK: - Keypad input helpers
    
    func handleInput(_ key: String) {
        if key == "." && inputString.contains(".") { return }
        if let dotIndex = inputString.firstIndex(of: ".") {
            let decimals = inputString.distance(from: dotIndex, to: inputString.endIndex) - 1
            if decimals >= 2 { return }
        }
        if inputString == "0" && key != "." { inputString = key }
        else { inputString += key }
    }
    
    func handleDelete() {
        if inputString.count > 1 { inputString.removeLast() }
        else { inputString = "0" }
    }
    
    
    // MARK: - AppStorage encode helpers
    
    func encodeAndSaveTax(_ rates: [StoredTaxRate]) {
        if let data = try? JSONEncoder().encode(rates),
           let json = String(data: data, encoding: .utf8) {
            availableTaxRatesJSON = json
        }
    }
    
    func encodeAndSaveTip(_ rates: [Double]) {
        if let data = try? JSONEncoder().encode(rates),
           let json = String(data: data, encoding: .utf8) {
            availableTipRatesJSON = json
        }
    }
    
    
    // MARK: - Save transaction to database
    
    func saveTransaction() {
        // Convert StoredTaxRate (UI model) → TaxRate (database model)
        // The Transaction init recalculates the dollar amounts automatically
        let txRates = activeTaxRates.map {
            TaxRate(name: $0.name, rate: $0.rate, amount: 0)
        }
        
        // Decode available tip rates for storage on the transaction
        let tipRates: [Double]
        if let data = availableTipRatesJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([Double].self, from: data) {
            tipRates = decoded
        } else {
            tipRates = []
        }
        
        let newTransaction = Transaction(
            // Use the note as the title if one was entered, otherwise use category name
            title:          noteText.isEmpty ? categoryName : noteText,
            amount:         inputValue,
            date:           selectedDate,
            categoryName:   categoryName,
            categorySymbol: categorySymbol,
            projectCode:    projectCode.isEmpty ? nil : projectCode,
            taxable:        !activeTaxRates.isEmpty,
            taxRates:       txRates,
            tippable:       selectedTipRate > 0,
            availableTipRates: tipRates,
            selectedTipRate: selectedTipRate
        )
        
        modelContext.insert(newTransaction)
        dismiss()
    }
}


// ============================================================
// MARK: - KeypadButton
// ============================================================
// Reusable button component for each key on all keypads in this file.
// 'isSpecial' gives special keys (⌫, Date, Tax/Tip, Code) a muted look.

struct KeypadButton: View {
    let label: String
    var isSpecial: Bool = false
    var fontSize: CGFloat = 24
    let action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .foregroundColor(isSpecial ? .secondary : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}


// ============================================================
// MARK: - TaxTipButton
// ============================================================
// The Tax/Tip key in the keypad.
// Tap  → opens the tax editor.
// Hold → opens the tip editor.
// Shows a blue dot when any tax or tip is currently active.

struct TaxTipButton: View {
    let hasActiveTax: Bool
    let hasTip: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Button {} label: {
            VStack(spacing: 3) {
                Text("Tax/Tip")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                // Blue dot = something is active for this transaction
                if hasActiveTax || hasTip {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        // Both gestures coexist — one doesn't cancel the other
        .simultaneousGesture(TapGesture().onEnded { onTap() })
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() })
    }
}


// ============================================================
// MARK: - DatePickerSheet
// ============================================================
// A medium-height sheet for selecting the transaction date and time.
// Appears when the user taps "Date" in the keypad.

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
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
            
            DatePicker(
                "",
                selection: $selectedDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            
            Spacer()
        }
    }
}


// ============================================================
// MARK: - TaxEditorView  (Image 3)
// ============================================================
// A scrollable list of all configured tax types.
// Each tile shows the rate % and name.
// Tap a tile → toggles it on/off (blue = active = will be applied).
// "+" → opens AddTaxView to create a new tax type.
// Top-left X  → cancels and reverts any changes.
// Top-right ✓ → confirms selections and closes.

struct TaxEditorView: View {
    
    // Binding to AddAmountView's activeTaxRates so changes here reflect there
    @Binding var activeTaxRates: [StoredTaxRate]
    
    @Environment(\.dismiss) var dismiss
    @State private var showAddTax = false
    
    // Snapshot of the original state — used to revert if X is tapped
    @State private var originalRates: [StoredTaxRate] = []
    
    // Same @AppStorage key as AddAmountView — changes here auto-sync there
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    
    // Decode available rates from JSON
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
                    
                    // One full-width tile per tax type
                    ForEach(availableRates, id: \.name) { tax in
                        let isActive = activeTaxRates.contains(where: { $0.name == tax.name })
                        
                        Button {
                            // Toggle this tax on/off for the current transaction
                            if isActive {
                                activeTaxRates.removeAll { $0.name == tax.name }
                            } else {
                                activeTaxRates.append(tax)
                            }
                        } label: {
                            VStack(spacing: 8) {
                                Text(formatRate(tax.rate))
                                    .font(.system(size: 42, weight: .bold, design: .rounded))
                                Text(tax.name)
                                    .font(.title3)
                            }
                            .foregroundColor(isActive ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(isActive ? Color.blue : Color.secondary.opacity(0.1))
                            .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // "+" tile — opens AddTaxView
                    Button {
                        showAddTax = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Save a snapshot so X can revert
                originalRates = activeTaxRates
            }
            .toolbar {
                // X — revert and close
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        activeTaxRates = originalRates
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").foregroundColor(.primary)
                    }
                }
                // Checkmark — confirm and close
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark").foregroundColor(.primary)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddTax) {
            AddTaxView().presentationDetents([.large])
        }
    }
}


// ============================================================
// MARK: - AddTaxView  (Image 2)
// ============================================================
// A popup for defining a new tax type.
// User types a percentage with the keypad and enters a name below.
// Rules:
//   - If the name already exists (case-insensitive) → close without adding.
//   - Same percentage with a DIFFERENT name → allowed (e.g. 7% SST when 7% PST exists).

struct AddTaxView: View {
    
    @Environment(\.dismiss) var dismiss
    // Same key as AddAmountView — writing here syncs everywhere
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    
    // rateString is the percentage as entered, e.g. "7" for 7%
    @State private var rateString = "0"
    @State private var taxName = ""
    
    // Convert percentage string to a decimal, e.g. "7" → 0.07
    var rateValue: Double { (Double(rateString) ?? 0) / 100.0 }
    
    // Decode existing rates to check for duplicate names
    var existingRates: [StoredTaxRate] {
        guard let data = availableTaxRatesJSON.data(using: .utf8),
              let rates = try? JSONDecoder().decode([StoredTaxRate].self, from: data)
        else { return [] }
        return rates
    }
    
    // Confirm button is only active when there's a name and a non-zero rate
    var canConfirm: Bool {
        !taxName.trimmingCharacters(in: .whitespaces).isEmpty && rateValue > 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // X button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Percentage display, e.g. "7%"
            Text("\(rateString)%")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .padding(.vertical, 16)
            
            // Tax name text field with placeholder
            ZStack(alignment: .center) {
                if taxName.isEmpty {
                    Text("Enter Tax Name Here")
                        .foregroundColor(Color.secondary.opacity(0.6))
                        .font(.title2)
                }
                TextField("", text: $taxName)
                    .multilineTextAlignment(.center)
                    .font(.title2)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            
            Spacer()
            Divider()
            
            // 3-column keypad (no special columns here)
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { handleInput("7") }
                    KeypadButton(label: "8") { handleInput("8") }
                    KeypadButton(label: "9") { handleInput("9") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { handleInput("4") }
                    KeypadButton(label: "5") { handleInput("5") }
                    KeypadButton(label: "6") { handleInput("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { handleInput("1") }
                    KeypadButton(label: "2") { handleInput("2") }
                    KeypadButton(label: "3") { handleInput("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: ".") { handleInput(".") }
                    KeypadButton(label: "0") { handleInput("0") }
                    KeypadButton(label: "Delete", isSpecial: true, fontSize: 14) { handleDelete() }
                }
                
                // Full-width confirm button
                Button {
                    confirmAdd()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canConfirm ? Color.green : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(!canConfirm)
            }
            .padding(12)
        }
    }
    
    func confirmAdd() {
        let trimmed = taxName.trimmingCharacters(in: .whitespaces)
        
        // Check for duplicate name (case-insensitive)
        // Note: same rate with a different name IS allowed
        let nameExists = existingRates.contains {
            $0.name.lowercased() == trimmed.lowercased()
        }
        
        if !nameExists {
            var updated = existingRates
            updated.append(StoredTaxRate(name: trimmed, rate: rateValue))
            if let data = try? JSONEncoder().encode(updated),
               let json = String(data: data, encoding: .utf8) {
                availableTaxRatesJSON = json
            }
        }
        // Close regardless — spec says "just close the popup"
        dismiss()
    }
    
    func handleInput(_ key: String) {
        if key == "." && rateString.contains(".") { return }
        if let dotIndex = rateString.firstIndex(of: ".") {
            let count = rateString.distance(from: dotIndex, to: rateString.endIndex) - 1
            if count >= 2 { return }
        }
        if rateString == "0" && key != "." { rateString = key }
        else { rateString += key }
    }
    
    func handleDelete() {
        if rateString.count > 1 { rateString.removeLast() }
        else { rateString = "0" }
    }
}


// ============================================================
// MARK: - TipEditorView  (Image 4)
// ============================================================
// A 2-column grid of tip percentage tiles.
// Tap  → selects that tip and closes the sheet.
// Hold → enters delete mode (red X appears on each tile).
// In delete mode, tapping X on a tile removes it permanently.
// "+" → opens AddTipView to add a new tip amount.
// Tiles are always sorted in ascending order.

struct TipEditorView: View {
    
    @Binding var selectedTipRate: Double
    @Environment(\.dismiss) var dismiss
    
    // Same key as AddAmountView — changes sync automatically
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""
    
    // When true, red X delete buttons appear on each tile
    @State private var deleteMode = false
    @State private var showAddTip = false
    
    // Decode and sort the available tip rates
    var tipRates: [Double] {
        guard let data = availableTipRatesJSON.data(using: .utf8),
              let rates = try? JSONDecoder().decode([Double].self, from: data)
        else { return [] }
        return rates.sorted()
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Header row
            HStack {
                Button {
                    if deleteMode {
                        // In delete mode, this button exits delete mode
                        withAnimation(.spring(response: 0.3)) { deleteMode = false }
                    } else {
                        dismiss()
                    }
                } label: {
                    // Shows "done" icon when in delete mode, "close" otherwise
                    Image(systemName: deleteMode ? "checkmark" : "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                if deleteMode {
                    Text("Tap × to remove")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Scrollable 2-column grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    
                    ForEach(tipRates, id: \.self) { rate in
                        TipTileView(
                            rate: rate,
                            isSelected: selectedTipRate == rate,
                            deleteMode: deleteMode,
                            onTap: {
                                // Select this tip and close the sheet
                                selectedTipRate = rate
                                dismiss()
                            },
                            onDelete: {
                                // Remove this rate from persistent storage
                                let updated = tipRates.filter { $0 != rate }
                                if let data = try? JSONEncoder().encode(updated),
                                   let json = String(data: data, encoding: .utf8) {
                                    availableTipRatesJSON = json
                                }
                                // If we deleted the currently selected rate, clear it
                                if selectedTipRate == rate { selectedTipRate = 0.0 }
                            },
                            onLongPress: {
                                // Enter delete mode
                                withAnimation(.spring(response: 0.3)) { deleteMode = true }
                            }
                        )
                    }
                    
                    // "+" tile — opens AddTipView
                    Button {
                        showAddTip = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showAddTip) {
            AddTipView().presentationDetents([.large])
        }
    }
}


// ============================================================
// MARK: - TipTileView
// ============================================================
// A single tile in the TipEditorView grid.
// Blue background = currently selected.
// In delete mode, a red × appears in the top-right corner.
// Long pressing any tile activates delete mode.

struct TipTileView: View {
    let rate: Double
    let isSelected: Bool
    let deleteMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        // ZStack lets us layer the X button on top of the tile
        ZStack(alignment: .topTrailing) {
            
            // Main tile
            Button {
                if !deleteMode { onTap() }
                // In delete mode, tapping the tile does nothing — only X deletes
            } label: {
                Text(formatRate(rate))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(isSelected ? Color.blue : Color.secondary.opacity(0.12))
                    .cornerRadius(16)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in onLongPress() }
            )
            
            // Red X — only visible in delete mode
            if deleteMode {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        // White background behind the icon so it's readable on any tile color
                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)  // sits in the top-right corner, slightly outside the tile
            }
        }
    }
}


// ============================================================
// MARK: - AddTipView  (Image 5)
// ============================================================
// A popup for adding a new tip percentage.
// If the percentage already exists → close without adding.

struct AddTipView: View {
    
    @Environment(\.dismiss) var dismiss
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""
    
    @State private var rateString = "0"
    
    var rateValue: Double { (Double(rateString) ?? 0) / 100.0 }
    
    var existingRates: [Double] {
        guard let data = availableTipRatesJSON.data(using: .utf8),
              let rates = try? JSONDecoder().decode([Double].self, from: data)
        else { return [] }
        return rates
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // X button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Percentage display
            Text("\(rateString)%")
                .font(.system(size: 56, weight: .light, design: .rounded))
                .padding(.vertical, 24)
            
            Spacer()
            Divider()
            
            // 3-column keypad
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { handleInput("7") }
                    KeypadButton(label: "8") { handleInput("8") }
                    KeypadButton(label: "9") { handleInput("9") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { handleInput("4") }
                    KeypadButton(label: "5") { handleInput("5") }
                    KeypadButton(label: "6") { handleInput("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { handleInput("1") }
                    KeypadButton(label: "2") { handleInput("2") }
                    KeypadButton(label: "3") { handleInput("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: ".") { handleInput(".") }
                    KeypadButton(label: "0") { handleInput("0") }
                    KeypadButton(label: "Delete", isSpecial: true, fontSize: 14) { handleDelete() }
                }
                
                // Full-width confirm button
                Button {
                    confirmAdd()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(rateValue > 0 ? Color.green : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(rateValue <= 0)
            }
            .padding(12)
        }
    }
    
    func confirmAdd() {
        // Only add if this exact percentage doesn't already exist
        if !existingRates.contains(rateValue) {
            var updated = existingRates
            updated.append(rateValue)
            updated.sort()  // keep ascending order
            if let data = try? JSONEncoder().encode(updated),
               let json = String(data: data, encoding: .utf8) {
                availableTipRatesJSON = json
            }
        }
        // Close regardless — spec says "it won't create a new tile"
        dismiss()
    }
    
    func handleInput(_ key: String) {
        if key == "." && rateString.contains(".") { return }
        if let dotIndex = rateString.firstIndex(of: ".") {
            let count = rateString.distance(from: dotIndex, to: rateString.endIndex) - 1
            if count >= 2 { return }
        }
        if rateString == "0" && key != "." { rateString = key }
        else { rateString += key }
    }
    
    func handleDelete() {
        if rateString.count > 1 { rateString.removeLast() }
        else { rateString = "0" }
    }
}


// ============================================================
// MARK: - Preview
// ============================================================
#Preview {
    AddAmountView(categoryName: "Grocery", categorySymbol: "basket.fill")
        .modelContainer(for: Transaction.self, inMemory: true)
}
