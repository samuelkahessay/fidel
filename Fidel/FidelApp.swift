import SwiftUI
import SwiftData
import AuthenticationServices
import Security

@main
struct FidelApp: App {
    private static let cloudKitContainerIdentifier = "iCloud.dev.skahessay.learnamharic"
    @State private var authManager = AuthManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self,
            SelamConversation.self,
            SelamMessage.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(Self.cloudKitContainerIdentifier)
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .environment(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

struct AuthGateView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        Group {
            if authManager.isCheckingSession {
                ProgressView("Checking account...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if authManager.isAuthenticated {
                ContentView()
            } else {
                AppleSignInView()
            }
        }
        .task {
            await authManager.restoreSessionIfNeeded()
        }
    }
}

struct AppleSignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

            VStack(spacing: AppTheme.Spacing.sm) {
                Text("Fidel")
                    .font(AppTheme.Typography.largeTitle)
                    .foregroundColor(.primary)

                Text("Sign in with Apple to save your personal learning progress.")
                    .font(AppTheme.Typography.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }

            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    await authManager.handleAppleSignIn(result: result)
                }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .padding(.horizontal, AppTheme.Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

@Observable
final class AuthManager {
    static let shared = AuthManager()
    static let previewUserId = "preview-user"

    var currentUserId: String?
    var displayName: String?
    var isCheckingSession = true
    var errorMessage: String?

    var isAuthenticated: Bool { currentUserId != nil }

    private let appleUserIdKey = "fidel.apple.user.id"
    private let displayNameKey = "fidel.apple.display.name"
    private let defaults: UserDefaults
    private var hasRestoredSession = false

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    func restoreSessionIfNeeded() async {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true
        await restoreSession()
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Invalid Apple sign-in response."
                return
            }

            guard KeychainStore.set(credential.user, for: appleUserIdKey) else {
                errorMessage = "Could not save sign-in session."
                return
            }

            currentUserId = credential.user
            displayName = formattedDisplayName(from: credential.fullName) ?? defaults.string(forKey: displayNameKey)
            if let displayName {
                defaults.set(displayName, forKey: displayNameKey)
            }
            errorMessage = nil
            isCheckingSession = false

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                errorMessage = nil
            } else {
                let code = (error as? ASAuthorizationError)?.code.rawValue ?? -1
                errorMessage = "\(error.localizedDescription) (code: \(code))"
            }
        }
    }

    func signOut() {
        clearStoredSession()
    }

    private func restoreSession() async {
        isCheckingSession = true
        errorMessage = nil

        guard let storedUserId = KeychainStore.value(for: appleUserIdKey) else {
            currentUserId = nil
            displayName = nil
            isCheckingSession = false
            return
        }

        let state = await credentialState(for: storedUserId)
        switch state {
        case .authorized:
            currentUserId = storedUserId
            displayName = defaults.string(forKey: displayNameKey)

        case .revoked, .notFound:
            clearStoredSession()

        @unknown default:
            clearStoredSession()
        }

        isCheckingSession = false
    }

    private func clearStoredSession() {
        currentUserId = nil
        displayName = nil
        errorMessage = nil
        KeychainStore.deleteValue(for: appleUserIdKey)
        defaults.removeObject(forKey: displayNameKey)
    }

    private func credentialState(for userId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userId) { state, error in
                guard error == nil else {
                    continuation.resume(returning: .notFound)
                    return
                }
                continuation.resume(returning: state)
            }
        }
    }

    private func formattedDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

private enum KeychainStore {
    private static let service = "dev.skahessay.learnamharic.auth"

    static func set(_ value: String, for key: String) -> Bool {
        let data = Data(value.utf8)
        deleteValue(for: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func value(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func deleteValue(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
