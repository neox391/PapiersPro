import XCTest
@testable import PapiersPro

final class TaxAndTotalsTests: XCTestCase {
    private func document(_ country: Country, rate: String, lines: [(String, String)], exempt: Bool = false) -> (DocumentData, BusinessProfile) {
        var profile = BusinessProfile()
        profile.country = country
        profile.trade = .developpeurFreelance
        profile.vatExempt = exempt
        var data = DocumentRules.newDocument(.facture, profile: profile)
        data.taxRateId = rate
        data.lines = lines.map { LineItem(quantity: Decimal(string: $0.0)!, unitPrice: Decimal(string: $0.1)!) }
        return (data, profile)
    }

    func testFrenchStandardRate() {
        let (data, profile) = document(.france, rate: "fr20", lines: [("2", "150"), ("1", "99.99")])
        let totals = DocumentRules.totals(for: data, profile: profile)
        XCTAssertEqual(totals.subtotal, Decimal(string: "399.99"))
        XCTAssertEqual(totals.taxTotal, Decimal(string: "80"))
        XCTAssertEqual(totals.total, Decimal(string: "479.99"))
    }

    func testFrenchReducedRateIsExact() {
        let (data, profile) = document(.france, rate: "fr55", lines: [("1", "100")])
        let totals = DocumentRules.totals(for: data, profile: profile)
        XCTAssertEqual(totals.taxTotal, Decimal(string: "5.5"))
    }

    func testQuebecAppliesTPSAndTVQSeparately() {
        let (data, profile) = document(.quebec, rate: "qcboth", lines: [("1", "100")])
        let totals = DocumentRules.totals(for: data, profile: profile)
        XCTAssertEqual(totals.taxes.count, 2)
        XCTAssertEqual(totals.taxes[0].amount, Decimal(string: "5"))
        XCTAssertEqual(totals.taxes[1].amount, Decimal(string: "9.98"))
        XCTAssertEqual(totals.total, Decimal(string: "114.98"))
    }

    func testVATExemptProfileHasNoTax() {
        let (data, profile) = document(.france, rate: "fr20", lines: [("3", "50")], exempt: true)
        let totals = DocumentRules.totals(for: data, profile: profile)
        XCTAssertEqual(totals.taxTotal, 0)
        XCTAssertEqual(totals.total, 150)
    }

    func testDefaultRatesByTradeAndCountry() {
        XCTAssertEqual(Country.france.defaultTaxRate(for: .restaurateur).id, "fr10")
        XCTAssertEqual(Country.belgique.defaultTaxRate(for: .restaurateur).id, "be12")
        XCTAssertEqual(Country.suisse.defaultTaxRate(for: .photographe).id, "ch81")
        XCTAssertEqual(Country.quebec.defaultTaxRate(for: .commercant).id, "qcboth")
    }
}

final class LegalMentionsTests: XCTestCase {
    func testFrenchFranchiseMention() {
        var profile = BusinessProfile()
        profile.country = .france
        profile.vatExempt = true
        let data = DocumentRules.newDocument(.facture, profile: profile)
        XCTAssertTrue(DocumentRules.legalMentions(for: data, profile: profile).contains { $0.contains("293 B") })
    }

    func testRecoveryFeeOnlyForProfessionalClients() {
        var profile = BusinessProfile()
        profile.country = .france
        var data = DocumentRules.newDocument(.facture, profile: profile)
        data.client.isProfessional = false
        XCTAssertFalse(DocumentRules.legalMentions(for: data, profile: profile).contains { $0.contains("40 €") })
        data.client.isProfessional = true
        XCTAssertTrue(DocumentRules.legalMentions(for: data, profile: profile).contains { $0.contains("40 €") })
    }

    func testBuildingTradeShowsDecennialInsurance() {
        var profile = BusinessProfile()
        profile.country = .france
        profile.trade = .artisanBatiment
        profile.insurance = "Assureur X, police 123"
        let data = DocumentRules.newDocument(.devis, profile: profile)
        XCTAssertTrue(DocumentRules.legalMentions(for: data, profile: profile).contains { $0.contains("décennale") && $0.contains("Assureur X") })
    }

    func testFormHidesIrrelevantFields() {
        let receipt = DocumentRules.configuration(for: .recu, trade: .commercant, country: .france)
        XCTAssertFalse(receipt.showsValidity)
        XCTAssertFalse(receipt.showsIntervention)
        let quote = DocumentRules.configuration(for: .devis, trade: .artisanBatiment, country: .france)
        XCTAssertTrue(quote.showsValidity)
        XCTAssertTrue(quote.showsLines)
    }
}

@MainActor
final class DocumentStoreTests: XCTestCase {
    private var directory: URL!

    override func setUp() async throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> DocumentStore {
        let store = DocumentStore(directory: directory)
        var profile = BusinessProfile()
        profile.companyName = "Test SARL"
        store.saveProfile(profile)
        return store
    }

    func testSequentialNumbering() async {
        let store = makeStore()
        let profile = store.profile!
        let year = Calendar(identifier: .gregorian).component(.year, from: .now)
        let first = store.save(DocumentRules.newDocument(.facture, profile: profile), id: nil)
        let second = store.save(DocumentRules.newDocument(.facture, profile: profile), id: nil)
        let quote = store.save(DocumentRules.newDocument(.devis, profile: profile), id: nil)
        XCTAssertEqual(first.data.number, "FAC-\(year)-0001")
        XCTAssertEqual(second.data.number, "FAC-\(year)-0002")
        XCTAssertEqual(quote.data.number, "DEV-\(year)-0001")
    }

    func testEditingKeepsNumberAndDoesNotCountAgain() async {
        let store = makeStore()
        let saved = store.save(DocumentRules.newDocument(.facture, profile: store.profile!), id: nil)
        var edited = saved.data
        edited.notes = "Modifié"
        let resaved = store.save(edited, id: saved.id)
        XCTAssertEqual(resaved.data.number, saved.data.number)
        XCTAssertEqual(store.documents.count, 1)
        XCTAssertEqual(store.documentsCreated(), 1)
    }

    func testFreeLimitOfThreePerMonth() async {
        let store = makeStore()
        for _ in 0..<3 {
            XCTAssertTrue(store.canCreateDocument(isPremium: false))
            store.save(DocumentRules.newDocument(.recu, profile: store.profile!), id: nil)
        }
        XCTAssertFalse(store.canCreateDocument(isPremium: false))
        XCTAssertTrue(store.canCreateDocument(isPremium: true))
    }

    func testPersistenceAcrossLaunches() async {
        let store = makeStore()
        store.save(DocumentRules.newDocument(.devis, profile: store.profile!), id: nil)
        let reloaded = DocumentStore(directory: directory)
        XCTAssertEqual(reloaded.profile?.companyName, "Test SARL")
        XCTAssertEqual(reloaded.documents.count, 1)
        XCTAssertEqual(reloaded.nextNumber(for: .devis).suffix(4), "0002")
    }

    func testQuoteToInvoiceKeepsReference() async {
        let store = makeStore()
        let quote = store.save(DocumentRules.newDocument(.devis, profile: store.profile!), id: nil)
        let invoice = DocumentRules.duplicate(quote.data, as: .facture, profile: store.profile!)
        XCTAssertEqual(invoice.type, .facture)
        XCTAssertEqual(invoice.number, "")
        XCTAssertEqual(invoice.quoteReference, quote.data.number)
    }
}
