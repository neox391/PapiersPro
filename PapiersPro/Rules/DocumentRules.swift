import Foundation

struct TaxLine: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let amount: Decimal
}

struct DocumentTotals: Equatable {
    let subtotal: Decimal
    let taxes: [TaxLine]
    let total: Decimal
    let deposit: Decimal?

    var taxTotal: Decimal { taxes.reduce(0) { $0 + $1.amount } }
}

/// Which optional sections of the form apply for a given trade, country and document.
struct FormConfiguration: Equatable {
    var showsLines: Bool
    var showsTax: Bool
    var showsPaymentTerms: Bool
    var showsPaymentMethod: Bool
    var showsValidity: Bool
    var showsDeposit: Bool
    var showsBody: Bool
    var showsPeriod: Bool
    var showsConditions: Bool
    var showsSite: Bool
    var showsIntervention: Bool
    var showsRide: Bool
    var showsSession: Bool
    var showsRights: Bool
    var showsCovers: Bool
    var showsDelivery: Bool
    var showsQuoteReference: Bool
    var showsClientProfessionalToggle: Bool
}

enum DocumentRules {

    // MARK: - Form

    static func configuration(for type: DocumentType, trade: Trade, country: Country) -> FormConfiguration {
        FormConfiguration(
            showsLines: type.hasLineItems,
            showsTax: type.hasTax,
            showsPaymentTerms: type.hasPaymentTerms,
            showsPaymentMethod: type == .facture || type == .recu,
            showsValidity: type.hasValidity,
            showsDeposit: type.hasDeposit,
            showsBody: type.hasBodyText,
            showsPeriod: type == .contrat,
            showsConditions: type.hasConditions,
            showsSite: trade == .artisanBatiment && [.devis, .facture, .contrat, .attestation, .bonDeCommande].contains(type),
            showsIntervention: type == .ficheIntervention,
            showsRide: trade == .chauffeurVTC && [.devis, .facture, .recu, .bonDeCommande].contains(type),
            showsSession: trade == .photographe && [.devis, .facture, .contrat, .bonDeCommande].contains(type),
            showsRights: trade == .photographe && [.devis, .facture, .contrat].contains(type),
            showsCovers: trade == .restaurateur && [.devis, .facture, .recu].contains(type),
            showsDelivery: type == .bonDeCommande,
            showsQuoteReference: type == .facture || type == .bonDeCommande,
            showsClientProfessionalToggle: type != .attestation
        )
    }

    // MARK: - New documents

    static func newDocument(_ type: DocumentType, profile: BusinessProfile) -> DocumentData {
        var data = DocumentData(type: type, trade: profile.trade, country: profile.country)
        data.taxRateId = profile.vatExempt ? TaxRate.exempt.id : profile.country.defaultTaxRate(for: profile.trade).id
        data.paymentDays = type == .recu ? 0 : profile.defaultPaymentDays
        data.paymentMethod = PaymentMethod.available(in: profile.country).first ?? .virement
        data.title = defaultTitle(type, trade: profile.trade)
        data.bodyText = type.hasBodyText ? defaultBody(type, profile: profile) : ""
        data.conditions = defaultConditions(type, profile: profile)
        data.technician = profile.ownerName
        if let unit = profile.trade.suggestedUnits.first {
            data.lines = [LineItem(unit: unit)]
        }
        if profile.trade == .photographe {
            data.rightsUsage = "Usage personnel et non commercial, durée illimitée, sans cession à des tiers."
        }
        return data
    }

    /// Copy of a document ready to be saved as a new one (new number, today's date).
    static func duplicate(_ source: DocumentData, as type: DocumentType? = nil, profile: BusinessProfile) -> DocumentData {
        var copy = source
        copy.number = ""
        copy.date = .now
        copy.lines = source.lines.map { line in
            var l = line
            l.id = UUID()
            return l
        }
        if let type, type != source.type {
            copy.type = type
            copy.title = defaultTitle(type, trade: source.trade)
            copy.conditions = defaultConditions(type, profile: profile)
            if source.type == .devis && type == .facture {
                copy.quoteReference = source.number
            }
            if type.hasBodyText && copy.bodyText.isEmpty {
                copy.bodyText = defaultBody(type, profile: profile)
            }
        }
        return copy
    }

    static func defaultTitle(_ type: DocumentType, trade: Trade) -> String {
        switch (type, trade) {
        case (.attestation, .artisanBatiment): return "Attestation de fin de travaux"
        case (.attestation, .photographe): return "Attestation de cession de droits"
        case (.attestation, .developpeurFreelance): return "Attestation de fin de mission"
        case (.attestation, .commercant): return "Attestation de vente"
        case (.attestation, _): return "Attestation de prestation"
        case (.contrat, .photographe): return "Contrat de prestation photographique"
        case (.contrat, .developpeurFreelance): return "Contrat de prestation de développement"
        case (.contrat, .artisanBatiment): return "Contrat de travaux"
        case (.recu, .restaurateur): return "Note"
        default: return type.label
        }
    }

    static func defaultConditions(_ type: DocumentType, profile: BusinessProfile) -> String {
        if !profile.defaultConditions.isEmpty && (type == .devis || type == .facture) {
            return profile.defaultConditions
        }
        switch type {
        case .devis:
            return profile.trade == .artisanBatiment
                ? "Devis gratuit. Les travaux débuteront après retour du devis daté et signé avec la mention « Bon pour accord »."
                : "Devis gratuit. La prestation débutera après acceptation signée du présent devis."
        case .facture:
            return ""
        case .bonDeCommande:
            return "La commande devient ferme à la signature du présent bon de commande."
        case .ficheIntervention:
            return "Le client reconnaît que l'intervention décrite ci-dessus a été réalisée."
        case .contrat, .attestation, .recu:
            return ""
        }
    }

    static func defaultBody(_ type: DocumentType, profile: BusinessProfile) -> String {
        switch type {
        case .contrat: return contractBody(profile: profile)
        case .attestation: return attestationBody(profile: profile)
        default: return ""
        }
    }

    private static func signatory(_ profile: BusinessProfile) -> String {
        let owner = profile.ownerName.isEmpty ? "[Nom Prénom]" : profile.ownerName
        if profile.companyName.isEmpty || profile.companyName == profile.ownerName {
            return "Je soussigné(e) \(owner)"
        }
        return "Je soussigné(e) \(owner), agissant pour le compte de \(profile.companyName),"
    }

    private static func attestationBody(profile: BusinessProfile) -> String {
        let who = signatory(profile)
        switch profile.trade {
        case .artisanBatiment:
            return """
            \(who) atteste avoir réalisé, pour le compte du bénéficiaire désigné ci-dessus, les travaux suivants, conformément au devis accepté et aux règles de l'art :

            Nature des travaux : 
            Date d'achèvement : 

            Les travaux ont été réceptionnés sans réserve.
            """
        case .photographe:
            return """
            \(who), auteur des photographies réalisées pour le bénéficiaire désigné ci-dessus, déclare céder à ce dernier les droits d'exploitation suivants :

            Photographies concernées : 
            Supports autorisés : 
            Durée et territoire : 

            Toute autre utilisation reste soumise à l'accord préalable et écrit de l'auteur.
            """
        case .developpeurFreelance:
            return """
            \(who) atteste avoir réalisé pour le bénéficiaire désigné ci-dessus la mission suivante :

            Intitulé de la mission : 
            Période : 
            Technologies : 

            La mission a été menée à son terme et les livrables ont été remis au client.
            """
        case .commercant:
            return """
            \(who) atteste avoir vendu au bénéficiaire désigné ci-dessus le(s) article(s) suivant(s) :

            Désignation : 
            Date d'achat : 
            Montant réglé : 
            """
        default:
            return """
            \(who) atteste que le bénéficiaire désigné ci-dessus a bénéficié de la prestation suivante :

            Nature de la prestation : 
            Date(s) : 
            """
        }
    }

    private static func contractBody(profile: BusinessProfile) -> String {
        var articles: [String] = []
        articles.append("""
        Article 1 – Objet
        Le présent contrat a pour objet de définir les conditions dans lesquelles le Prestataire réalise pour le Client la prestation décrite ci-dessous.
        """)
        articles.append("""
        Article 2 – Durée
        Le contrat prend effet et se termine aux dates indiquées ci-dessus. Il pourra être prolongé par accord écrit des parties.
        """)
        articles.append("""
        Article 3 – Prix et paiement
        Le prix de la prestation est détaillé dans le tableau ci-dessous. Il est payable selon les modalités indiquées dans le présent contrat.
        """)
        articles.append("""
        Article 4 – Obligations des parties
        Le Prestataire s'engage à exécuter la prestation avec soin et selon les règles de l'art. Le Client s'engage à fournir les informations, documents et accès nécessaires et à régler le prix convenu.
        """)
        switch profile.trade {
        case .developpeurFreelance:
            articles.append("""
            Article 5 – Propriété intellectuelle
            Les droits patrimoniaux sur les livrables spécifiques sont cédés au Client à compter du paiement intégral du prix. Le Prestataire conserve la propriété de ses outils, bibliothèques et savoir-faire préexistants.
            """)
        case .photographe:
            articles.append("""
            Article 5 – Droits d'auteur
            Le Photographe reste titulaire des droits d'auteur sur les images. Le Client bénéficie uniquement des droits d'utilisation définis dans le présent contrat. Toute autre exploitation nécessite un accord écrit préalable.
            """)
            articles.append("""
            Article 6 – Annulation
            En cas d'annulation par le Client moins de 15 jours avant la date prévue, l'acompte versé reste acquis au Photographe.
            """)
        case .artisanBatiment:
            articles.append("""
            Article 5 – Assurances et réception
            Le Prestataire déclare être titulaire des assurances professionnelles requises pour les travaux concernés. Les travaux feront l'objet d'une réception contradictoire à leur achèvement.
            """)
        default:
            break
        }
        let next = articles.count + 1
        articles.append("""
        Article \(next) – Résiliation
        En cas de manquement grave de l'une des parties à ses obligations, l'autre partie pourra résilier le contrat après une mise en demeure restée sans effet pendant 15 jours.
        """)
        articles.append("""
        Article \(next + 1) – Droit applicable
        Le présent contrat est soumis au \(profile.country.governingLaw). En cas de différend, les parties rechercheront une solution amiable avant toute action en justice.
        """)
        return articles.joined(separator: "\n\n")
    }

    // MARK: - Totals

    static func effectiveTaxRate(_ data: DocumentData, profile: BusinessProfile) -> TaxRate {
        profile.vatExempt ? .exempt : data.taxRate
    }

    static func totals(for data: DocumentData, profile: BusinessProfile) -> DocumentTotals {
        let subtotal = data.lines.reduce(Decimal(0)) { $0 + $1.total }
        let rate = effectiveTaxRate(data, profile: profile)
        let taxes = rate.components.map { TaxLine(name: $0.name, amount: (subtotal * $0.rate).rounded(scale: 2)) }
        let total = subtotal + taxes.reduce(Decimal(0)) { $0 + $1.amount }
        var deposit: Decimal?
        if data.type.hasDeposit && data.depositPercent > 0 {
            deposit = (total * Decimal(data.depositPercent) / 100).rounded(scale: 2)
        }
        return DocumentTotals(subtotal: subtotal, taxes: taxes, total: total, deposit: deposit)
    }

    // MARK: - Legal mentions

    /// Identification lines printed under the company name.
    static func providerIdentity(_ profile: BusinessProfile) -> [String] {
        var lines: [String] = []
        let country = profile.country
        var legal = profile.legalForm
        if legal.isEmpty && profile.trade == .autoEntrepreneur && country == .france {
            legal = "Entrepreneur individuel (EI)"
        }
        if !legal.isEmpty {
            if !profile.shareCapital.isEmpty {
                lines.append("\(legal) au capital de \(profile.shareCapital)")
            } else {
                lines.append(legal)
            }
        }
        if !profile.companyId.isEmpty { lines.append("\(country.companyIdLabel) : \(profile.companyId)") }
        if !profile.registration.isEmpty { lines.append(profile.registration) }
        if !profile.vatExempt && !profile.vatNumber.isEmpty { lines.append("\(country.vatNumberLabel) : \(profile.vatNumber)") }
        if let label = profile.licenseLabel, !profile.professionalLicense.isEmpty {
            lines.append("\(label) : \(profile.professionalLicense)")
        }
        return lines
    }

    static func legalMentions(for data: DocumentData, profile: BusinessProfile) -> [String] {
        var m: [String] = []
        let type = data.type
        let trade = data.trade
        let country = data.country
        let pro = data.client.isProfessional
        let rate = effectiveTaxRate(data, profile: profile)
        let isCommercial = [.devis, .facture, .bonDeCommande, .contrat, .recu].contains(type)

        if profile.vatExempt && isCommercial {
            switch country {
            case .france: m.append("TVA non applicable, art. 293 B du CGI.")
            case .belgique: m.append("Petite entreprise soumise au régime de la franchise de la taxe – TVA non applicable.")
            case .suisse: m.append("Non assujetti à la TVA.")
            case .quebec: m.append("Petit fournisseur – non inscrit aux fichiers de la TPS et de la TVQ.")
            }
        }

        switch country {
        case .france:
            if trade == .artisanBatiment && (rate.id == "fr10" || rate.id == "fr55") && (type == .devis || type == .facture) {
                m.append("Taux réduit de TVA appliqué sous réserve de la remise par le client de l'attestation prévue aux articles 278-0 bis A et 279-0 bis du CGI (logement achevé depuis plus de 2 ans).")
            }
            if type == .facture {
                if pro {
                    m.append("En cas de retard de paiement, des pénalités égales à trois fois le taux d'intérêt légal seront exigibles, ainsi qu'une indemnité forfaitaire pour frais de recouvrement de 40 € (art. L441-10 et D441-5 du Code de commerce).")
                } else {
                    m.append("En cas de retard de paiement, des pénalités au taux d'intérêt légal pourront être appliquées.")
                }
                m.append("Pas d'escompte pour paiement anticipé.")
            }
            if !pro && (type == .devis || type == .contrat) && [.artisanBatiment, .autoEntrepreneur, .photographe].contains(trade) {
                m.append("Pour un contrat conclu hors établissement, le client consommateur dispose d'un délai de rétractation de 14 jours (art. L221-18 du Code de la consommation).")
            }
            if trade == .artisanBatiment && [.devis, .facture, .contrat].contains(type) {
                let insurance = profile.insurance.isEmpty ? "[à compléter dans votre profil]" : profile.insurance
                m.append("Assurance professionnelle décennale : \(insurance).")
            }
            if trade == .chauffeurVTC && [.facture, .recu, .devis, .bonDeCommande].contains(type) {
                m.append("Prestation de transport avec chauffeur sur réservation préalable. Prix total convenu avant la prise en charge.")
            }
            if trade == .restaurateur && (type == .recu || type == .facture) {
                m.append("Prix nets, service compris.")
            }
            if trade == .commercant && (type == .facture || type == .recu) && !pro {
                m.append("Garantie légale de conformité de 2 ans (art. L217-3 et suivants du Code de la consommation) et garantie des vices cachés (art. 1641 et suivants du Code civil).")
            }
        case .belgique:
            if trade == .artisanBatiment && rate.id == "be0" && pro && (type == .facture || type == .devis) {
                m.append("Autoliquidation – TVA due par le cocontractant (art. 20 de l'arrêté royal n° 1).")
            }
            if trade == .artisanBatiment && rate.id == "be6" && (type == .devis || type == .facture) {
                m.append("Taux de TVA de 6 % appliqué sur base de l'attestation du client (habitation privée de plus de 10 ans).")
            }
            if type == .facture {
                if pro {
                    m.append("Tout retard de paiement entraîne de plein droit des intérêts de retard au taux légal ainsi qu'une indemnité forfaitaire de 40 € (loi du 2 août 2002).")
                } else {
                    m.append("Après un premier rappel gratuit resté sans suite, des intérêts de retard et une indemnité forfaitaire pourront être réclamés (Code de droit économique, art. XIX.2).")
                }
            }
            if trade == .artisanBatiment && [.devis, .facture, .contrat].contains(type) {
                let insurance = profile.insurance.isEmpty ? "[à compléter dans votre profil]" : profile.insurance
                m.append("Assurance responsabilité civile décennale (loi du 31 mai 2017) : \(insurance).")
            }
            if trade == .commercant && (type == .facture || type == .recu) && !pro {
                m.append("Garantie légale de conformité de 2 ans (art. 1649bis et suivants du Code civil).")
            }
        case .suisse:
            if type == .facture {
                m.append("Payable à \(data.paymentDays) jours net. Intérêt moratoire de 5 % l'an dès l'échéance (art. 104 CO).")
            }
            if trade == .commercant && (type == .facture || type == .recu) {
                m.append("Garantie selon les art. 197 ss CO, sauf dispositions contraires.")
            }
        case .quebec:
            if type == .facture {
                m.append("Des frais d'intérêt pourront être appliqués sur tout solde impayé après la date d'échéance.")
            }
            if !pro && (type == .contrat || type == .devis) {
                m.append("Le consommateur bénéficie des droits prévus par la Loi sur la protection du consommateur (RLRQ, c. P-40.1).")
            }
            if trade == .commercant && (type == .facture || type == .recu) && !pro {
                m.append("Garantie légale prévue par la Loi sur la protection du consommateur.")
            }
        }

        if trade == .photographe && [.devis, .facture, .contrat].contains(type) {
            m.append("Les photographies restent l'œuvre de leur auteur ; seuls les droits d'utilisation mentionnés sont cédés.")
        }
        if trade == .developpeurFreelance && (type == .devis || type == .contrat) {
            m.append("Les droits sur les livrables spécifiques sont cédés au client après paiement intégral.")
        }
        if type == .recu {
            m.append("Reçu pour valoir ce que de droit.")
        }
        return m
    }

    // MARK: - Checks

    /// Human readable warnings about missing mandatory information.
    static func missingInformation(for data: DocumentData, profile: BusinessProfile) -> [String] {
        var issues: [String] = []
        if data.client.isEmpty {
            issues.append("Indiquez le nom du \(data.type.clientSectionTitle.lowercased()).")
        }
        if profile.companyId.isEmpty {
            issues.append("Ajoutez votre \(profile.country.companyIdLabel) dans votre profil.")
        }
        let rate = effectiveTaxRate(data, profile: profile)
        if data.type.hasTax && !rate.isExempt && profile.vatNumber.isEmpty && profile.country != .suisse {
            issues.append("Ajoutez votre \(profile.country.vatNumberLabel) dans votre profil, ou activez la franchise de TVA.")
        }
        if data.trade == .artisanBatiment && (profile.country == .france || profile.country == .belgique)
            && profile.insurance.isEmpty && [.devis, .facture, .contrat].contains(data.type) {
            issues.append("L'assurance décennale doit figurer sur vos devis et factures : complétez votre profil.")
        }
        if let label = profile.licenseLabel, profile.professionalLicense.isEmpty, data.type != .attestation {
            issues.append("Complétez le champ « \(label) » dans votre profil.")
        }
        if data.type.hasLineItems && data.lines.allSatisfy({ $0.description.trimmingCharacters(in: .whitespaces).isEmpty }) {
            issues.append("Ajoutez au moins une ligne.")
        }
        return issues
    }
}
