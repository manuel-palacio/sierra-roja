const { test, expect } = require('@playwright/test');

// The real build on a phone held sideways: the briefing tells of taps, a tap sends the squad
// walking, and a drag scrolls the view without ordering anything. Saves screenshots for a
// human to read.
test.use({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 3, hasTouch: true, isMobile: true });

const pos = (page) => page.evaluate(() => { window.sierraProbe(); return window.sierraState.pos; });

test('a phone gets the touch briefing, taps move the squad and drags only scroll', async ({ page }) => {
  test.setTimeout(90000);
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.goto('/?probe=1&briefing=1');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'build/e2e/touch-briefing.png' });

  // Start is the wide button low in the middle of the panel.
  await page.touchscreen.tap(422, 327);
  await page.waitForTimeout(600);
  await page.screenshot({ path: 'build/e2e/touch-hud.png' });

  const start = await pos(page);
  const client = await page.context().newCDPSession(page);
  const finger = (type, x, y) => client.send('Input.dispatchTouchEvent',
    { type, touchPoints: type === 'touchEnd' ? [] : [{ x, y }] });
  await finger('touchStart', 500, 200);
  for (let x = 500; x >= 380; x -= 20) await finger('touchMove', x, 200);
  await finger('touchEnd', 380, 200);
  await page.waitForTimeout(1200);
  const held = await pos(page);
  expect(Math.hypot(held[0] - start[0], held[1] - start[1])).toBeLessThan(0.1);

  await page.touchscreen.tap(560, 200);
  await page.waitForFunction((from) => {
    window.sierraProbe();
    const p = window.sierraState.pos;
    return Math.hypot(p[0] - from[0], p[1] - from[1]) > 1.0;
  }, start);
  await page.screenshot({ path: 'build/e2e/touch-moved.png' });
  expect(errors).toEqual([]);
});
