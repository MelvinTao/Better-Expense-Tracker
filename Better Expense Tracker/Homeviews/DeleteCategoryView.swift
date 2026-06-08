import SwiftUI
import SwiftData

// Shown when the user taps X on a category tile in edit mode.
// A countdown from 5 ticks automatically — if it hits 0, the sheet closes (nothing deleted).
// The countdown PAUSES while the keyboard is on screen.
// To actually delete: type "CONFIRM" in the text field and tap the checkmark.

struct DeleteCategoryView: View {

    let category: CategoryModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query private var allTransactions: [Transaction]

    @State private var confirmText = ""
    @State private var countdown = 5
    @State private var deleteTransactionsToo = true
    @FocusState private var keyboardIsShown: Bool   // true when the TextField is focused

    var isConfirmed: Bool { confirmText == "CONFIRM" }

    var categoryTransactions: [Transaction] {
        allTransactions.filter { $0.categoryName == category.name }
    }

    var body: some View {
        VStack(spacing: 0) {

            // Top row: X (cancel) and countdown number
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .medium)).foregroundColor(.primary)
                }
                Spacer()
                Text("\(countdown)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            Spacer()

            // Confirmation card
            VStack(spacing: 16) {
                VStack(spacing: 8) {
                    Text("Delete \"\(category.name)\"?")
                        .font(.headline).foregroundColor(.white)

                    Text("This category has \(categoryTransactions.count) transaction(s). Toggle below to choose whether to delete them too. Then type \"CONFIRM\" and tap the checkmark.")
                        .font(.footnote).foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)

                    // Toggle: also delete transactions, or keep them?
                    HStack {
                        Text(deleteTransactionsToo ? "Also delete transactions" : "Keep transactions")
                            .font(.caption).foregroundColor(.white)
                        Spacer()
                        Toggle("", isOn: $deleteTransactionsToo).labelsHidden().tint(.white)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 8)

                // CONFIRM text field — keyboard is NOT shown by default; user must tap the field
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 8).fill(Color.white).frame(height: 44)
                    if confirmText.isEmpty {
                        Text("Type CONFIRM here").foregroundColor(Color.secondary.opacity(0.5)).font(.callout)
                    }
                    TextField("", text: $confirmText)
                        .multilineTextAlignment(.center).font(.callout)
                        .autocorrectionDisabled()
                        .focused($keyboardIsShown)  // this binding pauses the countdown
                }

                // Checkmark — only active when confirmText == "CONFIRM"
                Button { confirmDelete() } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(isConfirmed ? Color.red : Color.white.opacity(0.3))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain).disabled(!isConfirmed)
            }
            .padding(20)
            .background(Color.red.opacity(0.85))
            .cornerRadius(20)
            .padding(.horizontal, 24)

            Spacer()
        }
        // Tick every second — pause while keyboard is shown
        .task {
            while countdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if !keyboardIsShown {
                    countdown -= 1
                }
            }
            dismiss()
        }
    }

    func confirmDelete() {
        guard isConfirmed else { return }
        if deleteTransactionsToo {
            for t in categoryTransactions { modelContext.delete(t) }
        }
        modelContext.delete(category)
        dismiss()
    }
}
