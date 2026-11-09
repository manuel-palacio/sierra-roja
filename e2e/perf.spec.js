const { test, expect } = require('@playwright/test');

// Headless Chromium falls back to software WebGL (SwiftShader) and throttles requestAnimationFrame
// (a blank page only reaches ~10-20 fps there), so the headless figure is a floor rather than a
// final answer. By default this test runs headed, which gets hardware WebGL (Metal on the mini)
// and a real frame rate. Set PERF_HEADLESS=1 for the headless floor (expected to fail the 30 fps
// bar on the mini). The renderer string is logged so the figure can be read in context.
test.use({ headless: process.env.PERF_HEADLESS === '1' });

test('runs at 30 fps or better with all guards patrolling', async ({ page }) => {
  test.setTimeout(60000);
  await page.goto('/?perf=1') // serve redirects /index.html and drops the query;
  await page.waitForFunction(() => window.sierraStarted === true);
  await page.waitForTimeout(20000); // guards patrol the whole time

  const renderer = await page.evaluate(() => {
    const gl = document.createElement('canvas').getContext('webgl2');
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    return ext
      ? `${gl.getParameter(ext.UNMASKED_VENDOR_WEBGL)} / ${gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)}`
      : gl.getParameter(gl.RENDERER);
  });
  const perf = await page.evaluate(() => window.sierraPerf());
  console.log(`WebGL renderer: ${renderer}`);
  console.log(`fps: ${perf.fps.toFixed(1)} over ${perf.frames} frames`);
  console.log(`guards: ${perf.guards}, displacement over window: ${perf.displacement.toFixed(2)} m`);
  expect(perf.guards).toBe(5);
  expect(perf.displacement).toBeGreaterThan(0);
  expect(perf.fps).toBeGreaterThanOrEqual(30);
});
