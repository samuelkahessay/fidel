# Amharic Learning App for iOS

A comprehensive iOS app for English speakers to learn Amharic (the official language of Ethiopia). Built with SwiftUI and SwiftData for iOS 17+.

## Features

### Learn Tab
- **Fidel Script Chart**: Interactive grid of all 238 Fidel characters (34 consonants x 7 vowel forms) with tap-to-hear pronunciation guides
- **Structured Lessons**: 5 progressive lessons covering greetings, questions, numbers, family, and daily routines
- **Sentence Patterns**: 15 pattern templates with substitution slots for building sentences
- **Vocabulary Cards**: Visual flashcards organized by category

### Practice Tab
- **Flashcards**: Swipeable cards with spaced repetition algorithm (SM-2) for optimal retention
- **Quizzes**: Multiple choice quizzes testing vocabulary, phrases, and Fidel recognition
- **Sentence Builder**: Interactive grammar practice by dragging words to construct sentences
- **Daily Goals**: Track your practice streak and daily XP targets

### Conversations Tab
- **10 Real-World Scenarios**: At the airport, hotel check-in, restaurant, market shopping, asking directions, introducing yourself, phone calls, emergencies, making friends, at the bank
- **Role-Play Mode**: Practice either speaker role in dialogues
- **Line-by-Line Translation**: See Amharic, transliteration, and English for each line

### Reference Tab
- **Quick Phrases**: 50 essential phrases for travel and daily use
- **Vocabulary Browser**: 68 words organized by category (Greetings, Numbers, Family, Food, Places, Time, Colors)
- **Number System**: Ethiopian numbers 1-19 with pronunciation
- **Search**: Find any word or phrase instantly

### Progress Tab
- **XP & Levels**: Gamified progression system
- **Streaks**: Track consecutive days of practice
- **Achievements**: Unlock badges for milestones
- **Statistics**: Words learned, accuracy rates, time practiced

## Technical Details

### Architecture
- **SwiftUI** for declarative UI
- **SwiftData** for persistence
- **MVVM** pattern with Observable view models
- **SM-2 Spaced Repetition** algorithm for flashcard scheduling

### Requirements
- iOS 17.0+
- Xcode 15.0+

### Project Structure
```
AmharicApp/
├── AmharicApp/
│   ├── Models/
│   │   ├── Models.swift          # Core data models
│   │   └── AmharicData.swift     # All Amharic content
│   ├── Views/
│   │   ├── Theme.swift           # Ethiopian-inspired design system
│   │   ├── Components.swift      # Reusable UI components
│   │   ├── LearnView.swift       # Lessons & patterns
│   │   ├── FidelView.swift       # Fidel alphabet chart
│   │   ├── PracticeView.swift    # Practice hub
│   │   ├── FlashcardView.swift   # Swipeable flashcards
│   │   ├── QuizView.swift        # Multiple choice quizzes
│   │   ├── SentenceBuilderView.swift
│   │   ├── ConversationsView.swift
│   │   ├── ConversationDetailView.swift
│   │   ├── ReferenceView.swift   # Quick reference
│   │   ├── ProgressView.swift    # Stats & achievements
│   │   └── LessonView.swift
│   ├── ViewModels/
│   │   └── ViewModels.swift      # Observable state management
│   ├── Services/
│   │   └── SpacedRepetition.swift # SM-2 algorithm
│   ├── AmharicAppApp.swift       # App entry point
│   └── ContentView.swift         # Tab navigation
└── AmharicApp.xcodeproj
```

## Building the App

1. Open `AmharicApp.xcodeproj` in Xcode 15+
2. Select an iOS 17+ simulator or device
3. Build and run (Cmd+R)

## Content Source

All Amharic content is sourced from the companion web application, including:
- Complete Fidel alphabet with 238 characters
- 15 sentence patterns with grammar explanations
- 10 conversation scripts with full dialogues
- 50 essential travel phrases
- 68 vocabulary words across 7 categories

## Design

The app features an Ethiopian-inspired color palette:
- **Green** (#229632): Primary accent, representing hope and the land
- **Yellow** (#FCDD09): Secondary accent, representing peace and harmony
- **Red** (#DA121A): Tertiary accent, representing strength and sacrifice

## Future Enhancements

- [ ] Audio pronunciation by native speakers
- [ ] Handwriting practice for Fidel characters
- [ ] Speech recognition for pronunciation feedback
- [ ] Additional vocabulary from CSV (547 words available)
- [ ] Cloud sync for progress across devices
- [ ] Offline mode with downloaded content
