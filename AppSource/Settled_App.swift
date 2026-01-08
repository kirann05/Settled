import SwiftUI
import Firebase
import FirebaseFirestore
// import FirebaseAppCheck  // Temporarily disabled until proper setup
import GoogleSignIn
import UserNotifications
// TODO: Uncomment after adding FirebaseMessaging dependency in Xcode
// import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate { // TODO: Add MessagingDelegate after FirebaseMessaging
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        // TEMPORARILY DISABLED: Firebase App Check until proper setup is complete
        // The iOS app needs to be registered in Firebase Console first

        // Configure Firebase as early as possible
        FirebaseApp.configure()

        // Configure Firestore settings with modern API
        let db = Firestore.firestore()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
        db.settings = settings
        
        // Configure Google Sign-In with client ID from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientID = plist["CLIENT_ID"] as? String else {
            return false
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Configure Firebase Cloud Messaging
        setupPushNotifications(application: application)
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Handle Google Sign-In URL scheme
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Push Notification Setup

    private func setupPushNotifications(application: UIApplication) {

        // Initialize FCM Token Manager early

        // TODO: Uncomment after adding FirebaseMessaging dependency
        // Set FCM messaging delegate
        // Messaging.messaging().delegate = self

        // Set UNUserNotificationCenter delegate with enhanced error handling
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions with comprehensive handling
        var authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        // Add iOS version specific options
        if #available(iOS 12.0, *) {
            authOptions.insert(.criticalAlert)
            authOptions.insert(.providesAppNotificationSettings)
        }
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions
        ) { [weak self] granted, error in

            // Handle authorization errors
            if let error = error {

                // Log specific error types for debugging
                if let authError = error as? UNError {
                    switch authError.code {
                    case .notificationsNotAllowed:
                        break
                    case .attachmentInvalidURL, .attachmentUnrecognizedType:
                        break
                    default:
                        break
                    }
                }
                return
            }

            // Handle authorization result
            if granted {

                // Register for remote notifications on main thread
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }

                // Initialize FCM token fetching after successful authorization
                Task {
                }

            } else {

                // Check current notification settings for detailed feedback
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        self?.logNotificationSettings(settings)
                    }
                }
            }
        }

        // Set up periodic notification settings check
        setupNotificationSettingsMonitoring()

        // Clean up any stale notification actions from previous sessions
        cleanupStaleNotificationActions()

        // Initialize push notification services
        initializePushNotificationServices()
    }

    /// Monitor notification settings changes
    private func setupNotificationSettingsMonitoring() {
        // Check notification settings every time app becomes active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    self?.handleNotificationSettingsUpdate(settings)
                }
            }
        }
    }

    /// Handle notification settings updates
    private func handleNotificationSettingsUpdate(_ settings: UNNotificationSettings) {
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            if !UIApplication.shared.isRegisteredForRemoteNotifications {
                UIApplication.shared.registerForRemoteNotifications()
            }
        case .denied:
            break
        case .notDetermined:
            break
        case .ephemeral:
            break
        @unknown default:
            break
        }
    }

    /// Log detailed notification settings for debugging
    private func logNotificationSettings(_ settings: UNNotificationSettings) {
    }

    /// Helper function to describe UNAuthorizationStatus
    private func authorizationStatusDescription(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral (App Clip)"
        @unknown default:
            return "Unknown (\(status.rawValue))"
        }
    }

    /// Helper function to describe UNNotificationSetting
    private func notificationSettingDescription(_ setting: UNNotificationSetting) -> String {
        switch setting {
        case .notSupported:
            return "Not Supported"
        case .disabled:
            return "Disabled"
        case .enabled:
            return "Enabled"
        @unknown default:
            return "Unknown (\(setting.rawValue))"
        }
    }
    
    // MARK: - Remote Notification Registration

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()

        // Store APN device token for debugging
        UserDefaults.standard.set(tokenString, forKey: "apn_device_token")
        UserDefaults.standard.set(Date(), forKey: "apn_token_received_date")

        // TODO: Uncomment after adding FirebaseMessaging dependency
        // Set APNs token for Firebase Messaging
        // Messaging.messaging().apnsToken = deviceToken

        // Note: Push notification system validation will be handled separately
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {

        // Log specific error details for debugging
        if let nsError = error as NSError? {

            // Common registration failure reasons
            switch nsError.code {
            case 3000...3999:
                break
            case 1000...1999:
                break
            default:
                break
            }
        }

        // Store failure information for debugging
        UserDefaults.standard.set(error.localizedDescription, forKey: "apn_registration_error")
        UserDefaults.standard.set(Date(), forKey: "apn_registration_failed_date")
    }

    /// Validates the complete push notification system
    private func validatePushNotificationSystem() async {

        // Basic validation - check if notification center is available
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let isConfiguredCorrectly = settings.authorizationStatus == .authorized &&
                                          settings.alertSetting == .enabled &&
                                          settings.soundSetting == .enabled

                if isConfiguredCorrectly {
                } else {
                    self.logNotificationSettings(settings)
                }
            }
        }

    }
    
    // MARK: - MessagingDelegate (TODO: Uncomment after adding FirebaseMessaging)
    /*
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            return
        }
        
        
        // Store token in Firestore when user is authenticated
        Task {
            await FCMTokenManager.shared.updateFCMToken(fcmToken)
        }
    }
    */
    
    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let request = notification.request
        let content = request.content
        let userInfo = content.userInfo


        // Log custom data for debugging
        if !userInfo.isEmpty {
        }

        // Enhanced presentation options based on content type
        var presentationOptions: UNNotificationPresentationOptions = [.banner, .sound]

        // Add badge only if specified
        if content.badge != nil {
            presentationOptions.insert(.badge)
        }

        // Add list presentation for iOS 14+
        if #available(iOS 14.0, *) {
            presentationOptions.insert(.list)
        }

        // Show critical alerts differently (only available on iOS 12.0+)
        if content.categoryIdentifier == "BILL_CRITICAL" {
            if #available(iOS 12.0, *) {
                // Note: .criticalAlert is not available in UNNotificationPresentationOptions
                // Critical alerts are handled through UNNotificationContent.sound with UNNotificationSoundName.defaultCritical
                presentationOptions.insert(.sound)
            }
        }

        completionHandler(presentationOptions)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let notification = response.notification
        let userInfo = notification.request.content.userInfo
        let actionIdentifier = response.actionIdentifier


        // Handle different action types
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            handleNotificationTap(userInfo: userInfo)

        case UNNotificationDismissActionIdentifier:
            handleNotificationDismiss(userInfo: userInfo)

        case "VIEW_BILL_ACTION":
            handleViewBillAction(userInfo: userInfo)

        case "MARK_PAID_ACTION":
            handleMarkPaidAction(userInfo: userInfo)

        default:
            break
        }

        completionHandler()
    }

    /// Handle notification tap (default action)
    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // Extract bill ID for navigation
        if let billId = userInfo["billId"] as? String {

            // Store the bill ID for navigation after app launch
            UserDefaults.standard.set(billId, forKey: "pending_bill_navigation")
            UserDefaults.standard.set(Date(), forKey: "pending_navigation_timestamp")

            // TODO: Implement deep linking navigation
            // This would typically trigger navigation in ContentView
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToBill"),
                object: nil,
                userInfo: ["billId": billId]
            )
        }
    }

    /// Handle notification dismiss
    private func handleNotificationDismiss(userInfo: [AnyHashable: Any]) {
        // Log dismissal for analytics
        if let billId = userInfo["billId"] as? String {

            // Could track engagement metrics here
            UserDefaults.standard.set(Date(), forKey: "last_notification_dismissed")
        }
    }

    /// Handle view bill action
    private func handleViewBillAction(userInfo: [AnyHashable: Any]) {
        // Same as tap handling
        handleNotificationTap(userInfo: userInfo)
    }

    /// Handle mark paid action
    private func handleMarkPaidAction(userInfo: [AnyHashable: Any]) {
        guard let billId = userInfo["billId"] as? String else {
            return
        }


        // Store the action for processing when app becomes active
        UserDefaults.standard.set(billId, forKey: "pending_mark_paid_bill")
        UserDefaults.standard.set(Date(), forKey: "pending_mark_paid_timestamp")

        // TODO: Implement background processing for mark paid
        // This would typically trigger a background task
        NotificationCenter.default.post(
            name: Notification.Name("MarkBillPaid"),
            object: nil,
            userInfo: ["billId": billId]
        )
    }

    /// Clean up stale navigation intents on app launch
    func cleanupStaleNotificationActions() {
        let maxAge: TimeInterval = 24 * 60 * 60 // 24 hours

        // Clean up stale navigation
        if let navTimestamp = UserDefaults.standard.object(forKey: "pending_navigation_timestamp") as? Date,
           Date().timeIntervalSince(navTimestamp) > maxAge {
            UserDefaults.standard.removeObject(forKey: "pending_bill_navigation")
            UserDefaults.standard.removeObject(forKey: "pending_navigation_timestamp")
        }

        // Clean up stale mark paid
        if let paidTimestamp = UserDefaults.standard.object(forKey: "pending_mark_paid_timestamp") as? Date,
           Date().timeIntervalSince(paidTimestamp) > maxAge {
            UserDefaults.standard.removeObject(forKey: "pending_mark_paid_bill")
            UserDefaults.standard.removeObject(forKey: "pending_mark_paid_timestamp")
        }
    }

    /// Initialize push notification services
    private func initializePushNotificationServices() {

        // Note: FCMTokenManager and PushNotificationService should be initialized
        // automatically via their shared instances when first accessed
        // This method serves as a placeholder for any additional initialization

    }

    // MARK: - MessagingDelegate (TODO: Uncomment after adding FirebaseMessaging)

    /*
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {

        guard let fcmToken = fcmToken else {
            return
        }

        // Store token with timestamp for debugging
        UserDefaults.standard.set(fcmToken, forKey: "fcm_registration_token")
        UserDefaults.standard.set(Date(), forKey: "fcm_token_received_date")


        // Update FCM token via FCMTokenManager
        Task {
            do {
                try await FCMTokenManager.shared.updateCurrentUserToken(fcmToken)
            } catch {
            }
        }
    }
    */

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

@main
struct SettledApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var sessionRecoveryManager = SettledRecoveryManager()
    @StateObject private var deepLinkCoordinator = DeepLinkCoordinator()

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isInitializing {
                    // Show branded loading screen instead of blank screen
                    LoadingView()
                } else if authViewModel.isSignedIn {
                    ContentView()
                        .environmentObject(authViewModel)
                        .environmentObject(sessionRecoveryManager)
                        .environmentObject(deepLinkCoordinator)
                        .onAppear {
                            // Check for saved session when app starts
                            sessionRecoveryManager.checkForSavedSession()

                            // Process pending deep link after successful login
                            if let pendingDeepLink = deepLinkCoordinator.pendingDeepLink {
                                deepLinkCoordinator.handle(pendingDeepLink)
                                deepLinkCoordinator.clearPendingDeepLink()
                            }
                        }
                        .onOpenURL { url in
                            // Handle deep links from notifications and external sources
                            deepLinkCoordinator.handle(url)
                        }
                } else {
                    AuthView()
                        .environmentObject(authViewModel)
                        .environmentObject(deepLinkCoordinator)
                        .onOpenURL { url in
                            // Store deep link for processing after login
                            deepLinkCoordinator.pendingDeepLink = url
                        }
                }
            }
        }
    }
}

struct LoadingView: View {
    @State private var isAnimating = false
    @State private var loadingText = "Loading..."
    @State private var dots = ""
    
    var body: some View {
        ZStack {
            // Gradient background similar to AuthView
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.adaptiveAccentBlue.opacity(0.1),
                    Color.purple.opacity(0.05),
                    Color(.systemBackground)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // App Icon and Branding
                VStack(spacing: 24) {
                    // Enhanced animated icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.adaptiveAccentBlue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 8)
                            .scaleEffect(isAnimating ? 1.05 : 1.0)
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                    
                    VStack(spacing: 12) {
                        Text("Settled")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text(loadingText + dots)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .animation(.easeInOut(duration: 0.5), value: dots)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            isAnimating = true
            startLoadingAnimation()
        }
    }
    
    private func startLoadingAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            withAnimation {
                if dots.count >= 3 {
                    dots = ""
                } else {
                    dots += "."
                }
            }
        }
    }
}