import SwiftUI

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var size: ControlSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .large ? .system(size: 14, weight: .semibold) : .system(size: 12.5, weight: .semibold))
            .padding(.horizontal, size == .large ? 18 : 12)
            .padding(.vertical, size == .large ? 10 : 6)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: size == .large ? 10 : 8, style: .continuous)
                    .fill(configuration.isPressed ? theme.brandDeep : theme.brand)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var size: ControlSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size == .large ? .system(size: 14, weight: .medium) : .system(size: 12.5, weight: .medium))
            .padding(.horizontal, size == .large ? 18 : 12)
            .padding(.vertical, size == .large ? 10 : 6)
            .foregroundStyle(theme.ink)
            .background(
                RoundedRectangle(cornerRadius: size == .large ? 10 : 8, style: .continuous)
                    .fill(configuration.isPressed ? theme.surface : theme.card)
                    .overlay(RoundedRectangle(cornerRadius: size == .large ? 10 : 8, style: .continuous).stroke(theme.line))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

struct DangerButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(theme.danger.opacity(configuration.isPressed ? 0.8 : 1)))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static var primaryLarge: PrimaryButtonStyle { PrimaryButtonStyle(size: .large) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
    static var secondaryLarge: SecondaryButtonStyle { SecondaryButtonStyle(size: .large) }
}

extension ButtonStyle where Self == DangerButtonStyle {
    static var danger: DangerButtonStyle { DangerButtonStyle() }
}

// MARK: - Card

struct CardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    var padding: CGFloat = 16
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.card)
                    .shadow(color: theme.cardShadow, radius: 10, y: 4)
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(theme.line))
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 14) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}
