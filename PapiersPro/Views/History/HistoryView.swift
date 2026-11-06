import SwiftUI

struct HistoryView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var search = ""
    @State private var typeFilter: DocumentType?
    @State private var editorRequest: EditorRequest?
    @State private var showPaywall = false
    @State private var pendingDeletion: SavedDocument?

    private var filtered: [SavedDocument] {
        store.documents.filter { doc in
            if let typeFilter, doc.data.type != typeFilter { return false }
            guard !search.isEmpty else { return true }
            let haystack = "\(doc.data.number) \(doc.data.client.name) \(doc.data.displayTitle) \(doc.data.lines.map(\.description).joined(separator: " "))"
            return haystack.localizedCaseInsensitiveContains(search)
        }
    }

    private var sections: [HistorySection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { doc in
            calendar.dateComponents([.year, .month], from: doc.data.date)
        }
        return grouped
            .sorted { lhs, rhs in
                (lhs.key.year ?? 0, lhs.key.month ?? 0) > (rhs.key.year ?? 0, rhs.key.month ?? 0)
            }
            .map { key, docs in
                let date = calendar.date(from: key) ?? .now
                let title = date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized
                return HistorySection(title: title, documents: docs.sorted { ($0.data.date, $0.data.number) > ($1.data.date, $1.data.number) })
            }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { section in
                    Section(section.title) {
                        ForEach(section.documents) { doc in
                            Button {
                                editorRequest = EditorRequest(data: doc.data, documentId: doc.id)
                            } label: {
                                DocumentRow(document: doc)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = doc
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                                Button {
                                    duplicate(doc)
                                } label: {
                                    Label("Dupliquer", systemImage: "plus.square.on.square")
                                }
                                .tint(.indigo)
                            }
                            .contextMenu {
                                Button {
                                    editorRequest = EditorRequest(data: doc.data, documentId: doc.id)
                                } label: {
                                    Label("Modifier", systemImage: "pencil")
                                }
                                Button {
                                    duplicate(doc)
                                } label: {
                                    Label("Dupliquer", systemImage: "plus.square.on.square")
                                }
                                if doc.data.type == .devis {
                                    Button {
                                        duplicate(doc, as: .facture)
                                    } label: {
                                        Label("Transformer en facture", systemImage: "arrow.right.doc.on.clipboard")
                                    }
                                }
                                Divider()
                                Button(role: .destructive) {
                                    pendingDeletion = doc
                                } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .overlay {
                if store.documents.isEmpty {
                    ContentUnavailableView(
                        "Aucun document",
                        systemImage: "doc.on.doc",
                        description: Text("Les documents que vous créez apparaîtront ici. Vous pourrez les modifier ou les dupliquer.")
                    )
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .searchable(text: $search, prompt: "Client, numéro, prestation…")
            .navigationTitle("Historique")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Type", selection: $typeFilter) {
                            Text("Tous les documents").tag(DocumentType?.none)
                            ForEach(DocumentType.allCases) { type in
                                Label(type.label, systemImage: type.symbol).tag(DocumentType?.some(type))
                            }
                        }
                    } label: {
                        Image(systemName: typeFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel("Filtrer")
                }
            }
            .confirmationDialog(
                "Supprimer ce document ?",
                isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { doc in
                Button("Supprimer", role: .destructive) {
                    store.delete(id: doc.id)
                }
            } message: { doc in
                Text("\(doc.data.type.label) \(doc.data.number) sera supprimé de l'historique. Son numéro ne sera pas réattribué.")
            }
            .fullScreenCover(item: $editorRequest) { request in
                DocumentEditorView(request: request)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func duplicate(_ doc: SavedDocument, as type: DocumentType? = nil) {
        guard let profile = store.profile else { return }
        guard store.canCreateDocument(isPremium: subscriptions.isPremium) else {
            showPaywall = true
            return
        }
        let copy = DocumentRules.duplicate(doc.data, as: type, profile: profile)
        editorRequest = EditorRequest(data: copy, documentId: nil)
    }
}

struct HistorySection: Identifiable {
    var id: String { title }
    let title: String
    let documents: [SavedDocument]
}
