import SwiftUI

struct CategoryButton: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var isPressed = false

    enum CurrencySymbol {
        case CAD, USD, AUD, NZD, CNY, JPY, EUR, GBP, CHF, WON
        var symbol: String {
            switch self {
            case .CAD, .USD, .AUD, .NZD: return "$"
            case .CNY, .JPY:             return "¥"
            case .EUR:                   return "€"
            case .GBP:                   return "£"
            case .CHF:                   return "₣"
            case .WON:                   return "₩"
            }
        }
    }

    let categoryName: String
    let categorySymbol: String
    let currencySymbol: CurrencySymbol
    let categoryAmount: Double
    var backgroundColor: CategoryColor     // now uses the top-level CategoryColor enum
    var transitionColor: Color
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    // Edit mode: when true, a red X badge appears on the tile
    var editMode: Bool = false
    var onDeleteTap: () -> Void = {}

    var onTap: () -> Void
    var onLongPress: () -> Void

    init(
        categoryName: String = "Grocery",
        categorySymbol: String = "basket.fill",
        currencySymbol: CurrencySymbol = .CAD,
        categoryAmount: Double = 0.0,
        backgroundColor: CategoryColor = .yellow,
        tileWidth: CGFloat = 120,
        tileHeight: CGFloat = 160,
        editMode: Bool = false,
        onDeleteTap: @escaping () -> Void = {},
        onTap: @escaping () -> Void = {},
        onLongPress: @escaping () -> Void = {}
    ) {
        self.categoryName = categoryName
        self.categorySymbol = categorySymbol
        self.currencySymbol = currencySymbol
        self.categoryAmount = categoryAmount
        self.backgroundColor = backgroundColor
        self.transitionColor = backgroundColor.transitionColor
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.editMode = editMode
        self.onDeleteTap = onDeleteTap
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    var body: some View {
        // ZStack lets us overlay the delete X badge on top of the tile corner
        ZStack(alignment: .topTrailing) {
            Button {} label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(backgroundColor.color)
                        .frame(width: tileWidth, height: tileHeight)
                        .shadow(color: backgroundColor.transitionColor, radius: 5)

                    Circle()
                        .fill(backgroundColor.transitionColor)
                        .frame(width: tileWidth * 0.4, height: tileWidth * 0.4)
                        .shadow(color: backgroundColor.transitionColor, radius: 15)

                    VStack {
                        Text(categoryName)
                            .font(.system(size: tileWidth * 0.16, design: .rounded))
                            .foregroundColor(Color.primary)
                        Spacer()
                        Image(systemName: categorySymbol)
                            .font(.system(size: tileWidth * 0.22))
                            .foregroundColor(colorScheme == .dark ? .black : .white)
                        Spacer()
                        Text("\(currencySymbol.symbol)\(categoryAmount, specifier: "%.2f")")
                            .font(.system(size: tileWidth * 0.16, design: .rounded))
                            .foregroundColor(Color.primary)
                            .bold()
                    }
                    .frame(width: tileWidth, height: tileHeight * 0.85)
                }
                .frame(width: tileWidth, height: tileHeight)
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false; onLongPress() }
            )
            .simultaneousGesture(TapGesture().onEnded { onTap() })

            // Red X badge — only visible when edit mode is active
            if editMode {
                Button { onDeleteTap() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white).frame(width: 16, height: 16))
                }
                .buttonStyle(.plain)
                .offset(x: 6, y: -6)
            }
        }
    }
}
