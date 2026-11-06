import Foundation

extension Decimal {
    /// Exact decimal percentage, e.g. `.percent("5.5")` == 0.055.
    static func percent(_ value: String) -> Decimal {
        (Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) ?? 0) / 100
    }
}

struct TaxComponent: Codable, Hashable {
    var name: String
    var rate: Decimal
}

struct TaxRate: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var components: [TaxComponent]

    var totalRate: Decimal { components.reduce(0) { $0 + $1.rate } }
    var isExempt: Bool { components.allSatisfy { $0.rate == 0 } }

    static let exempt = TaxRate(id: "exempt", label: "Sans TVA", components: [])
}

enum Country: String, CaseIterable, Codable, Identifiable, Hashable {
    case france, belgique, suisse, quebec

    var id: String { rawValue }

    var label: String {
        switch self {
        case .france: return "France"
        case .belgique: return "Belgique"
        case .suisse: return "Suisse"
        case .quebec: return "Québec"
        }
    }

    var flag: String {
        switch self {
        case .france: return "🇫🇷"
        case .belgique: return "🇧🇪"
        case .suisse: return "🇨🇭"
        case .quebec: return "🇨🇦"
        }
    }

    var currencyCode: String {
        switch self {
        case .france, .belgique: return "EUR"
        case .suisse: return "CHF"
        case .quebec: return "CAD"
        }
    }

    var locale: Locale {
        switch self {
        case .france: return Locale(identifier: "fr_FR")
        case .belgique: return Locale(identifier: "fr_BE")
        case .suisse: return Locale(identifier: "fr_CH")
        case .quebec: return Locale(identifier: "fr_CA")
        }
    }

    var companyIdLabel: String {
        switch self {
        case .france: return "SIRET"
        case .belgique: return "N° d'entreprise (BCE)"
        case .suisse: return "IDE"
        case .quebec: return "NEQ"
        }
    }

    var companyIdPlaceholder: String {
        switch self {
        case .france: return "123 456 789 00012"
        case .belgique: return "0123.456.789"
        case .suisse: return "CHE-123.456.789"
        case .quebec: return "1234567890"
        }
    }

    var vatNumberLabel: String {
        switch self {
        case .france: return "N° TVA intracommunautaire"
        case .belgique: return "N° TVA"
        case .suisse: return "N° TVA"
        case .quebec: return "N° TPS / N° TVQ"
        }
    }

    var vatNumberPlaceholder: String {
        switch self {
        case .france: return "FR12 123456789"
        case .belgique: return "BE0123.456.789"
        case .suisse: return "CHE-123.456.789 TVA"
        case .quebec: return "123456789 RT0001 / 1234567890 TQ0001"
        }
    }

    var taxName: String { self == .quebec ? "Taxes" : "TVA" }

    var bankLabel: String { self == .quebec ? "Coordonnées bancaires" : "IBAN" }

    var bankPlaceholder: String {
        switch self {
        case .france: return "FR76 3000 6000 0112 3456 7890 189"
        case .belgique: return "BE68 5390 0754 7034"
        case .suisse: return "CH93 0076 2011 6238 5295 7"
        case .quebec: return "Transit 12345 – Inst. 815 – Compte 1234567"
        }
    }

    var showsBIC: Bool { self != .quebec }

    var vatExemptLabel: String {
        switch self {
        case .france: return "Franchise en base de TVA (pas de TVA facturée)"
        case .belgique: return "Régime de franchise des petites entreprises"
        case .suisse: return "Non assujetti à la TVA"
        case .quebec: return "Petit fournisseur (non inscrit TPS/TVQ)"
        }
    }

    var taxRates: [TaxRate] {
        switch self {
        case .france:
            return [
                TaxRate(id: "fr20", label: "TVA 20 %", components: [TaxComponent(name: "TVA 20 %", rate: .percent("20"))]),
                TaxRate(id: "fr10", label: "TVA 10 %", components: [TaxComponent(name: "TVA 10 %", rate: .percent("10"))]),
                TaxRate(id: "fr55", label: "TVA 5,5 %", components: [TaxComponent(name: "TVA 5,5 %", rate: .percent("5.5"))]),
                TaxRate(id: "fr21", label: "TVA 2,1 %", components: [TaxComponent(name: "TVA 2,1 %", rate: .percent("2.1"))]),
                TaxRate(id: "fr0", label: "Exonéré (0 %)", components: [])
            ]
        case .belgique:
            return [
                TaxRate(id: "be21", label: "TVA 21 %", components: [TaxComponent(name: "TVA 21 %", rate: .percent("21"))]),
                TaxRate(id: "be12", label: "TVA 12 %", components: [TaxComponent(name: "TVA 12 %", rate: .percent("12"))]),
                TaxRate(id: "be6", label: "TVA 6 %", components: [TaxComponent(name: "TVA 6 %", rate: .percent("6"))]),
                TaxRate(id: "be0", label: "Exonéré / Autoliquidation (0 %)", components: [])
            ]
        case .suisse:
            return [
                TaxRate(id: "ch81", label: "TVA 8,1 %", components: [TaxComponent(name: "TVA 8,1 %", rate: .percent("8.1"))]),
                TaxRate(id: "ch38", label: "TVA 3,8 % (hébergement)", components: [TaxComponent(name: "TVA 3,8 %", rate: .percent("3.8"))]),
                TaxRate(id: "ch26", label: "TVA 2,6 %", components: [TaxComponent(name: "TVA 2,6 %", rate: .percent("2.6"))]),
                TaxRate(id: "ch0", label: "Exonéré (0 %)", components: [])
            ]
        case .quebec:
            return [
                TaxRate(id: "qcboth", label: "TPS 5 % + TVQ 9,975 %", components: [
                    TaxComponent(name: "TPS 5 %", rate: .percent("5")),
                    TaxComponent(name: "TVQ 9,975 %", rate: .percent("9.975"))
                ]),
                TaxRate(id: "qctps", label: "TPS 5 % seulement", components: [TaxComponent(name: "TPS 5 %", rate: .percent("5"))]),
                TaxRate(id: "qc0", label: "Détaxé / Exonéré (0 %)", components: [])
            ]
        }
    }

    func defaultTaxRate(for trade: Trade) -> TaxRate {
        let preferredId: String?
        switch (self, trade) {
        case (.france, .restaurateur), (.france, .chauffeurVTC): preferredId = "fr10"
        case (.belgique, .restaurateur): preferredId = "be12"
        case (.belgique, .chauffeurVTC): preferredId = "be6"
        default: preferredId = nil
        }
        if let preferredId, let rate = taxRates.first(where: { $0.id == preferredId }) {
            return rate
        }
        return taxRates[0]
    }

    func taxRate(id: String) -> TaxRate? {
        if id == TaxRate.exempt.id { return .exempt }
        return taxRates.first { $0.id == id }
    }

    var governingLaw: String {
        switch self {
        case .france: return "droit français"
        case .belgique: return "droit belge"
        case .suisse: return "droit suisse"
        case .quebec: return "droit en vigueur au Québec"
        }
    }
}
