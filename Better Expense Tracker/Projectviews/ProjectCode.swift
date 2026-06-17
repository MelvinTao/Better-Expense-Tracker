import SwiftData
import Foundation

// A top-level project code (e.g. "PHOTO", "3D-PRINT")
@Model
class ProjectCode {
    var name: String
    var sortOrder: Int
    var subCodes: [String]   // ordered list of sub-code names

    init(name: String, sortOrder: Int = 0, subCodes: [String] = []) {
        self.name = name
        self.sortOrder = sortOrder
        self.subCodes = subCodes
    }
}
