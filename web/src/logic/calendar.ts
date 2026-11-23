// Local-calendar helpers matching Swift's `Calendar.current` (Gregorian, en_US).

const DAY = 86_400_000

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate())
}

/** `dateComponents([.day], from:to:).day`: whole local days, DST-safe. */
export function wholeDaysBetween(from: Date, to: Date): number {
  const offsetDelta = (from.getTimezoneOffset() - to.getTimezoneOffset()) * 60_000
  const days = (to.getTime() - from.getTime() - offsetDelta) / DAY
  return days < 0 ? Math.ceil(days) : Math.floor(days)
}

/** `calendar.date(byAdding: .day, value: n, to: date)`. */
export function addDays(date: Date, days: number): Date {
  const result = new Date(date)
  result.setDate(result.getDate() + days)
  return result
}

/**
 * `yearForWeekOfYear * 100 + weekOfYear` for the en_US Gregorian calendar:
 * weeks start on Sunday and week 1 is the week containing 1 January.
 */
export function weekKey(date: Date): number {
  const day = startOfDay(date)
  const weekStart = addDays(day, -day.getDay())
  const weekEnd = addDays(weekStart, 6)
  // The week containing 1 January belongs to the new year.
  const year = weekEnd.getFullYear() > weekStart.getFullYear() ? weekEnd.getFullYear() : weekStart.getFullYear()
  const jan1 = new Date(year, 0, 1)
  const firstWeekStart = addDays(jan1, -jan1.getDay())
  const week = Math.round(wholeDaysBetween(firstWeekStart, weekStart) / 7) + 1
  return year * 100 + week
}
