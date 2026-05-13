# Amharic Learning App for iOS

A comprehensive iOS app for English speakers to learn Amharic (the official language of Ethiopia). Built with SwiftUI and SwiftData for iOS 17+.

## Features

### Journey Tab
- **Fidel Script Chart**: Interactive grid of all 238 Fidel characters (34 consonants x 7 vowel forms) with visual pronunciation hints
- **Structured Lessons**: 8 progressive lessons covering greetings, family, directions, food, time, health, travel, and culture
- **Sentence Patterns**: 30 pattern templates with substitution slots for building sentences
- **Vocabulary Cards**: Visual flashcards organized by category

### Practice Modes
- **Flashcards**: Swipeable cards with FSRS-style spaced repetition for optimal retention
- **Quizzes**: Multiple choice quizzes testing vocabulary, phrases, and Fidel recognition
- **Pronunciation**: Generated offline phrase pronunciation for the 25-clip survival-phrase pilot
- **Sentence Builder**: Interactive grammar practice by dragging words to construct sentences
- **Daily Goals**: Track your practice streak and daily XP targets

### Conversations
- **24 Real-World Scenarios**: Practice practical dialogue across travel, food, shopping, family, emergencies, and daily life
- **Role-Play Mode**: Practice either speaker role in dialogues
- **Line-by-Line Translation**: See Amharic, transliteration, and English for each line

### Reference Tab
- **Quick Phrases**: 174 phrases for travel and daily use, including 25 generated offline pronunciation clips
- **Vocabulary Browser**: 436 words organized by category
- **Number System**: Ethiopian numbers, months, ordinals, and fractions
- **Culture Notes**: 20 cultural notes connected to lessons and conversations
- **Search**: Find any word or phrase instantly

### Progress Tab
- **XP & Levels**: Gamified progression system
- **Streaks**: Track consecutive days of practice
- **Achievements**: Unlock badges for milestones
- **Statistics**: Words learned, accuracy rates, time practiced

## Technical Details

### Architecture
- **SwiftUI** for declarative UI
- **SwiftData** for local progress persistence
- **MVVM** pattern with Observable view models
- **FSRS-style Spaced Repetition** algorithm for flashcard scheduling
- **Manifest-driven bundled audio** for generated pronunciation playback without runtime API keys
- **User-controlled JSON backup** for progress export/import

### Requirements
- iOS 17.0+
- Xcode 15.0+

### Project Structure
```
Fidel/
├── docs/
│   ├── README.md
│   └── status/
│       └── fidel-group-audit.md
├── Fidel/
│   ├── Models/
│   │   ├── Models.swift          # Core data models
│   │   └── AmharicData.swift     # JSON-backed content adapter
│   ├── Data/                     # Bundled lessons, patterns, vocabulary, phrases, conversations, notes, audio manifests
│   ├── Audio/                    # Voice-scoped generated pronunciation MP3s
│   ├── Services/                 # Audio, stage, progress export, stroke, and spaced repetition services
│   ├── Repositories/             # Lesson/progress/Selam data boundaries
│   ├── ViewModels/               # Observable feature state
│   ├── Views/
│   │   ├── Theme.swift           # Ethiopian-inspired design system
│   │   ├── Components.swift      # Reusable UI components
│   │   ├── JourneyView.swift     # Stage-gated learning path
│   │   ├── FidelView.swift       # Fidel alphabet chart
│   │   ├── PracticeView.swift    # Practice hub
│   │   ├── FlashcardView.swift   # Swipeable flashcards
│   │   ├── QuizView.swift        # Multiple choice quizzes
│   │   ├── SentenceBuilderView.swift
│   │   ├── ConversationDetailView.swift
│   │   ├── ReferenceView.swift   # Quick reference
│   │   ├── ProgressView.swift    # Stats & achievements
│   │   └── TracingView.swift     # Handwriting practice
│   ├── FidelApp.swift            # App entry point
│   └── ContentView.swift         # Tab navigation
└── Fidel.xcodeproj
```

## Building the App

1. Open `Fidel.xcodeproj` in Xcode 15+
2. Select an iOS 17+ simulator or device
3. Build and run (Cmd+R)

## Content Source

All Amharic content is sourced from the companion web application, including:
- Complete Fidel alphabet with 238 characters
- 30 sentence patterns with grammar explanations
- 24 conversation scripts with full dialogues
- 174 phrases
- 436 vocabulary words across multiple categories
- 20 cultural notes

## Design

The app features an Ethiopian-inspired color palette:
- **Green** (#229632): Primary accent, representing hope and the land
- **Yellow** (#FCDD09): Secondary accent, representing peace and harmony
- **Red** (#DA121A): Tertiary accent, representing strength and sacrifice

## Future Enhancements

Future product and content work is tracked in `docs/backlog.md`.
