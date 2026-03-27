import StoreKit
import SwiftUI

@MainActor
@Observable
final class AdRemovalStore {
    static let shared = AdRemovalStore()

    private let productID = "com.taehee.calendartodo.removeads"
    private(set) var isAdRemoved = false
    private(set) var product: Product?
    private(set) var isLoading = false

    private init() {
        isAdRemoved = UserDefaults.standard.bool(forKey: "isAdRemoved")
        Task {
            await loadProduct()
            await checkEntitlement()
            listenForTransactions()
        }
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            print("[Store] Failed to load products: \(error)")
        }
    }

    func purchase() async {
        guard let product else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                setAdRemoved(true)
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("[Store] Purchase failed: \(error)")
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        try? await AppStore.sync()
        await checkEntitlement()
    }

    private func checkEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == productID {
                setAdRemoved(true)
                return
            }
        }
    }

    private func listenForTransactions() {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == "com.taehee.calendartodo.removeads" {
                        await MainActor.run { AdRemovalStore.shared.setAdRemoved(true) }
                    }
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.verificationFailed
        }
    }

    fileprivate func setAdRemoved(_ value: Bool) {
        isAdRemoved = value
        UserDefaults.standard.set(value, forKey: "isAdRemoved")
    }

    enum StoreError: Error {
        case verificationFailed
    }
}
