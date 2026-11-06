import SwiftUI
import UIKit

enum Legal {
    static let disclaimer = "Les modèles sont fournis à titre indicatif et ne remplacent pas un conseil juridique. Vérifiez qu'ils correspondent à votre situation."
}

struct DisclaimerNote: View {
    var body: some View {
        Label {
            Text(Legal.disclaimer)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor.opacity(isEnabled ? 1 : 0.4)))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("ILLIMITÉ")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(.white)
            .background(Capsule().fill(LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing)))
    }
}

enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Text field for amounts and quantities accepting "," or "." and updating the value on every keystroke.
struct DecimalField: View {
    let title: String
    @Binding var value: Decimal
    let locale: Locale

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .onAppear { text = format(value) }
            .onChange(of: text) { _, newText in
                if let parsed = DecimalParser.parse(newText) {
                    if parsed != value { value = parsed }
                } else if newText.trimmingCharacters(in: .whitespaces).isEmpty, value != 0 {
                    value = 0
                }
            }
            .onChange(of: value) { _, newValue in
                if !focused { text = format(newValue) }
            }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { text = format(value) }
            }
    }

    private func format(_ v: Decimal) -> String {
        guard v != 0 else { return "" }
        return v.formatted(.number.precision(.fractionLength(0...2)).grouping(.never).locale(locale))
    }
}
