import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

const routes = [
  ['landing', '/'],
  ['today', '/app/#/'],
  ['learn', '/app/#/learn'],
  ['lesson', '/app/#/lesson/1'],
  ['conversation', '/app/#/conversation/1'],
  ['practice', '/app/#/practice'],
  ['flashcards', '/app/#/practice/flashcards'],
  ['quiz', '/app/#/practice/quiz'],
  ['match', '/app/#/practice/match'],
  ['word order', '/app/#/practice/word-order'],
  ['tracing', '/app/#/practice/tracing/0-1'],
  ['reading', '/app/#/practice/reading'],
  ['fidel chart', '/app/#/reference/fidel'],
  ['phrases', '/app/#/reference/phrases'],
  ['selam', '/app/#/selam'],
  ['you', '/app/#/you'],
] as const

for (const [name, url] of routes) {
  test(`${name} has no serious accessibility violations`, async ({ page }) => {
    await page.goto(url)
    await expect(page.locator('h1').first()).toBeVisible()
    await page.waitForTimeout(300)
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze()
    const serious = results.violations.filter((v) => v.impact === 'serious' || v.impact === 'critical')
    expect(serious.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).slice(0, 3).join(', ')}`)).toEqual([])
  })
}

test.describe('dark mode', () => {
  test.use({ colorScheme: 'dark' })
  for (const [name, url] of routes) {
    test(`${name} keeps sufficient contrast in dark mode`, async ({ page }) => {
      await page.goto(url)
      await expect(page.locator('h1').first()).toBeVisible()
      await page.waitForTimeout(300)
      const results = await new AxeBuilder({ page }).withRules(['color-contrast']).analyze()
      expect(results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).slice(0, 3).join(', ')}`)).toEqual([])
    })
  }
})
