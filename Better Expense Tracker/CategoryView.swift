import SwiftUI
struct CategoryButton: View {
    @Environment(\.colorScheme) var colorScheme

    // Tracks whether the button is currently being held down
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

    enum BackgroundColor {
        case red, green, blue, yellow, purple, orange

        var color: Color {
            switch self {
            case .red:    return Color(#colorLiteral(red: 0.910, green: 0.478, blue: 0.643, alpha: 1))
            case .green:  return Color(#colorLiteral(red: 0.722, green: 0.886, blue: 0.592, alpha: 1))
            case .blue:   return Color(#colorLiteral(red: 0.475, green: 0.839, blue: 0.976, alpha: 1))
            case .yellow: return Color(#colorLiteral(red: 0.976, green: 0.851, blue: 0.549, alpha: 1))
            case .purple: return Color(#colorLiteral(red: 0.557, green: 0.353, blue: 0.969, alpha: 1))
            case .orange: return Color(#colorLiteral(red: 0.957, green: 0.659, blue: 0.545, alpha: 1))
            }
        }

        var transitionColor: Color {
            switch self {
            case .red:    return Color(#colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1))
            case .green:  return Color(#colorLiteral(red: 0.341, green: 0.624, blue: 0.169, alpha: 1))
            case .blue:   return Color(#colorLiteral(red: 0.176, green: 0.498, blue: 0.757, alpha: 1))
            case .yellow: return Color(#colorLiteral(red: 0.953, green: 0.686, blue: 0.133, alpha: 1))
            case .purple: return Color(#colorLiteral(red: 0.3647058904, green: 0.06666667014, blue: 0.9686274529, alpha: 1))
            case .orange: return Color(#colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1))
            }
        }
    }

    let categoryName: String
    let categorySymbol: String
    let currencySymbol: CurrencySymbol
    let categoryAmount: Double
    var backgroundColor: BackgroundColor
    var transitionColor: Color
    let tileWidth: CGFloat
    let tileHeight: CGFloat

    // These are closures — blocks of code the parent passes in to define what happens
    // '() -> Void' means: a function that takes nothing and returns nothing
    var onTap: () -> Void
    var onLongPress: () -> Void

    init(
        categoryName: String = "Grocery",
        categorySymbol: String = "basket.fill",
        currencySymbol: CurrencySymbol = .CAD,
        categoryAmount: Double = 0.0,
        backgroundColor: BackgroundColor = .yellow,
        tileWidth: CGFloat = 120,
        tileHeight: CGFloat = 160,
        onTap: @escaping () -> Void = {},       // default: do nothing on tap
        onLongPress: @escaping () -> Void = {}  // default: do nothing on long press
    ) {
        self.categoryName = categoryName
        self.categorySymbol = categorySymbol
        self.currencySymbol = currencySymbol
        self.categoryAmount = categoryAmount
        self.backgroundColor = backgroundColor
        self.transitionColor = backgroundColor.transitionColor
        self.tileWidth = tileWidth
        self.tileHeight = tileHeight
        self.onTap = onTap
        self.onLongPress = onLongPress
    }

    var body: some View {
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
            .scaleEffect(isPressed ? 1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    onLongPress()
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded { onTap() }
        )
    }
}
