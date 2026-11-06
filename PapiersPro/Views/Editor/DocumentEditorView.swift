import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct DocumentEditorView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(SubscriptionManager.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var data: DocumentData
    @State private var documentId: UUID?
    @State private var savedSnapshot: DocumentData?
    @State private var logoImage: UIImage?
    @State private var showFullPreview = false
    @State private var showDiscardConfirmation = false
    @State private var shareItem: ShareItem?
    @State private var exportFile: PDFFileDocument?
    @State private var exportName = "Document"
    @State private var showExporter = false
    @State private var exportMessage: String?

    init(request: EditorRequest) {
        _data = State(initialValue: request.data)
        _documentId = State(initialValue: request.documentId)
        _savedSnapshot = State(initialValue: request.documentId == nil ? nil : request.data)
    }

    private var profile: BusinessProfile { store.profile ?? BusinessProfile() }

    private var context: DocumentContext {
        let number = data.number.isEmpty ? store.nextNumber(for: data.type, date: data.date) : data.number
        return DocumentContext(data: data, profile: profile, logo: subscriptions.isPremium ? logoImage : nil, displayNumber: number)
    }

    private var hasUnsavedChanges: Bool { savedSnapshot != data }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    HStack(spacing: 0) {
                        DocumentForm(data: $data, profile: profile, recentClients: store.recentClients, isNew: documentId == nil)
                            .frame(maxWidth: 480)
                        Divider()
                        GeometryReader { proxy in
                            ScrollView {
                                DocumentPreview(ctx: context, width: min(proxy.size.width - 48, 700))
                                    .frame(maxWidth: .infinity)
                                    .padding(24)
                            }
                            .background(Color(.systemGroupedBackground))
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        compactPreview
                        Divider()
                        DocumentForm(data: $data, profile: profile, recentClients: store.recentClients, isNew: documentId == nil)
                    }
                }
            }
            .navigationTitle(data.number.isEmpty ? data.type.label : data.number)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        if hasUnsavedChanges { showDiscardConfirmation = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        persist()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { Keyboard.dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { actionBar }
            .confirmationDialog("Enregistrer les modifications ?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
                Button("Enregistrer") {
                    persist()
                    dismiss()
                }
                Button("Ne pas enregistrer", role: .destructive) { dismiss() }
                Button("Continuer l'édition", role: .cancel) {}
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(fileURL: item.url, subject: item.subject)
                    .presentationDetents([.medium, .large])
            }
            .fileExporter(isPresented: $showExporter, document: exportFile, contentType: .pdf, defaultFilename: exportName) { result in
                if case .success = result { exportMessage = "PDF enregistré dans Fichiers." }
            }
            .fullScreenCover(isPresented: $showFullPreview) {
                FullPreviewView(ctx: context)
            }
            .alert(exportMessage ?? "", isPresented: Binding(get: { exportMessage != nil }, set: { if !$0 { exportMessage = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                if logoImage == nil, let logo = store.logoData { logoImage = UIImage(data: logo) }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
    }

    // MARK: Preview

    private var compactPreview: some View {
        let ctx = context
        let pages = DocumentPaginator.paginate(ctx)
        let height: CGFloat = 230
        let scale = height / PageMetrics.height
        return ZStack(alignment: .bottomTrailing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(pages) { page in
                        DocumentPageView(page: page, pageCount: pages.count, ctx: ctx)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(width: PageMetrics.width * scale, height: height, alignment: .topLeading)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onTapGesture { showFullPreview = true }

            Button {
                showFullPreview = true
            } label: {
                Label("Agrandir", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.thinMaterial, in: Capsule())
            }
            .padding(10)
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Aperçu du document")
    }

    // MARK: Actions

    private var actionBar: some View {
        HStack(spacing: 10) {
            actionButton("Imprimer", "printer") {
                persist()
                PrintService.print(context)
            }
            actionButton("PDF", "arrow.down.doc") {
                persist()
                let ctx = context
                exportName = PDFExporter.fileName(for: ctx).replacingOccurrences(of: ".pdf", with: "")
                exportFile = PDFFileDocument(data: PDFExporter.render(ctx))
                showExporter = true
            }
            actionButton("Partager", "square.and.arrow.up") {
                persist()
                let ctx = context
                do {
                    let url = try PDFExporter.writeTemporaryFile(ctx)
                    let subject = "\(ctx.data.displayTitle) \(ctx.displayNumber) – \(ctx.profile.displayName)"
                    shareItem = ShareItem(url: url, subject: subject)
                } catch {
                    exportMessage = "Impossible de préparer le PDF."
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.bar)
    }

    private func actionButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.accentColor.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    /// Saves the document; a new document gets its definitive number here.
    private func persist() {
        Keyboard.dismiss()
        let saved = store.save(data, id: documentId)
        documentId = saved.id
        data = saved.data
        savedSnapshot = saved.data
    }
}

struct FullPreviewView: View {
    let ctx: DocumentContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView([.vertical]) {
                    DocumentPreview(ctx: ctx, width: max(200, min(proxy.size.width - 32, 800)))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Aperçu A4")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }
}
