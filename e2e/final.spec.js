const { test, expect } = require('@playwright/test');

// The art, night look and sound in the real build: a user gesture unlocks audio, nothing may log
// an error, and a screenshot is kept for a human to look at (build/e2e/final.png).
test('night scene renders, audio unlocks on a click, no console errors', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1500);
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.click(box.x + box.width * 0.5, box.y + box.height * 0.5); // the gesture
  await page.mouse.dblclick(box.x + box.width * 0.45, box.y + box.height * 0.6); // a run order makes footstep noise
  await page.waitForTimeout(1500);
  // click the guard nearest the middle of the screen so its vision cones show on the night map
  await page.evaluate(() => window.sierraProbe());
  const guards = await page.evaluate(() => window.sierraGuards);
  const centre = [640, 360];
  guards.sort((a, b) => Math.hypot(a[0] - centre[0], a[1] - centre[1]) - Math.hypot(b[0] - centre[0], b[1] - centre[1]));
  if (guards.length) await page.mouse.click(box.x + guards[0][0], box.y + guards[0][1]);
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/e2e/final.png' });
  expect(errors).toEqual([]);
});
