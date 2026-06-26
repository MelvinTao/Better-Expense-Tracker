import SwiftData
import Foundation

// ============================================================
// MARK: - FinanceType
// ============================================================

enum FinanceType: Codable, Equatable {
    case oneTime
    case weekly
    case monthly
    case quarterly
    case custom(days: Int)

    private enum CodingKeys: String, CodingKey {
        case type, days
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .oneTime:              try container.encode("oneTime",    forKey: .type)
        case .weekly:               try container.encode("weekly",     forKey: .type)
        case .monthly:              try container.encode("monthly",    forKey: .type)
        case .quarterly:            try container.encode("quarterly",  forKey: .type)
        case .custom(let days):
            try container.encode("custom", forKey: .type)
            try container.encode(days,     forKey: .days)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "weekly":    self = .weekly
        case "monthly":   self = .monthly
        case "quarterly": self = .quarterly
        case "custom":
            let days = try container.decode(Int.self, forKey: .days)
            self = .custom(days: days)
        default:          self = .oneTime
        }
    }

    var displayName: String {
        switch self {
        case .oneTime:            return "One-Time"
        case .weekly:             return "Weekly"
        case .monthly:            return "Monthly"
        case .quarterly:          return "Quarterly"
        case .custom(let d):      return "Every \(d) days"
        }
    }
}

// ============================================================
// MARK: - FinanceSchedule
// ============================================================

struct FinanceSchedule: Codable, Equatable {
    var type: FinanceType
    var paymentAmount: Double
    var totalPayments: Int?   // nil = indefinite (stop generating at today)

    static var oneTime: FinanceSchedule {
        FinanceSchedule(type: .oneTime, paymentAmount: 0, totalPayments: 1)
    }
}

// ============================================================
// MARK: - AssetCategory
// ============================================================

@Model
class AssetCategory {
    var name: String
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \AssetItem.category)
    var assets: [AssetItem] = []

    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
}

// ============================================================
// MARK: - AssetItem
// ============================================================

@Model
class AssetItem {
    var name: String
    var purchasePrice: Double
    var purchaseDate: Date
    var taxPaidAmount: Double       // stored as absolute dollar amount
    var imageData: Data?            // JPEG-compressed 512×512, nil = use symbol
    var symbolName: String?         // SF Symbol name; used when imageData == nil
    var sortOrder: Int

    var category: AssetCategory?

    var projectCode: String?
    var projectSubCode: String?

    // FinanceSchedule encoded as JSON to avoid a separate SwiftData table
    var financeScheduleJSON: String

    // All auto-generated Transaction entries share this as their groupID
    var assetGroupID: String

    init(
        name: String,
        purchasePrice: Double,
        purchaseDate: Date = .now,
        taxPaidAmount: Double = 0,
        imageData: Data? = nil,
        symbolName: String? = "shippingbox.fill",
        sortOrder: Int = 0,
        projectCode: String? = nil,
        projectSubCode: String? = nil,
        financeSchedule: FinanceSchedule = .oneTime,
        assetGroupID: String = UUID().uuidString
    ) {
        self.name = name
        self.purchasePrice = purchasePrice
        self.purchaseDate = purchaseDate
        self.taxPaidAmount = taxPaidAmount
        self.imageData = imageData
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.projectCode = projectCode
        self.projectSubCode = projectSubCode
        self.assetGroupID = assetGroupID
        self.financeScheduleJSON = Self.encode(financeSchedule)
    }

    // Computed accessor — decodes/encodes the JSON on demand
    var financeSchedule: FinanceSchedule {
        get {
            guard let data = financeScheduleJSON.data(using: .utf8),
                  let s = try? JSONDecoder().decode(FinanceSchedule.self, from: data)
            else { return .oneTime }
            return s
        }
        set {
            financeScheduleJSON = Self.encode(newValue)
        }
    }

    var effectiveSymbol: String {
        symbolName ?? "shippingbox.fill"
    }

    private static func encode(_ schedule: FinanceSchedule) -> String {
        (try? String(data: JSONEncoder().encode(schedule), encoding: .utf8)) ?? "{}"
    }
}
