const { test, expect } = require('@playwright/test');

// A plain visit in the real build: the title first, then the briefing, then the game. Saves a
// screenshot of the title for a human to read.
test('a plain visit opens on the title, then the briefing, without errors', async ({ page }) => {
  test.setTimeout(60000);
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/index.html');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'build/e2e/title.png' });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/e2e/title-then-briefing.png' });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/e2e/title-then-game.png' });
  expect(errors).toEqual([]);
});

test.describe('on a phone held sideways', () => {
  test.use({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });
  test('the title fits the screen', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.goto('/?lang=es'); // serve drops the query from /index.html
    await page.waitForFunction(() => window.sierraStarted === true);
    await page.waitForTimeout(1000);
    await page.screenshot({ path: 'build/e2e/title-phone-es.png' });
    expect(errors).toEqual([]);
  });
});
