const { test, expect } = require('@playwright/test');

// The game in Spanish in the real build: ?lang=es puts the briefing and the HUD in Spanish.
// Saves a screenshot of each for a human to read.
test('?lang=es shows the briefing and the HUD in Spanish without errors', async ({ page }) => {
  test.setTimeout(60000);
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?lang=es&probe=1&briefing=1');
  await expect(page.locator('html')).toHaveAttribute('lang', 'es');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'build/e2e/briefing-es.png' });
  await page.keyboard.press('Enter');
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/e2e/hud-es.png' });
  expect(errors).toEqual([]);
});
