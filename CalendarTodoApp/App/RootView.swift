import CalendarTodoCore
import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AppSettings.self) private var appSettings

    @Environment(\.scenePhase) private var scenePhase
    @State private var hasProfile: Bool? = nil
    @State private var showCalendarSetup = false
    @State private var wasInBackground = true

    var body: some View {
        Group {
            if !appSettings.hasCompletedOnboarding {
                OnboardingView()
            } else if !authService.isAuthenticated {
                SignInView()
            } else if hasProfile == nil {
                ProgressView(L10n.loading)
                    .task { await checkProfile() }
            } else if hasProfile == false {
                ProfileSetupView(onComplete: {
                    showCalendarSetup = true
                    hasProfile = true
                })
            } else if showCalendarSetup {
                CalendarSyncSetupView(onComplete: {
                    showCalendarSetup = false
                })
            } else {
                ContentView()
                    .onAppear {
                        guard wasInBackground else { return }
                        wasInBackground = false
                        Task {
                            await InterstitialAdManager.shared.loadAd()
                            try? await Task.sleep(for: .seconds(1))
                            InterstitialAdManager.shared.showAdIfNeeded()
                        }
                    }
            }
        }
        .animation(.default, value: authService.isAuthenticated)
        .animation(.default, value: appSettings.hasCompletedOnboarding)
        .animation(.default, value: hasProfile)
        .onChange(of: scenePhase) { old, new in
            if new == .background || new == .inactive {
                wasInBackground = true
            } else if new == .active && wasInBackground && authService.isAuthenticated {
                wasInBackground = false
                Task {
                    await InterstitialAdManager.shared.loadAd()
                    try? await Task.sleep(for: .seconds(1))
                    InterstitialAdManager.shared.showAdIfNeeded()
                }
            }
        }
        .onChange(of: authService.isAuthenticated) { _, isAuth in
            if isAuth {
                hasProfile = nil // reset to trigger check
            } else {
                hasProfile = nil
            }
        }
    }

    private func checkProfile() async {
        print("[Root] Checking profile... isAuth=\(authService.isAuthenticated), userID=\(authService.currentUser?.id.uuidString ?? "nil")")
        do {
            let profile = try await authService.fetchProfile()
            hasProfile = profile != nil
            print("[Root] Profile check result: \(profile != nil)")
        } catch {
            hasProfile = false
            print("[Root] Profile check error: \(error.localizedDescription)")
        }
    }
}
