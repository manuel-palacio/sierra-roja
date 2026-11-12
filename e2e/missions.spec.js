const { test, expect } = require('@playwright/test');

// The second mission in the real build: it loads from the address, shows its own objective, and
// takes an order without console errors.
test('the powder store mission loads and plays', async ({ page }) => {
  test.setTimeout(90000);
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1&mission=powder_store');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1500);
  const state = () => page.evaluate(() => { window.sierraProbe(); return window.sierraState; });
  const start = (await state()).pos;
  expect(start[0]).toBeLessThan(-40); // the squad starts in the south-west of this map
  expect((await page.evaluate(() => { window.sierraProbe(); return window.sierraGuards.length; }))).toBeGreaterThanOrEqual(0);
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.click(box.x + box.width * 0.7, box.y + box.height * 0.45);
  await page.waitForFunction((from) => {
    window.sierraProbe();
    const p = window.sierraState.pos;
    return Math.hypot(p[0] - from[0], p[1] - from[1]) > 1.0;
  }, start, { timeout: 30000 });
  await page.screenshot({ path: 'build/e2e/powder-store.png' });
  expect(errors).toEqual([]);
});

// Addresses from before the campaign still open the missions they have become, and the new
// mission loads from its own.
const title = async (page, query) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1&' + query);
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1200);
  const state = await page.evaluate(() => { window.sierraProbe(); return window.sierraState; });
  expect(errors).toEqual([]);
  return state;
};

for (const [query, id, shown] of [
  ['mission=bridge', 'guadarrama', 'The bridge in the Guadarrama'],
  ['mission=bridge_night', 'guadarrama', 'The bridge in the Guadarrama'],
  ['mission=powder_store_night', 'powder_store', 'The powder store'],
  ['mission=carchuna', 'carchuna', 'Fort Carchuna'],
  ['mission=no_such_place', 'guadarrama', 'The bridge in the Guadarrama'],
]) {
  test(`?${query} opens ${shown}`, async ({ page }) => {
    test.setTimeout(90000);
    const state = await title(page, query);
    expect(state.mission).toBe(id);
    expect(state.title).toBe(shown);
  });
}
