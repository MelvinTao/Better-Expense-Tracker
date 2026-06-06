// HomeView shows the category tile grid.
// It tracks which category was tapped and shows the AddAmountView sheet for it.
// It also reads all transactions from the database to compute live category totals.

import SwiftUI
import SwiftData

struct HomeView: View {
    
    // Fetch all transactions live from the database.
    // This updates automatically whenever any transaction is added or deleted.
    @Query var transactions: [Transaction]
    
    // Tracks which category the user tapped.
    // When this is set, the sheet appears.
    // When the sheet is dismissed, this is cleared back to nil.
    @State private var selectedCategory: HomeView.CategorySelection? = nil
    
    let categories: [(name: String, symbol: String, color: CategoryButton.BackgroundColor)] = [
        ("Grocery",   "basket.fill",  .yellow),
        ("Transport", "car.fill",     .blue),
        ("Health",    "heart.fill",   .red),
        ("Shopping",  "bag.fill",     .purple),
        ("Food",      "fork.knife",   .orange),
        ("Travel",    "airplane",     .green),
    ]
    
    let padding: CGFloat = 16
    let spacing: CGFloat = 16
    let minTileWidth: CGFloat = 90
    let maxTileWidth: CGFloat = 160
    
    // Adds up all transaction amounts for a given category name
    func totalAmount(for categoryName: String) -> Double {
        transactions
            .filter { $0.categoryName == categoryName }
            .reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - (padding * 2)
            let columnCount = max(1, Int(availableWidth / (minTileWidth + spacing)))
            let tileWidth = min(maxTileWidth, (availableWidth - CGFloat(columnCount - 1) * spacing) / CGFloat(columnCount))
            let tileHeight = tileWidth * 4 / 3
            
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: spacing), count: columnCount),
                    spacing: spacing
                ) {
                    ForEach(categories, id: \.name) { category in
                        CategoryButton(
                            categoryName:    category.name,
                            categorySymbol:  category.symbol,
                            categoryAmount:  totalAmount(for: category.name),
                            backgroundColor: category.color,
                            tileWidth:       tileWidth,
                            tileHeight:      tileHeight,
                            onTap: {
                                selectedCategory = HomeView.CategorySelection(name: category.name, symbol: category.symbol)
                            },
                            onLongPress: {
                                // You can decide what long press does later
                                print("\(category.name) held")
                            }
                        )
                    }
                }
                .padding(padding)
            }
        }
        // This sheet appears whenever selectedCategory is not nil.
        // It automatically closes and clears selectedCategory when dismissed.
        .sheet(item: $selectedCategory) { category in
            AddAmountView(categoryName: category.name, categorySymbol: category.symbol)
                .presentationDetents([.large])
        }
    }
}

// This extension is required for .sheet(item:) to work.
// It tells Swift how to uniquely identify each category tuple.
extension HomeView {
    struct CategorySelection: Identifiable {
        let id = UUID()
        let name: String
        let symbol: String
    }
}

#Preview {
    HomeView()
}
