import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { expect, test } from '@playwright/test'
import { openApp, totalXP } from './helpers'

test('the Fidel chart shows all 238 characters and plays audio', async ({ page }) => {
  await openApp(page, 'reference/fidel')
  await expect(page.getByRole('gridcell')).toHaveCount(238)
  const audio = page.waitForResponse((r) => r.url().includes('/audio/fidel/'))
  await page.getByRole('gridcell', { name: /^ሀ,/ }).click()
  expect((await audio).ok()).toBeTruthy()
})

test('phrase and word search filters the lists', async ({ page }) => {
  await openApp(page, 'reference/phrases')
  await page.getByLabel('Search').fill('thank')
  await expect(page.getByText(/^\d+ phrases$/)).not.toHaveText('706 phrases')
  await openApp(page, 'reference/vocabulary')
  await page.getByLabel('Search').fill('water')
  await expect(page.locator('.list-item [lang="am"]', { hasText: 'ውሃ' }).first()).toBeVisible()
})

test('numbers and culture references render', async ({ page }) => {
  await openApp(page, 'reference/numbers')
  await expect(page.getByRole('heading', { name: 'Ethiopian months' })).toBeVisible()
  await openApp(page, 'reference/culture')
  await expect(page.locator('details.card')).toHaveCount(90)
})

test('Selam points to the iOS app', async ({ page }) => {
  await openApp(page, 'selam')
  await expect(page.getByRole('link', { name: 'Get Fidel on the App Store' })).toHaveAttribute('href', /apps\.apple\.com/)
})

test('changing pace updates the daily recommendation size', async ({ page }) => {
  await openApp(page, 'you')
  await page.getByRole('radio', { name: /Intense/ }).click()
  await openApp(page)
  await expect(page.getByText('Pace: Intense')).toBeVisible()
  await expect(page.getByText('~15 min · 12 new')).toBeVisible()
})

test('backup export uses the iOS format and import merges it', async ({ page }) => {
  await openApp(page, 'you')
  const download = page.waitForEvent('download')
  await page.getByRole('button', { name: 'Export' }).click()
  const file = await (await download).path()
  const backup = JSON.parse(fs.readFileSync(file!, 'utf8'))
  expect(Object.keys(backup).sort()).toEqual(['exportedAt', 'flashcards', 'settings', 'userProgress', 'version'])
  expect(backup.version).toBe(1)

  // A backup written by the iOS app's import test fixture.
  const fixture = JSON.parse(fs.readFileSync(path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../FidelTests/Golden/backup.json'), 'utf8'))
  const tmp = path.join(test.info().outputDir, 'ios-backup.json')
  fs.mkdirSync(path.dirname(tmp), { recursive: true })
  fs.writeFileSync(tmp, JSON.stringify(fixture.cases[0].backup))
  await page.locator('input[type="file"]').setInputFiles(tmp)
  await expect(page.getByRole('status')).toContainText('Backup imported')
  expect(await totalXP(page)).toBe(340)
})
