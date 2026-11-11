const { test, expect } = require('@playwright/test');

// The art, night look and sound in the real build: a user gesture unlocks audio, nothing may log
// an error, and a screenshot is kept for a human to look at (build/e2e/final.png, with a charge
// planted and the Dynamiter crawling beside it, then build/e2e/flash.png of its detonation).
// Headless Chromium draws in software, where the full scene runs well below real time: the 10 s
// fuse can take half a minute, hence the long waits.
test('the scene renders, audio unlocks on a click, no console errors', async ({ page }) => {
  test.setTimeout(120000);
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
  await page.keyboard.press('e'); // plants at the Dynamiter's feet
  await page.mouse.click(box.x + box.width * 0.55, box.y + box.height * 0.45); // walk off it
  await page.waitForTimeout(1200);
  await page.keyboard.press('c');
  await page.waitForTimeout(600);
  // click the guard nearest the middle of the screen so its vision cones show on the night map
  await page.evaluate(() => window.sierraProbe());
  const guards = await page.evaluate(() => window.sierraGuards);
  const centre = [640, 360];
  guards.sort((a, b) => Math.hypot(a[0] - centre[0], a[1] - centre[1]) - Math.hypot(b[0] - centre[0], b[1] - centre[1]));
  if (guards.length) await page.mouse.click(box.x + guards[0][0], box.y + guards[0][1]);
  await page.waitForTimeout(500);
  await page.screenshot({ path: 'build/e2e/final.png' });
  expect((await page.evaluate(() => { window.sierraProbe(); return window.sierraState; })).fuse).toMatch(/^Fuse: \d+s$/);
  // leave the blast and see the detonation from outside it
  await page.keyboard.press('c');
  await page.mouse.dblclick(box.x + box.width * 0.23, box.y + box.height * 0.75);
  await page.waitForFunction(() => {
    window.sierraProbe();
    return window.sierraState.message === 'The charge was too far from the bridge';
  }, null, { polling: 16, timeout: 80000 });
  await page.screenshot({ path: 'build/e2e/flash.png' });
  expect(errors).toEqual([]);
});
