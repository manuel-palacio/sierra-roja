const { test, expect } = require('@playwright/test');

test('game boots with a visible canvas and no console errors', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto('/index.html');
  await expect(page.locator('canvas')).toBeVisible();
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForTimeout(500); // let the first frames run
  await expect(page.locator('#message')).toBeHidden();
  expect(errors).toEqual([]);
});

test('keys and clicks in the real build raise no console errors', async ({ page }) => {
  const errors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') errors.push(msg.text());
  });
  page.on('pageerror', (err) => errors.push(err.message));

  await page.goto('/index.html');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForTimeout(500);
  const box = await page.locator('canvas').boundingBox();
  const at = (fx, fy) => [box.x + box.width * fx, box.y + box.height * fy];
  await page.mouse.click(...at(0.5, 0.5));
  await page.mouse.dblclick(...at(0.4, 0.6));
  for (const key of ['1', '2', 'c', 'c', 'q', 'Escape', 'e', 'r', 'f', 'Space', 'Space', '1', 'e']) {
    await page.keyboard.press(key);
  }
  await page.mouse.click(...at(0.6, 0.4));
  await page.mouse.click(...at(0.5, 0.5), { button: 'right' });
  await page.mouse.wheel(0, -300);
  await page.mouse.wheel(0, 300);
  await page.mouse.move(...at(0.5, 0.5));
  await page.mouse.move(box.x + 2, box.y + 2);
  await page.waitForTimeout(500);
  await page.mouse.move(...at(0.5, 0.5));
  await page.waitForTimeout(500);
  expect(errors).toEqual([]);
});

test('shows a message when WebGL2 is unavailable', async ({ page }) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (type, ...args) {
      if (type === 'webgl2') return null;
      return original.call(this, type, ...args);
    };
  });

  await page.goto('/index.html');
  await expect(page.getByText('This game needs WebGL2')).toBeVisible();
});
