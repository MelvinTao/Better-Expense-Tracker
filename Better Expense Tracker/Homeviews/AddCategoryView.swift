import SwiftUI
import SwiftData

// Create or edit a category.
// Pass editingCategory to pre-fill all fields and update in place instead of inserting.

struct AddCategoryView: View {

    let isOutcome: Bool
    var editingCategory: CategoryModel? = nil   // nil = create, non-nil = edit
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var name = ""
    @State private var selectedSymbol = "basket.fill"
    @State private var selectedColor: CategoryColor? = nil

    @State private var activeTaxRates: [StoredTaxRate] = []
    @State private var selectedTipRate: Double = 0.0
    @State private var isReusable = false
    @State private var isGasoline = false
    @State private var gasolineTaxPerLiter: Double = 0.0

    @State private var showSymbolPicker = false
    @State private var showColorPicker = false
    @State private var showTaxEditor = false
    @State private var showTipEditor = false
    @State private var showExtras = false
    @State private var showGasolineTaxEditor = false

    @FocusState private var nameFieldFocused: Bool
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""

    var isEditMode: Bool { editingCategory != nil }
    var tileColor: CategoryColor { selectedColor ?? .gray }
    var colorIsChosen: Bool { selectedColor != nil }
    var totalTaxRate: Double { activeTaxRates.reduce(0) { $0 + $1.rate } }

    var body: some View {
        VStack(spacing: 0) {

            // Header: X and Checkmark
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundColor(.primary)
                }
                Spacer()
                if colorIsChosen || isEditMode {
                    Button { saveCategory() } label: {
                        Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            // Tile preview
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(tileColor.color)
                    .frame(width: 140, height: 180)
                    .onTapGesture { showColorPicker = true }

                Circle()
                    .fill(tileColor.transitionColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: selectedSymbol)
                            .font(.system(size: 28)).foregroundColor(.white)
                    )
                    .onTapGesture { showSymbolPicker = true }
            }
            .padding(.bottom, 12)

            // Category name input
            ZStack(alignment: .center) {
                if name.isEmpty {
                    Text("Category name").foregroundColor(Color.secondary.opacity(0.5)).font(.title2)
                }
                TextField("", text: $name)
                    .multilineTextAlignment(.center).font(.title2)
                    .focused($nameFieldFocused)
            }
            .padding(.horizontal, 32).padding(.vertical, 8)
            .onTapGesture { nameFieldFocused = true }

            Spacer()

            // Tax / Tip / Extras buttons
            HStack(spacing: 12) {
                Button {
                    if isGasoline { showGasolineTaxEditor = true }
                    else { showTaxEditor = true }
                } label: {
                    VStack(spacing: 2) {
                        Text("Tax").font(.caption)
                        if isGasoline {
                            Text(gasolineTaxPerLiter > 0
                                 ? String(format: "%.2f ¢/L", gasolineTaxPerLiter)
                                 : "None")
                                .font(.headline)
                        } else {
                            Text(activeTaxRates.isEmpty ? "None" : formatRate(totalTaxRate)).font(.headline)
                        }
                    }
                    .foregroundColor({
                        if isGasoline { return gasolineTaxPerLiter > 0 ? Color.white : Color.primary }
                        return activeTaxRates.isEmpty ? Color.primary : Color.white
                    }())
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background({
                        if isGasoline { return gasolineTaxPerLiter > 0 ? tileColor.color : Color.secondary.opacity(0.12) }
                        return activeTaxRates.isEmpty ? Color.secondary.opacity(0.12) : tileColor.color
                    }())
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button { showTipEditor = true } label: {
                    VStack(spacing: 2) {
                        Text("Tip").font(.caption)
                        Text(selectedTipRate > 0 ? formatRate(selectedTipRate) : "None").font(.headline)
                    }
                    .foregroundColor(selectedTipRate > 0 ? .white : .primary)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(selectedTipRate > 0 ? tileColor.color : Color.secondary.opacity(0.12))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                Button { showExtras = true } label: {
                    VStack(spacing: 2) {
                        Text("Extras").font(.caption)
                        Text(isReusable || isGasoline ? "On" : "None").font(.headline)
                    }
                    .foregroundColor(isReusable || isGasoline ? .white : .primary)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(isReusable || isGasoline ? tileColor.color : Color.secondary.opacity(0.12))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
        .onAppear {
            if !isEditMode { nameFieldFocused = true }
            if let c = editingCategory {
                name           = c.name
                selectedSymbol = c.symbol
                selectedColor  = CategoryColor(rawValue: c.colorName)
                selectedTipRate = c.defaultTipRate
                isReusable          = c.isReusable
                isGasoline          = c.isGasoline
                gasolineTaxPerLiter = c.gasolineTaxPerLiter
                if let data = UserDefaults.standard.string(forKey: "availableTaxRatesJSON")?.data(using: .utf8),
                   let allRates = try? JSONDecoder().decode([StoredTaxRate].self, from: data) {
                    activeTaxRates = allRates.filter { c.defaultActiveTaxNames.contains($0.name) }
                }
            }
        }
        .sheet(isPresented: $showSymbolPicker) {
            SymbolPickerView(selectedSymbol: $selectedSymbol, accentColor: selectedColor)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showColorPicker) {
            ColorPickerView(selectedColor: $selectedColor)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTaxEditor) {
            TaxEditorView(
                activeTaxRates: $activeTaxRates,
                accentColor: tileColor.color
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showTipEditor) {
            TipEditorView(
                selectedTipRate: $selectedTipRate,
                accentColor: tileColor.color
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showExtras) {
            ExtrasEditorView(isReusable: $isReusable, isGasoline: $isGasoline)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showGasolineTaxEditor) {
            GasolineTaxEditorView(taxPerLiter: $gasolineTaxPerLiter, accentColor: tileColor.color)
                .presentationDetents([.large])
        }
    }

    func saveCategory() {
        guard let color = selectedColor else { return }

        let taxNames = activeTaxRates.map { $0.name }
        let taxNamesJSON = (try? String(
            data: JSONEncoder().encode(taxNames),
            encoding: .utf8
        )) ?? "[]"

        if let existing = editingCategory {
            existing.name     = name.isEmpty ? "New Category" : name
            existing.symbol   = selectedSymbol
            existing.colorName = color.rawValue
            existing.defaultActiveTaxNamesJSON = taxNamesJSON
            existing.defaultTipRate  = selectedTipRate
            existing.taxable              = !activeTaxRates.isEmpty
            existing.tippable             = selectedTipRate > 0
            existing.isReusable           = isReusable
            existing.isGasoline           = isGasoline
            existing.gasolineTaxPerLiter  = gasolineTaxPerLiter
        } else {
            let query = FetchDescriptor<CategoryModel>(sortBy: [SortDescriptor(\.sortOrder, order: .reverse)])
            let maxOrder = (try? modelContext.fetch(query).first?.sortOrder) ?? -1

            modelContext.insert(CategoryModel(
                name:                   name.isEmpty ? "New Category" : name,
                symbol:                 selectedSymbol,
                colorName:              color.rawValue,
                isOutcome:              isOutcome,
                sortOrder:              maxOrder + 1,
                defaultActiveTaxNamesJSON: taxNamesJSON,
                defaultTipRate:         selectedTipRate,
                taxable:                !activeTaxRates.isEmpty,
                tippable:               selectedTipRate > 0,
                isReusable:             isReusable,
                isGasoline:             isGasoline,
                gasolineTaxPerLiter:    gasolineTaxPerLiter
            ))
        }
        dismiss()
    }
}


// ============================================================
// MARK: - ColorPickerView
// ============================================================

struct ColorPickerView: View {
    @Binding var selectedColor: CategoryColor?
    @Environment(\.dismiss) var dismiss

    let choices: [CategoryColor] = [
        .red, .green, .blue, .yellow, .purple, .orange,
        .pink, .teal, .mint, .coral, .indigo, .lime, .sky, .rose, .amber
    ]

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Choose Color").font(.headline)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(choices, id: \.self) { choice in
                    Button {
                        selectedColor = choice
                        dismiss()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(choice.color)
                                .frame(height: 80)

                            if selectedColor == choice {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            Spacer()
        }
    }
}


// ============================================================
// MARK: - SymbolPickerView
// ============================================================
// A 4-column scrollable grid of SF Symbol names.
// Tapping a symbol selects it and closes the sheet.

struct SymbolPickerView: View {
    @Binding var selectedSymbol: String
    var accentColor: CategoryColor?
    @Environment(\.dismiss) var dismiss

    let symbols: [String] = [
        "basket.fill", "cart.fill", "bag.fill",
        "fork.knife", "cup.and.saucer.fill", "birthday.cake.fill",
        "car.fill", "airplane", "bus.fill",
        "tram.fill", "bicycle", "fuelpump.fill",
        "heart.fill", "cross.fill", "pills.fill",
        "stethoscope", "bandage.fill", "syringe.fill",
        "house.fill", "building.2.fill", "building.fill",
        "tv.fill", "desktopcomputer", "laptopcomputer",
        "iphone", "headphones", "camera.fill",
        "gamecontroller.fill", "film.fill", "music.note",
        "book.fill", "graduationcap.fill", "pencil",
        "briefcase.fill", "folder.fill", "doc.fill",
        "dollarsign.circle.fill", "creditcard.fill", "banknote.fill",
        "chart.line.uptrend.xyaxis", "chart.bar.fill", "percent",
        "gift.fill", "party.popper.fill", "balloon.fill",
        "figure.walk", "figure.run", "dumbbell.fill",
        "sportscourt.fill", "tennis.racket", "soccerball",
        "leaf.fill", "tree.fill", "pawprint.fill",
        "sun.max.fill", "moon.fill", "cloud.rain.fill",
        "wrench.fill", "hammer.fill", "screwdriver.fill",
        "paintbrush.fill", "scissors", "tuningfork",
        "wifi", "bolt.fill", "drop.fill",
        "flame.fill", "snowflake", "wind",
        "shippingbox.fill", "archivebox.fill", "tray.fill",
        "car.2.fill", "truck.box.fill", "ferry.fill",
        "photo.fill", "camera.aperture", "lens.aperture",
    ]

    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                Text("Choose Symbol").font(.headline)
                Spacer()
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .medium))
                    .opacity(0)
            }
            .padding(.horizontal, 20).padding(.vertical, 16)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            dismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedSymbol == symbol
                                          ? (accentColor?.color ?? Color.blue)
                                          : Color.secondary.opacity(0.12))
                                    .frame(width: 64, height: 64)

                                Image(systemName: symbol)
                                    .font(.system(size: 28))
                                    .foregroundColor(selectedSymbol == symbol ? .white : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
        }
    }
}


// ============================================================
// MARK: - ExtrasEditorView
// ============================================================

struct ExtrasEditorView: View {
    @Binding var isReusable: Bool
    @Binding var isGasoline: Bool
    @Environment(\.dismiss) var dismiss

    @State private var originalReusable = false
    @State private var originalGasoline = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isReusable = originalReusable
                    isGasoline = originalGasoline
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 32)

            HStack {
                Text("Reusable").font(.title2)
                Spacer()
                Toggle("", isOn: $isReusable).labelsHidden()
            }
            .padding(.horizontal, 24).padding(.vertical, 8)

            HStack {
                Text("Gasoline").font(.title2)
                Spacer()
                Toggle("", isOn: $isGasoline).labelsHidden()
            }
            .padding(.horizontal, 24).padding(.vertical, 8)

            Spacer()
        }
        .onAppear {
            originalReusable = isReusable
            originalGasoline = isGasoline
        }
    }
}


// ============================================================
// MARK: - GasolineTaxEditorView
// ============================================================

struct GasolineTaxEditorView: View {
    @Binding var taxPerLiter: Double
    let accentColor: Color
    @Environment(\.dismiss) var dismiss

    @State private var rateString = "0"

    var rateValue: Double { Double(rateString) ?? 0 }
    var canConfirm: Bool { rateValue > 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.primary)
                }
                Spacer()
            }
            .padding(.horizontal, 20).padding(.top, 20)

            VStack(spacing: 4) {
                Text(String(format: "$%.2f ¢/L", rateValue))
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .padding(.vertical, 16)
                Text("Gasoline tax per litre")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
            Divider()

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    KeypadButton(label: "7") { ri("7") }
                    KeypadButton(label: "8") { ri("8") }
                    KeypadButton(label: "9") { ri("9") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "4") { ri("4") }
                    KeypadButton(label: "5") { ri("5") }
                    KeypadButton(label: "6") { ri("6") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: "1") { ri("1") }
                    KeypadButton(label: "2") { ri("2") }
                    KeypadButton(label: "3") { ri("3") }
                }
                HStack(spacing: 8) {
                    KeypadButton(label: ".", isSpecial: false) { ri(".") }
                    KeypadButton(label: "0") { ri("0") }
                    KeypadButton(label: "delete", isSpecial: true, fontSize: 20,
                                 fontWeight: .medium, systemImage: "delete.backward") { rd() }
                }
                Button { confirm() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(canConfirm ? accentColor : Color.gray.opacity(0.4))
                        .cornerRadius(12)
                }
                .buttonStyle(.plain).disabled(!canConfirm)
            }
            .padding(12)
        }
        .onAppear {
            if taxPerLiter > 0 {
                rateString = String(format: "%.2f", taxPerLiter)
                    .replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
                if rateString.isEmpty { rateString = "0" }
            }
        }
    }

    func ri(_ key: String) {
        if key == "." && rateString.contains(".") { return }
        if let di = rateString.firstIndex(of: "."),
           rateString.distance(from: di, to: rateString.endIndex) - 1 >= 2 { return }
        if rateString == "0" && key != "." { rateString = key } else { rateString += key }
    }

    func rd() { if rateString.count > 1 { rateString.removeLast() } else { rateString = "0" } }

    func confirm() {
        taxPerLiter = rateValue
        dismiss()
    }
}


// ============================================================
// MARK: - Preview
// ============================================================
#Preview {
    AddCategoryView(isOutcome: true)
        .modelContainer(for: [Transaction.self, CategoryModel.self], inMemory: true)
}
