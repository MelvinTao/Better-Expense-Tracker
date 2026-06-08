import SwiftData
import Foundation

// Stores a user-defined category (e.g. "Grocery", "Salary") in the database.
// Previously, categories were hardcoded arrays in HomeView.
// Now they're persistent so the user can add, delete, and configure them.
@Model
class CategoryModel {

    var name: String
    var symbol: String
    var colorName: String       // raw value of CategoryColor, e.g. "yellow"
    var isOutcome: Bool         // true = spending (outcome), false = earning (income)
    var sortOrder: Int          // controls display order within each group

    // Default tax/tip settings for this category, stored as JSON strings.
    // When AddAmountView opens for this category, these are used to pre-fill selections.
    var defaultActiveTaxNamesJSON: String   // JSON of [String] — which tax names are on by default
    var defaultTipRate: Double              // e.g. 0.18 for 18% tip by default; 0.0 = no tip

    // Category-level feature flags
    var taxable: Bool
    var tippable: Bool
    var isReusable: Bool
    var isGasoline: Bool

    init(
        name: String,
        symbol: String = "basket.fill",
        colorName: String = "yellow",
        isOutcome: Bool = true,
        sortOrder: Int = 0,
        defaultActiveTaxNamesJSON: String = "[]",
        defaultTipRate: Double = 0.0,
        taxable: Bool = false,
        tippable: Bool = false,
        isReusable: Bool = false,
        isGasoline: Bool = false
    ) {
        self.name = name
        self.symbol = symbol
        self.colorName = colorName
        self.isOutcome = isOutcome
        self.sortOrder = sortOrder
        self.defaultActiveTaxNamesJSON = defaultActiveTaxNamesJSON
        self.defaultTipRate = defaultTipRate
        self.taxable = taxable
        self.tippable = tippable
        self.isReusable = isReusable
        self.isGasoline = isGasoline
    }

    // Convenience: converts the stored colorName string back to a CategoryColor enum value
    var categoryColor: CategoryColor {
        CategoryColor(rawValue: colorName) ?? .gray
    }

    // Convenience: decodes the default active tax names from JSON
    var defaultActiveTaxNames: [String] {
        guard let data = defaultActiveTaxNamesJSON.data(using: .utf8),
              let names = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return names
    }
}
