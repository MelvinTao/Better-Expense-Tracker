// ============================================================
// MARK: - PeriodNavigatorBar  (shared by HomeView & TransactionsView)
// ============================================================
import SwiftUI

// ============================================================
// MARK: - AppDateRange  (shared enum used by all three views)
// ============================================================

enum AppDateRange: String, CaseIterable {
    case week   = "Week"
    case month  = "Month"
    case year   = "Year"
    case custom = "Custom"
}

// ============================================================
// MARK: - SharedDateRangeTabs
// ============================================================

struct SharedDateRangeTabs: View {
    @Binding var selected: AppDateRange
    let onRangeChange: () -> Void
    /// Called when the user taps Custom — caller should present its date picker.
    var onCustomTap: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppDateRange.allCases, id: \.self) { range in
                let isSelected = selected == range
                Button {
                    if range == .custom {
                        onCustomTap?()
                    } else {
                        selected = range
                        onRangeChange()
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundColor(isSelected ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                        .background(
                            isSelected
                                ? RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.2))
                                : RoundedRectangle(cornerRadius: 7).fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

// ============================================================
// MARK: - CustomDateRangeSheet
// ============================================================

struct CustomDateRangeSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: .date)
                Section {
                    Button("All Time") {
                        startDate = Date.distantPast
                        endDate   = Date()
                        isPresented = false
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Custom Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

struct PeriodNavigatorBar<Label: View>: View {
    let onPrevious: () -> Void
    let onNext: () -> Void
    var nextDisabled: Bool = false
    var nextDimmed: Bool = false
    var hideChevrons: Bool = false
    @ViewBuilder var label: Label

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .opacity(hideChevrons ? 0 : 1)
            .allowsHitTesting(!hideChevrons)

            Spacer()
            label
            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(nextDimmed ? Color.primary.opacity(0.3) : .primary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .disabled(nextDisabled)
            .opacity(hideChevrons ? 0 : 1)
            .allowsHitTesting(!hideChevrons)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}


// ============================================================
// MARK: - WeekPickerSheet
// A calendar grid where each row is a tappable week.
// Selecting a row returns the Monday of that week via `selectedWeekStart`.
// ============================================================

struct WeekPickerSheet: View {
    /// The Monday of the currently active week (read/write).
    @Binding var selectedWeekStart: Date
    @Binding var isPresented: Bool

    private let cal = Calendar.current

    // The first day of the displayed month
    @State private var displayedMonth: Date = Calendar.current.startOfMonth(for: Date())

    private var displayedYear:  Int { cal.component(.year,  from: displayedMonth) }
    private var displayedMonthIdx: Int { cal.component(.month, from: displayedMonth) }

    private let dayHeaders = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    // Returns all weeks (rows) that overlap the displayed month.
    // Each row is an array of 7 Date? (nil = day outside the calendar grid).
    private var weeks: [[Date?]] {
        // First Monday on or before the first of the month
        let firstOfMonth = displayedMonth
        let weekdayOfFirst = cal.component(.weekday, from: firstOfMonth) // 1=Sun…7=Sat
        // Convert to Mon=0 … Sun=6
        let mondayOffset = (weekdayOfFirst + 5) % 7
        guard let gridStart = cal.date(byAdding: .day, value: -mondayOffset, to: firstOfMonth) else { return [] }

        // Build rows until we've passed the end of the month
        guard let endOfMonth = cal.date(byAdding: .month, value: 1, to: firstOfMonth) else { return [] }

        var result: [[Date?]] = []
        var cursor = gridStart
        while cursor < endOfMonth {
            var row: [Date?] = []
            for d in 0..<7 {
                let day = cal.date(byAdding: .day, value: d, to: cursor)!
                // Show days from adjacent months as dimmed (include them for layout)
                row.append(day)
            }
            result.append(row)
            cursor = cal.date(byAdding: .weekOfYear, value: 1, to: cursor)!
        }
        return result
    }

    // Monday of `selectedWeekStart` (normalised)
    private var activeMonday: Date {
        let weekday = cal.component(.weekday, from: selectedWeekStart)
        let offset = (weekday + 5) % 7
        return cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: selectedWeekStart)!)
    }

    private func isSelectedWeek(_ monday: Date?) -> Bool {
        guard let monday else { return false }
        return cal.isDate(monday, inSameDayAs: activeMonday)
    }

    private func monthLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with Cancel button
            HStack {
                Text("Select Week")
                    .font(.headline)
                Spacer()
                Button("Cancel") { isPresented = false }
                    .font(.body)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            // Month / year navigator
            HStack {
                Button {
                    displayedMonth = cal.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()
                Text(monthLabel(displayedMonth))
                    .font(.title3.bold())
                Spacer()

                Button {
                    displayedMonth = cal.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Day-of-week headers
            HStack(spacing: 0) {
                ForEach(dayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            // Week rows
            VStack(spacing: 6) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { _, row in
                    let monday = row.first!! // always non-nil first cell
                    let selected = isSelectedWeek(monday)

                    Button {
                        selectedWeekStart = monday
                        isPresented = false
                    } label: {
                        HStack(spacing: 0) {
                            ForEach(0..<7, id: \.self) { i in
                                let day = row[i]
                                let inMonth = day.map { cal.component(.month, from: $0) == displayedMonthIdx } ?? false
                                Text(day.map { "\(cal.component(.day, from: $0))" } ?? "")
                                    .font(.system(size: 15, weight: selected ? .semibold : .regular))
                                    .foregroundColor(
                                        selected ? (inMonth ? .white : Color.white.opacity(0.55))
                                                 : (inMonth ? Color(UIColor.label) : Color(UIColor.tertiaryLabel))
                                    )
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selected ? Color.accentColor : Color.secondary.opacity(0.08))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)

            Spacer()
        }
        .onAppear {
            displayedMonth = cal.startOfMonth(for: activeMonday)
        }
    }
}

// ============================================================
// MARK: - MonthPickerSheet
// ============================================================

struct MonthPickerSheet: View {
    @Binding var selectedMonth: Date
    @Binding var isPresented: Bool
    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: selectedMonth)
    }
    private let years: [Int] = {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 5)...(current + 2))
    }()

    private let monthSymbols: [String] = {
        let fmt = DateFormatter()
        return fmt.shortMonthSymbols ?? DateFormatter().shortMonthSymbols!
    }()

    @State private var displayedYear: Int = Calendar.current.component(.year, from: Date())

    private var selectedYear: Int    { Calendar.current.component(.year,  from: selectedMonth) }
    private var selectedMonthIdx: Int { Calendar.current.component(.month, from: selectedMonth) - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack {
                    Button {
                        if displayedYear > years.first! { displayedYear -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(displayedYear > years.first! ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                    Text(String(displayedYear)).font(.title3.bold())
                    Spacer()

                    Button {
                        if displayedYear < years.last! { displayedYear += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(displayedYear < years.last! ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(0..<12, id: \.self) { idx in
                        let isSelected = idx == selectedMonthIdx && displayedYear == selectedYear
                        Button {
                            var comps = DateComponents()
                            comps.year  = displayedYear
                            comps.month = idx + 1
                            comps.day   = 1
                            if let date = Calendar.current.date(from: comps) {
                                selectedMonth = date
                            }
                            isPresented = false
                        } label: {
                            Text(monthSymbols[idx])
                                .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                                )
                                .foregroundColor(isSelected ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Select Month")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
        .onAppear { displayedYear = selectedYear }
    }
}

// ============================================================
// MARK: - MonthPeriodNavigatorBar
// A self-contained month navigator with:
//   • Tap label  → opens MonthPickerSheet
//   • Long-press → jumps back to the current month
// ============================================================

struct MonthPeriodNavigatorBar: View {
    @Binding var selectedMonth: Date

    @State private var showPicker = false

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(selectedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: selectedMonth)
    }

    var body: some View {
        PeriodNavigatorBar(
            onPrevious: {
                selectedMonth = Calendar.current.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
            },
            onNext: {
                selectedMonth = Calendar.current.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
            },
            nextDisabled: false,
            nextDimmed:   false
        ) {
            // Tap: open month picker. Long-press: return to today.
            Text(monthLabel)
                .font(.headline)
                .foregroundColor(.primary)
                .onTapGesture {
                    showPicker = true
                }
                .onLongPressGesture(minimumDuration: 0.4) {
                    guard !isCurrentMonth else { return }
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedMonth = Calendar.current.startOfMonth(for: Date())
                    }
                }
        }
        .sheet(isPresented: $showPicker) {
            MonthPickerSheet(selectedMonth: $selectedMonth, isPresented: $showPicker)
                .presentationDetents([.medium])
        }
    }
}

