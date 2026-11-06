import PhotosUI
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @AppStorage("appearance") private var appearance: Appearance = .system

    @State private var showPaywall = false
    @State private var showTradePicker = false
    @State private var showManageSubscription = false
    @State private var confirmReset = false

    var body: some View {
        let profile = store.profile ?? BusinessProfile()
        NavigationStack {
            Form {
                Section("Mon activité") {
                    NavigationLink {
                        CompanySettingsView()
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Mon entreprise")
                                Text(profile.displayName).font(.footnote).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "building.2")
                        }
                    }
                    Button {
                        if subscriptions.isPremium { showTradePicker = true } else { showPaywall = true }
                    } label: {
                        HStack {
                            Label("Métier", systemImage: profile.trade.symbol)
                            Spacer()
                            Text(profile.trade.label).foregroundStyle(.secondary)
                            if !subscriptions.isPremium {
                                Image(systemName: "lock.fill").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                    Picker(selection: Binding(
                        get: { profile.country },
                        set: { country in
                            var p = profile
                            p.country = country
                            store.saveProfile(p)
                        }
                    )) {
                        ForEach(Country.allCases) { country in
                            Text("\(country.flag) \(country.label)").tag(country)
                        }
                    } label: {
                        Label("Pays", systemImage: "globe.europe.africa")
                    }
                }

                Section("Apparence") {
                    Picker(selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.label).tag($0) }
                    } label: {
                        Label("Thème", systemImage: "circle.lefthalf.filled")
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    if subscriptions.isPremium {
                        Label("PapiersPro Illimité actif", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Button("Gérer mon abonnement") { showManageSubscription = true }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Label("Passer à Illimité", systemImage: "sparkles")
                                Spacer()
                                PremiumBadge()
                            }
                        }
                        LabeledContent("Documents ce mois-ci", value: "\(store.documentsCreated()) / \(DocumentStore.freeDocumentsPerMonth)")
                    }
                    Button("Restaurer mes achats") {
                        Task { await subscriptions.restore() }
                    }
                } header: {
                    Text("Abonnement")
                }

                Section {
                    ForEach([DocumentType.devis, .facture], id: \.self) { type in
                        LabeledContent("Prochain \(type.label.lowercased())", value: store.nextNumber(for: type))
                    }
                } header: {
                    Text("Numérotation")
                } footer: {
                    Text("Les numéros se suivent automatiquement, sans trou, et repartent à 1 chaque année.")
                }

                Section("Informations") {
                    DisclaimerNote()
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }

                Section {
                    Button("Réinitialiser l'application", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Supprime votre profil et tout l'historique de cet appareil.")
                }
            }
            .navigationTitle("Réglages")
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .sheet(isPresented: $showTradePicker) { TradePickerSheet() }
            .manageSubscriptionsSheet(isPresented: $showManageSubscription)
            .confirmationDialog("Tout effacer ?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Effacer mon profil et mes documents", role: .destructive) { store.resetAll() }
            } message: {
                Text("Cette action est définitive.")
            }
        }
    }
}

struct CompanySettingsView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var profile = BusinessProfile()
    @State private var loaded = false

    var body: some View {
        BusinessInfoForm(profile: $profile) {
            LogoSection()
            Section {
                Picker("Délai de paiement par défaut", selection: $profile.defaultPaymentDays) {
                    ForEach(PaymentTerms.options, id: \.self) { days in
                        Text(PaymentTerms.label(days)).tag(days)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Conditions par défaut (devis et factures)").font(.caption).foregroundStyle(.secondary)
                    TextField("Ex. Acompte de 30 % à la commande.", text: $profile.defaultConditions, axis: .vertical)
                        .lineLimit(2...6)
                }
            } header: {
                Text("Valeurs par défaut")
            }
        }
        .navigationTitle("Mon entreprise")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !loaded, let current = store.profile {
                profile = current
                loaded = true
            }
        }
        .onChange(of: profile) { _, newValue in
            if loaded { store.saveProfile(newValue) }
        }
    }
}

enum PaymentTerms {
    static let options = [0, 8, 15, 30, 45, 60]

    static func label(_ days: Int) -> String {
        days == 0 ? "À réception" : "\(days) jours"
    }
}

struct LogoSection: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @State private var item: PhotosPickerItem?
    @State private var showPaywall = false

    var body: some View {
        Section {
            HStack(spacing: 16) {
                Group {
                    if let data = store.logoData, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo").font(.title).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 72)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.tertiarySystemFill)))

                VStack(alignment: .leading, spacing: 8) {
                    if subscriptions.isPremium {
                        PhotosPicker(selection: $item, matching: .images) {
                            Text(store.logoData == nil ? "Ajouter un logo" : "Changer le logo")
                        }
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 6) {
                                Text("Ajouter un logo")
                                PremiumBadge()
                            }
                        }
                    }
                    if store.logoData != nil {
                        Button("Retirer", role: .destructive) { store.setLogo(nil) }
                            .font(.footnote)
                    }
                }
            }
            .buttonStyle(.borderless)
        } header: {
            Text("Logo")
        } footer: {
            Text(subscriptions.isPremium
                 ? "Votre logo apparaît en haut de chaque document."
                 : "Le logo personnalisé est inclus dans PapiersPro Illimité.")
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    store.setLogo(LogoProcessor.normalized(image))
                }
                item = nil
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView() }
    }
}

enum LogoProcessor {
    /// Downscales the logo to keep storage and PDF size small.
    static func normalized(_ image: UIImage, maxSide: CGFloat = 600) -> Data? {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.pngData()
    }
}

struct TradePickerSheet: View {
    @Environment(DocumentStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tous les métiers sont inclus dans votre abonnement. Les documents proposés s'adaptent au métier choisi.")
                        .foregroundStyle(.secondary)
                    TradeGrid(selection: Binding(
                        get: { store.profile?.trade },
                        set: { trade in
                            guard let trade, var p = store.profile else { return }
                            p.trade = trade
                            store.saveProfile(p)
                            dismiss()
                        }
                    ))
                }
                .padding(20)
            }
            .navigationTitle("Changer de métier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
