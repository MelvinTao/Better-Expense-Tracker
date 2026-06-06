// This is the very first file that runs when your app launches.
// Every SwiftUI app has exactly one file marked with @main — this is it.
// Its job is to open the first window and set up the database.

import SwiftUI
import SwiftData

@main // ← tells Swift "start the app here"
struct BetterExpenseTrackerApp: App {
    
    var body: some Scene {
        WindowGroup {
            // ContentView is the first screen the user sees (your tab bar)
            ContentView()
            // Add this inside BetterExpenseTrackerApp, inside the WindowGroup
            // It prints the exact path to your database file in the Xcode console
            .onAppear {
                let path = FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                    .first!
                    .path
                print("Database location: \(path)")
            }
        }
        // .modelContainer sets up the database for the entire app.
        // It tells SwiftData: "I want to store Transaction objects"
        // It also automatically passes the database to EVERY view in the app —
        // you don't need to manually connect each view to it.
        .modelContainer(for: Transaction.self)
    }
}
