import SwiftUI
import SwiftData

// ============================================================
// MARK: - ExportView
// ============================================================
// Full-screen sheet that lets the user choose a date range and
// a subset of categories, then exports matching transactions to
// a CSV file via the system share sheet.

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Transaction.date, order: .reverse) var transactions: [Transaction]
    @Query(sort: \CategoryModel.sortOrder) var categories: [CategoryModel]

    // Date range (defaults to last 30 days)
    @State private var exportStart: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var exportEnd: Date = Date()
    @State private var isAllTime: Bool = false

    // Category filter — empty set means "all categories"
    @State private var selectedCategoryNames: Set<String> = []

    // Share sheet
    @State private var csvURL: URL? = nil
    @State private var showShareSheet = false

    // --------------------------------------------------------
    // MARK: Filtering
    // --------------------------------------------------------

    var exportableTransactions: [Transaction] {
        let cal = Calendar.current
        let start: Date = isAllTime ? Date.distantPast : cal.startOfDay(for: exportStart)
        let end: Date   = isAllTime ? Date.distantFuture : cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: exportEnd)) ?? exportEnd

        return transactions
            .filter { $0.date >= start && $0.date < end }
            .filter { selectedCategoryNames.isEmpty || selectedCategoryNames.contains($0.categoryName) }
            .filter { !$0.isGasolineSplit }   // exclude synthetic daily split rows
    }

    var allCategoriesSelected: Bool { selectedCategoryNames.isEmpty }

    // --------------------------------------------------------
    // MARK: Body
    // --------------------------------------------------------

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Text("Export Transactions")
                        .font(.headline)
                    Spacer()
                    // Balance the X button
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .medium))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {

                        // ---- Date Range section ----
                        sectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Date Range")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 2)

                                // All Time toggle
                                HStack {
                                    Text("All Time")
                                        .font(.body)
                                    Spacer()
                                    Toggle("", isOn: $isAllTime)
                                        .labelsHidden()
                                }

                                if !isAllTime {
                                    Divider()

                                    VStack(spacing: 8) {
                                        DatePicker("From", selection: $exportStart, in: ...exportEnd, displayedComponents: .date)
                                        Divider()
                                        DatePicker("To", selection: $exportEnd, in: exportStart..., displayedComponents: .date)
                                    }
                                }
                            }
                        }

                        // ---- Category section ----
                        sectionCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Categories")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 2)

                                // All Categories toggle
                                HStack {
                                    Text("All Categories")
                                        .font(.body)
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { allCategoriesSelected },
                                        set: { if $0 { selectedCategoryNames.removeAll() } }
                                    ))
                                    .labelsHidden()
                                }

                                if !allCategoriesSelected || !categories.isEmpty {
                                    Divider()

                                    VStack(spacing: 0) {
                                        ForEach(categories) { cat in
                                            categoryRow(cat)
                                            if cat.id != categories.last?.id {
                                                Divider().padding(.leading, 36)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- Summary ----
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text("\(exportableTransactions.count) transaction\(exportableTransactions.count == 1 ? "" : "s") will be exported")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)

                    }
                    .padding(.vertical, 8)
                }

                // ---- Export button ----
                Divider()
                Button {
                    let url = generateCSV()
                    csvURL = url
                    showShareSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.doc.fill")
                        Text("Export CSV")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(exportableTransactions.isEmpty ? Color.gray.opacity(0.4) : Color.primary)
                    .cornerRadius(14)
                }
                .buttonStyle(.plain)
                .disabled(exportableTransactions.isEmpty)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = csvURL {
                ShareSheet(url: url)
            }
        }
    }

    // --------------------------------------------------------
    // MARK: Sub-views
    // --------------------------------------------------------

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func categoryRow(_ cat: CategoryModel) -> some View {
        let isSelected = selectedCategoryNames.contains(cat.name)
        Button {
            if isSelected {
                selectedCategoryNames.remove(cat.name)
            } else {
                selectedCategoryNames.insert(cat.name)
            }
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(cat.categoryColor.color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: cat.symbol)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                    )
                Text(cat.name)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    // --------------------------------------------------------
    // MARK: CSV Generation
    // --------------------------------------------------------

    private func generateCSV() -> URL {
        let txns = exportableTransactions

        // Collect all distinct tax rate names across all transactions, preserving first-seen order
        var taxNamesOrdered: [String] = []
        var taxNamesSet: Set<String> = []
        for tx in txns {
            for rate in tx.taxRates {
                if taxNamesSet.insert(rate.name).inserted {
                    taxNamesOrdered.append(rate.name)
                }
            }
        }

        // Build header
        var headerParts = [
            "Date", "Time", "Title", "Type", "Category",
            "Project Code", "Sub-code", "Currency",
            "Base Amount"
        ]
        for name in taxNamesOrdered { headerParts.append("\(name) Amount") }
        headerParts += [
            "Tax Total", "Tip Rate (%)", "Tip Amount", "Total Amount",
            "Reusable", "Duration (days)", "Daily Amount",
            "Gasoline", "Liters", "Price/L (¢)", "Gas Tax/L (¢)", "Gas Tax Total"
        ]
        var rows: [String] = [headerParts.map(csvEscape).joined(separator: ",")]

        // Build one row per transaction
        let dateFmt = CachedDateFormatters.csvDate
        let timeFmt = CachedDateFormatters.csvTime

        for tx in txns {
            var parts: [String] = [
                dateFmt.string(from: tx.date),
                timeFmt.string(from: tx.date),
                tx.title,
                tx.isIncome ? "Income" : "Expense",
                tx.categoryName,
                tx.projectCode ?? "",
                tx.projectSubCode ?? "",
                tx.currency,
                String(format: "%.2f", tx.baseAmount)
            ]

            // Per-tax-name amounts (blank if this tx doesn't have that tax)
            for name in taxNamesOrdered {
                if let rate = tx.taxRates.first(where: { $0.name == name }) {
                    parts.append(String(format: "%.2f", rate.amount))
                } else {
                    parts.append("")
                }
            }

            let tipRatePct = tx.tippable ? tx.selectedTipRate * 100 : 0.0
            parts += [
                String(format: "%.2f", tx.totalTaxAmount),
                tx.tippable ? String(format: "%.2f", tipRatePct) : "",
                tx.tippable ? String(format: "%.2f", tx.tipAmount) : "",
                String(format: "%.2f", tx.amount),
                tx.reusable ? "Yes" : "No",
                tx.reusable ? "\(tx.reusableDurationDays)" : "",
                tx.reusable ? String(format: "%.2f", tx.dailyAmount) : "",
                tx.gasoline ? "Yes" : "No",
                tx.gasoline ? String(format: "%.3f", tx.liters) : "",
                tx.gasoline ? String(format: "%.2f", tx.pricePerLiter) : "",
                tx.gasoline ? String(format: "%.2f", tx.taxPerLiter) : "",
                tx.gasoline ? String(format: "%.2f", tx.gasolineTaxAmount) : ""
            ]

            rows.append(parts.map(csvEscape).joined(separator: ","))
        }

        let csv = rows.joined(separator: "\n")
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("transactions_export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Wraps a field in double-quotes if it contains commas, quotes, or newlines.
    private func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

// ============================================================
// MARK: - ShareSheet (UIActivityViewController wrapper)
// ============================================================

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// ============================================================
// MARK: - Preview
// ============================================================
#Preview {
    ExportView()
        .modelContainer(for: [Transaction.self, CategoryModel.self], inMemory: true)
}
