import SwiftUI

struct HomeView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var editorRequest: EditorRequest?
    @State private var showPaywall = false
    @State private var showTradePicker = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        let profile = store.profile ?? BusinessProfile()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(profile)

                    if !subscriptions.isPremium {
                        usageCard
                    }

                    if profile.companyId.isEmpty {
                        NavigationLink {
                            CompanySettingsView()
                        } label: {
                            Label("Complétez votre \(profile.country.companyIdLabel) pour des documents conformes", systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Créer un document")
                        .font(.title3.bold())

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(profile.trade.documents) { type in
                            Button {
                                create(type, profile: profile)
                            } label: {
                                DocumentTypeCard(type: type)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !store.documents.isEmpty {
                        recent
                    }

                    DisclaimerNote()
                        .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PapiersPro")
            .fullScreenCover(item: $editorRequest) { request in
                DocumentEditorView(request: request)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showTradePicker) {
                TradePickerSheet()
            }
        }
    }

    private func header(_ profile: BusinessProfile) -> some View {
        HStack(spacing: 14) {
            Image(systemName: profile.trade.symbol)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName).font(.headline).lineLimit(1)
                Text("\(profile.trade.label) · \(profile.country.flag) \(profile.country.label)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                if subscriptions.isPremium { showTradePicker = true } else { showPaywall = true }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Changer de métier")
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var usageCard: some View {
        let used = min(store.documentsCreated(), DocumentStore.freeDocumentsPerMonth)
        let remaining = store.remainingFreeDocuments()
        return Button {
            showPaywall = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(remaining > 0
                         ? "\(remaining) document\(remaining > 1 ? "s" : "") gratuit\(remaining > 1 ? "s" : "") restant\(remaining > 1 ? "s" : "") ce mois-ci"
                         : "Limite gratuite atteinte ce mois-ci")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    PremiumBadge()
                }
                ProgressView(value: Double(used), total: Double(DocumentStore.freeDocumentsPerMonth))
                    .tint(remaining > 0 ? Color.accentColor : .orange)
                Text("Passez à Illimité : documents sans limite, logo et tous les métiers.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Récents").font(.title3.bold())
            VStack(spacing: 0) {
                ForEach(store.documents.prefix(3)) { doc in
                    Button {
                        editorRequest = EditorRequest(data: doc.data, documentId: doc.id)
                    } label: {
                        DocumentRow(document: doc)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if doc.id != store.documents.prefix(3).last?.id {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        }
    }

    private func create(_ type: DocumentType, profile: BusinessProfile) {
        guard store.canCreateDocument(isPremium: subscriptions.isPremium) else {
            showPaywall = true
            return
        }
        editorRequest = EditorRequest(data: DocumentRules.newDocument(type, profile: profile), documentId: nil)
    }
}

struct DocumentTypeCard: View {
    let type: DocumentType

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: type.symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
            Text(type.label)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(type.shortDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(Rectangle())
    }
}

struct DocumentRow: View {
    @Environment(DocumentStore.self) private var store
    let document: SavedDocument

    var body: some View {
        let data = document.data
        HStack(spacing: 12) {
            Image(systemName: data.type.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(data.type.label) \(data.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(data.client.name.isEmpty ? "Sans client" : data.client.name)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if data.type.hasLineItems {
                    Text(data.country.money(DocumentRules.totals(for: data, profile: store.profile ?? BusinessProfile()).total))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.primary)
                }
                Text(data.country.date(data.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}
