# Learn Amharic - Authentication & Database Setup Guide

This document provides step-by-step instructions for adding authentication and a database to the Learn Amharic iOS app.

---

## Table of Contents
1. [Authentication Options](#authentication-options)
2. [Clerk Setup (Recommended)](#clerk-setup-recommended)
3. [Database Options](#database-options)
4. [Supabase Integration](#supabase-integration)
5. [Architecture Recommendations](#architecture-recommendations)

---

## Authentication Options

| Provider | Pros | Cons | Best For |
|----------|------|------|----------|
| **Clerk** | Prebuilt SwiftUI views, Simple setup, Great docs | Requires iOS 17+ | Quick MVP, Modern apps |
| **Firebase Auth** | Free tier, Google ecosystem | Complex setup, SDK bloat | Existing Firebase users |
| **Auth0** | Enterprise features, MFA | More complex, Higher pricing | Enterprise apps |
| **Supabase Auth** | Open source, PostgreSQL | Newer iOS SDK | Full-stack with Supabase |

**Recommendation:** Use **Clerk** for authentication + **Supabase** for database (or CloudKit for Apple-only).

---

## Clerk Setup (Recommended)

### Prerequisites
- Xcode 16+
- iOS 17+ deployment target
- Clerk account (free tier available)

### Step 1: Create Clerk Application

1. Go to [clerk.com](https://clerk.com) and sign up
2. Create a new application
3. Select your authentication methods:
   - Email/Password
   - Sign in with Apple (recommended for iOS)
   - Google OAuth (optional)
4. Copy your **Publishable Key** from the dashboard

### Step 2: Configure Clerk Dashboard for iOS

1. Go to **Configure > Native Applications**
2. Click **Add Native Application**
3. Enter your iOS app details:
   - **App ID Prefix**: Found in Apple Developer Portal > Certificates, Identifiers & Profiles > App IDs
   - **Bundle ID**: `com.yourname.LearnAmharic`

### Step 3: Install Clerk iOS SDK

Add to your project via Swift Package Manager:

1. In Xcode: **File > Add Package Dependencies**
2. Search for: `https://github.com/clerk/clerk-ios`
3. Select version `0.50.0` or later

Or add to `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/clerk/clerk-ios", from: "0.50.0")
]
```

### Step 4: Configure Associated Domains

1. In Xcode, select your target > **Signing & Capabilities**
2. Click **+ Capability** > **Associated Domains**
3. Add: `applinks:your-clerk-frontend-api.clerk.accounts.dev`
   - Replace with your Clerk Frontend API domain from dashboard

### Step 5: Initialize Clerk in App

Update `LearnAmharicApp.swift`:

```swift
import SwiftUI
import SwiftData
import ClerkSDK

@main
struct LearnAmharicApp: App {
    // SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProgress.self,
            FlashcardProgress.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    // Clerk instance
    @State private var clerk = Clerk(publishableKey: "pk_test_YOUR_PUBLISHABLE_KEY")
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Load Clerk on app launch
                    try? await clerk.load()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(\.clerk, clerk)  // Inject Clerk into environment
    }
}
```

### Step 6: Create Authentication Flow

Create `AuthenticationView.swift`:

```swift
import SwiftUI
import ClerkSDK

struct AuthenticationView: View {
    @Environment(\.clerk) private var clerk
    
    var body: some View {
        // Check if user is signed in
        if let user = clerk.user {
            // User is authenticated - show main content
            MainTabView(user: user)
        } else {
            // User is not authenticated - show auth view
            AuthView()  // Clerk's prebuilt authentication UI
        }
    }
}

struct MainTabView: View {
    let user: User
    
    var body: some View {
        TabView {
            // Your existing tabs
            LearnView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
            
            PracticeView()
                .tabItem { Label("Practice", systemImage: "brain.head.profile") }
            
            // Add profile tab
            ProfileView(user: user)
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
    }
}

struct ProfileView: View {
    let user: User
    @Environment(\.clerk) private var clerk
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        AsyncImage(url: user.imageUrl) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(user.fullName ?? "Learner")
                                .font(.headline)
                            Text(user.primaryEmailAddress?.emailAddress ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Sign Out", role: .destructive) {
                        Task {
                            try? await clerk.signOut()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}
```

### Step 7: Add Sign in with Apple

1. In Xcode: **Signing & Capabilities > + Capability > Sign in with Apple**
2. In Clerk Dashboard: **Configure > SSO Connections > Apple**
3. Clerk's `AuthView` will automatically show the Apple sign-in button

### Complete Clerk Configuration Checklist

- [ ] Create Clerk application
- [ ] Add Native Application in Clerk dashboard
- [ ] Install ClerkSDK via SPM
- [ ] Add Associated Domains capability
- [ ] Initialize Clerk in app entry point
- [ ] Replace ContentView with AuthenticationView
- [ ] Enable Sign in with Apple capability
- [ ] Test sign up/sign in flow

---

## Database Options

| Option | Sync | Offline | Cost | Best For |
|--------|------|---------|------|----------|
| **SwiftData (Current)** | No | Yes | Free | Local-only data |
| **CloudKit** | Yes | Yes | Free (with limits) | Apple-only apps |
| **Supabase** | Yes | With offline plugin | Free tier | Cross-platform, Full control |
| **Firebase Firestore** | Yes | Yes | Free tier | Google ecosystem |

### Current Setup: SwiftData (Local Only)

The app currently uses SwiftData for local persistence:
- `UserProgress` - XP, streaks, completed lessons
- `FlashcardProgress` - Spaced repetition data

**Limitation:** Data doesn't sync across devices or persist if app is deleted.

---

## Supabase Integration

For cloud sync and cross-device data, add Supabase:

### Step 1: Create Supabase Project

1. Go to [supabase.com](https://supabase.com) and create account
2. Create a new project
3. Copy your **Project URL** and **anon public key**

### Step 2: Create Database Tables

Run this SQL in Supabase SQL Editor:

```sql
-- User progress table
CREATE TABLE user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,  -- Clerk user ID
    total_xp INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_practice_date TIMESTAMPTZ,
    lessons_completed INTEGER[] DEFAULT '{}',
    daily_goal INTEGER DEFAULT 50,
    current_level INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Flashcard progress table
CREATE TABLE flashcard_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    item_id TEXT NOT NULL,
    item_type TEXT NOT NULL,
    stability DOUBLE PRECISION DEFAULT 0,
    difficulty DOUBLE PRECISION DEFAULT 0,
    interval INTEGER DEFAULT 0,
    repetitions INTEGER DEFAULT 0,
    lapses INTEGER DEFAULT 0,
    next_review_date TIMESTAMPTZ DEFAULT NOW(),
    last_review_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, item_id, item_type)
);

-- Row Level Security (RLS)
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE flashcard_progress ENABLE ROW LEVEL SECURITY;

-- Policies: Users can only access their own data
CREATE POLICY "Users can view own progress" ON user_progress
    FOR SELECT USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "Users can update own progress" ON user_progress
    FOR UPDATE USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "Users can insert own progress" ON user_progress
    FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));

-- Same for flashcard_progress
CREATE POLICY "Users can view own flashcards" ON flashcard_progress
    FOR SELECT USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "Users can update own flashcards" ON flashcard_progress
    FOR UPDATE USING (user_id = current_setting('app.user_id', true));

CREATE POLICY "Users can insert own flashcards" ON flashcard_progress
    FOR INSERT WITH CHECK (user_id = current_setting('app.user_id', true));
```

### Step 3: Install Supabase iOS SDK

Add via Swift Package Manager:
```
https://github.com/supabase/supabase-swift
```

### Step 4: Create Supabase Client

Create `SupabaseManager.swift`:

```swift
import Foundation
import Supabase

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        client = SupabaseClient(
            supabaseURL: URL(string: "https://YOUR_PROJECT.supabase.co")!,
            supabaseKey: "YOUR_ANON_KEY"
        )
    }
    
    // MARK: - User Progress
    
    func fetchUserProgress(userId: String) async throws -> UserProgressDTO? {
        let response: [UserProgressDTO] = try await client
            .from("user_progress")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return response.first
    }
    
    func upsertUserProgress(_ progress: UserProgressDTO) async throws {
        try await client
            .from("user_progress")
            .upsert(progress)
            .execute()
    }
    
    // MARK: - Flashcard Progress
    
    func fetchFlashcardProgress(userId: String) async throws -> [FlashcardProgressDTO] {
        try await client
            .from("flashcard_progress")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
    }
    
    func upsertFlashcardProgress(_ progress: FlashcardProgressDTO) async throws {
        try await client
            .from("flashcard_progress")
            .upsert(progress)
            .execute()
    }
}

// DTOs for Supabase
struct UserProgressDTO: Codable {
    let id: UUID?
    let userId: String
    var totalXp: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastPracticeDate: Date?
    var lessonsCompleted: [Int]
    var dailyGoal: Int
    var currentLevel: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case totalXp = "total_xp"
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastPracticeDate = "last_practice_date"
        case lessonsCompleted = "lessons_completed"
        case dailyGoal = "daily_goal"
        case currentLevel = "current_level"
    }
}

struct FlashcardProgressDTO: Codable {
    let id: UUID?
    let userId: String
    let itemId: String
    let itemType: String
    var stability: Double
    var difficulty: Double
    var interval: Int
    var repetitions: Int
    var lapses: Int
    var nextReviewDate: Date
    var lastReviewDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case itemId = "item_id"
        case itemType = "item_type"
        case stability, difficulty, interval, repetitions, lapses
        case nextReviewDate = "next_review_date"
        case lastReviewDate = "last_review_date"
    }
}
```

### Step 5: Sync Strategy

Create `SyncManager.swift`:

```swift
import Foundation

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    
    private let supabase = SupabaseManager.shared
    
    // Sync local SwiftData to Supabase
    func syncToCloud(userId: String, localProgress: UserProgress) async throws {
        isSyncing = true
        defer { isSyncing = false }
        
        let dto = UserProgressDTO(
            id: nil,
            userId: userId,
            totalXp: localProgress.totalXP,
            currentStreak: localProgress.currentStreak,
            longestStreak: localProgress.longestStreak,
            lastPracticeDate: localProgress.lastPracticeDate,
            lessonsCompleted: localProgress.lessonsCompleted,
            dailyGoal: localProgress.dailyGoal,
            currentLevel: 1  // Calculate from XP
        )
        
        try await supabase.upsertUserProgress(dto)
        lastSyncDate = Date()
    }
    
    // Sync from Supabase to local SwiftData
    func syncFromCloud(userId: String) async throws -> UserProgressDTO? {
        isSyncing = true
        defer { isSyncing = false }
        
        let cloudProgress = try await supabase.fetchUserProgress(userId: userId)
        lastSyncDate = Date()
        
        return cloudProgress
    }
}
```

---

## Architecture Recommendations

### Recommended Stack

```
┌─────────────────────────────────────────┐
│           Learn Amharic iOS             │
├─────────────────────────────────────────┤
│  SwiftUI Views                          │
├─────────────────────────────────────────┤
│  View Models (@Observable)              │
├─────────────────────────────────────────┤
│  Local: SwiftData    │  Cloud: Supabase │
│  (Offline-first)     │  (Sync on Wi-Fi) │
├─────────────────────────────────────────┤
│  Clerk Auth                             │
└─────────────────────────────────────────┘
```

### Offline-First Strategy

1. **Write to SwiftData first** (instant, works offline)
2. **Queue sync operations** when online
3. **Conflict resolution:** Last-write-wins with timestamp
4. **Sync trigger:** On app foreground, after each lesson completion

### Environment Variables

Create `Secrets.swift` (add to .gitignore):

```swift
enum Secrets {
    static let clerkPublishableKey = "pk_test_..."
    static let supabaseURL = "https://xxx.supabase.co"
    static let supabaseAnonKey = "eyJ..."
}
```

Or use Xcode's build configuration:
1. Create `Config.xcconfig`
2. Add keys as build settings
3. Access via `Bundle.main.infoDictionary`

---

## Quick Start Checklist

### MVP (Local + Auth)
- [ ] Set up Clerk account
- [ ] Install ClerkSDK
- [ ] Add Sign in with Apple
- [ ] Wrap app in AuthenticationView
- [ ] Test auth flow

### Full Sync
- [ ] Set up Supabase project
- [ ] Create database tables
- [ ] Install Supabase SDK
- [ ] Create SupabaseManager
- [ ] Implement SyncManager
- [ ] Add sync UI indicators
- [ ] Test offline/online scenarios

---

## Resources

- [Clerk iOS Docs](https://clerk.com/docs/quickstarts/ios)
- [Supabase Swift Docs](https://supabase.com/docs/reference/swift/introduction)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Sign in with Apple Guide](https://developer.apple.com/sign-in-with-apple/)
