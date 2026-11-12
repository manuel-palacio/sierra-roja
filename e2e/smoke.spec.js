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
  await expect(page.locator('#status')).toBeHidden(); // the loading line goes once the game runs
  expect(errors).toEqual([]);
});

test('a progress bar fills while the game loads and goes when it runs', async ({ page }) => {
  // The engine file is held back so the bar can be seen part way.
  let release;
  const held = new Promise((resolve) => { release = resolve; });
  await page.route('**/index.wasm', async (route) => { await held; await route.continue(); });
  await page.goto('/index.html');
  await expect(page.locator('#status')).toBeVisible();
  await expect(page.locator('#bar')).toBeVisible();
  await expect(page.locator('#status h1')).toHaveText('Sierra Roja');
  const before = Number(await page.locator('#bar').getAttribute('aria-valuenow'));
  expect(before).toBeLessThan(100);
  release();
  await page.waitForFunction(() => window.sierraStarted === true);
  await expect(page.locator('#status')).toBeHidden();
  expect(Number(await page.locator('#bar').getAttribute('aria-valuenow'))).toBeGreaterThan(before);
});

test('an error while loading is put on the page with the browser it happened in', async ({ page }) => {
  // The engine's main script is made to fail, as a browser that cannot run it would.
  await page.route('**/index.js', (route) => route.fulfill({ contentType: 'application/javascript', body: 'throw new Error("engine script broke");' }));
  await page.goto('/index.html');
  await expect(page.locator('#message')).toContainText('The game could not start.');
  await expect(page.locator('#message')).toContainText('Mozilla/'); // the user agent line
  await expect(page.locator('canvas')).toBeHidden();
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

// Saves live in IndexedDB, which Godot writes to asynchronously after the file closes, plus a
// synchronous localStorage copy (see save_game.gd). The reload tests cover each path.
async function bootWithProbe(page) {
  await page.goto('/?probe=1');
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
}

const state = (page) => page.evaluate(() => { window.sierraProbe(); return window.sierraState; });

async function waitForMessage(page, text) {
  await page.waitForFunction((t) => {
    window.sierraProbe();
    return window.sierraState.message === t;
  }, text, { polling: 16 });
}

function collectErrors(page) {
  const errors = [];
  page.on('console', (msg) => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', (err) => errors.push(err.message));
  return errors;
}

test('quick save survives a move, a load and a page reload', async ({ page }) => {
  const errors = collectErrors(page);
  await bootWithProbe(page);
  const box = await page.locator('canvas').boundingBox();
  const saved = (await state(page)).pos;

  await page.keyboard.press('o');
  await waitForMessage(page, 'Game saved');

  await page.mouse.click(box.x + box.width * 0.6, box.y + box.height * 0.6);
  await page.waitForFunction((from) => {
    window.sierraProbe();
    const p = window.sierraState.pos;
    return Math.hypot(p[0] - from[0], p[1] - from[1]) > 1.0;
  }, saved);

  await page.keyboard.press('l');
  await waitForMessage(page, 'Game loaded');
  let now = (await state(page)).pos;
  expect(Math.hypot(now[0] - saved[0], now[1] - saved[1])).toBeLessThan(0.5);

  await page.reload();
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
  await page.keyboard.press('l');
  await waitForMessage(page, 'Game loaded');
  now = (await state(page)).pos;
  expect(Math.hypot(now[0] - saved[0], now[1] - saved[1])).toBeLessThan(0.5);
  expect(errors).toEqual([]);
});

test('a reload right after the saved message still finds the save', async ({ page }) => {
  const errors = collectErrors(page);
  await bootWithProbe(page);
  await page.keyboard.press('o');
  await waitForMessage(page, 'Game saved');
  await page.reload(); // no grace time at all
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
  await page.keyboard.press('l');
  await waitForMessage(page, 'Game loaded');
  expect(errors).toEqual([]);
});

test('the save reaches IndexedDB at user://quicksave.json and loads from there alone', async ({ page }) => {
  const errors = collectErrors(page);
  await bootWithProbe(page);
  await page.keyboard.press('o');
  await waitForMessage(page, 'Game saved');
  const keys = () => page.evaluate(() => new Promise((resolve, reject) => {
    const open = indexedDB.open('/userfs');
    open.onerror = () => reject(open.error);
    open.onsuccess = () => {
      const all = open.result.transaction('FILE_DATA').objectStore('FILE_DATA').getAllKeys();
      all.onsuccess = () => { open.result.close(); resolve(all.result); };
    };
  }));
  const saveFiles = async () => (await keys()).filter((k) => k.includes('/Sierra Roja/quicksave'));
  await expect.poll(saveFiles).toEqual(['/userfs/godot/app_userdata/Sierra Roja/quicksave.json']);
  await page.evaluate(() => localStorage.clear());
  await page.reload();
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForFunction(() => typeof window.sierraProbe === 'function');
  await page.waitForTimeout(500);
  await page.keyboard.press('l');
  await waitForMessage(page, 'Game loaded');
  expect(errors).toEqual([]);
});

test('a corrupt save offers a restart and raises no console errors', async ({ page }) => {
  const errors = collectErrors(page);
  await page.setViewportSize({ width: 1280, height: 720 });
  await bootWithProbe(page);
  await page.evaluate(() => localStorage.setItem('user://quicksave.json', '{ not json'));
  await page.keyboard.press('l');
  await waitForMessage(page, "This save can't be loaded. Restart the mission?");
  await page.waitForTimeout(200);
  await page.screenshot({ path: 'build/e2e/bad-save.png' });
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

test('refuses to start outside a secure context', async ({ page }) => {
  const errors = collectErrors(page);
  await page.addInitScript(() => {
    Object.defineProperty(window, 'isSecureContext', { value: false });
  });

  await page.goto('/index.html');
  await expect(page.locator('#message')).toHaveText('This game must be opened over HTTPS');
  await expect(page.locator('canvas')).toBeHidden();
  await page.waitForTimeout(1000); // long enough for the engine to have started, had it been asked
  expect(await page.evaluate(() => window.sierraStarted)).toBeUndefined();
  expect(errors).toEqual([]);
});
