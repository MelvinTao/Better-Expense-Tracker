import SwiftUI
import SwiftData

@main
struct BetterExpenseTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Both Transaction and CategoryModel need their own database tables
        .modelContainer(for: [Transaction.self, CategoryModel.self])
    }
}
