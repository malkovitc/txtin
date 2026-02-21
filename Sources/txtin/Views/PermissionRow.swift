import SwiftUI

struct PermissionRow: View {
    let title: String
    let description: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(granted ? "[OK]" : "[NO]")
                .font(.terminal(10, weight: .bold))
                .foregroundStyle(granted ? TerminalTheme.accent : TerminalTheme.error)
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.terminal(11, weight: .semibold))
                    .foregroundStyle(TerminalTheme.textPrimary)
                Text(description)
                    .font(.terminal(9))
                    .foregroundStyle(TerminalTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            if granted {
                Text(actionTitle.uppercased())
                    .font(.terminal(9, weight: .semibold))
                    .foregroundStyle(TerminalTheme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(TerminalTheme.panelSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(TerminalTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Button(actionTitle.uppercased(), action: action)
                    .buttonStyle(TerminalActionButtonStyle(isPrimary: true))
            }
        }
        .padding(7)
        .background(TerminalTheme.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(TerminalTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
