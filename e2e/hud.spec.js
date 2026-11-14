const { test, expect } = require('@playwright/test');

// Opens the game with ?probe=1 so the test can ask where a walking guard is on screen, clicks it
// (which shows its vision cone) and saves a screenshot of the map, HUD and cone for a human to read.
test('HUD, map and a vision cone draw', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1'); // serve drops the query from /index.html redirects, so use /
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
  const box = await page.locator('canvas').boundingBox();
  // A guard that is on the screen: a click outside the page takes the game's focus and pauses it.
  const [x, y] = await page.evaluate(() => {
    window.sierraProbe();
    return window.sierraGuards.find(([gx, gy]) => gx > 20 && gx < 1260 && gy > 80 && gy < 600);
  });
  await page.mouse.click(box.x + x, box.y + y);
  await page.waitForTimeout(400);
  await page.screenshot({ path: 'build/e2e/hud.png' });
  expect(errors).toEqual([]);
});
