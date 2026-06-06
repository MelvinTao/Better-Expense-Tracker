//
//  ContentView.swift
//  Better Expense Tracker
//
//  Created by Melvin Tao on 2026-05-27.
//

import SwiftUI

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
                case 2: AnalysisView()      // If selectedTab == 2, show AnalysisView
                case 3: SettingView()       // If selectedTab == 3, show SettingView
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
                TabBarButton(icon: "chart.line.text.clipboard.fill", label: "Analysis",    tag: 2, selected: $selectedTab)
                TabBarButton(icon: "gearshape.fill",                 label: "Setting",     tag: 3, selected: $selectedTab)
            }
            // Sets the tab bar to exactly your defined height.
            .frame(height: tabBarHeight)
            
            // Makes the HStack stretch to fill the full screen width.
            // Without this, the HStack would only be as wide as its contents.
            .frame(maxWidth: .infinity)
            
            // Adds a frosted-glass background to the tab bar (built into SwiftUI).
            // You could replace this with .background(Color.white) or any other color.
            .background(.ultraThinMaterial)
            
        }
        .shadow(color: Color.secondary, radius: 20, y: 15)
        
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

struct ContentView_Preview:
    PreviewProvider {
        static var previews: some View {
            ContentView()
        }
    }
