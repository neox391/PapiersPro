import Foundation
import Observation
import StoreKit

/// StoreKit 2 monthly subscription "PapiersPro Illimité".
@MainActor
@Observable
final class SubscriptionManager {
    static let monthlyProductId = "com.papierspro.app.unlimited.monthly"

    private(set) var product: Product?
    private(set) var isPremium = false
    private(set) var isLoading = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await start() }
    }

    func start() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            product = try await Product.products(for: [Self.monthlyProductId]).first
        } catch {
            errorMessage = "Impossible de charger l'abonnement. Vérifiez votre connexion."
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.monthlyProductId,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPremium = active
    }

    func purchase() async {
        if product == nil { await loadProducts() }
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "L'achat n'a pas pu aboutir. Réessayez plus tard."
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            errorMessage = "La restauration a échoué. Réessayez plus tard."
        }
        await refreshEntitlements()
    }
}
