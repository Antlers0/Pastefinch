import SwiftUI
import AppKit

enum PFTheme {
    /// Cool signal accent — light tech, not neon.
    static let accent = Color(red: 0.10, green: 0.55, blue: 0.72)
    static let accentSoft = Color(red: 0.78, green: 0.92, blue: 0.97)
    static let pin = Color(red: 0.92, green: 0.52, blue: 0.12)

    static let panel = Color(red: 0.975, green: 0.982, blue: 0.990)
    static let panelTint = Color(red: 0.90, green: 0.96, blue: 0.99)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.945, green: 0.955, blue: 0.965)
    static let ink = Color(red: 0.14, green: 0.17, blue: 0.22)
    static let inkSecondary = Color(red: 0.42, green: 0.46, blue: 0.52)
    static let inkTertiary = Color(red: 0.62, green: 0.66, blue: 0.72)
    static let hairline = Color(red: 0.82, green: 0.86, blue: 0.90)

    static let panelCorner: CGFloat = 14
    static let controlCorner: CGFloat = 9
    static let rowCorner: CGFloat = 8

    static let rowIdle = Color.clear
    static let rowHover = Color(red: 0.90, green: 0.95, blue: 0.98)
    static let rowPinned = Color(red: 0.91, green: 0.96, blue: 0.98)
}

struct PFHairline: View {
    var body: some View {
        Rectangle()
            .fill(PFTheme.hairline)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

struct PFIconBadge: View {
    let systemName: String
    var tint: Color = PFTheme.inkSecondary

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(PFTheme.surfaceMuted)
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 36, height: 36)
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(PFTheme.hairline, lineWidth: 1)
        )
    }
}

struct PFGhostIconButton: View {
    let systemName: String
    var tint: Color = PFTheme.inkSecondary
    var help: String
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(hovering ? PFTheme.surfaceMuted : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering = $0 }
    }
}

struct PFKeyCap: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .rounded))
            .foregroundStyle(PFTheme.inkSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(PFTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(PFTheme.hairline, lineWidth: 1)
            )
    }
}
