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
