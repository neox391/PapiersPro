import SwiftUI

struct OnboardingView: View {
    @Environment(DocumentStore.self) private var store

    private enum Step: Int { case welcome, trade, country, company }

    @State private var step: Step = .welcome
    @State private var profile = BusinessProfile()
    @State private var tradeChosen = false
    @State private var countryChosen = false

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .welcome: welcome
                case .trade: tradeStep
                case .country: countryStep
                case .company: companyStep
                }
            }
            .animation(.easeInOut, value: step)
            .toolbar {
                if step != .welcome {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
                        } label: {
                            Label("Retour", systemImage: "chevron.left")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        StepIndicator(current: step.rawValue, total: 3)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Welcome

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 40)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Bienvenue sur PapiersPro")
                        .font(.largeTitle.bold())
                    Text("Vos devis, factures et documents administratifs, prêts à imprimer en quelques secondes.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 18) {
                    feature("square.grid.2x2", "Adapté à votre métier", "Seuls les documents et champs utiles s'affichent.")
                    feature("checkmark.shield", "Mentions légales ajoutées", "Selon votre pays : France, Belgique, Suisse ou Québec.")
                    feature("printer", "Imprimer, PDF, partager", "AirPrint, mail ou WhatsApp en un geste.")
                }
                Card { DisclaimerNote() }
                Button("Commencer") { step = .trade }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
    }

    private func feature(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Trade

    private var tradeStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StepHeader(title: "Quel est votre métier ?", subtitle: "Nous affichons les documents adaptés à votre activité.")
                    TradeGrid(selection: Binding(
                        get: { tradeChosen ? profile.trade : nil },
                        set: { trade in
                            if let trade {
                                profile.trade = trade
                                profile.vatExempt = trade.defaultVATExempt
                                tradeChosen = true
                            }
                        }
                    ))
                }
                .padding(20)
            }
            bottomButton("Continuer", enabled: tradeChosen) { step = .country }
        }
    }

    // MARK: Country

    private var countryStep: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    StepHeader(title: "Dans quel pays exercez-vous ?", subtitle: "Taux de TVA, numéros d'identification et mentions légales en dépendent.")
                    VStack(spacing: 12) {
                        ForEach(Country.allCases) { country in
                            let selected = countryChosen && profile.country == country
                            Button {
                                profile.country = country
                                countryChosen = true
                            } label: {
                                HStack(spacing: 16) {
                                    Text(country.flag).font(.largeTitle)
                                    VStack(alignment: .leading) {
                                        Text(country.label).font(.headline)
                                        Text("\(country.companyIdLabel) · \(country.currencyCode)")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .font(.title2)
                                        .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.4))
                                }
                                .padding(16)
                                .background(SelectableBackground(selected: selected))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
            bottomButton("Continuer", enabled: countryChosen) { step = .company }
        }
    }

    // MARK: Company

    private var companyStep: some View {
        VStack(spacing: 0) {
            BusinessInfoForm(profile: $profile, header: AnyView(
                StepHeader(title: "Votre entreprise", subtitle: "Saisie une seule fois, réutilisée sur tous vos documents. Modifiable à tout moment dans Réglages.")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(.bottom, 4)
            ))
            bottomButton("Terminer", enabled: profile.isComplete) {
                Keyboard.dismiss()
                store.saveProfile(profile)
            }
        }
    }

    private func bottomButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!enabled)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
    }
}

struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title.bold())
            Text(subtitle).font(.body).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .accessibilityLabel("Étape \(current) sur \(total)")
    }
}

struct SelectableBackground: View {
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.secondary.opacity(0.15), lineWidth: selected ? 2 : 1)
            )
    }
}

struct TradeGrid: View {
    @Binding var selection: Trade?
    var lockedTrades: Set<Trade> = []

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(Trade.allCases) { trade in
                let selected = selection == trade
                Button {
                    selection = trade
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: trade.symbol)
                                .font(.title2)
                                .foregroundStyle(selected ? Color.white : Color.accentColor)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(selected ? Color.accentColor : Color.accentColor.opacity(0.12)))
                            Spacer()
                            if lockedTrades.contains(trade) {
                                Image(systemName: "lock.fill").foregroundStyle(.secondary)
                            }
                        }
                        Text(trade.label)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2, reservesSpace: true)
                            .foregroundStyle(.primary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SelectableBackground(selected: selected))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}
