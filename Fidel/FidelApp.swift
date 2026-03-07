import SwiftUI
import SwiftData
import AuthenticationServices
import Security
import OSLog

private enum AppConfiguration {
    static let cloudKitContainerIdentifier = "iCloud.dev.skahessay.learnamharic"
    static let keychainService = "dev.skahessay.learnamharic.auth"
}

private let authLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "dev.skahessay.learnamharic", category: "Auth")

@main
struct FidelApp: App {
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
            cloudKitDatabase: .private(AppConfiguration.cloudKitContainerIdentifier)
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
            } else if authManager.isAuthenticated || authManager.isGuest {
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
        ScrollView {
            VStack(spacing: AppTheme.Spacing.lg) {
                VStack(spacing: AppTheme.Spacing.sm) {
                    Text("Fidel")
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundColor(.primary)

                    Text("Sign in with Apple to save your personal learning progress.")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let authDiagnostic = authManager.authDiagnostic {
                    AuthDiagnosticCard(diagnostic: authDiagnostic)
                        .padding(.horizontal, AppTheme.Spacing.md)
                }

                SignInWithAppleButton(.continue) { request in
                    authManager.prepareForAppleSignIn()
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    Task {
                        await authManager.handleAppleSignIn(result: result)
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 52)
                .padding(.horizontal, AppTheme.Spacing.md)

                Button {
                    authManager.continueAsGuest()
                } label: {
                    Text("Continue as Guest")
                        .font(AppTheme.Typography.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

private struct AuthDiagnosticCard: View {
    let diagnostic: AuthDiagnostic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(diagnostic.title)
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(.primary)

                    Text(diagnostic.summary)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let likelyCause = diagnostic.likelyCause {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Likely cause")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(likelyCause)
                        .font(AppTheme.Typography.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(diagnostic.details) { detail in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(detail.label)
                            .font(AppTheme.Typography.caption.weight(.semibold))
                            .foregroundColor(.primary)

                        Text(detail.value)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if !diagnostic.nextSteps.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Next steps")
                        .font(AppTheme.Typography.caption.weight(.semibold))
                        .foregroundColor(.primary)

                    ForEach(Array(diagnostic.nextSteps.enumerated()), id: \.offset) { index, step in
                        Text("\(index + 1). \(step)")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

@Observable
final class AuthManager {
    static let shared = AuthManager()
    static let previewUserId = "preview-user"

    var currentUserId: String?
    var displayName: String?
    var isCheckingSession = true
    fileprivate var authDiagnostic: AuthDiagnostic?

    var isAuthenticated: Bool { currentUserId != nil }
    private(set) var isGuest = false

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

    func prepareForAppleSignIn() {
        authDiagnostic = nil
    }

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authDiagnostic = AuthDiagnostic(
                    title: "Apple sign-in returned the wrong credential type",
                    summary: "The sheet completed, but the app did not receive an Apple ID credential.",
                    likelyCause: "The authorization flow was interrupted or returned an unexpected payload before the credential reached the app.",
                    details: baseDiagnosticDetails(error: nil, codeLabel: "unexpected-credential-type"),
                    nextSteps: commonRecoverySteps(includeDirectTapReminder: false)
                )
                return
            }

            guard KeychainStore.set(credential.user, for: appleUserIdKey) else {
                authDiagnostic = AuthDiagnostic(
                    title: "Apple sign-in succeeded, but the session could not be stored",
                    summary: "The app received your Apple account identifier, then failed while saving it to the keychain.",
                    likelyCause: "Keychain access often fails when the installed app still uses stale signing data from an older bundle or provisioning profile.",
                    details: baseDiagnosticDetails(error: nil, codeLabel: "keychain-write-failed"),
                    nextSteps: [
                        "Delete the app from the device or simulator and install it again.",
                        "Confirm the app is signed with the same team and bundle ID shown in Xcode.",
                        "If this still fails on a device, restart the device to clear stale keychain state."
                    ]
                )
                return
            }

            currentUserId = credential.user
            displayName = formattedDisplayName(from: credential.fullName) ?? defaults.string(forKey: displayNameKey)
            if let displayName {
                defaults.set(displayName, forKey: displayNameKey)
            }
            authDiagnostic = nil
            isCheckingSession = false

        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                authDiagnostic = nil
            } else {
                authDiagnostic = diagnostic(for: error)
            }
        }
    }

    func continueAsGuest() {
        currentUserId = "guest"
        isGuest = true
        authDiagnostic = nil
        isCheckingSession = false
    }

    func signOut() {
        isGuest = false
        clearStoredSession()
    }

    private func restoreSession() async {
        isCheckingSession = true
        authDiagnostic = nil

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
        authDiagnostic = nil
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

    private func diagnostic(for error: Error) -> AuthDiagnostic {
        log(error: error)

        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .unknown:
                return AuthDiagnostic(
                    title: "Apple sign-in failed with an unknown system error",
                    summary: "The sheet opened, but Apple did not return a usable credential to the app.",
                    likelyCause: "This usually points to a capability or provisioning mismatch for the current bundle ID, especially after an app ID or entitlement change.",
                    details: baseDiagnosticDetails(error: error, codeLabel: authorizationCodeName(authError.code)),
                    nextSteps: commonRecoverySteps(includeDirectTapReminder: false)
                )
            case .failed, .notHandled:
                return AuthDiagnostic(
                    title: "Apple sign-in could not complete",
                    summary: "Apple accepted the request but stopped before returning a credential to the app.",
                    likelyCause: "The installed build often does not match the App ID capabilities or provisioning profile that Apple expects for Sign in with Apple.",
                    details: baseDiagnosticDetails(error: error, codeLabel: authorizationCodeName(authError.code)),
                    nextSteps: commonRecoverySteps(includeDirectTapReminder: false)
                )
            case .invalidResponse:
                return AuthDiagnostic(
                    title: "Apple sign-in returned an invalid response",
                    summary: "The system responded, but the payload was incomplete or unusable.",
                    likelyCause: "This can happen when the request is interrupted or when the signed build does not match the enabled Apple sign-in configuration.",
                    details: baseDiagnosticDetails(error: error, codeLabel: authorizationCodeName(authError.code)),
                    nextSteps: [
                        "Try the sign-in flow again from a fresh app launch.",
                        "Delete the app and reinstall it so Xcode applies the latest entitlements.",
                        "Verify that Sign in with Apple is enabled for the current bundle ID in Apple Developer."
                    ]
                )
            case .notInteractive:
                return AuthDiagnostic(
                    title: "Apple sign-in needs a direct user interaction",
                    summary: "The system refused the request because it was not started from an active tap.",
                    likelyCause: "The request must begin directly from the Sign in with Apple button while the app is in the foreground.",
                    details: baseDiagnosticDetails(error: error, codeLabel: authorizationCodeName(authError.code)),
                    nextSteps: [
                        "Tap the Apple button once to start the flow.",
                        "Do not trigger sign-in from an automatic retry, task, or background callback.",
                        "Bring the app back to the foreground and try again."
                    ]
                )
            case .canceled:
                return AuthDiagnostic(
                    title: "Apple sign-in was canceled",
                    summary: "The sign-in sheet was dismissed before completion.",
                    likelyCause: nil,
                    details: baseDiagnosticDetails(error: error, codeLabel: authorizationCodeName(authError.code)),
                    nextSteps: []
                )
            @unknown default:
                return AuthDiagnostic(
                    title: "Apple sign-in failed with an unrecognized error",
                    summary: "The system returned an error code this build does not map yet.",
                    likelyCause: "Treat this as a signing or environment issue first, then use the system code below to narrow it down.",
                    details: baseDiagnosticDetails(error: error, codeLabel: "unrecognized-\(authError.code.rawValue)"),
                    nextSteps: commonRecoverySteps(includeDirectTapReminder: false)
                )
            }
        }

        return AuthDiagnostic(
            title: "Apple sign-in failed before the app could classify the error",
            summary: "The system returned a non-authorization error.",
            likelyCause: "Start with the runtime details below. The bundle ID, runtime environment, and system message usually explain which setup layer failed.",
            details: baseDiagnosticDetails(error: error, codeLabel: "non-auth-error"),
            nextSteps: commonRecoverySteps(includeDirectTapReminder: false)
        )
    }

    private func baseDiagnosticDetails(error: Error?, codeLabel: String) -> [AuthDiagnostic.Detail] {
        let runtimeBundleId = Bundle.main.bundleIdentifier ?? "unknown"
        let runtimeEnvironment = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil ? "Device" : "Simulator"
        let nsError = error as NSError?

        var details: [AuthDiagnostic.Detail] = [
            .init(label: "Authorization code", value: codeLabel),
            .init(label: "Runtime bundle ID", value: runtimeBundleId),
            .init(label: "CloudKit container", value: AppConfiguration.cloudKitContainerIdentifier),
            .init(label: "Keychain service", value: AppConfiguration.keychainService),
            .init(label: "Runtime environment", value: runtimeEnvironment)
        ]

        if let nsError {
            details.append(.init(label: "System domain", value: nsError.domain))
            details.append(.init(label: "System code", value: "\(nsError.code)"))

            let localizedMessage = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            if !localizedMessage.isEmpty {
                details.append(.init(label: "System message", value: localizedMessage))
            }

            if let failureReason = nsError.localizedFailureReason?.trimmingCharacters(in: .whitespacesAndNewlines),
               !failureReason.isEmpty {
                details.append(.init(label: "Failure reason", value: failureReason))
            }

            if let recoverySuggestion = nsError.localizedRecoverySuggestion?.trimmingCharacters(in: .whitespacesAndNewlines),
               !recoverySuggestion.isEmpty {
                details.append(.init(label: "Recovery hint", value: recoverySuggestion))
            }

            details.append(contentsOf: flattenedUserInfoDetails(from: nsError))
        }

        return details
    }

    private func commonRecoverySteps(includeDirectTapReminder: Bool) -> [String] {
        var steps = [
            "In Apple Developer, enable Sign in with Apple for the current bundle ID shown below.",
            "In Xcode, open Signing & Capabilities and confirm this target still uses the same team, bundle ID, and entitlements.",
            "Delete the app from the device or simulator, then rebuild so Xcode installs a fresh provisioning profile."
        ]

        if ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil {
            steps.append("If you are testing on Simulator, confirm it is signed into an Apple ID. A physical device is the more reliable test for this flow.")
        }

        if includeDirectTapReminder {
            steps.append("Start the flow from a direct tap on the Apple button.")
        }

        return steps
    }

    private func authorizationCodeName(_ code: ASAuthorizationError.Code) -> String {
        switch code {
        case .unknown:
            return "unknown (\(code.rawValue))"
        case .canceled:
            return "canceled (\(code.rawValue))"
        case .invalidResponse:
            return "invalidResponse (\(code.rawValue))"
        case .notHandled:
            return "notHandled (\(code.rawValue))"
        case .failed:
            return "failed (\(code.rawValue))"
        case .notInteractive:
            return "notInteractive (\(code.rawValue))"
        @unknown default:
            return "unrecognized (\(code.rawValue))"
        }
    }

    private func flattenedUserInfoDetails(from error: NSError) -> [AuthDiagnostic.Detail] {
        let interestingKeys = [
            NSUnderlyingErrorKey,
            NSLocalizedFailureReasonErrorKey,
            NSLocalizedRecoverySuggestionErrorKey,
            NSLocalizedDescriptionKey
        ]

        var details: [AuthDiagnostic.Detail] = []

        for key in interestingKeys {
            guard let value = error.userInfo[key] else { continue }
            let renderedValue = renderUserInfoValue(value)
            guard !renderedValue.isEmpty else { continue }
            details.append(.init(label: "userInfo[\(key)]", value: renderedValue))
        }

        let remainingKeys = error.userInfo.keys
            .map { "\($0)" }
            .filter { !interestingKeys.contains($0) }
            .sorted()

        for key in remainingKeys {
            guard let value = error.userInfo[key] else { continue }
            let renderedValue = renderUserInfoValue(value)
            guard !renderedValue.isEmpty else { continue }
            details.append(.init(label: "userInfo[\(key)]", value: renderedValue))
        }

        return details
    }

    private func renderUserInfoValue(_ value: Any) -> String {
        switch value {
        case let nestedError as NSError:
            let description = nestedError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return "domain=\(nestedError.domain), code=\(nestedError.code), message=\(description)"
        case let string as String:
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        case let array as [Any]:
            return array.map(renderUserInfoValue).joined(separator: " | ")
        default:
            return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func log(error: Error) {
        let nsError = error as NSError
        authLogger.error("Apple Sign-In failed. domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) message=\(nsError.localizedDescription, privacy: .public)")

        if !nsError.userInfo.isEmpty {
            let renderedUserInfo = nsError.userInfo
                .map { key, value in "\(key)=\(renderUserInfoValue(value))" }
                .sorted()
                .joined(separator: " | ")
            authLogger.error("Apple Sign-In userInfo: \(renderedUserInfo, privacy: .public)")
        }
    }
}

fileprivate struct AuthDiagnostic: Identifiable {
    struct Detail: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    let id = UUID()
    let title: String
    let summary: String
    let likelyCause: String?
    let details: [Detail]
    let nextSteps: [String]
}

private enum KeychainStore {
    private static let service = AppConfiguration.keychainService

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
