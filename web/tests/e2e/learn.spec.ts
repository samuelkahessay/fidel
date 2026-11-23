import { expect, test } from '@playwright/test'
import { openApp, totalXP } from './helpers'

test('landing page links into the app and the App Store', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toContainText('Amharic')
  await expect(page.getByRole('link', { name: 'Get it on the App Store' })).toHaveAttribute('href', /apps\.apple\.com/)
  await page.getByRole('link', { name: 'Try it in your browser' }).click()
  await expect(page.getByRole('heading', { name: 'Today' })).toBeVisible()
})

test('Today recommends the first lesson and Continue opens it', async ({ page }) => {
  await openApp(page)
  await expect(page.getByRole('heading', { name: 'Start a new lesson' })).toBeVisible()
  await page.getByRole('link', { name: 'Continue' }).click()
  await expect(page.getByRole('heading', { name: 'Greetings & Introductions' })).toBeVisible()
})

test('Learn shows eight open lessons in themed sections with mastery rings', async ({ page }) => {
  await openApp(page, 'learn')
  for (const section of ['Script & Sounds', 'Survival Phrases', 'Building Sentences', 'Fluency']) {
    await expect(page.getByRole('heading', { name: new RegExp(section) })).toBeVisible()
  }
  await expect(page.locator('a.list-item[href^="#/lesson/"]')).toHaveCount(8)
  await expect(page.getByRole('img', { name: /New, 0% learned/ }).first()).toBeVisible()
})

test('completing a lesson awards XP, credits characters and marks it completed', async ({ page }) => {
  await openApp(page, 'lesson/1')
  for (const tab of ['Vocabulary', 'Phrases', 'Culture', 'Patterns']) {
    await page.getByRole('tab', { name: tab }).click()
    await expect(page.getByRole('tab', { name: tab })).toHaveAttribute('aria-selected', 'true')
  }
  await page.getByRole('button', { name: 'Complete lesson' }).click()
  await expect(page.getByRole('status')).toContainText('Lesson complete')
  // 25 XP for the lesson plus 2 XP per Fidel character the lesson uses.
  expect(await totalXP(page)).toBeGreaterThan(25)
  await openApp(page, 'learn')
  await expect(page.locator('a[href="#/lesson/1"]')).toContainText('Completed')
})

test('a conversation plays line by line and can be completed', async ({ page }) => {
  await openApp(page, 'conversation/1')
  const next = page.getByRole('button', { name: 'Next line' })
  while (await next.isVisible()) await next.click()
  await page.getByRole('button', { name: 'Finish conversation' }).click()
  await expect(page.getByRole('status').last()).toContainText('Conversation practiced')
})

test('role-play hides your lines until you reveal them', async ({ page }) => {
  await openApp(page, 'conversation/1')
  await page.getByRole('button', { name: /^Be / }).first().click()
  await page.getByRole('button', { name: 'Next line' }).click()
  await expect(page.getByRole('button', { name: 'Say it, then reveal' }).first()).toBeVisible()
})
