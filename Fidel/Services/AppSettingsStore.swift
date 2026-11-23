import Foundation

enum SettingsKeys {
    static let dailyXPGoal = "fidel.settings.dailyXPGoal"
    static let preferredResponseLanguage = "fidel.settings.preferredResponseLanguage"
    static let showsTransliteration = "fidel.settings.showsTransliteration"
    static let autoPlaysPronunciation = "fidel.settings.autoPlaysPronunciation"
    static let hapticsEnabled = "fidel.settings.hapticsEnabled"
    static let selectedReferenceTab = "fidel.settings.selectedReferenceTab"
    static let showsAITools = "fidel.settings.showsAITools"
    static let onboardingComplete = "fidel.settings.onboardingComplete"
    static let lastOpenedActivity = "fidel.settings.lastOpenedActivity"
    static let dailyGoalTier = "fidel.settings.dailyGoalTier"
}

struct AppSettingsStore {
    static let defaultDailyXPGoal = 50

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        registerDefaults()
    }

    var dailyXPGoal: Int {
        get {
            let value = defaults.integer(forKey: SettingsKeys.dailyXPGoal)
            return value > 0 ? value : Self.defaultDailyXPGoal
        }
        nonmutating set {
            defaults.set(clampDailyGoal(newValue), forKey: SettingsKeys.dailyXPGoal)
        }
    }

    var preferredResponseLanguage: String {
        get { defaults.string(forKey: SettingsKeys.preferredResponseLanguage) ?? "mixed" }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.preferredResponseLanguage) }
    }

    var showsTransliteration: Bool {
        get { defaults.bool(forKey: SettingsKeys.showsTransliteration) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.showsTransliteration) }
    }

    var autoPlaysPronunciation: Bool {
        get { defaults.bool(forKey: SettingsKeys.autoPlaysPronunciation) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.autoPlaysPronunciation) }
    }

    var hapticsEnabled: Bool {
        get { defaults.bool(forKey: SettingsKeys.hapticsEnabled) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.hapticsEnabled) }
    }

    var selectedReferenceTab: Int {
        get { defaults.integer(forKey: SettingsKeys.selectedReferenceTab) }
        nonmutating set { defaults.set(max(0, newValue), forKey: SettingsKeys.selectedReferenceTab) }
    }

    var showsAITools: Bool {
        get { defaults.bool(forKey: SettingsKeys.showsAITools) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.showsAITools) }
    }

    var onboardingComplete: Bool {
        get { defaults.bool(forKey: SettingsKeys.onboardingComplete) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.onboardingComplete) }
    }

    var lastOpenedActivity: String? {
        get { defaults.string(forKey: SettingsKeys.lastOpenedActivity) }
        nonmutating set { defaults.set(newValue, forKey: SettingsKeys.lastOpenedActivity) }
    }

    var dailyGoalTier: DailyGoalTier {
        get {
            guard let raw = defaults.string(forKey: SettingsKeys.dailyGoalTier),
                let tier = DailyGoalTier(rawValue: raw)
            else { return .default }
            return tier
        }
        nonmutating set { defaults.set(newValue.rawValue, forKey: SettingsKeys.dailyGoalTier) }
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            SettingsKeys.dailyXPGoal: Self.defaultDailyXPGoal,
            SettingsKeys.preferredResponseLanguage: "mixed",
            SettingsKeys.showsTransliteration: true,
            SettingsKeys.autoPlaysPronunciation: true,
            SettingsKeys.hapticsEnabled: true,
            SettingsKeys.selectedReferenceTab: 0,
            SettingsKeys.showsAITools: true,
            SettingsKeys.onboardingComplete: false,
            SettingsKeys.dailyGoalTier: DailyGoalTier.default.rawValue,
        ])
    }

    private func clampDailyGoal(_ value: Int) -> Int {
        min(max(value, 10), 500)
    }
}
