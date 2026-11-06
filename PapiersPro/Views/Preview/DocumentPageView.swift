import SwiftUI

/// One A4 page drawn at 1 point = 1 PDF point. Always light, like paper.
struct DocumentPageView: View {
    let page: DocumentPage
    let pageCount: Int
    let ctx: DocumentContext

    static let ink = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)
    static let accent = Color(red: 0.18, green: 0.42, blue: 0.88)
    static let tint = Color(red: 0.95, green: 0.96, blue: 0.98)
    static let rule = Color(red: 0.86, green: 0.88, blue: 0.91)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(page.blocks) { placed in
                blockView(placed.block)
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(PageMetrics.margin)
        .frame(width: PageMetrics.width, height: PageMetrics.height, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Self.ink)
        .environment(\.colorScheme, .light)
        .clipped()
    }

    @ViewBuilder
    private func blockView(_ block: DocumentBlock) -> some View {
        switch block {
        case .header: header
        case .parties: parties
        case .details(let rows): details(rows)
        case .sectionTitle(let title): sectionTitle(title)
        case .paragraph(let text): paragraph(text)
        case .tableHeader: tableHeader
        case .row(let line): row(line)
        case .totals: totals
        case .note(let title, let text): note(title: title, text: text)
        case .signatures: signatures
        case .mentions(let items): mentions(items)
        }
    }

    private func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    if let logo = ctx.logo {
                        Image(uiImage: logo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 140, maxHeight: 50, alignment: .leading)
                            .padding(.bottom, 8)
                    }
                    Text(ctx.profile.displayName.isEmpty ? "Votre entreprise" : ctx.profile.displayName)
                        .font(font(DocFont.company, .semibold))
                        .padding(.bottom, 3)
                    ForEach(ctx.providerLines + ctx.identity, id: \.self) { line in
                        Text(line).font(font(DocFont.small)).foregroundStyle(Self.muted)
                    }
                }
                .frame(width: PageMetrics.contentWidth * 0.55, alignment: .leading)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(ctx.data.displayTitle.uppercased())
                        .font(font(DocFont.title, .bold))
                        .foregroundStyle(Self.accent)
                        .multilineTextAlignment(.trailing)
                    Text("N° \(ctx.displayNumber)").font(font(DocFont.body, .semibold))
                    Text("Date : \(ctx.country.date(ctx.data.date))").font(font(DocFont.body))
                }
                .frame(width: PageMetrics.contentWidth * 0.42, alignment: .trailing)
            }
            Rectangle().fill(Self.rule).frame(height: 1).padding(.top, 12).padding(.bottom, 9)
        }
    }

    // MARK: Parties

    private var parties: some View {
        HStack(alignment: .top, spacing: 0) {
            if ctx.data.type == .contrat {
                partyBox(title: "LE PRESTATAIRE", name: ctx.profile.displayName, lines: ctx.providerLines)
            }
            Spacer(minLength: 0)
            partyBox(title: ctx.data.type.clientSectionTitle.uppercased(), name: ctx.data.client.name, lines: ctx.clientLines)
        }
        .padding(.bottom, 14)
    }

    private func partyBox(title: String, name: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(font(7, .semibold)).foregroundStyle(Self.muted).padding(.bottom, 3)
            Text(name.isEmpty ? "—" : name).font(font(DocFont.body + 1, .semibold)).padding(.bottom, 2)
            ForEach(lines, id: \.self) { line in
                Text(line).font(font(DocFont.small))
            }
        }
        .padding(10)
        .frame(width: PageMetrics.contentWidth * 0.46, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(Self.tint))
    }

    // MARK: Body

    private func details(_ rows: [InfoRow]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(rows, id: \.self) { row in
                HStack(alignment: .top, spacing: 8) {
                    Text(row.label).font(font(DocFont.body, .semibold)).foregroundStyle(Self.muted)
                        .frame(width: 122, alignment: .leading)
                    Text(row.value).font(font(DocFont.body))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.bottom, 14)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(font(DocFont.section, .semibold))
            .foregroundStyle(Self.accent)
            .frame(height: 22, alignment: .topLeading)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(font(DocFont.body))
            .lineSpacing(0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }

    private func note(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.uppercased()).font(font(7, .semibold)).foregroundStyle(Self.muted)
            Text(text).font(font(DocFont.body))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 12)
    }

    // MARK: Table

    private var showsHT: Bool { !DocumentRules.effectiveTaxRate(ctx.data, profile: ctx.profile).isExempt }

    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Désignation").frame(width: PageMetrics.descriptionColumn, alignment: .leading)
            Text("Qté").frame(width: PageMetrics.quantityColumn, alignment: .trailing)
            Text("Unité").frame(width: PageMetrics.unitColumn, alignment: .center)
            Text(showsHT ? "P.U. HT" : "P.U.").frame(width: PageMetrics.priceColumn, alignment: .trailing)
            Text(showsHT ? "Total HT" : "Total").frame(width: PageMetrics.totalColumn, alignment: .trailing)
        }
        .font(font(DocFont.small, .semibold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 6)
        .frame(width: PageMetrics.contentWidth, height: 22)
        .background(RoundedRectangle(cornerRadius: 4).fill(Self.accent))
    }

    private func row(_ line: LineItem) -> some View {
        let c = ctx.country
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                Text(line.description)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: PageMetrics.descriptionColumn - 6, alignment: .leading)
                    .padding(.trailing, 6)
                Text(c.number(line.quantity)).frame(width: PageMetrics.quantityColumn, alignment: .trailing)
                Text(line.unit).frame(width: PageMetrics.unitColumn, alignment: .center)
                Text(c.money(line.unitPrice)).frame(width: PageMetrics.priceColumn, alignment: .trailing)
                Text(c.money(line.total)).frame(width: PageMetrics.totalColumn, alignment: .trailing)
            }
            .font(font(DocFont.body))
            .padding(.horizontal, 6)
            .padding(.vertical, 4.5)
            Rectangle().fill(Self.rule).frame(height: 0.5)
        }
        .frame(width: PageMetrics.contentWidth)
    }

    private var totals: some View {
        let c = ctx.country
        let t = ctx.totals
        return HStack {
            Spacer()
            VStack(spacing: 0) {
                if showsHT {
                    totalRow("Total HT", c.money(t.subtotal))
                    ForEach(t.taxes) { tax in totalRow(tax.name, c.money(tax.amount)) }
                    totalRow("Total TTC", c.money(t.total), emphasized: true)
                } else {
                    totalRow("Sous-total", c.money(t.subtotal))
                    totalRow("Total", c.money(t.total), emphasized: true)
                }
                if let deposit = t.deposit {
                    totalRow("Acompte \(ctx.data.depositPercent) %", c.money(deposit))
                }
            }
            .frame(width: 220)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private func totalRow(_ label: String, _ value: String, emphasized: Bool = false) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
        }
        .font(font(emphasized ? DocFont.body + 1.5 : DocFont.body, emphasized ? .bold : .regular))
        .foregroundStyle(emphasized ? Color.white : Self.ink)
        .padding(.horizontal, 8)
        .frame(height: emphasized ? 20 : 16)
        .background(RoundedRectangle(cornerRadius: 4).fill(emphasized ? Self.accent : Color.clear))
    }

    // MARK: Signatures & mentions

    private var signatures: some View {
        let type = ctx.data.type
        return VStack(alignment: .leading, spacing: 6) {
            Text(ctx.placeAndDate).font(font(DocFont.small)).foregroundStyle(Self.muted)
            HStack(alignment: .top, spacing: 16) {
                if let provider = type.providerSignatureLabel {
                    signatureBox(provider)
                } else {
                    Spacer().frame(width: PageMetrics.contentWidth * 0.46)
                }
                Spacer(minLength: 0)
                if let client = type.clientSignatureLabel {
                    signatureBox(client)
                }
            }
        }
        .padding(.bottom, 10)
    }

    private func signatureBox(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(font(DocFont.small, .semibold)).foregroundStyle(Self.muted)
            RoundedRectangle(cornerRadius: 6)
                .stroke(Self.rule, lineWidth: 1)
                .frame(height: 62)
        }
        .frame(width: PageMetrics.contentWidth * 0.46)
    }

    private func mentions(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(font(DocFont.mention))
                    .foregroundStyle(Self.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private var footer: some View {
        HStack {
            let id = ctx.profile.companyId.isEmpty ? "" : " · \(ctx.country.companyIdLabel) \(ctx.profile.companyId)"
            Text(ctx.profile.displayName + id)
            Spacer()
            Text("Page \(page.id + 1) / \(pageCount)")
        }
        .font(font(7))
        .foregroundStyle(Self.muted)
        .frame(height: PageMetrics.footerHeight, alignment: .bottom)
    }
}

/// Scaled stack of all pages for on-screen preview.
struct DocumentPreview: View {
    let ctx: DocumentContext
    var width: CGFloat

    var body: some View {
        let pages = DocumentPaginator.paginate(ctx)
        let scale = width / PageMetrics.width
        VStack(spacing: 12) {
            ForEach(pages) { page in
                DocumentPageView(page: page, pageCount: pages.count, ctx: ctx)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: PageMetrics.width * scale, height: PageMetrics.height * scale, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 4 * max(scale, 0.5)))
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
            }
        }
    }
}
