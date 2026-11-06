import Foundation

enum DocumentType: String, CaseIterable, Codable, Identifiable, Hashable {
    case devis
    case facture
    case contrat
    case attestation
    case bonDeCommande
    case ficheIntervention
    case recu

    var id: String { rawValue }

    var label: String {
        switch self {
        case .devis: return "Devis"
        case .facture: return "Facture"
        case .contrat: return "Contrat de prestation"
        case .attestation: return "Attestation"
        case .bonDeCommande: return "Bon de commande"
        case .ficheIntervention: return "Fiche d'intervention"
        case .recu: return "Reçu"
        }
    }

    var shortDescription: String {
        switch self {
        case .devis: return "Proposition de prix avant travaux ou prestation"
        case .facture: return "Demande de paiement après prestation"
        case .contrat: return "Cadre et conditions de votre mission"
        case .attestation: return "Certifier une prestation ou une situation"
        case .bonDeCommande: return "Confirmer une commande"
        case .ficheIntervention: return "Compte rendu d'intervention signé"
        case .recu: return "Preuve d'un paiement reçu"
        }
    }

    var symbol: String {
        switch self {
        case .devis: return "doc.text.magnifyingglass"
        case .facture: return "eurosign.square"
        case .contrat: return "signature"
        case .attestation: return "checkmark.seal"
        case .bonDeCommande: return "cart"
        case .ficheIntervention: return "wrench.and.screwdriver"
        case .recu: return "banknote"
        }
    }

    var numberPrefix: String {
        switch self {
        case .devis: return "DEV"
        case .facture: return "FAC"
        case .contrat: return "CTR"
        case .attestation: return "ATT"
        case .bonDeCommande: return "BC"
        case .ficheIntervention: return "FI"
        case .recu: return "REC"
        }
    }

    var hasLineItems: Bool {
        switch self {
        case .attestation: return false
        default: return true
        }
    }

    var hasTax: Bool { hasLineItems }

    var hasPaymentTerms: Bool { self == .facture || self == .contrat || self == .bonDeCommande }

    var hasValidity: Bool { self == .devis }

    var hasDeposit: Bool { self == .devis || self == .contrat || self == .bonDeCommande }

    var hasBodyText: Bool { self == .contrat || self == .attestation }

    var hasDelivery: Bool { self == .bonDeCommande }

    var hasIntervention: Bool { self == .ficheIntervention }

    var hasPaymentReceived: Bool { self == .recu }

    var hasConditions: Bool { self != .attestation && self != .recu }

    var clientSectionTitle: String {
        switch self {
        case .attestation: return "Bénéficiaire"
        default: return "Client"
        }
    }

    var linesSectionTitle: String {
        switch self {
        case .ficheIntervention: return "Fournitures et main-d'œuvre"
        case .recu: return "Détail du paiement"
        case .bonDeCommande: return "Articles commandés"
        default: return "Prestations"
        }
    }

    var clientSignatureLabel: String? {
        switch self {
        case .devis: return "Bon pour accord – date et signature du client"
        case .contrat: return "Le client (lu et approuvé)"
        case .bonDeCommande: return "Signature du client"
        case .ficheIntervention: return "Signature du client"
        default: return nil
        }
    }

    var providerSignatureLabel: String? {
        switch self {
        case .contrat: return "Le prestataire"
        case .attestation: return "Signature et cachet"
        case .ficheIntervention: return "Signature de l'intervenant"
        case .recu: return "Signature"
        default: return nil
        }
    }
}
