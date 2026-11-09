const { test, expect } = require('@playwright/test');

// The opening screen in the real build: it holds every order until it is started, and Enter
// starts it. ?probe=1 alone skips the briefing; ?briefing=1 puts it up with the probe running.
const pos = (page) => page.evaluate(() => { window.sierraProbe(); return window.sierraState.pos; });

test('the briefing holds orders until Enter, then the game takes them', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/?probe=1&briefing=1');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'build/e2e/briefing.png' });

  const box = await page.locator('canvas').boundingBox();
  const ground = [box.x + box.width * 0.9, box.y + box.height * 0.5]; // beside the panel, east of the squad
  const start = await pos(page);
  await page.mouse.click(...ground);
  await page.keyboard.press('c');
  await page.waitForTimeout(1200);
  const held = await pos(page);
  expect(Math.hypot(held[0] - start[0], held[1] - start[1])).toBeLessThan(0.1);

  await page.keyboard.press('Enter');
  await page.waitForTimeout(300);
  await page.mouse.click(...ground);
  await page.waitForFunction((from) => {
    window.sierraProbe();
    const p = window.sierraState.pos;
    return Math.hypot(p[0] - from[0], p[1] - from[1]) > 1.0;
  }, start);
  await page.screenshot({ path: 'build/e2e/started.png' });
  expect(errors).toEqual([]);
});

test('a plain visit opens on the briefing and Space starts it without errors', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  await page.goto('/index.html');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForTimeout(800);
  await page.keyboard.press('Space');
  await page.waitForTimeout(300);
  const box = await page.locator('canvas').boundingBox();
  await page.mouse.click(box.x + box.width * 0.4, box.y + box.height * 0.6);
  await page.waitForTimeout(500);
  expect(errors).toEqual([]);
});
