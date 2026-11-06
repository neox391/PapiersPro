import SwiftUI

/// The editing form. Only sections relevant to the trade, country and document type are shown.
struct DocumentForm: View {
    @Binding var data: DocumentData
    let profile: BusinessProfile
    let recentClients: [ClientInfo]
    let isNew: Bool

    private var config: FormConfiguration {
        DocumentRules.configuration(for: data.type, trade: data.trade, country: data.country)
    }

    private var country: Country { data.country }

    var body: some View {
        let cfg = config
        let issues = DocumentRules.missingInformation(for: data, profile: profile)
        Form {
            if !issues.isEmpty {
                Section {
                    ForEach(issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("À vérifier")
                }
            }

            documentSection
            clientSection(cfg)

            if cfg.showsPeriod {
                Section("Période") {
                    DatePicker("Début", selection: $data.startDate, displayedComponents: .date)
                    DatePicker("Fin", selection: $data.endDate, in: data.startDate..., displayedComponents: .date)
                }
            }

            tradeSections(cfg)

            if cfg.showsBody {
                Section {
                    TextField("Texte", text: $data.bodyText, axis: .vertical)
                        .lineLimit(6...30)
                        .font(.callout)
                    Button("Rétablir le modèle") {
                        data.bodyText = DocumentRules.defaultBody(data.type, profile: profile)
                    }
                    .font(.footnote)
                } header: {
                    Text(data.type == .contrat ? "Clauses du contrat" : "Texte de l'attestation")
                } footer: {
                    Text("Modèle prérempli selon votre métier : complétez ou adaptez-le librement.")
                }
            }

            if cfg.showsLines {
                LineItemsSection(data: $data, profile: profile)
            }

            if cfg.showsTax {
                taxSection
            }

            if cfg.showsPaymentTerms || cfg.showsPaymentMethod || cfg.showsValidity || cfg.showsDeposit {
                paymentSection(cfg)
            }

            Section("Conditions et remarques") {
                if cfg.showsConditions {
                    TextField("Conditions particulières", text: $data.conditions, axis: .vertical)
                        .lineLimit(2...8)
                }
                TextField("Remarques (facultatif)", text: $data.notes, axis: .vertical)
                    .lineLimit(1...6)
            }

            mentionsSection

            Section {
                DisclaimerNote()
            }
            .listRowBackground(Color.clear)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: Sections

    private var documentSection: some View {
        Section {
            if data.type == .contrat || data.type == .attestation {
                TextField("Titre", text: $data.title)
            }
            DatePicker("Date", selection: $data.date, displayedComponents: .date)
            LabeledContent("Numéro", value: data.number.isEmpty ? "Attribué à l'enregistrement" : data.number)
                .foregroundStyle(.secondary)
        } header: {
            Text(data.type.label)
        }
    }

    private func clientSection(_ cfg: FormConfiguration) -> some View {
        Section {
            HStack {
                TextField(data.type == .attestation ? "Nom du bénéficiaire" : "Nom du client", text: $data.client.name)
                    .textContentType(.name)
                if !recentClients.isEmpty {
                    Menu {
                        ForEach(recentClients, id: \.self) { client in
                            Button(client.name) { data.client = client }
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.badge.clock")
                    }
                    .accessibilityLabel("Clients récents")
                }
            }
            TextField("Adresse", text: $data.client.street)
            HStack {
                TextField("Code postal", text: $data.client.postalCode)
                    .frame(maxWidth: 110)
                Divider()
                TextField("Ville", text: $data.client.city)
            }
            if data.type != .attestation {
                TextField("E-mail (facultatif)", text: $data.client.email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Téléphone (facultatif)", text: $data.client.phone)
                    .keyboardType(.phonePad)
            }
            if cfg.showsClientProfessionalToggle {
                Toggle("Client professionnel", isOn: $data.client.isProfessional)
                if data.client.isProfessional {
                    TextField("\(country.companyIdLabel) du client", text: $data.client.companyId)
                    TextField("\(country.vatNumberLabel) du client", text: $data.client.vatNumber)
                }
            }
        } header: {
            Text(data.type.clientSectionTitle)
        }
    }

    @ViewBuilder
    private func tradeSections(_ cfg: FormConfiguration) -> some View {
        if cfg.showsQuoteReference {
            Section("Référence") {
                TextField("N° du devis associé (facultatif)", text: $data.quoteReference)
            }
        }
        if cfg.showsSite {
            Section("Chantier") {
                TextField("Adresse du chantier", text: $data.siteAddress, axis: .vertical)
            }
        }
        if cfg.showsIntervention {
            Section("Intervention") {
                TextField("Lieu d'intervention", text: $data.siteAddress, axis: .vertical)
                DatePicker("Début", selection: $data.interventionStart)
                DatePicker("Fin", selection: $data.interventionEnd, in: data.interventionStart...)
                TextField("Intervenant", text: $data.technician)
                TextField("Travaux réalisés", text: $data.workDescription, axis: .vertical)
                    .lineLimit(3...10)
            }
        }
        if cfg.showsRide {
            Section("Course") {
                DatePicker("Date et heure", selection: $data.rideDate)
                TextField("Lieu de prise en charge", text: $data.pickupAddress)
                TextField("Destination", text: $data.dropoffAddress)
                TextField("Véhicule (modèle, immatriculation)", text: $data.vehiclePlate)
            }
        }
        if cfg.showsSession {
            Section("Séance photo") {
                DatePicker("Date", selection: $data.sessionDate, displayedComponents: .date)
                TextField("Lieu", text: $data.sessionPlace)
            }
        }
        if cfg.showsRights {
            Section {
                TextField("Usage autorisé", text: $data.rightsUsage, axis: .vertical)
                    .lineLimit(2...6)
            } header: {
                Text("Droits d'utilisation cédés")
            } footer: {
                Text("Précisez les supports, la durée et le territoire.")
            }
        }
        if cfg.showsCovers {
            Section("Service") {
                Stepper("Couverts : \(data.covers)", value: $data.covers, in: 0...500)
            }
        }
        if cfg.showsDelivery {
            Section("Livraison") {
                DatePicker("Date de livraison", selection: $data.deliveryDate, displayedComponents: .date)
                TextField("Adresse de livraison (si différente)", text: $data.deliveryAddress, axis: .vertical)
            }
        }
    }

    private var taxSection: some View {
        let totals = DocumentRules.totals(for: data, profile: profile)
        return Section {
            if profile.vatExempt {
                Label(country.vatExemptLabel, systemImage: "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Taux de \(country.taxName)", selection: $data.taxRateId) {
                    ForEach(country.taxRates) { rate in
                        Text(rate.label).tag(rate.id)
                    }
                }
            }
            if profile.vatExempt {
                LabeledContent("Total", value: country.money(totals.total))
                    .font(.headline)
            } else {
                LabeledContent("Total HT", value: country.money(totals.subtotal))
                ForEach(totals.taxes) { tax in
                    LabeledContent(tax.name, value: country.money(tax.amount))
                }
                LabeledContent("Total TTC", value: country.money(totals.total))
                    .font(.headline)
            }
        } header: {
            Text(country.taxName)
        }
    }

    private func paymentSection(_ cfg: FormConfiguration) -> some View {
        Section("Paiement") {
            if cfg.showsValidity {
                Stepper("Validité : \(data.validityDays) jours", value: $data.validityDays, in: 1...365, step: data.validityDays < 30 ? 1 : 15)
            }
            if cfg.showsPaymentTerms {
                Picker("Délai de paiement", selection: $data.paymentDays) {
                    ForEach(paymentOptions, id: \.self) { days in
                        Text(PaymentTerms.label(days)).tag(days)
                    }
                }
            }
            if cfg.showsPaymentMethod {
                Picker(data.type == .recu ? "Payé par" : "Mode de paiement", selection: $data.paymentMethod) {
                    ForEach(PaymentMethod.available(in: country)) { method in
                        Text(method.label).tag(method)
                    }
                }
            }
            if cfg.showsDeposit {
                Picker("Acompte", selection: $data.depositPercent) {
                    ForEach([0, 10, 20, 30, 40, 50, 100], id: \.self) { percent in
                        Text(percent == 0 ? "Aucun" : "\(percent) %").tag(percent)
                    }
                }
            }
        }
    }

    private var paymentOptions: [Int] {
        var options = PaymentTerms.options
        if !options.contains(data.paymentDays) { options.append(data.paymentDays); options.sort() }
        return options
    }

    private var mentionsSection: some View {
        let mentions = DocumentRules.legalMentions(for: data, profile: profile)
        return Section {
            if mentions.isEmpty {
                Text("Aucune mention spécifique pour ce document.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mentions, id: \.self) { mention in
                    Text(mention)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Mentions légales", systemImage: "checkmark.shield")
        } footer: {
            Text("Ajoutées automatiquement selon votre pays (\(country.label)), votre métier et le type de client.")
        }
    }
}

struct LineItemsSection: View {
    @Binding var data: DocumentData
    let profile: BusinessProfile

    var body: some View {
        let country = data.country
        Section {
            ForEach($data.lines) { $line in
                LineItemEditor(line: $line, country: country, trade: data.trade)
            }
            .onDelete { offsets in
                data.lines.remove(atOffsets: offsets)
            }
            .onMove { from, to in
                data.lines.move(fromOffsets: from, toOffset: to)
            }
            Button {
                withAnimation {
                    data.lines.append(LineItem(unit: data.trade.suggestedUnits.first ?? "u"))
                }
            } label: {
                Label("Ajouter une ligne", systemImage: "plus.circle.fill")
            }
        } header: {
            Text(data.type.linesSectionTitle)
        } footer: {
            Text("Balayez une ligne vers la gauche pour la supprimer.")
        }
    }
}

struct LineItemEditor: View {
    @Binding var line: LineItem
    let country: Country
    let trade: Trade

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(trade.lineDescriptionPlaceholder, text: $line.description, axis: .vertical)
                .lineLimit(1...4)
                .font(.body.weight(.medium))
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Quantité").font(.caption2).foregroundStyle(.secondary)
                    DecimalField(title: "1", value: $line.quantity, locale: country.locale)
                        .textFieldStyle(.roundedBorder)
                }
                .frame(width: 76)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unité").font(.caption2).foregroundStyle(.secondary)
                    Menu {
                        ForEach(trade.suggestedUnits, id: \.self) { unit in
                            Button(unit) { line.unit = unit }
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Text(line.unit.isEmpty ? "u" : line.unit)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(.tertiarySystemFill)))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prix unitaire").font(.caption2).foregroundStyle(.secondary)
                    DecimalField(title: "0,00", value: $line.unitPrice, locale: country.locale)
                        .textFieldStyle(.roundedBorder)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total").font(.caption2).foregroundStyle(.secondary)
                    Text(country.money(line.total))
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
