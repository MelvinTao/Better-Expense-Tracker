import SwiftData
import Foundation

// A single tax component — name, rate, and calculated dollar amount.
// 'Codable' is required so SwiftData knows how to save this struct to the database.
struct TaxRate: Codable {
    var name: String    // e.g. "GST", "PST", "Carbon Tax"
    var rate: Double    // as a decimal, e.g. 0.05 means 5%
    var amount: Double  // dollar amount paid — calculated automatically on save
}

@Model
class Transaction {
    
    // MARK: - Core
    // Every transaction has these fields no matter what type it is
    
    var title: String
    var amount: Double          // the final number the user typed — what they actually paid
    var date: Date
    var categoryName: String
    var categorySymbol: String
    var currency: String        // treated as a label only — "JPY", "USD", etc. No conversion.
    var projectCode: String?    // the '?' makes it optional — nil if not project-related
    var note: String?
    
    // MARK: - Base amount
    // The price BEFORE any tax or tip — always calculated automatically
    
    var baseAmount: Double
    
    
    // MARK: - Tax
    
    var taxable: Bool
    
    // A flexible list of named tax rates.
    // Example for BC: [TaxRate(name: "GST", rate: 0.05, amount: 2.25),
    //                   TaxRate(name: "PST", rate: 0.07, amount: 3.15)]
    // You can have 1, 2, 3 or more rates per transaction.
    // The 'amount' field on each is calculated automatically — you don't set it manually.
    var taxRates: [TaxRate]
    
    var totalTaxAmount: Double  // sum of all taxRate.amount values — calculated automatically
    
    
    // MARK: - Tip
    
    var tippable: Bool
    
    // The list of tip options shown to the user.
    // e.g. [0.0, 0.10, 0.12, 0.15, 0.18] shows buttons: 0%, 10%, 12%, 15%, 18%
    // This will move to the Category model later so you configure it once per category.
    var availableTipRates: [Double]
    
    var selectedTipRate: Double  // the rate the user actually chose, e.g. 0.18
    var tipAmount: Double        // calculated: baseAmount * selectedTipRate
    
    
    // MARK: - Reusable
    
    var reusable: Bool
    var reusableDurationDays: Int  // e.g. a 3-year TV = 1095
    var dailyAmount: Double        // amount / reusableDurationDays — calculated automatically
    
    
    // MARK: - Gasoline
    // Important: do NOT set taxable = true on gasoline transactions.
    // Gas uses a flat per-litre tax (cents/L), not a percentage of the price.
    
    var gasoline: Bool
    var pricePerLiter: Double      // pump price in cents/L, e.g. 199.9
    var taxPerLiter: Double        // tax in cents/L, e.g. 27.0 for Vancouver
    var liters: Double             // calculated: amount / (pricePerLiter / 100)
    var gasolineTaxAmount: Double  // calculated: liters * (taxPerLiter / 100)
    var previousFillupDate: Date?  // the date of the previous fillup — used for daily average
    var dailyGasolineCost: Double  // amount / days since last fillup — calculated automatically
    
    
    // MARK: - Initializer
    
    init(
        // Core
        title: String,
        amount: Double,
        date: Date = .now,
        categoryName: String,
        categorySymbol: String,
        currency: String = "CAD",
        projectCode: String? = nil,
        note: String? = nil,
        
        // Tax — default rates are BC's GST + PST
        // You can pass in a completely different list for other categories
        taxable: Bool = false,
        taxRates: [TaxRate] = [
            TaxRate(name: "GST", rate: 0.05, amount: 0),
            TaxRate(name: "PST", rate: 0.07, amount: 0)
        ],
        
        // Tip — default options match common Canadian restaurant tip amounts
        tippable: Bool = false,
        availableTipRates: [Double] = [0.0, 0.10, 0.12, 0.15, 0.18],
        selectedTipRate: Double = 0.0,
        
        // Reusable
        reusable: Bool = false,
        reusableDurationDays: Int = 1,
        
        // Gasoline
        gasoline: Bool = false,
        pricePerLiter: Double = 0.0,
        taxPerLiter: Double = 0.0,
        previousFillupDate: Date? = nil
    ) {
        // --- Store all inputs ---
        
        self.title = title
        self.amount = amount
        self.date = date
        self.categoryName = categoryName
        self.categorySymbol = categorySymbol
        self.currency = currency
        self.projectCode = projectCode
        self.note = note
        self.taxable = taxable
        self.tippable = tippable
        self.availableTipRates = availableTipRates
        self.selectedTipRate = tippable ? selectedTipRate : 0.0
        self.reusable = reusable
        self.reusableDurationDays = reusableDurationDays
        self.gasoline = gasoline
        self.pricePerLiter = pricePerLiter
        self.taxPerLiter = taxPerLiter
        self.previousFillupDate = previousFillupDate
        
        
        // --- Calculate base amount ---
        // The formula works by reversing: amount = base * (1 + taxRates + tipRate)
        // So:                             base   = amount / (1 + taxRates + tipRate)
        
        // Add up all the tax rates in the list, e.g. 0.05 + 0.07 = 0.12
        let totalTaxRate = taxable
            ? taxRates.reduce(0) { $0 + $1.rate }
            : 0.0
        
        let tipRateUsed = tippable ? selectedTipRate : 0.0
        let totalRate   = totalTaxRate + tipRateUsed
        
        // If no rates apply, base is just the full amount
        let base = totalRate > 0 ? amount / (1.0 + totalRate) : amount
        self.baseAmount = base
        
        
        // --- Calculate each tax component's dollar amount ---
        
        // We make a mutable copy of the taxRates list so we can fill in the .amount field
        var calculatedRates = taxRates
        var totalTax = 0.0
        
        if taxable {
            for i in calculatedRates.indices {
                // e.g. base=$44.99, GST rate=0.05 → GST amount = $2.25
                calculatedRates[i].amount = base * calculatedRates[i].rate
                totalTax += calculatedRates[i].amount
            }
            self.taxRates = calculatedRates
        } else {
            // Not taxable — store an empty list
            self.taxRates = []
        }
        
        self.totalTaxAmount = totalTax
        
        
        // --- Tip ---
        
        self.tipAmount = tippable ? base * tipRateUsed : 0.0
        
        
        // --- Gasoline ---
        // pricePerLiter and taxPerLiter are in CENTS/L
        // We divide by 100 to convert to $/L before calculating
        
        if gasoline && pricePerLiter > 0 {
            let calcLiters = amount / (pricePerLiter / 100.0)
            self.liters = calcLiters
            self.gasolineTaxAmount = calcLiters * (taxPerLiter / 100.0)
        } else {
            self.liters = 0.0
            self.gasolineTaxAmount = 0.0
        }
        
        if gasoline, let prevDate = previousFillupDate {
            let days = Calendar.current
                .dateComponents([.day], from: prevDate, to: date).day ?? 1
            self.dailyGasolineCost = days > 0 ? amount / Double(days) : amount
        } else {
            self.dailyGasolineCost = 0.0
        }
        
        
        // --- Reusable ---
        
        if reusable && reusableDurationDays > 0 {
            self.dailyAmount = amount / Double(reusableDurationDays)
        } else {
            self.dailyAmount = amount
        }
    }
}
