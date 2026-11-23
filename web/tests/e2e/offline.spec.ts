import { expect, test } from '@playwright/test'

// Service workers are only exercised in Chromium here; WebKit's Playwright build
// does not run them reliably under automation.
test.use({ serviceWorkers: 'allow' })

test('the app works offline after the first visit, including audio already heard', async ({ page, context, browserName }) => {
  test.skip(browserName !== 'chromium', 'service worker test runs in Chromium')
  await page.goto('/app/#/reference/fidel')
  await page.evaluate(() => navigator.serviceWorker.ready)
  // Reload so the page is controlled by the service worker, then hear one clip.
  await page.reload()
  await page.waitForFunction(() => !!navigator.serviceWorker.controller)
  const clip = page.waitForResponse((r) => r.url().includes('/audio/fidel/'))
  await page.getByRole('gridcell', { name: /^ሀ ha$/ }).click()
  await clip

  await context.setOffline(true)
  await page.goto('/app/#/learn')
  await expect(page.locator('a.list-item[href^="#/lesson/"]')).toHaveCount(8)
  await page.goto('/app/#/reference/fidel')
  await expect(page.getByRole('gridcell')).toHaveCount(238)
  const played = await page.evaluate(async () => {
    const response = await fetch(`${location.origin}/audio/fidel/azure/am-ET-AmehaNeural/fidel-00-1-ha.mp3`)
    return response.ok
  })
  expect(played).toBe(true)
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1 })).toBeVisible()
})
