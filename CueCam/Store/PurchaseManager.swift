import Foundation
import StoreKit

/// Handles the single non-consumable "Pro" unlock via StoreKit 2.
/// One-time purchase converts better than a subscription for a tool people reach for
/// occasionally, and there's nothing recurring to manage.
@MainActor
final class PurchaseManager: ObservableObject {
    /// Must match the Product ID in App Store Connect (and Products.storekit for testing).
    static let proProductID = "com.rajannagar.CueCam.pro"

    @Published private(set) var product: Product?
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var priceText: String { product?.displayPrice ?? "$6.99" }

    func start() async {
        updatesTask = listenForTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Loading

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            product = products.first
        } catch {
            lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isPro = owned
    }

    // MARK: - Buying

    func purchase() async {
        lastError = nil
        isLoading = true
        defer { isLoading = false }

        // The product may not have loaded yet (e.g. no network, or the StoreKit
        // configuration / App Store Connect product isn't available). Try once more.
        if product == nil { await loadProducts() }
        guard let product else {
            lastError = "The store is unavailable right now. Please try again in a moment."
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isPro = true
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. You were not charged."
        }
    }

    #if DEBUG
    /// Developer-only shortcut to flip Pro on/off while testing. Compiled out of
    /// App Store (Release) builds entirely.
    func debugSetPro(_ on: Bool) { isPro = on }
    #endif

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Transaction updates

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
