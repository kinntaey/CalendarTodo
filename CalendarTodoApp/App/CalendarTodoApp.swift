import CalendarTodoCore
import SwiftUI
import SwiftData

@main
struct CalendarTodoApp: App {
    @State private var authService = AuthService()
    @State private var appSettings = AppSettings()

    #if !os(macOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LocalEvent.self,
            LocalTodo.self,
            LocalTodoList.self,
            LocalTag.self,
            LocalProfile.self,
            LocalNotification.self,
            SyncCursor.self,
        ])

        let storeURL: URL
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier) {
            storeURL = groupURL.appending(path: "CalendarTodo.store")
        } else {
            storeURL = URL.applicationSupportDirectory.appending(path: "CalendarTodo.store")
        }

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            allowsSave: true
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(appSettings)
                .environment(\.locale, DateHelpers.preferredLocale)
                .task {
                    #if !os(macOS)
                    if authService.isAuthenticated {
                        await PushNotificationService.shared.requestPermission()
                    }
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

#if !os(macOS)
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await PushNotificationService.shared.registerDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] Failed to register: \(error)")
    }

    // 푸시 알림 탭했을 때
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationCenter.default.post(name: .openSocialTab, object: nil)
        completionHandler()
    }

    // 앱이 foreground일 때도 알림 표시
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

extension Notification.Name {
    static let openSocialTab = Notification.Name("openSocialTab")
}
#endif
