import SwiftUI

/// Company information form, labels adapted to the country and trade.
struct BusinessInfoForm<Footer: View>: View {
    @Binding var profile: BusinessProfile
    var header: AnyView? = nil
    @ViewBuilder var footer: Footer

    var body: some View {
        let country = profile.country
        Form {
            if let header {
                Section { header }
            }

            Section("Entreprise") {
                TextField("Nom de l'entreprise", text: $profile.companyName)
                    .textContentType(.organizationName)
                TextField("Nom et prénom du dirigeant", text: $profile.ownerName)
                    .textContentType(.name)
                TextField(legalFormPlaceholder, text: $profile.legalForm)
            }

            Section("Adresse") {
                TextField("Adresse", text: $profile.street)
                    .textContentType(.fullStreetAddress)
                HStack {
                    TextField("Code postal", text: $profile.postalCode)
                        .textContentType(.postalCode)
                        .frame(maxWidth: 110)
                    Divider()
                    TextField("Ville", text: $profile.city)
                        .textContentType(.addressCity)
                }
            }

            Section("Contact") {
                TextField("Téléphone", text: $profile.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("E-mail", text: $profile.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Site web (facultatif)", text: $profile.website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                LabeledField(country.companyIdLabel, placeholder: country.companyIdPlaceholder, text: $profile.companyId)
                Toggle(country.vatExemptLabel, isOn: $profile.vatExempt)
                if !profile.vatExempt {
                    LabeledField(country.vatNumberLabel, placeholder: country.vatNumberPlaceholder, text: $profile.vatNumber)
                }
                LabeledField(profile.registrationLabel, placeholder: profile.registrationPlaceholder, text: $profile.registration)
                if showsCapital {
                    LabeledField("Capital social", placeholder: "Ex. 10 000 €", text: $profile.shareCapital)
                }
            } header: {
                Text("Identification")
            } footer: {
                if profile.vatExempt {
                    Text("La mention d'exonération de TVA sera ajoutée automatiquement à vos documents.")
                }
            }

            if profile.insuranceLabel != nil || profile.licenseLabel != nil {
                Section("Votre métier") {
                    if let label = profile.insuranceLabel {
                        LabeledField(label, placeholder: "Ex. AXA – contrat n° 123456 – France", text: $profile.insurance)
                    }
                    if let label = profile.licenseLabel {
                        LabeledField(label, placeholder: "Numéro", text: $profile.professionalLicense)
                    }
                }
            }

            Section {
                LabeledField(country.bankLabel, placeholder: country.bankPlaceholder, text: $profile.iban)
                    .textInputAutocapitalization(.characters)
                if country.showsBIC {
                    LabeledField("BIC", placeholder: "Ex. AGRIFRPP", text: $profile.bic)
                        .textInputAutocapitalization(.characters)
                }
            } header: {
                Text("Paiement")
            } footer: {
                Text("Affiché sur vos factures pour faciliter le règlement par virement.")
            }

            footer
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var legalFormPlaceholder: String {
        switch profile.country {
        case .france: return "Forme juridique (EI, SASU, SARL…)"
        case .belgique: return "Forme juridique (indépendant, SRL…)"
        case .suisse: return "Forme juridique (raison individuelle, Sàrl, SA…)"
        case .quebec: return "Forme juridique (entreprise individuelle, inc.…)"
        }
    }

    private var showsCapital: Bool {
        let form = profile.legalForm.lowercased()
        return ["sarl", "sas", "sasu", "eurl", "sa", "srl", "sàrl", "sc", "inc", "société"].contains { form.contains($0) }
    }
}

extension BusinessInfoForm where Footer == EmptyView {
    init(profile: Binding<BusinessProfile>, header: AnyView? = nil) {
        self._profile = profile
        self.header = header
        self.footer = EmptyView()
    }
}

struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 2)
    }
}
