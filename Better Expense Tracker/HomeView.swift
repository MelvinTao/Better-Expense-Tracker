import SwiftUI
import SwiftData

struct HomeView: View {

    // Live queries from SwiftData — update automatically when data changes
    @Query(sort: \CategoryModel.sortOrder) var categories: [CategoryModel]
    @Query var transactions: [Transaction]
    @Environment(\.modelContext) var modelContext

    // Edit mode: when true, X badges and + tiles appear
    @State private var editMode = false

    // Which category tile was tapped (opens AddAmountView)
    @State private var selectedCategory: CategoryModel? = nil

    // Which category X was tapped (opens DeleteCategoryView)
    @State private var categoryToDelete: CategoryModel? = nil

    // Which category tile was tapped in edit mode (opens edit sheet)
    @State private var categoryToEdit: CategoryModel? = nil

    // Which section's + was tapped (nil = not adding, true = outcome, false = income)
    @State private var addingCategoryIsOutcome: Bool? = nil

    // Prevents seeding default categories more than once
    @AppStorage("hasSeededCategories") private var hasSeededCategories = false

    let padding: CGFloat = 16
    let spacing: CGFloat = 12
    let minTileWidth: CGFloat = 90
    let maxTileWidth: CGFloat = 160

    // Split categories into the two groups
    var outcomeCategories: [CategoryModel] { categories.filter { $0.isOutcome } }
    var incomeCategories:  [CategoryModel] { categories.filter { !$0.isOutcome } }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (padding * 2)
            let columnCount = max(1, Int(availableWidth / (minTileWidth + spacing)))
            let tileWidth = min(maxTileWidth, (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
            let tileHeight = tileWidth * 4 / 3

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Outcome section (spending categories)
                    CategorySection(
                        title: "Outcome",
                        categories: outcomeCategories,
                        transactions: transactions,
                        columnCount: columnCount,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        spacing: spacing,
                        editMode: editMode,
                        onTileTap:       { selectedCategory = $0 },
                        onTileEdit:      { categoryToEdit = $0 },
                        onTileLongPress: { withAnimation(.spring(response: 0.3)) { editMode = true } },
                        onTileDelete:    { categoryToDelete = $0 },
                        onAddTap:        { addingCategoryIsOutcome = true }
                    )

                    // Income section (earning categories)
                    CategorySection(
                        title: "Income",
                        categories: incomeCategories,
                        transactions: transactions,
                        columnCount: columnCount,
                        tileWidth: tileWidth,
                        tileHeight: tileHeight,
                        spacing: spacing,
                        editMode: editMode,
                        onTileTap:       { selectedCategory = $0 },
                        onTileEdit:      { categoryToEdit = $0 },
                        onTileLongPress: { withAnimation(.spring(response: 0.3)) { editMode = true } },
                        onTileDelete:    { categoryToDelete = $0 },
                        onAddTap:        { addingCategoryIsOutcome = false }
                    )
                }
                .padding(padding)
            }
            // "Done" button — floats in top-right corner when in edit mode
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
        }
        .onAppear { seedIfNeeded() }

        // Sheet: add a transaction to an existing category
        .sheet(item: $selectedCategory) { category in
            AddAmountView(
                categoryName:           category.name,
                categorySymbol:         category.symbol,
                categoryColor:          category.categoryColor,
                isIncome:               !category.isOutcome,
                defaultActiveTaxNames:  category.defaultActiveTaxNames,
                defaultTipRate:         category.defaultTipRate
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
// Extracted into its own view to keep HomeView clean.

struct CategorySection: View {
    let title: String
    let categories: [CategoryModel]
    let transactions: [Transaction]
    let columnCount: Int
    let tileWidth: CGFloat
    let tileHeight: CGFloat
    let spacing: CGFloat
    let editMode: Bool
    let onTileTap: (CategoryModel) -> Void
    let onTileEdit: (CategoryModel) -> Void
    let onTileLongPress: () -> Void
    let onTileDelete: (CategoryModel) -> Void
    let onAddTap: () -> Void

    func total(for name: String) -> Double {
        transactions.filter { $0.categoryName == name }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.largeTitle).bold()
                .padding(.leading, 4)

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: columnCount),
                spacing: spacing
            ) {
                ForEach(categories) { category in
                    CategoryButton(
                        categoryName:    category.name,
                        categorySymbol:  category.symbol,
                        categoryAmount:  total(for: category.name),
                        backgroundColor: category.categoryColor,
                        tileWidth:       tileWidth,
                        tileHeight:      tileHeight,
                        editMode:        editMode,
                        onDeleteTap:     { onTileDelete(category) },
                        onTap:           { editMode ? onTileEdit(category) : onTileTap(category) },
                        onLongPress:     { onTileLongPress() }
                    )
                }

                // + tile — always visible when section is empty, or in edit mode
                if editMode || categories.isEmpty {
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
            }
        }
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
