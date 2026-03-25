import SwiftUI

// MARK: - App Theme

enum AppTheme {
    // MARK: - Colors

    static let accent = Color(.label)
    static let accentLight = Color(.label)
    static let accentGradient = LinearGradient(
        colors: [Color(.label)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Semantic colors
    static let todayHighlight = LinearGradient(
        colors: [Color(.label)],
        startPoint: .top,
        endPoint: .bottom
    )
    static let selectedHighlight = Color(.label).opacity(0.12)

    // Priority colors
    static let priorityHigh = Color(red: 255/255, green: 107/255, blue: 107/255)
    static let priorityMedium = Color(red: 255/255, green: 169/255, blue: 77/255)
    static let priorityLow = Color(red: 116/255, green: 143/255, blue: 252/255)

    // MARK: - Typography

    static let displayFont: Font = .system(size: 34, weight: .black, design: .rounded)
    static let titleFont: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let headlineFont: Font = .system(size: 17, weight: .semibold, design: .rounded)
    static let bodyFont: Font = .system(size: 15, weight: .regular, design: .rounded)
    static let captionFont: Font = .system(size: 12, weight: .medium, design: .rounded)
    static let tinyFont: Font = .system(size: 10, weight: .medium, design: .rounded)

    // MARK: - Spacing & Radius

    static let cardRadius: CGFloat = 16
    static let smallRadius: CGFloat = 10
    static let buttonRadius: CGFloat = 14
}

// MARK: - Card Shadow Modifier

struct CardShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }
}

extension View {
    func cardShadow() -> some View {
        modifier(CardShadowModifier())
    }
}
