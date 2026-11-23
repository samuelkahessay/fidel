import { expect, test } from '@playwright/test'
import { content, openApp } from './helpers'

test('Practice lists all eleven modes', async ({ page }) => {
  await openApp(page, 'practice')
  await expect(page.locator('a.list-item[href^="#/practice/"]')).toHaveCount(11)
})

test('Flashcards: reveal, rate twenty cards, see results', async ({ page }) => {
  await openApp(page, 'practice/flashcards')
  for (let i = 0; i < 20; i++) {
    await page.locator('button.flashcard').click()
    await page.getByRole('button', { name: i % 3 ? 'I knew it' : 'Still learning' }).click()
  }
  await expect(page.getByRole('status')).toContainText('of 20 correct')
})

test('Quiz: twelve mixed questions with feedback', async ({ page }) => {
  await openApp(page, 'practice/quiz')
  for (let i = 0; i < 12; i++) {
    const options = page.locator('button.option')
    if (await options.count()) await options.first().click()
    else {
      await page.getByLabel('Your answer').fill('xyz')
      await page.getByRole('button', { name: 'Check' }).click()
    }
    await expect(page.locator('.feedback')).toBeVisible()
    await page.getByRole('button', { name: i === 11 ? 'See results' : 'Next' }).click()
  }
  await expect(page.getByRole('status')).toContainText('of 12 correct')
})

test('Fill the Blank grades the chosen word', async ({ page }) => {
  await openApp(page, 'practice/cloze')
  for (let i = 0; i < 8; i++) {
    await page.locator('button.option').first().click()
    await expect(page.locator('.feedback')).toBeVisible()
    await page.getByRole('button', { name: i === 7 ? 'See results' : 'Next' }).click()
  }
  await expect(page.getByRole('status')).toContainText('of 8 correct')
})

test('Match Pairs: matching every pair finishes the session', async ({ page }) => {
  const data = await content(page)
  const englishFor = new Map(data.vocabulary.map((w) => [w.amharic, w.english]))
  await openApp(page, 'practice/match')
  for (let round = 0; round < 3; round++) {
    await expect(page.getByText(`Round ${round + 1}/3`)).toBeVisible()
    for (let pair = 0; pair < 5; pair++) {
      const tile = page.locator('button.word-tile[lang="am"]:not([disabled])').first()
      const amharic = (await tile.innerText()).trim()
      await tile.click()
      await page.locator('button.word-tile:not([lang]):not([disabled])', { hasText: englishFor.get(amharic)! }).first().click()
    }
  }
  await expect(page.getByRole('status')).toContainText('15 pairs')
})

test('Word Order: build a sentence from tiles and check it', async ({ page }) => {
  await openApp(page, 'practice/word-order')
  await page.getByRole('group', { name: 'Word bank' }).locator('button').first().click()
  await page.getByRole('button', { name: 'Check' }).click()
  await expect(page.locator('.feedback')).toBeVisible()
})

test('Sentence Builder substitutes a word into a pattern', async ({ page }) => {
  await openApp(page, 'practice/sentence-builder')
  await page.locator('button.list-item').first().click()
  await page.locator('button.word-tile').first().click()
  await expect(page.locator('.card[role="status"] [lang="am"]')).not.toBeEmpty()
})

test('Grammar opens a topic with a rule summary and examples', async ({ page }) => {
  await openApp(page, 'practice/grammar')
  await page.locator('button.list-item').first().click()
  await expect(page.locator('section.card').first()).toBeVisible()
  await expect(page.locator('.card p').first()).not.toBeEmpty()
})

test('Reading: answer every comprehension question', async ({ page }) => {
  await openApp(page, 'practice/reading')
  await page.locator('a.list-item').first().click()
  const questions = page.locator('fieldset')
  await expect(questions.first()).toBeVisible()
  for (let i = 0; i < (await questions.count()); i++) await questions.nth(i).locator('button.option').first().click()
  await expect(page.getByRole('status')).toContainText('correct')
})

test('Speed Drill counts down and scores self-graded answers', async ({ page }) => {
  await openApp(page, 'practice/speed-drill')
  await expect(page.getByRole('timer')).toHaveText(/\d+s/)
  for (let i = 0; i < 20; i++) await page.getByRole('button', { name: 'Correct' }).click()
  await expect(page.getByRole('status')).toContainText('Final score: 20/20')
})

test('Pronunciation plays the native clip', async ({ page }) => {
  await openApp(page, 'practice/pronunciation')
  const audio = page.waitForResponse((r) => r.url().includes('/audio/') && r.status() < 400)
  await page.getByRole('button', { name: 'Listen' }).click()
  expect((await audio).ok()).toBeTruthy()
})
