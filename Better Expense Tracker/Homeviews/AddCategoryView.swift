import SwiftUI
import SwiftData

// Create or edit a category.
// Pass editingCategory to pre-fill all fields and update in place instead of inserting.
// - Tile preview in the center (grey until color is chosen on create; pre-filled on edit)
// - Tap the symbol circle → SymbolPickerView
// - Tap the tile background → color picker
// - Name input with auto-shown keyboard
// - Tax / Tip / Extras configuration buttons
// - Checkmark appears after a color is selected (always visible in edit mode)

struct AddCategoryView: View {

    let isOutcome: Bool
    var editingCategory: CategoryModel? = nil   // nil = create, non-nil = edit
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    @State private var name = ""
    @State private var selectedSymbol = "basket.fill"
    @State private var selectedColor: CategoryColor? = nil  // nil = grey (no color chosen yet)

    @State private var activeTaxRates: [StoredTaxRate] = []
    @State private var selectedTipRate: Double = 0.0
    @State private var isReusable = false
    @State private var isGasoline = false

    @State private var showSymbolPicker = false
    @State private var showColorPicker = false
    @State private var showTaxEditor = false
    @State private var showTipEditor = false
    @State private var showExtras = false

    @FocusState private var nameFieldFocused: Bool
    @AppStorage("availableTaxRatesJSON") private var availableTaxRatesJSON = ""
    @AppStorage("availableTipRatesJSON") private var availableTipRatesJSON = ""

    var isEditMode: Bool { editingCategory != nil }
    // Tile shows grey until user picks a color (in create mode)
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
                // Checkmark always visible in edit mode; in create mode only after color is picked
                if colorIsChosen || isEditMode {
                    Button { saveCategory() } label: {
                        Image(systemName: "checkmark").font(.system(size: 20, weight: .semibold)).foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            // Tile preview
            ZStack {
                // Tile background — tapping opens color picker
                RoundedRectangle(cornerRadius: 15)
                    .fill(tileColor.color)
                    .frame(width: 140, height: 180)
                    .onTapGesture { showColorPicker = true }

                // Symbol circle — tapping opens symbol picker
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
                Button { showTaxEditor = true } label: {
                    VStack(spacing: 2) {
                        Text("Tax").font(.caption)
                        Text(activeTaxRates.isEmpty ? "None" : formatRate(totalTaxRate)).font(.headline)
                    }
                    .foregroundColor(activeTaxRates.isEmpty ? .primary : .white)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(activeTaxRates.isEmpty ? Color.secondary.opacity(0.12) : tileColor.color)
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
                            // In create mode, auto-focus the name field
                            if !isEditMode { nameFieldFocused = true }
                            // In edit mode, pre-fill all fields from the existing category
                            if let c = editingCategory {
                                name           = c.name
                                selectedSymbol = c.symbol
                                selectedColor  = CategoryColor(rawValue: c.colorName)
                                selectedTipRate = c.defaultTipRate
                                isReusable     = c.isReusable
                                isGasoline     = c.isGasoline
                                // Decode default active tax names back into StoredTaxRate objects
                                if let data = UserDefaults.standard.string(forKey: "availableTaxRatesJSON")?.data(using: .utf8),
                                   let allRates = try? JSONDecoder().decode([StoredTaxRate].self, from: data) {
                                    activeTaxRates = allRates.filter { c.defaultActiveTaxNames.contains($0.name) }
                                }
                            }
                        }

                        // MARK: Sheets
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
                    }

                    func saveCategory() {
                        guard let color = selectedColor else { return }

                        // Encode the active tax names so the category remembers its defaults
                        let taxNames = activeTaxRates.map { $0.name }
                        let taxNamesJSON = (try? String(
                            data: JSONEncoder().encode(taxNames),
                            encoding: .utf8
                        )) ?? "[]"

                        if let existing = editingCategory {
                            // Edit mode — mutate the existing object in place
                            existing.name     = name.isEmpty ? "New Category" : name
                            existing.symbol   = selectedSymbol
                            existing.colorName = color.rawValue
                            existing.defaultActiveTaxNamesJSON = taxNamesJSON
                            existing.defaultTipRate  = selectedTipRate
                            existing.taxable         = !activeTaxRates.isEmpty
                            existing.tippable        = selectedTipRate > 0
                            existing.isReusable      = isReusable
                            existing.isGasoline      = isGasoline
                        } else {
                            // Create mode — insert a new category at the end
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
                                isGasoline:             isGasoline
                            ))
                        }
                        dismiss()
                    }
                }


                // ============================================================
                // MARK: - ColorPickerView
                // ============================================================
                // A simple grid of the available CategoryColor options.
                // The currently selected color has a checkmark overlay.

                struct ColorPickerView: View {
                    @Binding var selectedColor: CategoryColor?
                    @Environment(\.dismiss) var dismiss

                    // All colors except gray (gray is only used as the default unselected state)
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
                                // Invisible placeholder keeps the title centered
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

                                            // Checkmark shown on the currently selected color
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
                // A 4-column scrollable grid of hardcoded SF Symbol names.
                // Tapping a symbol selects it and closes the sheet.
                // The selected symbol has a highlighted background.

                struct SymbolPickerView: View {
                    @Binding var selectedSymbol: String
                    var accentColor: CategoryColor?
                    @Environment(\.dismiss) var dismiss

                    // Hardcoded list of available symbols — add more here as needed
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
                                                    // Highlighted background for the selected symbol
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
                // MARK: - ExtrasEditorView  (Image 7)
                // ============================================================
                // Two toggle rows: Reusable and Gasoline.
                // X cancels (reverts). Checkmark confirms.

                struct ExtrasEditorView: View {
                    @Binding var isReusable: Bool
                    @Binding var isGasoline: Bool
                    @Environment(\.dismiss) var dismiss

                    // Snapshot for revert on cancel
                    @State private var originalReusable = false
                    @State private var originalGasoline = false

                    var body: some View {
                        VStack(spacing: 0) {
                            HStack {
                                Button {
                                    // Revert and close
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

                            // Reusable toggle row
                            HStack {
                                Text("Reusable")
                                    .font(.title2)
                                Spacer()
                                Toggle("", isOn: $isReusable).labelsHidden()
                            }
                            .padding(.horizontal, 24).padding(.vertical, 8)

                            // Gasoline toggle row
                            HStack {
                                Text("Gasoline")
                                    .font(.title2)
                                Spacer()
                                Toggle("", isOn: $isGasoline).labelsHidden()
                            }
                            .padding(.horizontal, 24).padding(.vertical, 8)

                            Spacer()
                        }
                        .onAppear {
                            // Save snapshot so X can revert
                            originalReusable = isReusable
                            originalGasoline = isGasoline
                        }
                    }
                }


                // ============================================================
                // MARK: - Preview
                // ============================================================
                #Preview {
                    AddCategoryView(isOutcome: true)
                        .modelContainer(for: [Transaction.self, CategoryModel.self], inMemory: true)
                }
