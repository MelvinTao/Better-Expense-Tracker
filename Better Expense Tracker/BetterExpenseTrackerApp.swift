import SwiftUI
import SwiftData
import UIKit

@main
struct BetterExpenseTrackerApp: App {
    init() {
        UITableView.appearance().separatorStyle = .none
        UITableView.appearance().layer.shadowOpacity = 0
        UITableViewCell.appearance().layer.shadowOpacity = 0
        UITableViewCell.appearance().layer.masksToBounds = true
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Both Transaction and CategoryModel need their own database tables
        .modelContainer(for: [Transaction.self, CategoryModel.self])
    }
}
