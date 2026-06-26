import SwiftUI
import SwiftData
import PhotosUI
import UIKit

// ============================================================
// MARK: - Free functions
// ============================================================

/// Advance a date by one finance-schedule interval.
private func advanceDate(_ date: Date, by type: FinanceType) -> Date {
    let cal = Calendar.current
    switch type {
    case .oneTime:              return date
    case .weekly:               return cal.date(byAdding: .day,   value: 7,  to: date) ?? date
    case .monthly:              return cal.date(byAdding: .month, value: 1,  to: date) ?? date
    case .quarterly:            return cal.date(byAdding: .month, value: 3,  to: date) ?? date
    case .custom(let days):     return cal.date(byAdding: .day,   value: days, to: date) ?? date
    }
}

/// Delete all Transactions whose groupID matches the asset's assetGroupID.
func deleteLinkedTransactions(groupID: String, in context: ModelContext) {
    let desc = FetchDescriptor<Transaction>(predicate: #Predicate { $0.groupID == groupID })
    if let hits = try? context.fetch(desc) {
        hits.forEach { context.delete($0) }
    }
    try? context.save()
}

/// Generate Transaction entries for an asset based on its FinanceSchedule.
/// Call deleteLinkedTransactions first if editing an existing asset.
func generateAssetTransactions(for asset: AssetItem, in context: ModelContext) {
    let schedule   = asset.financeSchedule
    let symbol     = asset.imageData != nil ? "photo.fill" : asset.effectiveSymbol
    let catName    = asset.category?.name ?? "Assets"
    let projCodes: [String] = [asset.projectCode, asset.projectSubCode].compactMap { $0 }
    let today      = Calendar.current.startOfDay(for: Date.now)

    // One-time: insert a single transaction on the purchase date (if amount > 0)
    if case .oneTime = schedule.type {
        if schedule.paymentAmount > 0 {
            let t = Transaction(
                title: asset.name,
                amount: schedule.paymentAmount,
                date: asset.purchaseDate,
                categoryName: catName,
                categorySymbol: symbol,
                projectCodes: projCodes,
                isIncome: false,
                taxable: false,
                groupID: asset.assetGroupID,
                isGasolineSplit: false
            )
            context.insert(t)
        }
        try? context.save()
        return
    }

    // Recurring: build list of payment dates
    var dates: [Date] = []
    var cursor = Calendar.current.startOfDay(for: asset.purchaseDate)
    var count = 0

    while true {
        dates.append(cursor)
        count += 1

        if let maxPayments = schedule.totalPayments, count >= maxPayments {
            break   // hit cap
        }

        let next = advanceDate(cursor, by: schedule.type)

        // Indefinite schedule: stop once we pass today
        if schedule.totalPayments == nil && next > today {
            break
        }
        cursor = next
    }

    for date in dates {
        let t = Transaction(
            title: asset.name,
            amount: schedule.paymentAmount,
            date: date,
            categoryName: catName,
            categorySymbol: symbol,
            projectCodes: projCodes,
            isIncome: false,
            taxable: false,
            groupID: asset.assetGroupID,
            isGasolineSplit: false
        )
        context.insert(t)
    }
    try? context.save()
}

// ============================================================
// MARK: - AddAssetCategorySheet
// ============================================================

struct AddAssetCategorySheet: View {
    var editing: AssetCategory? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetCategory.sortOrder) private var allCategories: [AssetCategory]

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.secondary)
                Spacer()
                Text(editing == nil ? "New Category" : "Rename Category")
                    .font(.headline)
                Spacer()
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)

            Divider()

            TextField("Category name", text: $name)
                .font(.title3)
                .padding(.horizontal, 20).padding(.vertical, 16)
                .focused($focused)

            Spacer()
        }
        .onAppear {
            name = editing?.name ?? ""
            focused = true
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let cat = editing {
            cat.name = trimmed
        } else {
            let maxOrder = allCategories.map(\.sortOrder).max() ?? -1
            let cat = AssetCategory(name: trimmed, sortOrder: maxOrder + 1)
            modelContext.insert(cat)
        }
        try? modelContext.save()
        dismiss()
    }
}

// ============================================================
// MARK: - SquareCropView (UIViewControllerRepresentable)
// ============================================================

struct SquareCropView: UIViewControllerRepresentable {
    let image: UIImage
    let onCrop: (UIImage) -> Void

    func makeUIViewController(context: Context) -> SquareCropViewController {
        let vc = SquareCropViewController(image: image)
        vc.onCrop = onCrop
        return vc
    }

    func updateUIViewController(_ uiViewController: SquareCropViewController, context: Context) {}
}

final class SquareCropViewController: UIViewController {
    var onCrop: ((UIImage) -> Void)?

    private let sourceImage: UIImage
    private let scrollView = UIScrollView()
    private let imageView  = UIImageView()
    private let overlayView = UIView()

    init(image: UIImage) {
        self.sourceImage = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)

        imageView.image = sourceImage
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        // Square overlay
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        overlayView.layer.borderColor = UIColor.white.cgColor
        overlayView.layer.borderWidth = 2
        view.addSubview(overlayView)

        // Crop button
        let cropBtn = UIButton(type: .system)
        cropBtn.setTitle("Crop", for: .normal)
        cropBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        cropBtn.tintColor = .white
        cropBtn.translatesAutoresizingMaskIntoConstraints = false
        cropBtn.addTarget(self, action: #selector(cropTapped), for: .touchUpInside)
        view.addSubview(cropBtn)

        // Cancel button
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 17)
        cancelBtn.tintColor = .white
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),

            cropBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cropBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            cancelBtn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            cancelBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let side = min(view.bounds.width, view.bounds.height - 120)
        let x = (view.bounds.width - side) / 2
        let y = (view.bounds.height - side) / 2 - 40
        overlayView.frame = CGRect(x: x, y: y, width: side, height: side)
    }

    @objc private func cropTapped() {
        let cropRect = overlayView.frame

        // Convert crop rect to image coordinates
        let imageSize = sourceImage.size
        let viewSize  = imageView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledW = imageSize.width  * scale
        let scaledH = imageSize.height * scale
        let offsetX = (viewSize.width  - scaledW) / 2
        let offsetY = (viewSize.height - scaledH) / 2

        // Map crop rect from screen to image space
        // Take scroll into account
        let scrollOffset = scrollView.contentOffset
        let adjustedCrop = CGRect(
            x: cropRect.origin.x + scrollOffset.x - offsetX,
            y: cropRect.origin.y + scrollOffset.y - offsetY,
            width: cropRect.width,
            height: cropRect.height
        )

        let imgX = adjustedCrop.origin.x / scale
        let imgY = adjustedCrop.origin.y / scale
        let imgW = adjustedCrop.width    / scale
        let imgH = adjustedCrop.height   / scale

        let clampedRect = CGRect(
            x: max(0, imgX),
            y: max(0, imgY),
            width: min(imgW, imageSize.width  - max(0, imgX)),
            height: min(imgH, imageSize.height - max(0, imgY))
        )

        guard clampedRect.width > 0, clampedRect.height > 0,
              let cgImage = sourceImage.cgImage?.cropping(to: clampedRect) else { return }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 512, height: 512))
        let cropped = renderer.image { _ in
            UIImage(cgImage: cgImage).draw(in: CGRect(origin: .zero, size: CGSize(width: 512, height: 512)))
        }

        onCrop?(cropped)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
}

extension SquareCropViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
}

// ============================================================
// MARK: - AssetTile
// ============================================================

struct AssetTile: View {
    let asset: AssetItem
    let tileSize: CGFloat
    let editMode: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onLongPress: () -> Void

    @State private var isPressed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Text(formatCurrency(asset.purchasePrice))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .padding(.top, 8)

                Spacer()

                // Image or SF Symbol
                if let data = asset.imageData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tileSize * 0.5, height: tileSize * 0.5)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: asset.effectiveSymbol)
                        .font(.system(size: tileSize * 0.25))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(asset.name)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
            }
            .frame(width: tileSize, height: tileSize)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: isPressed)

            // Delete badge
            if editMode {
                Button { onDelete() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, .red)
                        .background(Circle().fill(Color.white).padding(3))
                }
                .offset(x: 6, y: -6)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onLongPressGesture(minimumDuration: 0.45, pressing: { pressing in
            if !editMode { isPressed = pressing }
        }, perform: {
            onLongPress()
        })
    }
}

// ============================================================
// MARK: - AddAsset tile (+ button tile in edit mode)
// ============================================================

private struct AddAssetTile: View {
    let tileSize: CGFloat
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Add asset")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: tileSize, height: tileSize)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            )
        }
    }
}

// ============================================================
// MARK: - AssetCategorySection
// ============================================================

struct AssetCategorySection: View {
    let category: AssetCategory
    let tileSize: CGFloat
    let spacing: CGFloat
    let editMode: Bool
    let onTapAsset: (AssetItem) -> Void
    let onDeleteAsset: (AssetItem) -> Void
    let onLongPress: () -> Void
    let onEditCategory: (AssetCategory) -> Void
    let onAddAsset: (AssetCategory) -> Void

    @State private var isCollapsed = false
    @State private var items: [AssetItem] = []

    // Drag state
    @State private var draggingID: PersistentIdentifier? = nil
    @State private var dragOffset: CGSize = .zero

    @Environment(\.modelContext) private var modelContext

    var sortedItems: [AssetItem] {
        category.assets.sorted { $0.sortOrder < $1.sortOrder }
    }

    var categoryTotal: Double {
        category.assets.reduce(0) { $0 + $1.purchasePrice }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack(spacing: 6) {
                if editMode {
                    Button {
                        onEditCategory(category)
                    } label: {
                        Text(category.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .underline()
                    }
                } else {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isCollapsed.toggle() }
                } label: {
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(formatCurrency(categoryTotal))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)

            if !isCollapsed {
                // Tile grid
                let columns = [GridItem(.adaptive(minimum: tileSize), spacing: spacing)]
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(items) { asset in
                        AssetTile(
                            asset: asset,
                            tileSize: tileSize,
                            editMode: editMode,
                            onTap: { onTapAsset(asset) },
                            onDelete: { onDeleteAsset(asset) },
                            onLongPress: onLongPress
                        )
                    }

                    if editMode {
                        AddAssetTile(tileSize: tileSize) {
                            onAddAsset(category)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear { items = sortedItems }
        .onChange(of: category.assets.count) { _, _ in items = sortedItems }
    }
}

// ============================================================
// MARK: - ProjectCodePickerSheet (used inside AddAssetView)
// ============================================================

private struct ProjectCodePickerSheet: View {
    @Binding var selectedCode: String?
    @Binding var selectedSubCode: String?

    @Query(sort: \ProjectCode.sortOrder) private var projectCodes: [ProjectCode]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("None") {
                        selectedCode = nil
                        selectedSubCode = nil
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                ForEach(projectCodes) { proj in
                    Section(header: Text(proj.name)) {
                        Button(proj.name) {
                            selectedCode = proj.name
                            selectedSubCode = nil
                            dismiss()
                        }
                        .foregroundColor(.primary)

                        ForEach(proj.subCodes, id: \.self) { sub in
                            Button("\(proj.name) / \(sub)") {
                                selectedCode = proj.name
                                selectedSubCode = sub
                                dismiss()
                            }
                            .foregroundColor(.primary)
                            .padding(.leading, 8)
                        }
                    }
                }
            }
            .navigationTitle("Project Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// ============================================================
// MARK: - AddAssetView
// ============================================================

struct AddAssetView: View {
    var editing: AssetItem? = nil
    var preselectedCategory: AssetCategory? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]

    // Image
    @State private var selectedImage: UIImage? = nil
    @State private var rawPickedImage: UIImage? = nil
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var showImageSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var showSymbolPicker = false
    @State private var showCropView = false
    @State private var selectedSymbol = "shippingbox.fill"

    // Fields
    @State private var name = ""
    @State private var priceString = ""
    @State private var purchaseDate = Date.now
    @State private var showDatePicker = false

    // Tax
    @State private var taxInputIsPercent = true
    @State private var taxString = ""

    // Category
    @State private var selectedCategoryID: PersistentIdentifier? = nil

    // Project
    @State private var selectedProjectCode: String? = nil
    @State private var selectedSubCode: String? = nil
    @State private var showProjectPicker = false

    // Finance
    @State private var isFinanced = false
    @State private var paymentString = ""
    @State private var scheduleType: FinanceType = .monthly
    @State private var customDays = 30
    @State private var totalPaymentsString = ""
    @State private var isIndefinite = true

    var selectedCategory: AssetCategory? {
        guard let id = selectedCategoryID else { return nil }
        return categories.first { $0.persistentModelID == id }
    }

    var parsedPrice: Double { Double(priceString) ?? 0 }
    var parsedPayment: Double { Double(paymentString) ?? 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imageWell
                    nameField
                    priceAndDateSection
                    taxSection
                    categorySection
                    projectSection
                    financeSection
                }
                .padding(20)
            }
            .navigationTitle(editing == nil ? "New Asset" : "Edit Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAsset() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || parsedPrice <= 0)
                }
            }
            .confirmationDialog("Choose Image Source", isPresented: $showImageSourceDialog) {
                Button("Photo Library") { showPhotoPicker = true }
                Button("Choose Symbol") { showSymbolPicker = true }
                if selectedImage != nil {
                    Button("Remove Image", role: .destructive) { selectedImage = nil }
                }
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $photosItem, matching: .images)
            .onChange(of: photosItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run {
                            rawPickedImage = ui
                            showCropView = true
                            photosItem = nil
                        }
                    }
                }
            }
            .sheet(isPresented: $showSymbolPicker) {
                SymbolPickerView(selectedSymbol: $selectedSymbol)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCropView) {
                if let raw = rawPickedImage {
                    SquareCropView(image: raw) { cropped in
                        selectedImage = cropped
                        rawPickedImage = nil
                    }
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showProjectPicker) {
                ProjectCodePickerSheet(
                    selectedCode: $selectedProjectCode,
                    selectedSubCode: $selectedSubCode
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showDatePicker) {
                VStack(spacing: 0) {
                    HStack {
                        Button("Cancel") { showDatePicker = false }.foregroundColor(.secondary)
                        Spacer()
                        Text("Purchase Date").font(.headline)
                        Spacer()
                        Button("Done") { showDatePicker = false }.fontWeight(.semibold)
                    }
                    .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 8)
                    Divider()
                    DatePicker("", selection: $purchaseDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding()
                }
                .presentationDetents([.height(420)])
            }
        }
        .onAppear { populateIfEditing() }
    }

    // MARK: - Sub-views

    private var imageWell: some View {
        Button { showImageSourceDialog = true } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(width: 160, height: 160)

                if let ui = selectedImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: selectedSymbol)
                            .font(.system(size: 52))
                            .foregroundColor(.secondary)
                        Text("Tap to change")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Asset Name").font(.caption).foregroundColor(.secondary)
            TextField("e.g. Sony A7IV", text: $name)
                .font(.title3)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var priceAndDateSection: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Purchase Price").font(.caption).foregroundColor(.secondary)
                HStack {
                    Text("$").foregroundColor(.secondary)
                    TextField("0.00", text: $priceString)
                        .keyboardType(.decimalPad)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Purchase Date").font(.caption).foregroundColor(.secondary)
                Button {
                    showDatePicker = true
                } label: {
                    Text(purchaseDate, style: .date)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var taxSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tax Paid (included in purchase price)").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 8) {
                // Toggle % / $
                HStack(spacing: 0) {
                    ForEach(["% ", "$"], id: \.self) { mode in
                        let isPct = mode == "% "
                        Button {
                            taxInputIsPercent = isPct
                            taxString = ""
                        } label: {
                            Text(mode)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(taxInputIsPercent == isPct ? Color.accentColor.opacity(0.2) : Color.clear)
                                .foregroundColor(taxInputIsPercent == isPct ? .accentColor : .secondary)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                TextField(taxInputIsPercent ? "e.g. 15" : "e.g. 150.00", text: $taxString)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Category").font(.caption).foregroundColor(.secondary)
            if categories.isEmpty {
                Text("No categories yet — add one from the Assets tab")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories) { cat in
                            let isSelected = selectedCategoryID == cat.persistentModelID
                            Button {
                                selectedCategoryID = isSelected ? nil : cat.persistentModelID
                            } label: {
                                Text(cat.name)
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                                    .foregroundColor(isSelected ? .accentColor : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Project Code (Optional)").font(.caption).foregroundColor(.secondary)
            Button { showProjectPicker = true } label: {
                HStack {
                    if let code = selectedProjectCode {
                        Text(selectedSubCode.map { "\(code) / \($0)" } ?? code)
                            .foregroundColor(.primary)
                    } else {
                        Text("None").foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var financeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Financed / Recurring Payments", isOn: $isFinanced.animation())
                .font(.system(size: 15))

            if isFinanced {
                VStack(alignment: .leading, spacing: 12) {
                    // Payment amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Payment Amount").font(.caption).foregroundColor(.secondary)
                        HStack {
                            Text("$").foregroundColor(.secondary)
                            TextField("0.00", text: $paymentString)
                                .keyboardType(.decimalPad)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Schedule type
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Schedule").font(.caption).foregroundColor(.secondary)
                        scheduleTypePicker
                    }

                    // Custom days
                    if case .custom = scheduleType {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Every how many days").font(.caption).foregroundColor(.secondary)
                            HStack {
                                TextField("30", value: $customDays, format: .number)
                                    .keyboardType(.numberPad)
                                Text("days").foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }

                    // Total payments
                    Toggle("Fixed number of payments", isOn: Binding(
                        get: { !isIndefinite },
                        set: { isIndefinite = !$0 }
                    ).animation())
                    .font(.system(size: 15))

                    if !isIndefinite {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Payments").font(.caption).foregroundColor(.secondary)
                            TextField("e.g. 60", text: $totalPaymentsString)
                                .keyboardType(.numberPad)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var scheduleTypePicker: some View {
        let types: [(String, FinanceType)] = [
            ("Weekly",    .weekly),
            ("Monthly",   .monthly),
            ("Quarterly", .quarterly),
            ("Custom",    .custom(days: customDays)),
        ]
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(types, id: \.0) { label, type in
                    let isSelected = scheduleTypesMatch(scheduleType, type)
                    Button {
                        scheduleType = type
                    } label: {
                        Text(label)
                            .font(.system(size: 14))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(isSelected ? Color.accentColor.opacity(0.2) : Color(.tertiarySystemGroupedBackground))
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func scheduleTypesMatch(_ a: FinanceType, _ b: FinanceType) -> Bool {
        switch (a, b) {
        case (.weekly, .weekly), (.monthly, .monthly), (.quarterly, .quarterly): return true
        case (.custom, .custom): return true
        default: return false
        }
    }

    // MARK: - Populate from editing

    private func populateIfEditing() {
        // If a category was preselected
        if let cat = preselectedCategory {
            selectedCategoryID = cat.persistentModelID
        }

        guard let asset = editing else { return }

        name           = asset.name
        priceString    = String(format: "%.2f", asset.purchasePrice)
        purchaseDate   = asset.purchaseDate
        selectedSymbol = asset.effectiveSymbol

        if let data = asset.imageData, let ui = UIImage(data: data) {
            selectedImage = ui
        }

        if asset.taxPaidAmount > 0 {
            taxInputIsPercent = false
            taxString = String(format: "%.2f", asset.taxPaidAmount)
        }

        if let id = asset.category?.persistentModelID {
            selectedCategoryID = id
        }

        selectedProjectCode = asset.projectCode
        selectedSubCode     = asset.projectSubCode

        let schedule = asset.financeSchedule
        if case .oneTime = schedule.type {
            isFinanced = false
        } else {
            isFinanced      = true
            paymentString   = String(format: "%.2f", schedule.paymentAmount)
            scheduleType    = schedule.type
            if let total = schedule.totalPayments {
                isIndefinite         = false
                totalPaymentsString  = "\(total)"
            } else {
                isIndefinite = true
            }
            if case .custom(let d) = schedule.type {
                customDays = d
            }
        }
    }

    // MARK: - Save

    private func saveAsset() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, parsedPrice > 0 else { return }

        // Tax amount
        let taxAmount: Double
        if let taxVal = Double(taxString), taxVal > 0 {
            taxAmount = taxInputIsPercent ? (parsedPrice * taxVal / 100.0) : taxVal
        } else {
            taxAmount = 0
        }

        // Image data
        let imgData: Data?
        if let ui = selectedImage {
            imgData = ui.jpegData(compressionQuality: 0.85)
        } else {
            imgData = nil
        }

        // Finance schedule
        let schedule: FinanceSchedule
        if isFinanced {
            let effectiveType: FinanceType
            if case .custom = scheduleType {
                effectiveType = .custom(days: customDays)
            } else {
                effectiveType = scheduleType
            }
            let totalPayments: Int? = isIndefinite ? nil : Int(totalPaymentsString)
            schedule = FinanceSchedule(type: effectiveType, paymentAmount: parsedPayment, totalPayments: totalPayments)
        } else {
            schedule = .oneTime
        }

        if let asset = editing {
            // Edit existing: delete old transactions, then regenerate
            deleteLinkedTransactions(groupID: asset.assetGroupID, in: modelContext)

            asset.name           = trimmedName
            asset.purchasePrice  = parsedPrice
            asset.purchaseDate   = purchaseDate
            asset.taxPaidAmount  = taxAmount
            asset.imageData      = imgData
            asset.symbolName     = imgData == nil ? selectedSymbol : nil
            asset.financeSchedule = schedule
            asset.category       = selectedCategory
            asset.projectCode    = selectedProjectCode
            asset.projectSubCode = selectedSubCode

            try? modelContext.save()
            generateAssetTransactions(for: asset, in: modelContext)
        } else {
            // Create new
            let maxOrder = selectedCategory?.assets.map(\.sortOrder).max() ?? -1
            let asset = AssetItem(
                name: trimmedName,
                purchasePrice: parsedPrice,
                purchaseDate: purchaseDate,
                taxPaidAmount: taxAmount,
                imageData: imgData,
                symbolName: imgData == nil ? selectedSymbol : nil,
                sortOrder: maxOrder + 1,
                projectCode: selectedProjectCode,
                projectSubCode: selectedSubCode,
                financeSchedule: schedule
            )
            asset.category = selectedCategory
            modelContext.insert(asset)
            try? modelContext.save()
            generateAssetTransactions(for: asset, in: modelContext)
        }

        dismiss()
    }
}

// ============================================================
// MARK: - Assetsview (root)
// ============================================================

struct Assetsview: View {
    @Query(sort: \AssetCategory.sortOrder) private var categories: [AssetCategory]

    @State private var editMode = false
    @State private var assetToEdit: AssetItem? = nil
    @State private var assetToDelete: AssetItem? = nil
    @State private var showDeleteAssetAlert = false
    @State private var showDeleteLinkedAlert = false
    @State private var showAddCategory = false
    @State private var categoryToEdit: AssetCategory? = nil
    @State private var preselectedCategoryForAdd: AssetCategory? = nil
    @State private var showAddAsset = false

    @Environment(\.modelContext) private var modelContext

    var totalPurchasePrice: Double {
        categories.flatMap(\.assets).reduce(0) { $0 + $1.purchasePrice }
    }

    let tileSize: CGFloat = 100
    let tileSpacing: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    VStack(spacing: 12) {
                        if categories.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No asset categories yet")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                Text("Tap + to create your first category")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            ForEach(categories) { category in
                                AssetCategorySection(
                                    category: category,
                                    tileSize: tileSize,
                                    spacing: tileSpacing,
                                    editMode: editMode,
                                    onTapAsset: { asset in
                                        if !editMode { assetToEdit = asset }
                                    },
                                    onDeleteAsset: { asset in
                                        assetToDelete = asset
                                        let hasLinked = hasLinkedTransactions(for: asset)
                                        if hasLinked {
                                            showDeleteLinkedAlert = true
                                        } else {
                                            showDeleteAssetAlert = true
                                        }
                                    },
                                    onLongPress: {
                                        withAnimation { editMode = true }
                                    },
                                    onEditCategory: { cat in
                                        categoryToEdit = cat
                                    },
                                    onAddAsset: { cat in
                                        preselectedCategoryForAdd = cat
                                        showAddAsset = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                    .padding(.top, 48) // space for the overlay buttons
                }

                // Top-right controls overlay
                HStack(spacing: 12) {
                    if editMode {
                        Button("Done") {
                            withAnimation { editMode = false }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                    } else {
                        Button {
                            showAddCategory = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 16)
            }

            Divider()

            // Total bar
            HStack {
                Text("Total")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatCurrency(totalPurchasePrice))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemGroupedBackground))
        // Add category sheet
        .sheet(isPresented: $showAddCategory) {
            AddAssetCategorySheet()
                .presentationDetents([.height(260)])
        }
        // Edit category sheet
        .sheet(item: $categoryToEdit) { cat in
            AddAssetCategorySheet(editing: cat)
                .presentationDetents([.height(260)])
        }
        // Add asset sheet (from + tile in edit mode)
        .sheet(isPresented: $showAddAsset) {
            AddAssetView(preselectedCategory: preselectedCategoryForAdd)
        }
        // Edit asset sheet (tap on tile)
        .sheet(item: $assetToEdit) { asset in
            AddAssetView(editing: asset)
        }
        // Delete asset (no linked transactions)
        .alert("Delete Asset?", isPresented: $showDeleteAssetAlert, presenting: assetToDelete) { asset in
            Button("Delete", role: .destructive) { deleteAsset(asset, deleteTransactions: false) }
            Button("Cancel", role: .cancel) {}
        } message: { asset in
            Text(""\(asset.name)" will be removed.")
        }
        // Delete asset + linked transactions
        .alert("Delete Asset?", isPresented: $showDeleteLinkedAlert, presenting: assetToDelete) { asset in
            Button("Delete Asset & Transactions", role: .destructive) {
                deleteAsset(asset, deleteTransactions: true)
            }
            Button("Delete Asset Only", role: .destructive) {
                deleteAsset(asset, deleteTransactions: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: { asset in
            Text(""\(asset.name)" has linked finance transactions. Do you want to delete those too?")
        }
    }

    private func hasLinkedTransactions(for asset: AssetItem) -> Bool {
        let gid = asset.assetGroupID
        let desc = FetchDescriptor<Transaction>(predicate: #Predicate { $0.groupID == gid })
        let count = (try? modelContext.fetchCount(desc)) ?? 0
        return count > 0
    }

    private func deleteAsset(_ asset: AssetItem, deleteTransactions: Bool) {
        if deleteTransactions {
            deleteLinkedTransactions(groupID: asset.assetGroupID, in: modelContext)
        }
        modelContext.delete(asset)
        try? modelContext.save()
        assetToDelete = nil
    }
}

// ============================================================
// MARK: - Preview
// ============================================================

#Preview {
    Assetsview()
        .modelContainer(for: [Transaction.self, CategoryModel.self, ProjectCode.self,
                               AssetCategory.self, AssetItem.self],
                        inMemory: true)
}
