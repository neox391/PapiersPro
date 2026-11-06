import Foundation

enum Trade: String, CaseIterable, Codable, Identifiable, Hashable {
    case artisanBatiment
    case coiffureEsthetique
    case autoEntrepreneur
    case restaurateur
    case chauffeurVTC
    case photographe
    case developpeurFreelance
    case commercant

    var id: String { rawValue }

    var label: String {
        switch self {
        case .artisanBatiment: return "Artisan du bâtiment"
        case .coiffureEsthetique: return "Coiffeur / Esthéticienne"
        case .autoEntrepreneur: return "Auto-entrepreneur"
        case .restaurateur: return "Restaurateur"
        case .chauffeurVTC: return "Chauffeur VTC"
        case .photographe: return "Photographe"
        case .developpeurFreelance: return "Développeur freelance"
        case .commercant: return "Commerçant"
        }
    }

    var symbol: String {
        switch self {
        case .artisanBatiment: return "hammer.fill"
        case .coiffureEsthetique: return "scissors"
        case .autoEntrepreneur: return "person.crop.square.fill"
        case .restaurateur: return "fork.knife"
        case .chauffeurVTC: return "car.fill"
        case .photographe: return "camera.fill"
        case .developpeurFreelance: return "laptopcomputer"
        case .commercant: return "bag.fill"
        }
    }

    var documents: [DocumentType] {
        switch self {
        case .artisanBatiment:
            return [.devis, .facture, .ficheIntervention, .contrat, .attestation, .bonDeCommande, .recu]
        case .coiffureEsthetique:
            return [.facture, .recu, .devis, .attestation]
        case .autoEntrepreneur:
            return [.devis, .facture, .contrat, .attestation, .bonDeCommande, .recu]
        case .restaurateur:
            return [.facture, .recu, .devis, .bonDeCommande]
        case .chauffeurVTC:
            return [.facture, .recu, .devis, .bonDeCommande]
        case .photographe:
            return [.devis, .facture, .contrat, .attestation, .bonDeCommande, .recu]
        case .developpeurFreelance:
            return [.devis, .facture, .contrat, .attestation, .bonDeCommande]
        case .commercant:
            return [.facture, .recu, .devis, .bonDeCommande, .attestation]
        }
    }

    /// Auto-entrepreneurs usually benefit from VAT exemption (franchise en base).
    var defaultVATExempt: Bool { self == .autoEntrepreneur }

    var lineDescriptionPlaceholder: String {
        switch self {
        case .artisanBatiment: return "Ex. Pose de carrelage 60x60"
        case .coiffureEsthetique: return "Ex. Coupe + brushing"
        case .autoEntrepreneur: return "Ex. Prestation de service"
        case .restaurateur: return "Ex. Menu du jour"
        case .chauffeurVTC: return "Ex. Course Paris → Orly"
        case .photographe: return "Ex. Séance photo 2 h"
        case .developpeurFreelance: return "Ex. Développement – journée"
        case .commercant: return "Ex. Article réf. 1234"
        }
    }

    var suggestedUnits: [String] {
        switch self {
        case .artisanBatiment: return ["u", "h", "jour", "m²", "ml", "m³", "forfait"]
        case .coiffureEsthetique: return ["u", "forfait"]
        case .autoEntrepreneur: return ["u", "h", "jour", "forfait"]
        case .restaurateur: return ["u", "couvert", "forfait"]
        case .chauffeurVTC: return ["course", "km", "h", "forfait"]
        case .photographe: return ["u", "h", "séance", "photo", "forfait"]
        case .developpeurFreelance: return ["jour", "h", "u", "forfait"]
        case .commercant: return ["u", "kg", "lot", "forfait"]
        }
    }
}
