import { expect, type Page } from '@playwright/test'
import type { RawContent } from '../../src/content/types'

export async function openApp(page: Page, route = '') {
  await page.goto(`/app/#/${route}`)
  await expect(page.locator('nav.tabs')).toBeVisible()
}

let cached: RawContent | null = null
export async function content(page: Page): Promise<RawContent> {
  cached ??= (await (await page.request.get('/content.json')).json()) as RawContent
  return cached
}

/** Reads the learner's total XP from the You tab. */
export async function totalXP(page: Page): Promise<number> {
  await openApp(page, 'you')
  const card = page.locator('.card', { hasText: 'Total XP' })
  return Number(await card.locator('strong').innerText())
}
