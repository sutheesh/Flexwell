import Foundation
import Observation
import StoreKit

/// Loads products, runs purchases, restores, watches transactions. Knows about StoreKit and nothing else.
@Observable
@MainActor
final class StoreService {
    /// Permanent once created in App Store Connect — they ship inside purchases.
    enum ProductID {
        static let monthly = "com.ilabbs.flexfit.pro.monthly"
        static let yearly = "com.ilabbs.flexfit.pro.yearly"
        static let all = [yearly, monthly]
        static let groupID = "21530000"
    }

    private(set) var products: [Product] = []
    private(set) var isLoading = false
    var lastError: String?
    private(set) var purchasedPro = false

    private let entitlements: EntitlementService
    private var updates: Task<Void, Never>?

    init(entitlements: EntitlementService) {
        self.entitlements = entitlements
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if let tx = try? self?.verified(result) { await tx.finish() }
                await self?.refreshPurchaseStatus()
            }
        }
    }

    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.id == ProductID.yearly && $1.id != ProductID.yearly }
        } catch {
            lastError = "Couldn't reach the App Store. Check your connection and try again."
        }
    }

    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let tx = try verified(verification)
                await tx.finish()
                await refreshPurchaseStatus()
                return purchasedPro
            case .pending:
                lastError = "Waiting for approval. You'll get Pro once it's confirmed."
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "That didn't go through. Nothing has been charged."
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Couldn't restore purchases right now."
        }
        await refreshPurchaseStatus()
    }

    func refreshPurchaseStatus() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if let tx = try? verified(result), ProductID.all.contains(tx.productID), tx.revocationDate == nil {
                active = true
            }
        }
        purchasedPro = active
        entitlements.premiumStatusChanged(to: active)
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified(let value, let error):
            #if DEBUG
            // StoreKit Testing signs locally; honour it while developing, never in Release.
            print("StoreKit: unverified transaction honoured in DEBUG:", error)
            return value
            #else
            throw error
            #endif
        }
    }
}
