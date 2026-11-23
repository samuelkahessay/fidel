// Port of NextStepPlanner and DailyGoalTier (Fidel/Services/NextStepPlanner.swift,
// Fidel/Models/DailyGoalTier.swift).

export type Tier = 'casual' | 'regular' | 'serious' | 'intense'

export const tiers: Record<Tier, { newCap: number; reviewCap: number; tracingSessionSize: number; estimatedMinutes: number; suggestedDailyXP: number; displayName: string }> = {
  casual: { newCap: 3, reviewCap: 10, tracingSessionSize: 5, estimatedMinutes: 2, suggestedDailyXP: 10, displayName: 'Casual' },
  regular: { newCap: 5, reviewCap: 15, tracingSessionSize: 8, estimatedMinutes: 5, suggestedDailyXP: 20, displayName: 'Regular' },
  serious: { newCap: 8, reviewCap: 20, tracingSessionSize: 12, estimatedMinutes: 10, suggestedDailyXP: 30, displayName: 'Serious' },
  intense: { newCap: 12, reviewCap: 30, tracingSessionSize: 16, estimatedMinutes: 15, suggestedDailyXP: 50, displayName: 'Intense' },
}
export const defaultTier: Tier = 'regular'
export const tierSubtitle = (t: Tier) => `~${tiers[t].estimatedMinutes} min · ${tiers[t].newCap} new`

export type HeroAction = { kind: 'lesson'; id: number } | { kind: 'flashcards' }

export interface RecommendedSession {
  kind: 'newLesson' | 'resumeLesson' | 'reviews' | 'allCaughtUp'
  lessonId?: number
  reviewCount: number
  newCount: number
  estimatedMinutes: number
  heroAction: HeroAction
  eyebrow: string
  title: string
  detail: string
}

export function plan(input: {
  completedLessonIds: number[]
  inProgressLessonId: number | null
  tier: Tier
  dueReviewCount: number
  orderedLessonIds: number[]
}): RecommendedSession {
  const t = tiers[input.tier]
  const completed = new Set(input.completedLessonIds)
  const reviews = Math.min(input.dueReviewCount, t.reviewCap)
  const nextNewId = input.orderedLessonIds.find((id) => !completed.has(id))

  if (reviews > 0) {
    const hasNew = nextNewId !== undefined
    return {
      kind: 'reviews', reviewCount: reviews, newCount: hasNew ? t.newCap : 0, estimatedMinutes: t.estimatedMinutes,
      heroAction: { kind: 'flashcards' }, eyebrow: 'Recommended today',
      title: `Review ${reviews} word${reviews === 1 ? '' : 's'}`,
      detail: hasNew ? 'then start something new' : 'keep your memory fresh',
    }
  }
  if (input.inProgressLessonId !== null && !completed.has(input.inProgressLessonId)) {
    return {
      kind: 'resumeLesson', lessonId: input.inProgressLessonId, reviewCount: 0, newCount: t.newCap,
      estimatedMinutes: t.estimatedMinutes, heroAction: { kind: 'lesson', id: input.inProgressLessonId },
      eyebrow: 'Pick up where you left off', title: 'Continue your lesson', detail: `~${t.estimatedMinutes} min`,
    }
  }
  if (nextNewId !== undefined) {
    return {
      kind: 'newLesson', lessonId: nextNewId, reviewCount: 0, newCount: t.newCap, estimatedMinutes: t.estimatedMinutes,
      heroAction: { kind: 'lesson', id: nextNewId }, eyebrow: 'Recommended today', title: 'Start a new lesson',
      detail: `~${t.estimatedMinutes} min · ${t.newCap} new`,
    }
  }
  return {
    kind: 'allCaughtUp', reviewCount: 0, newCount: 0, estimatedMinutes: t.estimatedMinutes,
    heroAction: { kind: 'flashcards' }, eyebrow: "You're all caught up", title: 'Free practice', detail: 'Review anything you like',
  }
}

/** `NextStepPlanner.recommend`: the in-progress lesson is the latest started-but-not-completed one. */
export function recommend(progress: { lessonsCompleted: number[]; lessonsInProgress: number[] }, lessonIds: number[], tier: Tier, dueReviewCount: number) {
  const completed = new Set(progress.lessonsCompleted)
  const inProgress = [...progress.lessonsInProgress].reverse().find((id) => !completed.has(id)) ?? null
  return plan({
    completedLessonIds: progress.lessonsCompleted, inProgressLessonId: inProgress, tier, dueReviewCount,
    orderedLessonIds: [...lessonIds].sort((a, b) => a - b),
  })
}
