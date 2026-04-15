import SwiftUI

enum AppTheme {
    static let backgroundTop = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let backgroundBottom = Color(red: 0.93, green: 0.88, blue: 0.80)
    static let cardBackground = Color.white.opacity(0.84)
    static let secondarySurface = Color.white.opacity(0.68)
    static let cardStroke = Color(red: 0.78, green: 0.68, blue: 0.58).opacity(0.22)
    static let accent = Color(red: 0.72, green: 0.31, blue: 0.14)
    static let accentSoft = Color(red: 0.95, green: 0.83, blue: 0.74)
    static let positiveAccent = Color(red: 0.16, green: 0.55, blue: 0.32)
    static let negativeAccent = Color(red: 0.71, green: 0.21, blue: 0.19)
    static let textPrimary = Color(red: 0.15, green: 0.12, blue: 0.11)
    static let textSecondary = Color(red: 0.38, green: 0.31, blue: 0.27)

    static let cornerRadius: CGFloat = 28
    static let screenPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let cardSpacing: CGFloat = 16

    static var appBackground: some View {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
