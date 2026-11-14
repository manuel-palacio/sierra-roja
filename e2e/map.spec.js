const { test, expect } = require('@playwright/test');

// The map view in the real build: M shows the whole ground with the guards' beats drawn on it.
// Saves a screenshot for a human to read.
test('M shows the map of the whole ground without errors', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
  await page.keyboard.press('m');
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'build/e2e/map.png' });
  await page.keyboard.press('m');
  await page.waitForTimeout(300);
  expect(errors).toEqual([]);
});
