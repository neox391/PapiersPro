import Foundation

struct ClientInfo: Codable, Equatable, Hashable {
    var name: String = ""
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var email: String = ""
    var phone: String = ""
    var isProfessional: Bool = false
    var companyId: String = ""
    var vatNumber: String = ""

    var addressLines: [String] {
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        return [street, cityLine].filter { !$0.isEmpty }
    }

    var isEmpty: Bool { name.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct LineItem: Codable, Equatable, Identifiable, Hashable {
    var id = UUID()
    var description: String = ""
    var quantity: Decimal = 1
    var unit: String = "u"
    var unitPrice: Decimal = 0

    var total: Decimal { (quantity * unitPrice).rounded(scale: 2) }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case virement, carte, especes, cheque, interac, twint, autre

    var id: String { rawValue }

    var label: String {
        switch self {
        case .virement: return "Virement bancaire"
        case .carte: return "Carte bancaire"
        case .especes: return "Espèces"
        case .cheque: return "Chèque"
        case .interac: return "Virement Interac"
        case .twint: return "TWINT"
        case .autre: return "Autre"
        }
    }

    static func available(in country: Country) -> [PaymentMethod] {
        switch country {
        case .france, .belgique: return [.virement, .carte, .especes, .cheque, .autre]
        case .suisse: return [.virement, .carte, .twint, .especes, .autre]
        case .quebec: return [.virement, .interac, .carte, .especes, .cheque, .autre]
        }
    }
}

/// Everything the user enters for one document. Stored as JSON in the history.
struct DocumentData: Codable, Equatable {
    var type: DocumentType
    var trade: Trade
    var country: Country
    var number: String = ""
    var date: Date = .now
    var title: String = ""

    var client = ClientInfo()
    var lines: [LineItem] = [LineItem()]
    var taxRateId: String = ""

    var paymentDays: Int = 30
    var paymentMethod: PaymentMethod = .virement
    var validityDays: Int = 30
    var depositPercent: Int = 0
    var conditions: String = ""
    var notes: String = ""

    var bodyText: String = ""
    var startDate: Date = .now
    var endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: .now) ?? .now

    // Trade specific
    var siteAddress: String = ""
    var interventionStart: Date = .now
    var interventionEnd: Date = Date.now.addingTimeInterval(3600)
    var workDescription: String = ""
    var technician: String = ""
    var pickupAddress: String = ""
    var dropoffAddress: String = ""
    var rideDate: Date = .now
    var vehiclePlate: String = ""
    var sessionDate: Date = .now
    var sessionPlace: String = ""
    var rightsUsage: String = ""
    var covers: Int = 0
    var deliveryDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    var deliveryAddress: String = ""
    var quoteReference: String = ""

    init(type: DocumentType, trade: Trade, country: Country) {
        self.type = type
        self.trade = trade
        self.country = country
    }
}

extension DocumentData {
    // Tolerant decoding so documents saved by older versions keep opening.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(DocumentType.self, forKey: .type)
        let trade = try c.decode(Trade.self, forKey: .trade)
        let country = try c.decode(Country.self, forKey: .country)
        self.init(type: type, trade: trade, country: country)
        func value<T: Decodable>(_ key: CodingKeys, _ current: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? current
        }
        number = value(.number, number)
        date = value(.date, date)
        title = value(.title, title)
        client = value(.client, client)
        lines = value(.lines, lines)
        taxRateId = value(.taxRateId, taxRateId)
        paymentDays = value(.paymentDays, paymentDays)
        paymentMethod = value(.paymentMethod, paymentMethod)
        validityDays = value(.validityDays, validityDays)
        depositPercent = value(.depositPercent, depositPercent)
        conditions = value(.conditions, conditions)
        notes = value(.notes, notes)
        bodyText = value(.bodyText, bodyText)
        startDate = value(.startDate, startDate)
        endDate = value(.endDate, endDate)
        siteAddress = value(.siteAddress, siteAddress)
        interventionStart = value(.interventionStart, interventionStart)
        interventionEnd = value(.interventionEnd, interventionEnd)
        workDescription = value(.workDescription, workDescription)
        technician = value(.technician, technician)
        pickupAddress = value(.pickupAddress, pickupAddress)
        dropoffAddress = value(.dropoffAddress, dropoffAddress)
        rideDate = value(.rideDate, rideDate)
        vehiclePlate = value(.vehiclePlate, vehiclePlate)
        sessionDate = value(.sessionDate, sessionDate)
        sessionPlace = value(.sessionPlace, sessionPlace)
        rightsUsage = value(.rightsUsage, rightsUsage)
        covers = value(.covers, covers)
        deliveryDate = value(.deliveryDate, deliveryDate)
        deliveryAddress = value(.deliveryAddress, deliveryAddress)
        quoteReference = value(.quoteReference, quoteReference)
    }

    var taxRate: TaxRate {
        country.taxRate(id: taxRateId) ?? country.defaultTaxRate(for: trade)
    }

    var dueDate: Date {
        Calendar.current.date(byAdding: .day, value: paymentDays, to: date) ?? date
    }

    var validUntil: Date {
        Calendar.current.date(byAdding: .day, value: validityDays, to: date) ?? date
    }

    var displayTitle: String { title.isEmpty ? type.label : title }
}

struct SavedDocument: Codable, Identifiable, Equatable {
    var id = UUID()
    var data: DocumentData
    var createdAt: Date = .now
    var updatedAt: Date = .now
}

extension Decimal {
    func rounded(scale: Int) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, .plain)
        return result
    }
}
