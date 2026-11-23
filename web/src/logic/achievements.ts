// `allAchievements` in Fidel/Models/Models.swift. Progress toward each is shown;
// like the app, nothing awards them yet (see docs/backlog.md).
import type { UserProgress } from './progress'

export interface Achievement {
  id: string
  title: string
  description: string
  requirement: number
  measure: (p: UserProgress) => number
}

const lessons = (p: UserProgress) => p.lessonsCompleted.length
const words = (p: UserProgress) => p.vocabularyMastered.length
const streak = (p: UserProgress) => p.longestStreak
const conversations = (p: UserProgress) => p.conversationsPracticed.length
const xp = (p: UserProgress) => p.totalXP

export const achievements: Achievement[] = [
  { id: 'first_steps', title: 'First Steps', description: 'Complete your first lesson', requirement: 1, measure: lessons },
  { id: 'word_collector', title: 'Word Collector', description: 'Learn 50 vocabulary words', requirement: 50, measure: words },
  { id: 'vocabulary_master', title: 'Vocabulary Master', description: 'Learn 200 vocabulary words', requirement: 200, measure: words },
  { id: 'streak_3', title: 'On Fire', description: 'Maintain a 3-day streak', requirement: 3, measure: streak },
  { id: 'streak_7', title: 'Week Warrior', description: 'Maintain a 7-day streak', requirement: 7, measure: streak },
  { id: 'streak_30', title: 'Dedicated Learner', description: 'Maintain a 30-day streak', requirement: 30, measure: streak },
  { id: 'conversationalist', title: 'Conversationalist', description: 'Practice 5 conversations', requirement: 5, measure: conversations },
  { id: 'social_butterfly', title: 'Social Butterfly', description: 'Practice all 30 conversations', requirement: 30, measure: conversations },
  { id: 'xp_100', title: 'Rising Star', description: 'Earn 100 XP', requirement: 100, measure: xp },
  { id: 'xp_500', title: 'Shining Star', description: 'Earn 500 XP', requirement: 500, measure: xp },
  { id: 'xp_1000', title: 'Superstar', description: 'Earn 1000 XP', requirement: 1000, measure: xp },
  { id: 'culture_explorer', title: 'Culture Explorer', description: 'Complete Lesson 8 (Culture)', requirement: 1,
    measure: (p) => (p.lessonsCompleted.includes(8) ? 1 : 0) },
  { id: 'polyglot', title: 'Polyglot', description: 'Complete all 8 lessons', requirement: 8, measure: lessons },
]
