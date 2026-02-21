import SwiftUI

enum TerminalTheme {
    static let background = Color(red: 0.03, green: 0.05, blue: 0.04)
    static let backgroundSecondary = Color(red: 0.05, green: 0.08, blue: 0.06)
    static let panel = Color(red: 0.08, green: 0.11, blue: 0.09)
    static let panelSecondary = Color(red: 0.11, green: 0.15, blue: 0.12)
    static let border = Color(red: 0.23, green: 0.34, blue: 0.25)

    static let textPrimary = Color(red: 0.78, green: 0.97, blue: 0.79)
    static let textSecondary = Color(red: 0.51, green: 0.72, blue: 0.53)

    static let accent = Color(red: 0.25, green: 0.92, blue: 0.35)
    static let accentDim = Color(red: 0.17, green: 0.53, blue: 0.24)
    static let warning = Color(red: 1.00, green: 0.78, blue: 0.23)
    static let error = Color(red: 1.00, green: 0.37, blue: 0.30)
}

extension Font {
    static func terminal(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct TerminalPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(TerminalTheme.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(TerminalTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

extension View {
    func terminalPanel() -> some View {
        modifier(TerminalPanelModifier())
    }
}

struct TerminalActionButtonStyle: ButtonStyle {
    let isPrimary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.terminal(12, weight: .semibold))
            .foregroundStyle(isPrimary ? Color.black : TerminalTheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isPrimary ? TerminalTheme.accent : TerminalTheme.panelSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isPrimary ? TerminalTheme.accent : TerminalTheme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.75 : 1.0)
    }
}
