import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PDFExporter {
    /// Renders every page as vector PDF data (A4).
    @MainActor
    static func render(_ ctx: DocumentContext) -> Data {
        let pages = DocumentPaginator.paginate(ctx)
        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: PageMetrics.width, height: PageMetrics.height)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, [
                kCGPDFContextTitle as String: "\(ctx.data.displayTitle) \(ctx.displayNumber)",
                kCGPDFContextCreator as String: "PapiersPro",
                kCGPDFContextAuthor as String: ctx.profile.displayName
              ] as CFDictionary)
        else { return Data() }

        for page in pages {
            let renderer = ImageRenderer(content: DocumentPageView(page: page, pageCount: pages.count, ctx: ctx))
            renderer.proposedSize = ProposedViewSize(width: PageMetrics.width, height: PageMetrics.height)
            pdf.beginPDFPage(nil)
            renderer.render { _, draw in
                draw(pdf)
            }
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return data as Data
    }

    static func fileName(for ctx: DocumentContext) -> String {
        let client = ctx.data.client.name.isEmpty ? "" : " – \(ctx.data.client.name)"
        let raw = "\(ctx.data.type.label) \(ctx.displayNumber)\(client)"
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return raw.components(separatedBy: invalid).joined(separator: "-") + ".pdf"
    }

    /// Writes the PDF in a temporary folder so it can be shared.
    @MainActor
    static func writeTemporaryFile(_ ctx: DocumentContext) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Export", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(fileName(for: ctx))
        try render(ctx).write(to: url, options: .atomic)
        return url
    }
}

enum PrintService {
    @MainActor
    static func print(_ ctx: DocumentContext) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = "\(ctx.data.displayTitle) \(ctx.displayNumber)"
        controller.printInfo = info
        controller.printingItem = PDFExporter.render(ctx)
        if UIDevice.current.userInterfaceIdiom == .pad,
           let view = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController?.view {
            let rect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 80, width: 1, height: 1)
            controller.present(from: rect, in: view, animated: true, completionHandler: nil)
        } else {
            controller.present(animated: true, completionHandler: nil)
        }
    }
}

struct PDFFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
