import SwiftUI
import UIKit

/// System share sheet (Mail, WhatsApp, Messages, AirDrop…) for an exported PDF.
struct ShareSheet: UIViewControllerRepresentable {
    let fileURL: URL
    let subject: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let item = PDFActivityItem(url: fileURL, subject: subject)
        return UIActivityViewController(activityItems: [item], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

final class PDFActivityItem: NSObject, UIActivityItemSource {
    let url: URL
    let subject: String

    init(url: URL, subject: String) {
        self.url = url
        self.subject = subject
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        subject
    }
}

struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
    let subject: String
}
