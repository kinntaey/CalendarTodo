import GoogleMobileAds
import SwiftUI

@MainActor
@Observable
final class InterstitialAdManager {
    static let shared = InterstitialAdManager()

    private var interstitialAd: InterstitialAd?
    private let adUnitID = "ca-app-pub-7476928655882352/9387112105"

    private init() {}

    func loadAd() async {
        guard !AdRemovalStore.shared.isAdRemoved else { return }
        do {
            interstitialAd = try await InterstitialAd.load(with: adUnitID, request: Request())
        } catch {
            print("[Ad] Interstitial load failed: \(error.localizedDescription)")
        }
    }

    func showAdIfNeeded() {
        guard !AdRemovalStore.shared.isAdRemoved, let ad = interstitialAd else { return }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            ad.present(from: rootVC)
            interstitialAd = nil
        }
    }
}
