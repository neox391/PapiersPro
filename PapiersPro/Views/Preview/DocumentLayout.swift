import SwiftUI
import UIKit

enum PageMetrics {
    static let width: CGFloat = 595.28
    static let height: CGFloat = 841.89
    static let margin: CGFloat = 40
    static let footerHeight: CGFloat = 28
    static var contentWidth: CGFloat { width - margin * 2 }
    static var contentHeight: CGFloat { height - margin * 2 - footerHeight }

    static let descriptionColumn: CGFloat = 250
    static let quantityColumn: CGFloat = 52
    static let unitColumn: CGFloat = 52
    static let priceColumn: CGFloat = 78
    static var totalColumn: CGFloat { contentWidth - descriptionColumn - quantityColumn - unitColumn - priceColumn }
}

enum DocFont {
    static let title: CGFloat = 20
    static let company: CGFloat = 13
    static let body: CGFloat = 9
    static let small: CGFloat = 8
    static let mention: CGFloat = 7
    static let section: CGFloat = 9.5
}

enum TextMeasure {
    static func height(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height) + 1
    }
}

struct InfoRow: Hashable {
    let label: String
    let value: String
}

enum DocumentBlock: Hashable {
    case header
    case parties
    case details([InfoRow])
    case sectionTitle(String)
    case paragraph(String)
    case tableHeader
    case row(LineItem)
    case totals
    case note(title: String, text: String)
    case signatures
    case mentions([String])
}

struct PlacedBlock: Identifiable, Hashable {
    let id: Int
    let block: DocumentBlock
}

struct DocumentPage: Identifiable, Hashable {
    let id: Int
    var blocks: [PlacedBlock]
}

/// All values needed to draw a document.
struct DocumentContext {
    let data: DocumentData
    let profile: BusinessProfile
    let logo: UIImage?
    let displayNumber: String
    let totals: DocumentTotals
    let mentions: [String]
    let identity: [String]

    init(data: DocumentData, profile: BusinessProfile, logo: UIImage?, displayNumber: String) {
        self.data = data
        self.profile = profile
        self.logo = logo
        self.displayNumber = displayNumber
        self.totals = DocumentRules.totals(for: data, profile: profile)
        self.mentions = DocumentRules.legalMentions(for: data, profile: profile)
        self.identity = DocumentRules.providerIdentity(profile)
    }

    var country: Country { data.country }
    var config: FormConfiguration { DocumentRules.configuration(for: data.type, trade: data.trade, country: data.country) }

    var printableLines: [LineItem] {
        data.lines.filter { !$0.description.trimmingCharacters(in: .whitespaces).isEmpty || $0.unitPrice != 0 }
    }

    var contactLines: [String] {
        [profile.phone, profile.email, profile.website].filter { !$0.isEmpty }
    }

    var clientLines: [String] {
        var lines = data.client.addressLines
        if data.client.isProfessional {
            if !data.client.companyId.isEmpty { lines.append("\(country.companyIdLabel) : \(data.client.companyId)") }
            if !data.client.vatNumber.isEmpty { lines.append("\(country.vatNumberLabel) : \(data.client.vatNumber)") }
        }
        lines.append(contentsOf: [data.client.phone, data.client.email].filter { !$0.isEmpty })
        return lines
    }

    var providerLines: [String] {
        profile.addressLines + contactLines
    }

    var detailRows: [InfoRow] {
        let d = data
        let c = country
        let cfg = config
        var rows: [InfoRow] = []
        if cfg.showsQuoteReference && !d.quoteReference.isEmpty {
            rows.append(InfoRow(label: "Réf. devis", value: d.quoteReference))
        }
        if cfg.showsValidity {
            rows.append(InfoRow(label: "Valable jusqu'au", value: c.date(d.validUntil)))
        }
        if d.type == .facture {
            rows.append(InfoRow(label: "Échéance", value: d.paymentDays == 0 ? "À réception" : c.date(d.dueDate)))
        }
        if cfg.showsPeriod {
            rows.append(InfoRow(label: "Période", value: "du \(c.date(d.startDate)) au \(c.date(d.endDate))"))
        }
        if cfg.showsSite && !d.siteAddress.isEmpty {
            rows.append(InfoRow(label: "Adresse du chantier", value: d.siteAddress))
        }
        if cfg.showsIntervention {
            if !d.siteAddress.isEmpty { rows.append(InfoRow(label: "Lieu d'intervention", value: d.siteAddress)) }
            rows.append(InfoRow(label: "Date", value: c.longDate(d.interventionStart)))
            rows.append(InfoRow(label: "Horaires", value: "de \(c.time(d.interventionStart)) à \(c.time(d.interventionEnd))"))
            if !d.technician.isEmpty { rows.append(InfoRow(label: "Intervenant", value: d.technician)) }
        }
        if cfg.showsRide {
            rows.append(InfoRow(label: "Date de la course", value: c.dateTime(d.rideDate)))
            if !d.pickupAddress.isEmpty { rows.append(InfoRow(label: "Prise en charge", value: d.pickupAddress)) }
            if !d.dropoffAddress.isEmpty { rows.append(InfoRow(label: "Destination", value: d.dropoffAddress)) }
            if !d.vehiclePlate.isEmpty { rows.append(InfoRow(label: "Véhicule", value: d.vehiclePlate)) }
        }
        if cfg.showsSession {
            rows.append(InfoRow(label: "Date de la séance", value: c.longDate(d.sessionDate)))
            if !d.sessionPlace.isEmpty { rows.append(InfoRow(label: "Lieu", value: d.sessionPlace)) }
        }
        if cfg.showsCovers && d.covers > 0 {
            rows.append(InfoRow(label: "Couverts", value: "\(d.covers)"))
        }
        if cfg.showsDelivery {
            rows.append(InfoRow(label: "Livraison prévue", value: c.date(d.deliveryDate)))
            if !d.deliveryAddress.isEmpty { rows.append(InfoRow(label: "Adresse de livraison", value: d.deliveryAddress)) }
        }
        return rows
    }

    var paymentText: String {
        let d = data
        var parts: [String] = []
        switch d.type {
        case .recu:
            parts.append("Somme de \(country.money(totals.total)) reçue le \(country.date(d.date)) par \(d.paymentMethod.label.lowercased()).")
        case .facture:
            parts.append("Mode de paiement : \(d.paymentMethod.label).")
            if d.paymentDays > 0 {
                parts.append("Paiement à \(d.paymentDays) jours, au plus tard le \(country.date(d.dueDate)).")
            } else {
                parts.append("Paiement à réception de la facture.")
            }
        case .contrat, .bonDeCommande:
            if d.paymentDays > 0 {
                parts.append("Paiement à \(d.paymentDays) jours à compter de la date de facturation.")
            }
        default:
            break
        }
        if [.facture, .contrat, .bonDeCommande].contains(d.type) && !profile.iban.isEmpty {
            var bank = "\(country.bankLabel) : \(profile.iban)"
            if country.showsBIC && !profile.bic.isEmpty { bank += " – BIC : \(profile.bic)" }
            parts.append(bank)
        }
        return parts.joined(separator: "\n")
    }

    var placeAndDate: String {
        let city = profile.city.isEmpty ? "" : "Fait à \(profile.city), "
        return city + "le \(country.longDate(data.date))"
    }
}

enum DocumentPaginator {
    static func blocks(for ctx: DocumentContext) -> [DocumentBlock] {
        let d = ctx.data
        let cfg = ctx.config
        var blocks: [DocumentBlock] = [.header, .parties]

        let rows = ctx.detailRows
        if !rows.isEmpty { blocks.append(.details(rows)) }

        if cfg.showsBody && !d.bodyText.isEmpty {
            for paragraph in d.bodyText.components(separatedBy: "\n\n") where !paragraph.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                blocks.append(.paragraph(paragraph))
            }
        }
        if cfg.showsIntervention && !d.workDescription.isEmpty {
            blocks.append(.note(title: "Travaux réalisés", text: d.workDescription))
        }
        if cfg.showsRights && !d.rightsUsage.isEmpty {
            blocks.append(.note(title: "Droits d'utilisation cédés", text: d.rightsUsage))
        }
        if cfg.showsLines && !ctx.printableLines.isEmpty {
            if d.type == .contrat || d.type == .ficheIntervention {
                blocks.append(.sectionTitle(d.type.linesSectionTitle))
            }
            blocks.append(.tableHeader)
            blocks.append(contentsOf: ctx.printableLines.map { .row($0) })
            blocks.append(.totals)
        }
        let payment = ctx.paymentText
        if !payment.isEmpty { blocks.append(.note(title: "Règlement", text: payment)) }
        if cfg.showsConditions && !d.conditions.isEmpty {
            blocks.append(.note(title: "Conditions", text: d.conditions))
        }
        if !d.notes.isEmpty { blocks.append(.note(title: "Remarques", text: d.notes)) }
        if d.type.clientSignatureLabel != nil || d.type.providerSignatureLabel != nil {
            blocks.append(.signatures)
        }
        if !ctx.mentions.isEmpty { blocks.append(.mentions(ctx.mentions)) }
        return blocks
    }

    static func height(of block: DocumentBlock, ctx: DocumentContext) -> CGFloat {
        let w = PageMetrics.contentWidth
        switch block {
        case .header:
            let leftWidth = w * 0.55
            var left: CGFloat = ctx.logo != nil ? 58 : 0
            left += TextMeasure.height(ctx.profile.displayName, size: DocFont.company, weight: .semibold, width: leftWidth) + 4
            for line in ctx.providerLines + ctx.identity {
                left += TextMeasure.height(line, size: DocFont.small, width: leftWidth) + 1
            }
            let right = TextMeasure.height(ctx.data.displayTitle, size: DocFont.title, weight: .bold, width: w * 0.42) + 44
            return max(left, right) + 22
        case .parties:
            let boxWidth = w * 0.46 - 20
            func box(_ name: String, _ lines: [String]) -> CGFloat {
                var h: CGFloat = 14 + TextMeasure.height(name.isEmpty ? " " : name, size: DocFont.body + 1, weight: .semibold, width: boxWidth)
                for line in lines { h += TextMeasure.height(line, size: DocFont.small, width: boxWidth) + 1 }
                return h + 20
            }
            let client = box(ctx.data.client.name, ctx.clientLines)
            if ctx.data.type == .contrat {
                return max(client, box(ctx.profile.displayName, ctx.providerLines)) + 14
            }
            return client + 14
        case .details(let rows):
            var h: CGFloat = 0
            for row in rows {
                h += TextMeasure.height(row.value, size: DocFont.body, width: w - 130) + 4
            }
            return h + 14
        case .sectionTitle:
            return 22
        case .paragraph(let text):
            return TextMeasure.height(text, size: DocFont.body, width: w) + 8
        case .tableHeader:
            return 22
        case .row(let line):
            return TextMeasure.height(line.description.isEmpty ? " " : line.description, size: DocFont.body, width: PageMetrics.descriptionColumn - 12) + 10
        case .totals:
            var count = 2 + ctx.totals.taxes.count
            if ctx.totals.deposit != nil { count += 1 }
            return CGFloat(count) * 16 + 18
        case .note(_, let text):
            return 14 + TextMeasure.height(text, size: DocFont.body, width: w) + 12
        case .signatures:
            return 104
        case .mentions(let items):
            var h: CGFloat = 10
            for item in items { h += TextMeasure.height(item, size: DocFont.mention, width: w) + 2 }
            return h
        }
    }

    static func paginate(_ ctx: DocumentContext) -> [DocumentPage] {
        let available = PageMetrics.contentHeight
        var pages: [DocumentPage] = []
        var current: [PlacedBlock] = []
        var used: CGFloat = 0
        var nextId = 0

        func place(_ block: DocumentBlock) {
            current.append(PlacedBlock(id: nextId, block: block))
            nextId += 1
        }

        for block in blocks(for: ctx) {
            let h = height(of: block, ctx: ctx)
            if used + h > available && !current.isEmpty {
                pages.append(DocumentPage(id: pages.count, blocks: current))
                current = []
                used = 0
                if case .row = block {
                    place(.tableHeader)
                    used += height(of: .tableHeader, ctx: ctx)
                }
            }
            place(block)
            used += h
        }
        if !current.isEmpty || pages.isEmpty {
            pages.append(DocumentPage(id: pages.count, blocks: current))
        }
        return pages
    }
}
