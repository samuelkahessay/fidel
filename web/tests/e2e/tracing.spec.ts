import { expect, test } from '@playwright/test'
import { canvasSize, recordingGlyphScale } from '../../src/logic/trace/engine'
import { type RecordedStroke, standardTuning, traceableStrokes } from '../../src/logic/trace/geometry'
import { content, openApp } from './helpers'

test('tracing a character along its strokes completes it and awards XP', async ({ page }) => {
  const data = await content(page)
  const strokes = ((await (await page.request.get('/strokes/0-1.json')).json()) as { strokes: RecordedStroke[] }).strokes
  const traceable = traceableStrokes(strokes, canvasSize, data.glyphStrokeWidths['0-1']!, recordingGlyphScale, standardTuning)

  await openApp(page, 'practice/tracing/0-1')
  const surface = page.locator('.trace-wrap[role="img"]')
  await expect(surface).toBeVisible()
  // Let the first-time stroke demonstration finish.
  await page.waitForTimeout(1600)
  const box = (await surface.boundingBox())!
  const toPage = (p: { x: number; y: number }) => ({ x: box.x + (p.x / canvasSize.width) * box.width, y: box.y + (p.y / canvasSize.height) * box.height })

  for (const stroke of traceable) {
    const start = toPage(stroke.startPoint)
    await page.mouse.move(start.x, start.y)
    await page.mouse.down()
    for (let i = 0; i < stroke.polyline.length; i += 3) {
      const p = toPage(stroke.polyline[i]!)
      await page.mouse.move(p.x, p.y)
    }
    const end = toPage(stroke.endPoint)
    await page.mouse.move(end.x, end.y)
    await page.mouse.up()
    await page.waitForTimeout(400)
  }
  await expect(page.getByRole('status')).toContainText('XP')
  await page.getByRole('button', { name: 'Next' }).click()
  await expect(page.getByRole('status')).toContainText('1 character traced')
})

test('a session can be completed with the accessible Skip stroke action', async ({ page }) => {
  await openApp(page, 'practice/tracing')
  await expect(page.locator('.trace-wrap[role="img"]')).toBeVisible()
  await page.waitForTimeout(1600)
  const skip = page.getByRole('button', { name: 'Skip stroke' })
  for (let i = 0; i < 6 && (await skip.isVisible()); i++) {
    await skip.click()
    await page.waitForTimeout(250)
  }
  await expect(page.getByRole('button', { name: 'Next' })).toBeVisible()
})
