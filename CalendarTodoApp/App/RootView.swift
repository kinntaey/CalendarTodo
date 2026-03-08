import CalendarTodoCore
import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if authService.isLoading {
                ProgressView("로딩 중...")
            } else if !authService.isAuthenticated {
                SignInView()
            } else {
                ContentView()
            }
        }
        .animation(.default, value: authService.isAuthenticated)
    }
}
