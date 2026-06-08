import SwiftUI

// Extracted from CategoryButton so it can be shared across CategoryModel,
// AddAmountView, AddCategoryView, and any future view without circular dependencies.
enum CategoryColor: String, CaseIterable, Codable {
    case red, green, blue, yellow, purple, orange, gray,
         pink, teal, mint, coral, indigo, lime, sky, rose, amber

    var color: Color {
        switch self {
        case .red:    return Color(#colorLiteral(red: 0.910, green: 0.478, blue: 0.643, alpha: 1))
        case .green:  return Color(#colorLiteral(red: 0.722, green: 0.886, blue: 0.592, alpha: 1))
        case .blue:   return Color(#colorLiteral(red: 0.475, green: 0.839, blue: 0.976, alpha: 1))
        case .yellow: return Color(#colorLiteral(red: 0.976, green: 0.851, blue: 0.549, alpha: 1))
        case .purple: return Color(#colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1))
        case .orange: return Color(#colorLiteral(red: 0.957, green: 0.659, blue: 0.545, alpha: 1))
        case .gray:   return Color(UIColor.systemGray5)
        case .pink:   return Color(#colorLiteral(red: 0.984, green: 0.714, blue: 0.831, alpha: 1))
        case .teal:   return Color(#colorLiteral(red: 0.522, green: 0.878, blue: 0.831, alpha: 1))
        case .mint:   return Color(#colorLiteral(red: 0.706, green: 0.941, blue: 0.800, alpha: 1))
        case .coral:  return Color(#colorLiteral(red: 0.988, green: 0.620, blue: 0.529, alpha: 1))
        case .indigo: return Color(#colorLiteral(red: 0.671, green: 0.718, blue: 0.976, alpha: 1))
        case .lime:   return Color(#colorLiteral(red: 0.831, green: 0.941, blue: 0.447, alpha: 1))
        case .sky:    return Color(#colorLiteral(red: 0.541, green: 0.808, blue: 0.976, alpha: 1))
        case .rose:   return Color(#colorLiteral(red: 0.988, green: 0.753, blue: 0.761, alpha: 1))
        case .amber:  return Color(#colorLiteral(red: 0.992, green: 0.847, blue: 0.400, alpha: 1))
        }
    }

    var transitionColor: Color {
        switch self {
        case .red:    return Color(#colorLiteral(red: 0.855, green: 0.251, blue: 0.478, alpha: 1))
        case .green:  return Color(#colorLiteral(red: 0.341, green: 0.624, blue: 0.169, alpha: 1))
        case .blue:   return Color(#colorLiteral(red: 0.176, green: 0.498, blue: 0.757, alpha: 1))
        case .yellow: return Color(#colorLiteral(red: 0.953, green: 0.686, blue: 0.133, alpha: 1))
        case .purple: return Color(#colorLiteral(red: 0.365, green: 0.067, blue: 0.969, alpha: 1))
        case .orange: return Color(#colorLiteral(red: 0.941, green: 0.498, blue: 0.353, alpha: 1))
        case .gray:   return Color(UIColor.systemGray3)
        case .pink:   return Color(#colorLiteral(red: 0.910, green: 0.294, blue: 0.561, alpha: 1))
        case .teal:   return Color(#colorLiteral(red: 0.145, green: 0.620, blue: 0.573, alpha: 1))
        case .mint:   return Color(#colorLiteral(red: 0.208, green: 0.698, blue: 0.447, alpha: 1))
        case .coral:  return Color(#colorLiteral(red: 0.929, green: 0.353, blue: 0.243, alpha: 1))
        case .indigo: return Color(#colorLiteral(red: 0.286, green: 0.369, blue: 0.859, alpha: 1))
        case .lime:   return Color(#colorLiteral(red: 0.467, green: 0.714, blue: 0.078, alpha: 1))
        case .sky:    return Color(#colorLiteral(red: 0.133, green: 0.557, blue: 0.820, alpha: 1))
        case .rose:   return Color(#colorLiteral(red: 0.882, green: 0.275, blue: 0.345, alpha: 1))
        case .amber:  return Color(#colorLiteral(red: 0.922, green: 0.600, blue: 0.047, alpha: 1))
        }
    }

    var displayName: String { rawValue.capitalized }
}
