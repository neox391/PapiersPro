import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(DocumentStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        PremiumBadge()
                        Text("PapiersPro Illimité")
                            .font(.largeTitle.bold())
                        Text(store.remainingFreeDocuments() == 0
                             ? "Vous avez utilisé vos \(DocumentStore.freeDocumentsPerMonth) documents gratuits ce mois-ci."
                             : "La version gratuite permet \(DocumentStore.freeDocumentsPerMonth) documents par mois.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 12)

                    VStack(alignment: .leading, spacing: 18) {
                        benefit("infinity", "Documents illimités", "Devis, factures, contrats… sans limite mensuelle.")
                        benefit("photo.on.rectangle", "Logo personnalisé", "Votre logo en en-tête de chaque document.")
                        benefit("square.grid.2x2", "Tous les métiers", "Passez d'une activité à l'autre à tout moment.")
                        benefit("clock.arrow.circlepath", "Historique complet", "Dupliquez et modifiez vos documents.")
                    }
                    .padding(20)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))

                    VStack(spacing: 12) {
                        Button {
                            Task { await subscriptions.purchase() }
                        } label: {
                            if subscriptions.isLoading {
                                ProgressView().tint(.white)
                            } else if let product = subscriptions.product {
                                Text("S'abonner – \(product.displayPrice) / mois")
                            } else {
                                Text("S'abonner")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(subscriptions.isLoading)

                        Button("Restaurer mes achats") {
                            Task { await subscriptions.restore() }
                        }
                        .font(.subheadline)
                    }

                    if let error = subscriptions.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }

                    Text("Abonnement mensuel renouvelé automatiquement, sauf résiliation au moins 24 h avant la fin de la période en cours. Le paiement est débité sur votre compte Apple. Gérez ou résiliez votre abonnement dans les réglages de votre compte.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Link("Conditions d'utilisation", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("Confidentialité", destination: URL(string: "https://www.apple.com/legal/privacy/fr-ww/")!)
                    }
                    .font(.caption)
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .onChange(of: subscriptions.isPremium) { _, isPremium in
                if isPremium { dismiss() }
            }
        }
    }

    private func benefit(_ symbol: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
