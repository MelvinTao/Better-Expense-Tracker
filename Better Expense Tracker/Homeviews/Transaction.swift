import SwiftData
import Foundation

struct TaxRate: Codable {
    var name: String
    var rate: Double
    var amount: Double
}

@Model
class Transaction {

    // MARK: - Core
    var title: String
    var amount: Double          // the final number the user typed (after tax, tip)
    var date: Date
    var categoryName: String
    var categorySymbol: String
    var currency: String
    var isIncome: Bool          // true = income category (salary, freelance, etc.)

    // Project code fields — directly stored, so renaming a ProjectCode cascades here.
    var projectCode: String?        // top-level code, e.g. "PROJ-A"
    var projectSubCode: String?     // sub-code under projectCode, e.g. "Q2-REVIEW"

    // Backward-compat computed property used by older display/save code.
    // Format: [] | [proj] | [proj, sub]
    var projectCodes: [String] {
        get {
            if let p = projectCode {
                return projectSubCode.map { [p, $0] } ?? [p]
            }
            return []
        }
        set {
            projectCode    = newValue.first
            projectSubCode = newValue.count > 1 ? newValue[1] : nil
        }
    }

    // Legacy JSON column — kept so SwiftData doesn't drop existing rows on schema change.
    // Not used for reads or writes anymore; value is always "[]".
    var projectCodesJSON: String = "[]"

    // MARK: - Base
    var baseAmount: Double      // price before tax and tip — always calculated automatically

    // MARK: - Tax
    var taxable: Bool
    var taxRates: [TaxRate]
    var totalTaxAmount: Double

    // MARK: - Tip
    var tippable: Bool
    var availableTipRates: [Double]
    var selectedTipRate: Double
    var tipAmount: Double

    // MARK: - Reusable
    var reusable: Bool
    var reusableDurationDays: Int
    var dailyAmount: Double

    // MARK: - Gasoline
    var gasoline: Bool
    var pricePerLiter: Double
    var taxPerLiter: Double
    var liters: Double
    var gasolineTaxAmount: Double
    var previousFillupDate: Date?
    var dailyGasolineCost: Double

    // MARK: - Linked group (gasoline daily splits share a groupID)
    // groupID is a UUID string shared by all daily transactions from one fill-up.
    // isGasolineSplit = true for the N-1 synthetic daily entries; false for the mother entry.
    var groupID: String?
    var isGasolineSplit: Bool

    init(
        title: String,
        amount: Double,
        date: Date = .now,
        categoryName: String,
        categorySymbol: String,
        currency: String = "CAD",
        projectCodes: [String] = [],
        isIncome: Bool = false,
        taxable: Bool = false,
        taxRates: [TaxRate] = [
            TaxRate(name: "GST", rate: 0.05, amount: 0),
            TaxRate(name: "PST", rate: 0.07, amount: 0)
        ],
        tippable: Bool = false,
        availableTipRates: [Double] = [0.0, 0.10, 0.12, 0.15, 0.18, 0.20],
        selectedTipRate: Double = 0.0,
        reusable: Bool = false,
        reusableDurationDays: Int = 1,
        gasoline: Bool = false,
        pricePerLiter: Double = 0.0,
        taxPerLiter: Double = 0.0,
        previousFillupDate: Date? = nil,
        groupID: String? = nil,
        isGasolineSplit: Bool = false
    ) {
        self.title = title
        self.amount = amount
        self.date = date
        self.categoryName = categoryName
        self.categorySymbol = categorySymbol
        self.currency = currency
        self.isIncome = isIncome
        self.projectCode    = projectCodes.first
        self.projectSubCode = projectCodes.count > 1 ? projectCodes[1] : nil
        self.projectCodesJSON = "[]"
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
        self.groupID = groupID
        self.isGasolineSplit = isGasolineSplit

        // MARK: Calculate base amount
        //
        // OUTCOME: amount = base × (1 + taxRate + tipRate)
        //          base   = amount / (1 + taxRate + tipRate)
        //
        // INCOME:  cheque = base × (1 − deductionRate)
        //          base   = cheque / (1 − deductionRate)
        //   Example: cheque = 1789.17, deductions = 3.5407%+5.5562%+1.6297%+8.2517% = 18.9783%
        //            base = 1789.17 / (1 − 0.189783) = 2208.26
        //   Swift Double gives ~15–17 significant digits so no cent is lost.

        let totalTaxRate = taxable ? taxRates.reduce(0) { $0 + $1.rate } : 0.0
        let tipRateUsed  = tippable ? selectedTipRate : 0.0

        let base: Double
        if isIncome {
            // The received amount is LESS than gross — deductions reduce it
            base = (taxable && totalTaxRate > 0 && totalTaxRate < 1.0)
                ? amount / (1.0 - totalTaxRate)
                : amount
        } else {
            // The paid amount is MORE than base — tax and tip are added on top
            let totalRate = totalTaxRate + tipRateUsed
            base = totalRate > 0 ? amount / (1.0 + totalRate) : amount
        }
        self.baseAmount = base

        // Calculate each tax component's dollar amount
        var calculatedRates = taxRates
        var totalTax = 0.0
        if taxable {
            for i in calculatedRates.indices {
                calculatedRates[i].amount = base * calculatedRates[i].rate
                totalTax += calculatedRates[i].amount
            }
            self.taxRates = calculatedRates
        } else {
            self.taxRates = []
        }
        self.totalTaxAmount = totalTax
        self.tipAmount = tippable ? base * tipRateUsed : 0.0

        // Gasoline (per-litre tax, not percentage)
        if gasoline && pricePerLiter > 0 {
            let calcLiters = amount / (pricePerLiter / 100.0)
            self.liters = calcLiters
            self.gasolineTaxAmount = calcLiters * (taxPerLiter / 100.0)
        } else {
            self.liters = 0.0
            self.gasolineTaxAmount = 0.0
        }

        if gasoline, let prevDate = previousFillupDate {
            let days = Calendar.current.dateComponents([.day], from: prevDate, to: date).day ?? 1
            self.dailyGasolineCost = days > 0 ? amount / Double(days) : amount
        } else {
            self.dailyGasolineCost = 0.0
        }

        // Reusable (spread cost over N days)
        self.dailyAmount = (reusable && reusableDurationDays > 0)
            ? amount / Double(reusableDurationDays)
            : amount
    }
}
