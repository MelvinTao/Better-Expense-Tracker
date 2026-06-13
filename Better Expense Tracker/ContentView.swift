//
//  ContentView.swift
//  Better Expense Tracker
//
//  Created by Melvin Tao on 2026-05-27.
//

import SwiftUI
import SwiftData

//struct ContentView: View {
//    var body: some View {
//        TabView{
//            HomeView()
//                .tabItem{
//                    Label("Home",
//                          systemImage: "dollarsign.bank.building.fill")
//                }
//            
//            TransactionsView()
//                .tabItem{
//                    Label("Transactions",
//                          systemImage: "calendar")
//                }
//            
//            AnalysisView()
//                .tabItem{
//                    Label("Analysis",
//                    systemImage: "chart.line.text.clipboard.fill")
//                }
//            
//            SettingView()
//                .tabItem{
//                    Label("Setting",
//                          systemImage: "gearshape.fill")
//                }
//                .labelStyle(.titleAndIcon)
//            
//                
//        }
//    }
//}

// ContentView is the main view of your app — it holds everything together.
// Think of it as the "root" or "container" of your screen.
struct ContentView: View {
    
    // @State means SwiftUI will watch this variable for changes.
    // When it changes, the view automatically redraws itself.
    // This tracks WHICH tab is currently selected (0 = Home, 1 = Transactions, etc.)
    @State private var selectedTab = 0
    
    // This is just a number we define once and reuse.
    // CGFloat is the number type used for sizes/positions in SwiftUI (like a decimal number).
    // Change 80 to whatever pixel height you want your tab bar to be.
    let tabBarHeight: CGFloat = 80

    // 'body' is required in every SwiftUI View.
    // It describes what the view looks like on screen.
    var body: some View {
        
        // ZStack layers views ON TOP of each other (like stacking papers).
        // We use this so the custom tab bar floats on top of the page content.
        // 'alignment: .bottom' means children are anchored to the bottom by default.
        ZStack(alignment: .bottom) {
            
            // --- PAGE CONTENT AREA ---
            
            // 'Group' is just a wrapper that lets us apply modifiers to several views at once.
            // Here we use it to show a different view depending on which tab is selected.
            Group {
                
                // 'switch' checks the value of selectedTab and shows the matching view.
                // It's like asking: "which tab number is active right now?"
                switch selectedTab {
                case 0: HomeView()          // If selectedTab == 0, show HomeView
                case 1: TransactionsView()  // If selectedTab == 1, show TransactionsView
                case 2: ProjectView()
                case 3: AnalysisView()      // If selectedTab == 3, show AnalysisView
                case 4: SettingView()       // If selectedTab == 4, show SettingView
                
                default: HomeView()         // Fallback — Swift requires a 'default' case
                }
            }
            // Makes the content fill the entire screen width and height.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Adds empty space at the bottom equal to the tab bar height.
            // This prevents your page content from being hidden BEHIND the tab bar.
            .padding(.bottom, tabBarHeight)
            
            
            // --- CUSTOM TAB BAR ---
            
            // HStack arranges views horizontally, side by side (like a row).
            // Since we put 4 buttons inside it, they'll appear in a row at the bottom.
            HStack {
                
                // Each TabBarButton is one tab item.
                // We pass in:
                //   icon  — the SF Symbol name (Apple's built-in icon library)
                //   label — the text shown below the icon
                //   tag   — a unique number identifying this tab (must match the switch above)
                //   selected — a binding to selectedTab so the button can update it
                TabBarButton(icon: "dollarsign.bank.building.fill", label: "Home",         tag: 0, selected: $selectedTab)
                TabBarButton(icon: "calendar",                       label: "Transactions", tag: 1, selected: $selectedTab)
                TabBarButton(icon: "folder.fill",
                             label: "Projects",
                             tag: 2, selected: $selectedTab)
                TabBarButton(icon: "chart.line.text.clipboard.fill", label: "Analysis",    tag: 3, selected: $selectedTab)
                TabBarButton(icon: "gearshape.fill",                 label: "Setting",     tag: 4, selected: $selectedTab)
            }
            // Sets the tab bar to exactly your defined height.
            .frame(height: tabBarHeight)
            
            // Makes the HStack stretch to fill the full screen width.
            // Without this, the HStack would only be as wide as its contents.
            .frame(maxWidth: .infinity)
            
            // Adds a frosted-glass background to the tab bar (built into SwiftUI).
            // You could replace this with .background(Color.white) or any other color.
            .background(.ultraThinMaterial)
            .shadow(color: Color.secondary.opacity(0.3), radius: 8, y: -2)
            
        }
        
        // By default, SwiftUI adds padding around the home indicator at the bottom.
        // This tells SwiftUI to let our ZStack draw all the way to the very bottom edge.
        // Our tab bar will visually extend behind the home indicator — this looks great!
        .ignoresSafeArea(edges: .bottom)
    }
}


// --- TAB BAR BUTTON ---

// This is a reusable component for a single tab button.
// Instead of writing the same button code 4 times, we write it once here
// and reuse it for each tab.
struct TabBarButton: View {
    
    // 'let' means these values are set once when the button is created and don't change.
    let icon: String     // The SF Symbol icon name (e.g. "calendar")
    let label: String    // The text shown below the icon (e.g. "Transactions")
    let tag: Int         // This button's unique ID number (0, 1, 2, or 3)
    
    // @Binding means this view does NOT own this variable — it SHARES it with the parent.
    // The '$' prefix (used when passing it in) means "pass a reference, not just the value".
    // So when the user taps this button, it can update 'selectedTab' in ContentView.
    @Binding var selected: Int

    var body: some View {
        
        // Button runs the code in the first { } block when tapped,
        // and shows the view in the 'label' { } block as the tappable content.
        Button {
            // When tapped, set selectedTab to this button's tag number.
            // Because 'selected' is a @Binding, this actually updates
            // the @State variable in ContentView, which redraws the whole screen.
            selected = tag
            
        } label: {
            
            // VStack arranges views vertically, top to bottom (like a column).
            // Here we stack the icon on top and the text label below.
            VStack(spacing: 4) { // spacing: 4 adds 4 pixels of gap between icon and text
                
                // Shows the SF Symbol icon.
                // .font(.system(size: 20)) sets the icon size to 20pt.
                Image(systemName: icon)
                    .font(.system(size: 20))
                
                // Shows the tab label text below the icon.
                // .caption2 is a small preset text style — good for tab bar labels.
                Text(label)
                    .font(.caption2)
            }
            
            // Changes the color based on whether this tab is selected.
            // 'selected == tag' is true only for the currently active tab.
            // Ternary syntax: condition ? valueIfTrue : valueIfFalse
            .foregroundStyle(selected == tag ? .blue : .gray)
            
            // Makes each button take up an equal share of the HStack's width.
            // This is what makes the 4 buttons evenly spaced!
            // Without this, buttons would be squished together in the center.
            .frame(maxWidth: .infinity)
        }
    }
}

struct ContentView_Preview: PreviewProvider {
    static var previews: some View {
        ContentView().modelContainer(Self.previewContainer)
    }

    // Build an in-memory container with seed categories + 15 sample transactions.
    @MainActor
    static var previewContainer: ModelContainer {
        let container = try! ModelContainer(
            for: Transaction.self, CategoryModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let ctx = container.mainContext

        // ── Categories ───────────────────────────────────────────
        let spending: [(String, String, String)] = [
            ("Grocery",   "basket.fill",            "yellow"),
            ("Transport", "car.fill",               "blue"),
            ("Health",    "heart.fill",             "red"),
            ("Shopping",  "bag.fill",               "purple"),
            ("Eat out",   "fork.knife",             "orange"),
            ("Travel",    "airplane",               "teal"),
            ("Coffee",    "cup.and.saucer.fill",    "amber"),
        ]
        for (i, (name, symbol, color)) in spending.enumerated() {
            ctx.insert(CategoryModel(name: name, symbol: symbol, colorName: color, isOutcome: true, sortOrder: i))
        }
        // Gasoline category — 27 ¢/L tax
        ctx.insert(CategoryModel(
            name: "Gasoline", symbol: "fuelpump.fill", colorName: "red",
            isOutcome: true, sortOrder: spending.count,
            isGasoline: true, gasolineTaxPerLiter: 27.0
        ))
        let income: [(String, String, String)] = [
            ("Salary",    "dollarsign.circle.fill", "green"),
            ("Freelance", "laptopcomputer",         "sky"),
        ]
        for (i, (name, symbol, color)) in income.enumerated() {
            ctx.insert(CategoryModel(name: name, symbol: symbol, colorName: color, isOutcome: false, sortOrder: i))
        }

        // ── Transactions ─────────────────────────────────────────
        // Today
        ctx.insert(Transaction(
            title: "Weekly groceries",
            amount: 68.43, date: ago(0, hour: 9, minute: 15),
            categoryName: "Grocery", categorySymbol: "basket.fill",
            projectCodes: ["PROJ-A"], isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0), TaxRate(name: "PST", rate: 0.07, amount: 0)]
        ))
        ctx.insert(Transaction(
            title: "Latte",
            amount: 6.75, date: ago(0, hour: 8, minute: 5),
            categoryName: "Coffee", categorySymbol: "cup.and.saucer.fill",
            isIncome: false
        ))

        // 1 day ago
        ctx.insert(Transaction(
            title: "Dinner with team",
            amount: 94.20, date: ago(1, hour: 19, minute: 30),
            categoryName: "Eat out", categorySymbol: "fork.knife",
            projectCodes: ["PROJ-B", "Q2-Review"],
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0)],
            tippable: true, selectedTipRate: 0.18
        ))
        ctx.insert(Transaction(
            title: "Uber",
            amount: 18.50, date: ago(1, hour: 20, minute: 10),
            categoryName: "Transport", categorySymbol: "car.fill",
            isIncome: false
        ))

        // 2 days ago
        ctx.insert(Transaction(
            title: "Salary",
            amount: 2_340.00, date: ago(2, hour: 10, minute: 0),
            categoryName: "Salary", categorySymbol: "dollarsign.circle.fill",
            isIncome: true,
            taxable: true,
            taxRates: [TaxRate(name: "CPP", rate: 0.0595, amount: 0), TaxRate(name: "EI", rate: 0.0166, amount: 0)]
        ))
        ctx.insert(Transaction(
            title: "Pharmacy",
            amount: 34.99, date: ago(2, hour: 14, minute: 45),
            categoryName: "Health", categorySymbol: "heart.fill",
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0)]
        ))
        // ── Gasoline fill-ups ────────────────────────────────────
        // Fill 1: 14 days ago — first fill ever, no previous date → single transaction
        // $70.00 at 189.99 ¢/L, 27 ¢/L tax
        // liters = 70.00 / (189.99/100) ≈ 36.84 L
        // gasTax = 36.84 × (27/100) ≈ $9.95
        let fill1Date = ago(14, hour: 11, minute: 0)
        let fill1Amount = 70.00
        let fill1Price  = 189.99   // ¢/L
        let fill1TaxPL  = 27.0     // ¢/L
        let fill1Liters = fill1Amount / (fill1Price / 100.0)
        let fill1TaxTotal = fill1Liters * (fill1TaxPL / 100.0)
        let fill1DailyCost = fill1Amount   // no split — first fill
        let fill1DailyTax  = fill1TaxTotal
        let gid1 = UUID().uuidString
        do {
            let t = Transaction(
                title: String(format: "%.1f L @ %.2f ¢/L", fill1Liters, fill1Price),
                amount: fill1DailyCost,
                date: fill1Date,
                categoryName: "Gasoline", categorySymbol: "fuelpump.fill",
                isIncome: false,
                gasoline: true,
                pricePerLiter: fill1Price,
                taxPerLiter: fill1TaxPL,
                groupID: gid1,
                isGasolineSplit: false
            )
            t.liters = fill1Liters
            t.gasolineTaxAmount = fill1DailyTax
            t.dailyGasolineCost = fill1DailyCost
            ctx.insert(t)
        }

        // Fill 2: 7 days ago — 7 days after fill 1 → split into 7 daily entries
        // $84.00 at 179.99 ¢/L, 27 ¢/L tax
        // liters = 84.00 / (179.99/100) ≈ 46.67 L
        // gasTax = 46.67 × (27/100) ≈ $12.60
        // dailyCost = 84.00 / 7 = $12.00/day
        let fill2Date = ago(7, hour: 11, minute: 0)
        let fill2Amount = 84.00
        let fill2Price  = 179.99
        let fill2TaxPL  = 27.0
        let fill2Liters = fill2Amount / (fill2Price / 100.0)
        let fill2TaxTotal = fill2Liters * (fill2TaxPL / 100.0)
        let fill2Days = 7
        let fill2DailyCost = fill2Amount / Double(fill2Days)
        let fill2DailyTax  = fill2TaxTotal / Double(fill2Days)
        let gid2 = UUID().uuidString
        let cal2 = Calendar.current
        let fmt2 = DateFormatter(); fmt2.dateFormat = "MMM d"
        for i in 0..<fill2Days {
            let dayOffset = i - (fill2Days - 1)   // -6 … 0
            let txDate = cal2.date(byAdding: .day, value: dayOffset,
                                   to: cal2.startOfDay(for: fill2Date)) ?? fill2Date
            let isMother = (i == fill2Days - 1)
            let txTitle: String
            if isMother {
                txTitle = String(format: "%.1f L @ %.2f ¢/L", fill2Liters, fill2Price)
            } else {
                txTitle = "Fill \(fmt2.string(from: fill2Date))"
            }
            let t = Transaction(
                title: txTitle,
                amount: fill2DailyCost,
                date: txDate,
                categoryName: "Gasoline", categorySymbol: "fuelpump.fill",
                isIncome: false,
                gasoline: true,
                pricePerLiter: isMother ? fill2Price : 0.0,
                taxPerLiter: fill2TaxPL,
                previousFillupDate: fill1Date,
                groupID: gid2,
                isGasolineSplit: !isMother
            )
            t.liters = isMother ? fill2Liters : 0.0
            t.gasolineTaxAmount = fill2DailyTax
            t.dailyGasolineCost = fill2DailyCost
            ctx.insert(t)
        }

        // 3 days ago
        ctx.insert(Transaction(
            title: "Freelance invoice #12",
            amount: 850.00, date: ago(3, hour: 11, minute: 0),
            categoryName: "Freelance", categorySymbol: "laptopcomputer",
            projectCodes: ["CLI-2026-03"],
            isIncome: true
        ))
        ctx.insert(Transaction(
            title: "New shoes",
            amount: 129.95, date: ago(3, hour: 15, minute: 20),
            categoryName: "Shopping", categorySymbol: "bag.fill",
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0), TaxRate(name: "PST", rate: 0.07, amount: 0)]
        ))

        // 5 days ago
        ctx.insert(Transaction(
            title: "Grocery",
            amount: 52.10, date: ago(5, hour: 17, minute: 0),
            categoryName: "Grocery", categorySymbol: "basket.fill",
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0)]
        ))
        ctx.insert(Transaction(
            title: "Brunch",
            amount: 28.50, date: ago(5, hour: 10, minute: 30),
            categoryName: "Eat out", categorySymbol: "fork.knife",
            isIncome: false,
            tippable: true, selectedTipRate: 0.15
        ))

        // 7 days ago
        ctx.insert(Transaction(
            title: "Flight YVR-YYZ",
            amount: 310.00, date: ago(7, hour: 6, minute: 45),
            categoryName: "Travel", categorySymbol: "airplane",
            projectCodes: ["CONF-2026"],
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0)]
        ))
        ctx.insert(Transaction(
            title: "Gym membership",
            amount: 45.00, date: ago(7, hour: 9, minute: 0),
            categoryName: "Health", categorySymbol: "heart.fill",
            isIncome: false
        ))

        // 10 days ago
        ctx.insert(Transaction(
            title: "Freelance invoice #11",
            amount: 620.00, date: ago(10, hour: 14, minute: 0),
            categoryName: "Freelance", categorySymbol: "laptopcomputer",
            projectCodes: ["CLI-2026-02"],
            isIncome: true
        ))
        ctx.insert(Transaction(
            title: "Monthly transit pass",
            amount: 98.00, date: ago(10, hour: 8, minute: 0),
            categoryName: "Transport", categorySymbol: "car.fill",
            isIncome: false
        ))

        // 14 days ago
        ctx.insert(Transaction(
            title: "Weekend getaway hotel",
            amount: 245.60, date: ago(14, hour: 15, minute: 0),
            categoryName: "Travel", categorySymbol: "airplane",
            projectCodes: ["PROJ-A", "Q2-Review"],
            isIncome: false,
            taxable: true,
            taxRates: [TaxRate(name: "GST", rate: 0.05, amount: 0), TaxRate(name: "PST", rate: 0.07, amount: 0)],
            tippable: true, selectedTipRate: 0.12
        ))

        return container
    }

    // Helper used only in the preview container setup
    static func ago(_ n: Int, hour: Int = 12, minute: Int = 0) -> Date {
        Calendar.current.date(byAdding: .day, value: -n,
            to: Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!)!
    }
}
