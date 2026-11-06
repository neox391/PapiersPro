import Foundation

struct BusinessProfile: Codable, Equatable {
    var trade: Trade = .autoEntrepreneur
    var country: Country = .france

    var companyName: String = ""
    var ownerName: String = ""
    var legalForm: String = ""
    var street: String = ""
    var postalCode: String = ""
    var city: String = ""
    var email: String = ""
    var phone: String = ""
    var website: String = ""

    var companyId: String = ""
    var vatNumber: String = ""
    var vatExempt: Bool = false
    var registration: String = ""
    var shareCapital: String = ""

    var iban: String = ""
    var bic: String = ""

    /// Professional insurance (décennale, RC Pro…): insurer, policy number, geographic coverage.
    var insurance: String = ""
    /// Trade licence (carte VTC, licence RBQ…).
    var professionalLicense: String = ""

    var defaultPaymentDays: Int = 30
    var defaultConditions: String = ""

    var hasLogo: Bool = false

    var addressLines: [String] {
        let cityLine = [postalCode, city].filter { !$0.isEmpty }.joined(separator: " ")
        return [street, cityLine].filter { !$0.isEmpty }
    }

    var displayName: String { companyName.isEmpty ? ownerName : companyName }

    var isComplete: Bool { !displayName.trimmingCharacters(in: .whitespaces).isEmpty }
}

extension BusinessProfile {
    var registrationLabel: String {
        switch country {
        case .france: return trade == .artisanBatiment ? "RCS / Répertoire des métiers" : "RCS / RM (si applicable)"
        case .belgique: return "RPM (tribunal de l'entreprise)"
        case .suisse: return "Registre du commerce"
        case .quebec: return "Registraire des entreprises"
        }
    }

    var registrationPlaceholder: String {
        switch country {
        case .france: return "RCS Lyon 123 456 789"
        case .belgique: return "RPM Bruxelles"
        case .suisse: return "RC Genève"
        case .quebec: return "Immatriculée au REQ"
        }
    }

    /// Label of the trade-specific insurance field, nil when not relevant.
    var insuranceLabel: String? {
        switch (trade, country) {
        case (.artisanBatiment, .france), (.artisanBatiment, .belgique):
            return "Assurance décennale (assureur, n° de contrat, zone couverte)"
        case (.artisanBatiment, _):
            return "Assurance responsabilité civile"
        case (.developpeurFreelance, _), (.photographe, _), (.autoEntrepreneur, _):
            return "Assurance RC Pro (facultatif)"
        default:
            return nil
        }
    }

    /// Label of the trade licence field, nil when not relevant.
    var licenseLabel: String? {
        switch (trade, country) {
        case (.chauffeurVTC, .france): return "N° de carte professionnelle VTC"
        case (.chauffeurVTC, .belgique): return "N° de licence LVC"
        case (.chauffeurVTC, .suisse): return "N° de carte professionnelle de chauffeur"
        case (.chauffeurVTC, .quebec): return "N° d'autorisation de chauffeur"
        case (.artisanBatiment, .quebec): return "N° de licence RBQ"
        default: return nil
        }
    }
}
